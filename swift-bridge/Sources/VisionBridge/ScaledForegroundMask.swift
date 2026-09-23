// Scaled foreground-instance mask bridge.
//
// Wraps `-[VNInstanceMaskObservation generateScaledMaskForImageForInstances:fromRequestHandler:error:]`,
// which renders the foreground mask at the source image's dimensions (NOT the
// inference resolution), with anti-aliased edges produced by Apple's internal
// upsampler. This is the API behind Finder's "Remove Background" Quick Action.
//
// That API returns a single-channel `kCVPixelFormatType_OneComponent32Float`
// buffer (values 0.0...1.0) and offers no `outputPixelFormat` override. The
// rest of this crate's `SegmentationMask` contract is an 8-bit `Vec<u8>`
// (0 = background, 255 = foreground), so we normalise the float buffer to
// OneComponent8.
//
// To avoid a double copy (Swift-side allocation + Rust `to_vec`), the bridge
// is split into a begin/finish pair: `begin` runs the request and retains the
// mask pixel buffer, reporting its dimensions; the Rust side then allocates
// the destination `Vec<u8>` and `finish` converts/copies the mask *directly*
// into that buffer — a single copy — before releasing the retained buffer.

import CoreGraphics
import CoreVideo
import Foundation
import Vision

/// Convert/copy a single-channel mask pixel buffer into a tightly packed 8-bit
/// (0...255) destination, one byte per pixel.
///
/// `OneComponent32Float` (what `generateScaledMaskForImage` returns) and
/// `OneComponent16Half` are scaled and clamped to `[0, 255]`; an already 8-bit
/// buffer is copied row-by-row.
/// `capacity` is the number of `UInt8` slots in `dst`; the function writes at
/// most `width * height` bytes and fails if `dst` is too small.
internal func fillOne8(
    from buffer: CVPixelBuffer,
    into dst: UnsafeMutablePointer<UInt8>,
    capacity: Int
) -> Int32 {
    let width = CVPixelBufferGetWidth(buffer)
    let height = CVPixelBufferGetHeight(buffer)
    let (pixelCount, overflow) = width.multipliedReportingOverflow(by: height)
    guard !overflow, pixelCount <= capacity else { return VN_INVALID_ARGUMENT }
    let format = CVPixelBufferGetPixelFormatType(buffer)
    let bytesPerPixel: Int
    switch format {
    case kCVPixelFormatType_OneComponent8:
        bytesPerPixel = 1
    case kCVPixelFormatType_OneComponent16Half:
        bytesPerPixel = 2
    case kCVPixelFormatType_OneComponent32Float:
        bytesPerPixel = 4
    default:
        return VN_REQUEST_FAILED
    }
    guard CVPixelBufferLockBaseAddress(buffer, .readOnly) == kCVReturnSuccess else {
        return VN_REQUEST_FAILED
    }
    defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
    guard let base = CVPixelBufferGetBaseAddress(buffer) else { return VN_REQUEST_FAILED }
    let srcBytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
    guard srcBytesPerRow >= width * bytesPerPixel else { return VN_REQUEST_FAILED }

    for y in 0..<height {
        let srcRow = base.advanced(by: y * srcBytesPerRow)
        let dstRow = dst.advanced(by: y * width)
        switch format {
        case kCVPixelFormatType_OneComponent8:
            memcpy(dstRow, srcRow, width)
        case kCVPixelFormatType_OneComponent16Half:
            let halves = srcRow.assumingMemoryBound(to: UInt16.self)
            for x in 0..<width {
                dstRow[x] = unitToByte(halfToFloat(halves[x]))
            }
        default:
            let floats = srcRow.assumingMemoryBound(to: Float32.self)
            for x in 0..<width {
                dstRow[x] = unitToByte(floats[x])
            }
        }
    }
    return VN_OK
}

internal func unitToByte(_ value: Float32) -> UInt8 {
    if value.isNaN {
        return 0
    }
    return UInt8(min(max((value * 255.0).rounded(), 0.0), 255.0))
}

internal func halfToFloat(_ bits: UInt16) -> Float32 {
    let sign = UInt32(bits & 0x8000) << 16
    let exponent = UInt32(bits >> 10) & 0x1F
    let mantissa = UInt32(bits & 0x03FF)
    if exponent == 0 {
        let magnitude = Float32(mantissa) * Float32(bitPattern: 0x3380_0000)
        return sign == 0 ? magnitude : -magnitude
    }
    if exponent == 0x1F {
        return Float32(bitPattern: sign | 0x7F80_0000 | (mantissa << 13))
    }
    return Float32(bitPattern: sign | ((exponent + 112) << 23) | (mantissa << 13))
}

