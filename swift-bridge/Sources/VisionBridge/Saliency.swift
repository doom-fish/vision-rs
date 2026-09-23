// Saliency bridge and test-render helper.

import AppKit
import CoreGraphics
import CoreImage
import CoreML
import CoreVideo
import Foundation
import ImageIO
import Vision

// MARK: - Saliency (v0.5)

/// One salient region. Matches `SaliencyRegionRaw` in src/ffi/mod.rs.
@frozen
public struct VNSaliencyRegionRaw {
    /// Confidence in 0.0...1.0.
    public var confidence: Float
    /// Normalised bounding box of the salient region.
    public var bbox_x: Double
    public var bbox_y: Double
    public var bbox_w: Double
    public var bbox_h: Double
}

/// Run attention-based saliency detection. Returns 1 result per
/// `VNSaliencyImageObservation`, each containing zero or more salient
/// objects. The output array packs the salient-object rectangles flat.
@_cdecl("vn_attention_saliency_in_path")
public func vn_attention_saliency_in_path(
    _ imagePath: UnsafePointer<CChar>,
    _ outArray: UnsafeMutablePointer<UnsafeMutableRawPointer?>,
    _ outCount: UnsafeMutablePointer<Int>,
    _ outErrorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    let pathStr = String(cString: imagePath)
    let url = URL(fileURLWithPath: pathStr)
    guard let ciImage = CIImage(contentsOf: url) else {
        outErrorMessage?.pointee = ffiString("Could not load image at \(pathStr)")
        return VN_IMAGE_LOAD_FAILED
    }
    let handler = VNImageRequestHandler(ciImage: ciImage, orientation: imageOrientation(path: pathStr), options: [:])
    let request = VNGenerateAttentionBasedSaliencyImageRequest()
    do {
        try handler.perform([request])
    } catch {
        outErrorMessage?.pointee = ffiString("VNImageRequestHandler.perform(saliency) failed: \(error.localizedDescription)")
        return VN_REQUEST_FAILED
    }
    guard let results = request.results, !results.isEmpty else {
        outArray.pointee = nil
        outCount.pointee = 0
        return VN_OK
    }
    // Flatten: each observation can carry multiple salient objects.
    var flat: [VNSaliencyRegionRaw] = []
    for obs in results {
        if let objects = obs.salientObjects {
            for obj in objects {
                flat.append(VNSaliencyRegionRaw(
                    confidence: obj.confidence,
                    bbox_x: Double(obj.boundingBox.origin.x),
                    bbox_y: Double(obj.boundingBox.origin.y),
                    bbox_w: Double(obj.boundingBox.size.width),
                    bbox_h: Double(obj.boundingBox.size.height)
                ))
            }
        }
    }
    if flat.isEmpty {
        outArray.pointee = nil
        outCount.pointee = 0
        return VN_OK
    }
    let buffer = UnsafeMutablePointer<VNSaliencyRegionRaw>.allocate(capacity: flat.count)
    for (i, r) in flat.enumerated() {
        buffer.advanced(by: i).initialize(to: r)
    }
    outArray.pointee = UnsafeMutableRawPointer(buffer)
    outCount.pointee = flat.count
    return VN_OK
}

@_cdecl("vn_saliency_regions_free")
public func vn_saliency_regions_free(_ array: UnsafeMutableRawPointer?, _ count: Int) {
    guard let array = array else { return }
    let typed = array.assumingMemoryBound(to: VNSaliencyRegionRaw.self)
    typed.deallocate()
    _ = count
}

/// Test helper used by smoke tests: renders `text` into a PNG at `outputPath`
/// using a system font, so OCR can be exercised without bundling fixture files.
///
/// Returns 0 on success, negative status on failure.
@_cdecl("vn_test_helper_render_text_png")
public func vn_test_helper_render_text_png(
    _ text: UnsafePointer<CChar>,
    _ width: Int32,
    _ height: Int32,
    _ outputPath: UnsafePointer<CChar>
) -> Int32 {
    let pathStr = String(cString: outputPath)
    guard let image = renderTextImage(String(cString: text), width: Int(width), height: Int(height)) else {
        return VN_UNKNOWN
    }
    let url = URL(fileURLWithPath: pathStr)
    guard let dest = CGImageDestinationCreateWithURL(
        url as CFURL,
        "public.png" as CFString,
        1,
        nil
    ) else {
        return VN_UNKNOWN
    }
    CGImageDestinationAddImage(dest, image, nil)
    if !CGImageDestinationFinalize(dest) {
        return VN_UNKNOWN
    }
    return VN_OK
}

private func renderTextImage(_ textStr: String, width w: Int, height h: Int) -> CGImage? {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: w,
        height: h,
        bitsPerComponent: 8,
        bytesPerRow: w * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return nil
    }

    // White background
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: w, height: h))

    // Draw the text in black using the system font.
    let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsContext
    let fontSize = CGFloat(h) * 0.4
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
        .foregroundColor: NSColor.black,
    ]
    let attributed = NSAttributedString(string: textStr, attributes: attrs)
    let textSize = attributed.size()
    let drawX = (CGFloat(w) - textSize.width) / 2
    let drawY = (CGFloat(h) - textSize.height) / 2
    attributed.draw(at: NSPoint(x: drawX, y: drawY))
    NSGraphicsContext.restoreGraphicsState()

    return context.makeImage()
}

@_cdecl("vn_test_helper_render_sideways_text_jpeg")
public func vn_test_helper_render_sideways_text_jpeg(
    _ text: UnsafePointer<CChar>,
    _ width: Int32,
    _ height: Int32,
    _ outputPath: UnsafePointer<CChar>
) -> Int32 {
    let pathStr = String(cString: outputPath)
    guard let upright = renderTextImage(String(cString: text), width: Int(width), height: Int(height)) else {
        return VN_UNKNOWN
    }

    let w = upright.width
    let h = upright.height
    guard let context = CGContext(
        data: nil,
        width: h,
        height: w,
        bitsPerComponent: 8,
        bytesPerRow: h * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return VN_UNKNOWN
    }
    context.translateBy(x: CGFloat(h), y: 0)
    context.rotate(by: .pi / 2)
    context.draw(upright, in: CGRect(x: 0, y: 0, width: w, height: h))
    guard let sideways = context.makeImage(),
          let dest = CGImageDestinationCreateWithURL(
            URL(fileURLWithPath: pathStr) as CFURL, "public.jpeg" as CFString, 1, nil) else {
        return VN_UNKNOWN
    }
    let properties = [kCGImagePropertyOrientation: CGImagePropertyOrientation.right.rawValue] as CFDictionary
    CGImageDestinationAddImage(dest, sideways, properties)
    return CGImageDestinationFinalize(dest) ? VN_OK : VN_UNKNOWN
}
