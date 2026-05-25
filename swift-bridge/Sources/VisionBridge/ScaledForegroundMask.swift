// Scaled foreground-instance mask bridge.
//
// Wraps `-[VNInstanceMaskObservation generateScaledMaskForImageForInstances:fromRequestHandler:error:]`,
// which returns a single-channel 8-bit alpha mask at the source image's
// dimensions (NOT the inference resolution). 0 = background, 255 = foreground,
// with anti-aliased edges produced by Apple's internal upsampler. This is the
// API behind Finder's "Remove Background" Quick Action.

import CoreGraphics
import CoreVideo
import Foundation
import Vision

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
        outMask.pointee = copyCVPixelBufferToBytes(scaled)
        outHasValue.pointee = true
    }
    return VN_OK
}