@available(macOS 14.0, *)
internal func beginScaledMask(
    of observation: VNInstanceMaskObservation,
    from handler: VNImageRequestHandler,
    _ outHasValue: UnsafeMutablePointer<Bool>,
    _ outWidth: UnsafeMutablePointer<Int32>,
    _ outHeight: UnsafeMutablePointer<Int32>,
    _ outHandle: UnsafeMutablePointer<UnsafeMutableRawPointer?>,
    _ outErrorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    let instances = observation.allInstances
    if instances.isEmpty {
        return VN_OK
    }
    let scaled: CVPixelBuffer
    do {
        scaled = try observation.generateScaledMaskForImage(forInstances: instances, from: handler)
    } catch {
        outErrorMessage?.pointee = ffiString(
            "generateScaledMaskForImage failed: \(error.localizedDescription)")
        return VN_REQUEST_FAILED
    }
    guard let width = Int32(exactly: CVPixelBufferGetWidth(scaled)),
          let height = Int32(exactly: CVPixelBufferGetHeight(scaled)) else {
        outErrorMessage?.pointee = ffiString("scaled mask is too large")
        return VN_REQUEST_FAILED
    }
    outWidth.pointee = width
    outHeight.pointee = height
    outHandle.pointee = Unmanaged.passRetained(scaled).toOpaque()
    outHasValue.pointee = true
    return VN_OK
}

/// Phase 1: run the foreground-instance-mask request, scale the union mask to
/// source resolution, and (when a subject is found) retain the resulting pixel
/// buffer, reporting its dimensions and an opaque handle. The caller MUST pass
/// that handle to `vn_scaled_foreground_mask_finish` exactly once to copy out
/// the data and release the buffer.
@_cdecl("vn_scaled_foreground_mask_begin")
public func vn_scaled_foreground_mask_begin(
    _ path: UnsafePointer<CChar>,
    _ outHasValue: UnsafeMutablePointer<Bool>,
    _ outWidth: UnsafeMutablePointer<Int32>,
    _ outHeight: UnsafeMutablePointer<Int32>,
    _ outHandle: UnsafeMutablePointer<UnsafeMutableRawPointer?>,
    _ outErrorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    outHasValue.pointee = false
    outWidth.pointee = 0
    outHeight.pointee = 0
    outHandle.pointee = nil

    if #unavailable(macOS 14.0) {
        outErrorMessage?.pointee = ffiString("scaled foreground mask requires macOS 14+")
        return VN_REQUEST_FAILED
    }
    let pathStr = String(cString: path)
    guard let cgImage = loadCGImage(path: pathStr) else {
        outErrorMessage?.pointee = ffiString("could not load image at \(pathStr)")
        return VN_IMAGE_LOAD_FAILED
    }
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    if #available(macOS 14.0, *) {
        let request = VNGenerateForegroundInstanceMaskRequest()
        do { try handler.perform([request]) } catch {
            outErrorMessage?.pointee = ffiString("foreground mask failed: \(error.localizedDescription)")
            return VN_REQUEST_FAILED
        }
        guard let obs = request.results?.first else {
            return VN_OK
        }
        return beginScaledMask(
            of: obs, from: handler, outHasValue, outWidth, outHeight, outHandle, outErrorMessage)
    }
    return VN_OK
}

/// Phase 2: convert/copy the mask retained by `vn_scaled_foreground_mask_begin`
/// or `vn_person_instance_mask_begin` directly into the caller-provided 8-bit
/// `dst` (capacity `dstLen` bytes), then release the retained pixel buffer.
/// Must be called exactly once per non-null handle returned by `begin`.
@_cdecl("vn_scaled_foreground_mask_finish")
public func vn_scaled_foreground_mask_finish(
    _ handle: UnsafeMutableRawPointer,
    _ dst: UnsafeMutablePointer<UInt8>?,
    _ dstLen: Int
) -> Int32 {
    let buffer = Unmanaged<CVPixelBuffer>.fromOpaque(handle).takeRetainedValue()
    guard let dst else { return VN_INVALID_ARGUMENT }
    return fillOne8(from: buffer, into: dst, capacity: dstLen)
}

/// Test-only helper: build a single-channel pixel buffer of `pixelFormat` from
/// `values` (row-major, `width * bytesPerPixel` bytes per row) and run it
/// through `fillOne8`, writing the normalised 8-bit result directly into the
/// caller-provided `dst`. Lets the Rust test suite verify the conversion
/// deterministically, without depending on the Vision segmentation model
/// detecting a subject.
@_cdecl("vn_test_helper_fill_one8")
public func vn_test_helper_fill_one8(
    _ values: UnsafeRawPointer,
    _ pixelFormat: UInt32,
    _ bytesPerPixel: Int32,
    _ width: Int32,
    _ height: Int32,
    _ dst: UnsafeMutablePointer<UInt8>,
    _ dstLen: Int
) -> Int32 {
    let w = Int(width)
    let h = Int(height)
    let rowBytes = w * Int(bytesPerPixel)
    var pixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(kCFAllocatorDefault, w, h, pixelFormat, nil, &pixelBuffer)
    guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
        return VN_UNKNOWN
    }
    guard CVPixelBufferLockBaseAddress(buffer, []) == kCVReturnSuccess else {
        return VN_UNKNOWN
    }
    if let base = CVPixelBufferGetBaseAddress(buffer) {
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        for y in 0..<h {
            memcpy(base.advanced(by: y * bytesPerRow), values.advanced(by: y * rowBytes), rowBytes)
        }
    }
    CVPixelBufferUnlockBaseAddress(buffer, [])
    return fillOne8(from: buffer, into: dst, capacity: dstLen)
}
