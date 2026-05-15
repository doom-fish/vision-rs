// Vision framework bridge — text recognition (OCR).
//
// Vision's APIs are mostly Obj-C with completion handlers. We wrap
// VNRecognizeTextRequest + VNImageRequestHandler behind a single synchronous
// C-callable function that loads an image from disk, runs OCR, and returns
// the observations as a packed array.

import Foundation
import Vision
import CoreImage
import CoreGraphics
import AppKit
import ImageIO

// MARK: - Status codes (mirrored in src/error.rs)

private let VN_OK: Int32 = 0
private let VN_INVALID_ARGUMENT: Int32 = -1
private let VN_IMAGE_LOAD_FAILED: Int32 = -2
private let VN_REQUEST_FAILED: Int32 = -3
private let VN_UNKNOWN: Int32 = -99

// MARK: - String helpers

@_cdecl("vn_string_free")
public func vn_string_free(_ str: UnsafeMutablePointer<CChar>?) {
    guard let str = str else { return }
    free(str)
}

private func ffiString(_ s: String) -> UnsafeMutablePointer<CChar>? {
    return s.withCString { strdup($0) }
}

// MARK: - FFI Result Types

/// One recognised text observation. Matches `RecognizedTextRaw` in src/ffi/mod.rs.
@frozen
public struct VNRecognizedTextRaw {
    /// NUL-terminated UTF-8 string (heap-allocated; caller frees with vn_string_free).
    public var text: UnsafeMutablePointer<CChar>?
    /// VNConfidence in 0.0...1.0
    public var confidence: Float
    /// Bounding box in normalised (0...1) image coordinates with origin at
    /// bottom-left (Vision convention).
    public var bbox_x: Double
    public var bbox_y: Double
    public var bbox_w: Double
    public var bbox_h: Double
}

/// Recognition mode — fast-but-less-accurate vs accurate-but-slower.
public enum VNRecognitionLevelRaw: Int32 {
    case fast = 0
    case accurate = 1
}

// MARK: - Image loading

/// Load an image from a file URL into a CGImage. Supports any format
/// CoreGraphics' ImageIO can read (PNG/JPEG/HEIC/TIFF/...).
private func loadCGImage(path: String) -> CGImage? {
    let url = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        return nil
    }
    return image
}

// MARK: - Public OCR entry point (file path)

/// Run text recognition on the image at `path` and write the observations
/// into a heap-allocated array. The Rust caller takes ownership of the
/// returned pointer and frees it via `vn_recognized_text_free`.
@_cdecl("vn_recognize_text_in_path")
public func vn_recognize_text_in_path(
    _ path: UnsafePointer<CChar>,
    _ recognitionLevel: Int32,
    _ usesLanguageCorrection: Bool,
    _ outArray: UnsafeMutablePointer<UnsafeMutableRawPointer?>,
    _ outCount: UnsafeMutablePointer<Int>,
    _ outErrorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    let pathStr = String(cString: path)
    guard let cgImage = loadCGImage(path: pathStr) else {
        outErrorMessage?.pointee = ffiString("could not load image at \(pathStr)")
        outArray.pointee = nil
        outCount.pointee = 0
        return VN_IMAGE_LOAD_FAILED
    }
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    return runOCR(
        handler: handler,
        recognitionLevel: recognitionLevel,
        usesLanguageCorrection: usesLanguageCorrection,
        outArray: outArray,
        outCount: outCount,
        outErrorMessage: outErrorMessage
    )
}

// MARK: - Public OCR entry point (CVPixelBuffer)

/// Run text recognition on a CVPixelBuffer. `pixelBufferPtr` is a raw
/// CVPixelBufferRef obtained from apple_cf::cv::CVPixelBuffer::as_ptr(),
/// from a videotoolbox decoder, screencapturekit, or any other capture
/// source. No bytes are copied; Vision reads the buffer in place.
@_cdecl("vn_recognize_text_in_pixel_buffer")
public func vn_recognize_text_in_pixel_buffer(
    _ pixelBufferPtr: UnsafeMutableRawPointer,
    _ recognitionLevel: Int32,
    _ usesLanguageCorrection: Bool,
    _ outArray: UnsafeMutablePointer<UnsafeMutableRawPointer?>,
    _ outCount: UnsafeMutablePointer<Int>,
    _ outErrorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    let pixelBuffer = Unmanaged<CVPixelBuffer>.fromOpaque(pixelBufferPtr).takeUnretainedValue()
    let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
    return runOCR(
        handler: handler,
        recognitionLevel: recognitionLevel,
        usesLanguageCorrection: usesLanguageCorrection,
        outArray: outArray,
        outCount: outCount,
        outErrorMessage: outErrorMessage
    )
}

/// Shared OCR driver — runs the request and packs results.
private func runOCR(
    handler: VNImageRequestHandler,
    recognitionLevel: Int32,
    usesLanguageCorrection: Bool,
    outArray: UnsafeMutablePointer<UnsafeMutableRawPointer?>,
    outCount: UnsafeMutablePointer<Int>,
    outErrorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel =
        recognitionLevel == 1 ? .accurate : .fast
    request.usesLanguageCorrection = usesLanguageCorrection

    do {
        try handler.perform([request])
    } catch {
        outErrorMessage?.pointee = ffiString(
            "VNImageRequestHandler.perform failed: \(error.localizedDescription)"
        )
        outArray.pointee = nil
        outCount.pointee = 0
        return VN_REQUEST_FAILED
    }

    guard let results = request.results, !results.isEmpty else {
        outArray.pointee = nil
        outCount.pointee = 0
        return VN_OK
    }

    let count = results.count
    let buffer = UnsafeMutablePointer<VNRecognizedTextRaw>.allocate(capacity: count)
    for (i, observation) in results.enumerated() {
        let candidate = observation.topCandidates(1).first
        let text = candidate?.string ?? ""
        let confidence = candidate?.confidence ?? observation.confidence
        let bbox = observation.boundingBox
        buffer.advanced(by: i).initialize(to: VNRecognizedTextRaw(
            text: ffiString(text),
            confidence: confidence,
            bbox_x: Double(bbox.origin.x),
            bbox_y: Double(bbox.origin.y),
            bbox_w: Double(bbox.size.width),
            bbox_h: Double(bbox.size.height)
        ))
    }
    outArray.pointee = UnsafeMutableRawPointer(buffer)
    outCount.pointee = count
    return VN_OK
}

@_cdecl("vn_recognized_text_free")
public func vn_recognized_text_free(
    _ array: UnsafeMutableRawPointer?,
    _ count: Int
) {
    guard let array = array else { return }
    let typed = array.assumingMemoryBound(to: VNRecognizedTextRaw.self)
    for i in 0..<count {
        if let text = typed.advanced(by: i).pointee.text {
            free(text)
        }
    }
    typed.deallocate()
}

// MARK: - Test helper: render text to a PNG

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
    let textStr = String(cString: text)
    let pathStr = String(cString: outputPath)

    let w = Int(width)
    let h = Int(height)
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
        return VN_UNKNOWN
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

    // Save as PNG via ImageIO.
    guard let image = context.makeImage() else { return VN_UNKNOWN }
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
