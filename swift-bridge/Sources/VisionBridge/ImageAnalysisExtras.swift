// Additional text/saliency/mask bridges added in the v0.13 coverage sweep.

import AppKit
import CoreGraphics
import CoreImage
import CoreML
import CoreVideo
import Foundation
import ImageIO
import Vision

// MARK: - Text rectangles (region-only, no OCR)

@_cdecl("vn_detect_text_rectangles_in_path")
public func vn_detect_text_rectangles_in_path(
    _ path: UnsafePointer<CChar>,
    _ reports_character_boxes: Bool,
    _ out_rects_raw: UnsafeMutableRawPointer,
    _ out_count: UnsafeMutablePointer<Int>,
    _ outErrorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    let out_rects = out_rects_raw.assumingMemoryBound(to: UnsafeMutablePointer<VNSimpleRectRaw>?.self)
    out_rects.pointee = nil
    out_count.pointee = 0
    let p = String(cString: path)
    guard let img = loadCGImage(path: p) else {
        outErrorMessage?.pointee = ffiString("could not load image at \(p)")
        return VN_IMAGE_LOAD_FAILED
    }
    let req = VNDetectTextRectanglesRequest()
    req.reportCharacterBoxes = reports_character_boxes
    let handler = VNImageRequestHandler(cgImage: img, options: [:])
    do { try handler.perform([req]) } catch {
        outErrorMessage?.pointee = ffiString("text rectangles request failed: \(error.localizedDescription)")
        return VN_REQUEST_FAILED
    }
    guard let obs = req.results else { return VN_OK }
    var rects = obs.map { mkRect($0.boundingBox, $0.confidence) }
    if rects.isEmpty { return VN_OK }
    let buf = UnsafeMutablePointer<VNSimpleRectRaw>.allocate(capacity: rects.count)
    buf.initialize(from: &rects, count: rects.count)
    out_rects.pointee = buf
    out_count.pointee = rects.count
    return VN_OK
}

// MARK: - Objectness-based saliency

@_cdecl("vn_objectness_saliency_in_path")
public func vn_objectness_saliency_in_path(
    _ path: UnsafePointer<CChar>,
    _ out_rects_raw: UnsafeMutableRawPointer,
    _ out_count: UnsafeMutablePointer<Int>,
    _ outErrorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    let out_rects = out_rects_raw.assumingMemoryBound(to: UnsafeMutablePointer<VNSimpleRectRaw>?.self)
    out_rects.pointee = nil
    out_count.pointee = 0
    let p = String(cString: path)
    guard let img = loadCGImage(path: p) else {
        outErrorMessage?.pointee = ffiString("could not load image at \(p)")
        return VN_IMAGE_LOAD_FAILED
    }
    let req = VNGenerateObjectnessBasedSaliencyImageRequest()
    let handler = VNImageRequestHandler(cgImage: img, options: [:])
    do { try handler.perform([req]) } catch {
        outErrorMessage?.pointee = ffiString("objectness saliency request failed: \(error.localizedDescription)")
        return VN_REQUEST_FAILED
    }
    guard let obs = req.results?.first, let regions = obs.salientObjects else { return VN_OK }
    var rects = regions.map { mkRect($0.boundingBox, $0.confidence) }
    if rects.isEmpty { return VN_OK }
    let buf = UnsafeMutablePointer<VNSimpleRectRaw>.allocate(capacity: rects.count)
    buf.initialize(from: &rects, count: rects.count)
    out_rects.pointee = buf
    out_count.pointee = rects.count
    return VN_OK
}

// MARK: - Person instance mask (macOS 14+)

/// Writes a packed 8-bit per-pixel mask. Caller must `free()` the buffer.
@_cdecl("vn_person_instance_mask_in_path")
public func vn_person_instance_mask_in_path(
    _ path: UnsafePointer<CChar>,
    _ out_width: UnsafeMutablePointer<Int>,
    _ out_height: UnsafeMutablePointer<Int>,
    _ out_bytes_per_row: UnsafeMutablePointer<Int>,
    _ out_data: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
    _ outErrorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    out_width.pointee = 0
    out_height.pointee = 0
    out_bytes_per_row.pointee = 0
    out_data.pointee = nil
    if #available(macOS 14.0, *) {
        let p = String(cString: path)
        guard let img = loadCGImage(path: p) else {
            outErrorMessage?.pointee = ffiString("could not load image at \(p)")
            return VN_IMAGE_LOAD_FAILED
        }
        let req = VNGeneratePersonInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: img, options: [:])
        do { try handler.perform([req]) } catch {
            outErrorMessage?.pointee = ffiString("person instance mask request failed: \(error.localizedDescription)")
            return VN_REQUEST_FAILED
        }
        guard let obs = req.results?.first else { return VN_OK }
        let allInstances = obs.allInstances
        if allInstances.isEmpty { return VN_OK }
        guard let pb = try? obs.generateScaledMaskForImage(forInstances: allInstances, from: handler) else {
            return VN_OK
        }
        CVPixelBufferLockBaseAddress(pb, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
        let w = CVPixelBufferGetWidth(pb)
        let h = CVPixelBufferGetHeight(pb)
        let bpr = CVPixelBufferGetBytesPerRow(pb)
        guard let base = CVPixelBufferGetBaseAddress(pb) else { return VN_OK }
        let size = bpr * h
        let data = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        data.initialize(from: base.assumingMemoryBound(to: UInt8.self), count: size)
        out_width.pointee = w
        out_height.pointee = h
        out_bytes_per_row.pointee = bpr
        out_data.pointee = data
        return VN_OK
    }
    return VN_REQUEST_FAILED
}

@_cdecl("vn_mask_buffer_free")
public func vn_mask_buffer_free(_ ptr: UnsafeMutablePointer<UInt8>?, _ size: Int) {
    guard let ptr = ptr else { return }
    ptr.deinitialize(count: size)
    ptr.deallocate()
}
