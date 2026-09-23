// Segmentation and optical-flow bridges.

import AppKit
import CoreGraphics
import CoreImage
import CoreML
import CoreVideo
import Foundation
import ImageIO
import Vision

// MARK: - Person segmentation (v0.10)

@frozen
public struct VNSegmentationMaskRaw {
    public var width: Int
    public var height: Int
    public var bytes_per_row: Int
    /// Newly-allocated buffer of `height * bytes_per_row` bytes.
    /// Caller frees via `vn_segmentation_mask_free`.
    public var bytes: UnsafeMutableRawPointer?
}

private func copyCVPixelBufferToBytes(_ buffer: CVPixelBuffer) -> VNSegmentationMaskRaw {
    let width = CVPixelBufferGetWidth(buffer)
    let height = CVPixelBufferGetHeight(buffer)
    let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
    CVPixelBufferLockBaseAddress(buffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
    guard let base = CVPixelBufferGetBaseAddress(buffer) else {
        return VNSegmentationMaskRaw(width: width, height: height,
                                     bytes_per_row: bytesPerRow, bytes: nil)
    }
    let size = height * bytesPerRow
    let out = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 8)
    memcpy(out, base, size)
    return VNSegmentationMaskRaw(
        width: width, height: height,
        bytes_per_row: bytesPerRow, bytes: out)
}

/// Quality levels for person segmentation: 0=fast, 1=balanced, 2=accurate.
@_cdecl("vn_generate_person_segmentation_in_path")
public func vn_generate_person_segmentation_in_path(
    _ path: UnsafePointer<CChar>,
    _ qualityLevel: Int32,
    _ outMaskRaw: UnsafeMutableRawPointer,
    _ outHasValue: UnsafeMutablePointer<Bool>,
    _ outErrorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    let outMask = outMaskRaw.assumingMemoryBound(to: VNSegmentationMaskRaw.self)
    let pathStr = String(cString: path)
    guard let cgImage = loadCGImage(path: pathStr) else {
        outErrorMessage?.pointee = ffiString("could not load image at \(pathStr)")
        outHasValue.pointee = false
        return VN_IMAGE_LOAD_FAILED
    }
    let handler = VNImageRequestHandler(cgImage: cgImage, orientation: imageOrientation(path: pathStr), options: [:])
    let request = VNGeneratePersonSegmentationRequest()
    if let lvl = VNGeneratePersonSegmentationRequest.QualityLevel(rawValue: UInt(qualityLevel)) {
        request.qualityLevel = lvl
    }
    // 8bppONE mask format (kCVPixelFormatType_OneComponent8).
    request.outputPixelFormat = kCVPixelFormatType_OneComponent8
    do { try handler.perform([request]) } catch {
        outErrorMessage?.pointee = ffiString("person segmentation failed: \(error.localizedDescription)")
        outHasValue.pointee = false
        return VN_REQUEST_FAILED
    }
    guard let obs = request.results?.first else {
        outHasValue.pointee = false
        return VN_OK
    }
    outMask.pointee = copyCVPixelBufferToBytes(obs.pixelBuffer)
    outHasValue.pointee = true
    return VN_OK
}

