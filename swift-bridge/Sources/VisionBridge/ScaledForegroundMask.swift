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
// OneComponent8 here rather than memcpy'ing raw float bytes through a u8 API.

import CoreGraphics
import CoreVideo
import Foundation
import Vision

/// Convert a scaled foreground mask pixel buffer into an 8-bit (0...255)
/// `VNSegmentationMaskRaw`, tightly packed at one byte per pixel.
///
/// Handles `OneComponent32Float` (the format `generateScaledMaskForImage`
/// returns) by scaling and clamping to `[0, 255]`, and passes an already
/// 8-bit buffer through unchanged. The returned `bytes` are owned by the
/// caller and freed via `vn_segmentation_mask_free`.
internal func scaledMaskToOne8(_ buffer: CVPixelBuffer) -> VNSegmentationMaskRaw {
    let width = CVPixelBufferGetWidth(buffer)
    let height = CVPixelBufferGetHeight(buffer)
    let format = CVPixelBufferGetPixelFormatType(buffer)

    if format == kCVPixelFormatType_OneComponent8 {
        return copyCVPixelBufferToBytes(buffer)
    }

    CVPixelBufferLockBaseAddress(buffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
    guard let base = CVPixelBufferGetBaseAddress(buffer) else {
        return VNSegmentationMaskRaw(width: width, height: height,
                                     bytes_per_row: width, bytes: nil)
    }
    let srcBytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
    let dstBytesPerRow = width
    let out = UnsafeMutableRawPointer.allocate(byteCount: height * dstBytesPerRow, alignment: 8)
    let dst = out.assumingMemoryBound(to: UInt8.self)
    for y in 0..<height {
        let srcRow = base.advanced(by: y * srcBytesPerRow)
            .assumingMemoryBound(to: Float32.self)
        let dstRow = dst.advanced(by: y * dstBytesPerRow)
        for x in 0..<width {
            let scaled = (srcRow[x] * 255.0).rounded()
            dstRow[x] = UInt8(min(max(scaled, 0.0), 255.0))
        }
    }
    return VNSegmentationMaskRaw(width: width, height: height,
                                 bytes_per_row: dstBytesPerRow, bytes: out)
}

@_cdecl("vn_generate_scaled_foreground_mask_in_path")
public func vn_generate_scaled_foreground_mask_in_path(
    _ path: UnsafePointer<CChar>,
    _ outMaskRaw: UnsafeMutableRawPointer,
    _ outHasValue: UnsafeMutablePointer<Bool>,
    _ outErrorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    let outMask = outMaskRaw.assumingMemoryBound(to: VNSegmentationMaskRaw.self)
    if #unavailable(macOS 14.0) {
        outErrorMessage?.pointee = ffiString("scaled foreground mask requires macOS 14+")
        outHasValue.pointee = false
        return VN_REQUEST_FAILED
    }
    let pathStr = String(cString: path)
    guard let cgImage = loadCGImage(path: pathStr) else {
        outErrorMessage?.pointee = ffiString("could not load image at \(pathStr)")
        outHasValue.pointee = false
        return VN_IMAGE_LOAD_FAILED
    }
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    if #available(macOS 14.0, *) {
        let request = VNGenerateForegroundInstanceMaskRequest()
        do { try handler.perform([request]) } catch {
            outErrorMessage?.pointee = ffiString("foreground mask failed: \(error.localizedDescription)")
            outHasValue.pointee = false
            return VN_REQUEST_FAILED
        }
        guard let obs = request.results?.first else {
            outHasValue.pointee = false
            return VN_OK
        }
        let scaled: CVPixelBuffer
        do {
            scaled = try obs.generateScaledMaskForImage(
                forInstances: obs.allInstances, from: handler)
        } catch {
            outErrorMessage?.pointee = ffiString(
                "generateScaledMaskForImage failed: \(error.localizedDescription)")
            outHasValue.pointee = false
            return VN_REQUEST_FAILED
        }
        outMask.pointee = scaledMaskToOne8(scaled)
        outHasValue.pointee = true
    }
    return VN_OK
}

/// Test-only helper: build a `OneComponent32Float` pixel buffer from `floats`
/// (row-major, `width * height` values in 0.0...1.0) and run it through
/// `scaledMaskToOne8`, writing the resulting 8-bit `VNSegmentationMaskRaw` to
/// `outMaskRaw`. Lets the Rust test suite verify the float→u8 normalisation
/// deterministically, without depending on the Vision segmentation model
/// detecting a subject. The caller frees `bytes` via `vn_segmentation_mask_free`.
@_cdecl("vn_test_helper_scaled_mask_to_one8")
public func vn_test_helper_scaled_mask_to_one8(
    _ floats: UnsafePointer<Float32>,
    _ width: Int32,
    _ height: Int32,
    _ outMaskRaw: UnsafeMutableRawPointer
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
    let outMask = outMaskRaw.assumingMemoryBound(to: VNSegmentationMaskRaw.self)
    outMask.pointee = scaledMaskToOne8(buffer)
    return VN_OK
}
