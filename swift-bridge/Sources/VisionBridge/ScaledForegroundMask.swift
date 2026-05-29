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
/// `OneComponent32Float` (what `generateScaledMaskForImage` returns) is scaled
/// and clamped to `[0, 255]`; an already 8-bit buffer is copied row-by-row.
/// `capacity` is the number of `UInt8` slots in `dst`; the function writes at
/// most `width * height` bytes and no-ops if `dst` is too small.
internal func fillOne8(
    from buffer: CVPixelBuffer,
    into dst: UnsafeMutablePointer<UInt8>,
    capacity: Int
) {
    let width = CVPixelBufferGetWidth(buffer)
    let height = CVPixelBufferGetHeight(buffer)
    guard width * height <= capacity else { return }
    let format = CVPixelBufferGetPixelFormatType(buffer)
    CVPixelBufferLockBaseAddress(buffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
    guard let base = CVPixelBufferGetBaseAddress(buffer) else { return }
    let srcBytesPerRow = CVPixelBufferGetBytesPerRow(buffer)

    if format == kCVPixelFormatType_OneComponent8 {
        for y in 0..<height {
            memcpy(dst.advanced(by: y * width),
                   base.advanced(by: y * srcBytesPerRow),
                   width)
        }
        return
    }

    for y in 0..<height {
        let srcRow = base.advanced(by: y * srcBytesPerRow)
            .assumingMemoryBound(to: Float32.self)
        let dstRow = dst.advanced(by: y * width)
        for x in 0..<width {
            let scaled = (srcRow[x] * 255.0).rounded()
            dstRow[x] = UInt8(min(max(scaled, 0.0), 255.0))
        }
    }
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
        let scaled: CVPixelBuffer
        do {
            scaled = try obs.generateScaledMaskForImage(
                forInstances: obs.allInstances, from: handler)
        } catch {
            outErrorMessage?.pointee = ffiString(
                "generateScaledMaskForImage failed: \(error.localizedDescription)")
            return VN_REQUEST_FAILED
        }
        outWidth.pointee = Int32(CVPixelBufferGetWidth(scaled))
        outHeight.pointee = Int32(CVPixelBufferGetHeight(scaled))
        outHandle.pointee = Unmanaged.passRetained(scaled).toOpaque()
        outHasValue.pointee = true
    }
    return VN_OK
}

/// Phase 2: convert/copy the mask retained by `vn_scaled_foreground_mask_begin`
/// directly into the caller-provided 8-bit `dst` (capacity `dstLen` bytes),
/// then release the retained pixel buffer. Must be called exactly once per
/// non-null handle returned by `begin`.
@_cdecl("vn_scaled_foreground_mask_finish")
public func vn_scaled_foreground_mask_finish(
    _ handle: UnsafeMutableRawPointer,
    _ dst: UnsafeMutablePointer<UInt8>,
    _ dstLen: Int
) {
    let buffer = Unmanaged<CVPixelBuffer>.fromOpaque(handle).takeRetainedValue()
    fillOne8(from: buffer, into: dst, capacity: dstLen)
}

/// Test-only helper: build a `OneComponent32Float` pixel buffer from `floats`
/// (row-major, `width * height` values in 0.0...1.0) and run it through
/// `fillOne8`, writing the normalised 8-bit result directly into the
/// caller-provided `dst`. Lets the Rust test suite verify the float→u8
/// conversion deterministically, without depending on the Vision segmentation
/// model detecting a subject.
@_cdecl("vn_test_helper_fill_one8_from_floats")
public func vn_test_helper_fill_one8_from_floats(
    _ floats: UnsafePointer<Float32>,
    _ width: Int32,
    _ height: Int32,
    _ dst: UnsafeMutablePointer<UInt8>,
    _ dstLen: Int
) -> Int32 {
    let w = Int(width)
    let h = Int(height)
    var pixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(
        kCFAllocatorDefault, w, h,
        kCVPixelFormatType_OneComponent32Float, nil, &pixelBuffer)
    guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
        return VN_UNKNOWN
    }
    CVPixelBufferLockBaseAddress(buffer, [])
    if let base = CVPixelBufferGetBaseAddress(buffer) {
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        for y in 0..<h {
            let row = base.advanced(by: y * bytesPerRow)
                .assumingMemoryBound(to: Float32.self)
            for x in 0..<w { row[x] = floats[y * w + x] }
        }
    }
    CVPixelBufferUnlockBaseAddress(buffer, [])
    fillOne8(from: buffer, into: dst, capacity: dstLen)
    return VN_OK
}