@_cdecl("vn_generate_foreground_instance_mask_in_path")
public func vn_generate_foreground_instance_mask_in_path(
    _ path: UnsafePointer<CChar>,
    _ outMaskRaw: UnsafeMutableRawPointer,
    _ outInstanceCount: UnsafeMutablePointer<Int>,
    _ outHasValue: UnsafeMutablePointer<Bool>,
    _ outErrorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    let outMask = outMaskRaw.assumingMemoryBound(to: VNSegmentationMaskRaw.self)
    if #unavailable(macOS 14.0) {
        outErrorMessage?.pointee = ffiString("foreground instance mask requires macOS 14+")
        outHasValue.pointee = false
        return VN_REQUEST_FAILED
    }
    let pathStr = String(cString: path)
    guard let cgImage = loadCGImage(path: pathStr) else {
        outErrorMessage?.pointee = ffiString("could not load image at \(pathStr)")
        outHasValue.pointee = false
        return VN_IMAGE_LOAD_FAILED
    }
    let handler = VNImageRequestHandler(cgImage: cgImage, orientation: imageOrientation(path: pathStr), options: [:])
    if #available(macOS 14.0, *) {
        let request = VNGenerateForegroundInstanceMaskRequest()
        do { try handler.perform([request]) } catch {
            outErrorMessage?.pointee = ffiString("foreground mask failed: \(error.localizedDescription)")
            outHasValue.pointee = false
            return VN_REQUEST_FAILED
        }
        guard let obs = request.results?.first else {
            outHasValue.pointee = false
            outInstanceCount.pointee = 0
            return VN_OK
        }
        outMask.pointee = copyCVPixelBufferToBytes(obs.instanceMask)
        outInstanceCount.pointee = obs.allInstances.count
        outHasValue.pointee = true
    }
    return VN_OK
}

@_cdecl("vn_segmentation_mask_free")
public func vn_segmentation_mask_free(_ mask: UnsafeMutableRawPointer) {
    let typed = mask.assumingMemoryBound(to: VNSegmentationMaskRaw.self)
    if let b = typed.pointee.bytes {
        b.deallocate()
        typed.pointee.bytes = nil
    }
}

// MARK: - Optical flow (v0.11)
//
// Two-frame request: frame A -> handler, frame B -> targeted request.
// computationAccuracy: 0=low, 1=medium, 2=high, 3=veryHigh.

@_cdecl("vn_generate_optical_flow_in_paths")
public func vn_generate_optical_flow_in_paths(
    _ pathA: UnsafePointer<CChar>,
    _ pathB: UnsafePointer<CChar>,
    _ computationAccuracy: Int32,
    _ outMaskRaw: UnsafeMutableRawPointer,
    _ outHasValue: UnsafeMutablePointer<Bool>,
    _ outErrorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    let outMask = outMaskRaw.assumingMemoryBound(to: VNSegmentationMaskRaw.self)
    let aStr = String(cString: pathA)
    let bStr = String(cString: pathB)
    guard let aImage = loadCGImage(path: aStr) else {
        outErrorMessage?.pointee = ffiString("could not load image A at \(aStr)")
        outHasValue.pointee = false
        return VN_IMAGE_LOAD_FAILED
    }
    guard let bImage = loadCGImage(path: bStr) else {
        outErrorMessage?.pointee = ffiString("could not load image B at \(bStr)")
        outHasValue.pointee = false
        return VN_IMAGE_LOAD_FAILED
    }
    let handler = VNImageRequestHandler(cgImage: aImage, orientation: imageOrientation(path: aStr), options: [:])
    let request = VNGenerateOpticalFlowRequest(targetedCGImage: bImage, orientation: imageOrientation(path: bStr), options: [:])
    if let lvl = VNGenerateOpticalFlowRequest.ComputationAccuracy(rawValue: UInt(computationAccuracy)) {
        request.computationAccuracy = lvl
    }
    request.outputPixelFormat = kCVPixelFormatType_TwoComponent32Float
    do { try handler.perform([request]) } catch {
        outErrorMessage?.pointee = ffiString("optical flow request failed: \(error.localizedDescription)")
        outHasValue.pointee = false
        return VN_REQUEST_FAILED
    }
    guard let obs = request.results?.first else {
        outHasValue.pointee = false
        return VN_OK
    }
    guard CVPixelBufferGetPixelFormatType(obs.pixelBuffer) == kCVPixelFormatType_TwoComponent32Float else {
        outErrorMessage?.pointee = ffiString("optical flow returned an unexpected pixel format")
        outHasValue.pointee = false
        return VN_REQUEST_FAILED
    }
    outMask.pointee = copyCVPixelBufferToBytes(obs.pixelBuffer)
    outHasValue.pointee = true
    return VN_OK
}
