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

// MARK: - Face Detection

/// One detected face. Layout-compatible with `DetectedFaceRaw` in Rust.
@frozen
public struct VNDetectedFaceRaw {
    /// Bounding box in normalised image coordinates (Vision convention,
    /// origin bottom-left).
    public var bbox_x: Double
    public var bbox_y: Double
    public var bbox_w: Double
    public var bbox_h: Double
    /// Face confidence in 0...1.
    public var confidence: Float
    /// Roll/yaw/pitch in radians; NaN if unavailable.
    public var roll: Float
    public var yaw: Float
    public var pitch: Float
}

@_cdecl("vn_detect_faces_in_path")
public func vn_detect_faces_in_path(
    _ path: UnsafePointer<CChar>,
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
    return runFaceDetect(
        handler: VNImageRequestHandler(cgImage: cgImage, options: [:]),
        outArray: outArray,
        outCount: outCount,
        outErrorMessage: outErrorMessage
    )
}

@_cdecl("vn_detect_faces_in_pixel_buffer")
public func vn_detect_faces_in_pixel_buffer(
    _ pixelBufferPtr: UnsafeMutableRawPointer,
    _ outArray: UnsafeMutablePointer<UnsafeMutableRawPointer?>,
    _ outCount: UnsafeMutablePointer<Int>,
    _ outErrorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    let pixelBuffer = Unmanaged<CVPixelBuffer>.fromOpaque(pixelBufferPtr).takeUnretainedValue()
    return runFaceDetect(
        handler: VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]),
        outArray: outArray,
        outCount: outCount,
        outErrorMessage: outErrorMessage
    )
}

private func runFaceDetect(
    handler: VNImageRequestHandler,
    outArray: UnsafeMutablePointer<UnsafeMutableRawPointer?>,
    outCount: UnsafeMutablePointer<Int>,
    outErrorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    let request = VNDetectFaceRectanglesRequest()
    do {
        try handler.perform([request])
    } catch {
        outErrorMessage?.pointee = ffiString(
            "VNImageRequestHandler.perform(face) failed: \(error.localizedDescription)"
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
    let buffer = UnsafeMutablePointer<VNDetectedFaceRaw>.allocate(capacity: count)
    for (i, observation) in results.enumerated() {
        let bbox = observation.boundingBox
        // roll/yaw/pitch are NSNumber? — convert to Float, NaN if missing.
        let roll = (observation.roll?.floatValue) ?? .nan
        let yaw = (observation.yaw?.floatValue) ?? .nan
        let pitch = (observation.pitch?.floatValue) ?? .nan
        buffer.advanced(by: i).initialize(to: VNDetectedFaceRaw(
            bbox_x: Double(bbox.origin.x),
            bbox_y: Double(bbox.origin.y),
            bbox_w: Double(bbox.size.width),
            bbox_h: Double(bbox.size.height),
            confidence: observation.confidence,
            roll: roll,
            yaw: yaw,
            pitch: pitch
        ))
    }
    outArray.pointee = UnsafeMutableRawPointer(buffer)
    outCount.pointee = count
    return VN_OK
}

@_cdecl("vn_detected_faces_free")
public func vn_detected_faces_free(_ array: UnsafeMutableRawPointer?, _ count: Int) {
    guard let array = array else { return }
    let typed = array.assumingMemoryBound(to: VNDetectedFaceRaw.self)
    typed.deallocate()
    _ = count // kept for symmetry with the OCR free fn
}

// MARK: - Barcode detection (v0.4)

/// One detected barcode. Matches `DetectedBarcodeRaw` in src/ffi/mod.rs.
@frozen
public struct VNDetectedBarcodeRaw {
    /// Payload string the barcode decodes to (e.g. URL, text). May be nil.
    public var payload: UnsafeMutablePointer<CChar>?
    /// Symbology identifier (e.g. "VNBarcodeSymbologyQR", "VNBarcodeSymbologyEAN13").
    public var symbology: UnsafeMutablePointer<CChar>?
    /// Confidence in 0.0...1.0.
    public var confidence: Float
    /// Bounding box in normalised (0..1) image coordinates, origin
    /// bottom-left (Vision convention).
    public var bbox_x: Double
    public var bbox_y: Double
    public var bbox_w: Double
    public var bbox_h: Double
}

@_cdecl("vn_detect_barcodes_in_path")
public func vn_detect_barcodes_in_path(
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
    let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
    return runBarcodeRequest(handler: handler, outArray: outArray, outCount: outCount, outErrorMessage: outErrorMessage)
}

private func runBarcodeRequest(
    handler: VNImageRequestHandler,
    outArray: UnsafeMutablePointer<UnsafeMutableRawPointer?>,
    outCount: UnsafeMutablePointer<Int>,
    outErrorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    let request = VNDetectBarcodesRequest()
    do {
        try handler.perform([request])
    } catch {
        outErrorMessage?.pointee = ffiString("VNImageRequestHandler.perform(barcodes) failed: \(error.localizedDescription)")
        return VN_REQUEST_FAILED
    }
    guard let results = request.results, !results.isEmpty else {
        outArray.pointee = nil
        outCount.pointee = 0
        return VN_OK
    }
    let count = results.count
    let buffer = UnsafeMutablePointer<VNDetectedBarcodeRaw>.allocate(capacity: count)
    for (i, observation) in results.enumerated() {
        let payload = observation.payloadStringValue ?? ""
        let symbology = observation.symbology.rawValue
        let bbox = observation.boundingBox
        buffer.advanced(by: i).initialize(to: VNDetectedBarcodeRaw(
            payload: ffiString(payload),
            symbology: ffiString(symbology),
            confidence: observation.confidence,
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

@_cdecl("vn_detected_barcodes_free")
public func vn_detected_barcodes_free(_ array: UnsafeMutableRawPointer?, _ count: Int) {
    guard let array = array else { return }
    let typed = array.assumingMemoryBound(to: VNDetectedBarcodeRaw.self)
    for i in 0..<count {
        let entry = typed.advanced(by: i).pointee
        if let p = entry.payload { free(p) }
        if let p = entry.symbology { free(p) }
    }
    typed.deallocate()
}

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
    let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
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

// MARK: - Face landmarks (v0.6)

/// One face + its detected landmarks. All point buffers are
/// normalised in 0..1 image coordinates (Vision convention; bottom-left
/// origin) and stored as `[x0, y0, x1, y1, …]` interleaved doubles.
/// Each `*_count` is the number of POINTS (not doubles).
/// A NULL pointer + 0 count means the region wasn't detected.
@frozen
public struct VNFaceLandmarksRaw {
    public var bbox_x: Double
    public var bbox_y: Double
    public var bbox_w: Double
    public var bbox_h: Double
    public var confidence: Float
    public var roll: Float
    public var yaw: Float
    public var pitch: Float

    public var face_contour: UnsafeMutablePointer<Double>?
    public var face_contour_count: Int
    public var left_eye: UnsafeMutablePointer<Double>?
    public var left_eye_count: Int
    public var right_eye: UnsafeMutablePointer<Double>?
    public var right_eye_count: Int
    public var left_eyebrow: UnsafeMutablePointer<Double>?
    public var left_eyebrow_count: Int
    public var right_eyebrow: UnsafeMutablePointer<Double>?
    public var right_eyebrow_count: Int
    public var nose: UnsafeMutablePointer<Double>?
    public var nose_count: Int
    public var nose_crest: UnsafeMutablePointer<Double>?
    public var nose_crest_count: Int
    public var median_line: UnsafeMutablePointer<Double>?
    public var median_line_count: Int
    public var outer_lips: UnsafeMutablePointer<Double>?
    public var outer_lips_count: Int
    public var inner_lips: UnsafeMutablePointer<Double>?
    public var inner_lips_count: Int
    public var left_pupil: UnsafeMutablePointer<Double>?
    public var left_pupil_count: Int
    public var right_pupil: UnsafeMutablePointer<Double>?
    public var right_pupil_count: Int
}

private func copyRegion(_ region: VNFaceLandmarkRegion2D?)
    -> (UnsafeMutablePointer<Double>?, Int)
{
    guard let region = region, region.pointCount > 0 else { return (nil, 0) }
    let n = region.pointCount
    let buf = UnsafeMutablePointer<Double>.allocate(capacity: n * 2)
    let pts = region.normalizedPoints
    for i in 0..<n {
        buf[i * 2] = Double(pts[i].x)
        buf[i * 2 + 1] = Double(pts[i].y)
    }
    return (buf, n)
}

@_cdecl("vn_detect_face_landmarks_in_path")
public func vn_detect_face_landmarks_in_path(
    _ path: UnsafePointer<CChar>,
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
    let request = VNDetectFaceLandmarksRequest()
    do {
        try handler.perform([request])
    } catch {
        outErrorMessage?.pointee = ffiString(
            "VNImageRequestHandler.perform(face-landmarks) failed: \(error.localizedDescription)"
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
    let buffer = UnsafeMutablePointer<VNFaceLandmarksRaw>.allocate(capacity: count)
    for (i, observation) in results.enumerated() {
        let bbox = observation.boundingBox
        let l = observation.landmarks
        let (fc, fcN) = copyRegion(l?.faceContour)
        let (le, leN) = copyRegion(l?.leftEye)
        let (re, reN) = copyRegion(l?.rightEye)
        let (leb, lebN) = copyRegion(l?.leftEyebrow)
        let (reb, rebN) = copyRegion(l?.rightEyebrow)
        let (nose, noseN) = copyRegion(l?.nose)
        let (nc, ncN) = copyRegion(l?.noseCrest)
        let (ml, mlN) = copyRegion(l?.medianLine)
        let (ol, olN) = copyRegion(l?.outerLips)
        let (il, ilN) = copyRegion(l?.innerLips)
        let (lp, lpN) = copyRegion(l?.leftPupil)
        let (rp, rpN) = copyRegion(l?.rightPupil)
        buffer.advanced(by: i).initialize(to: VNFaceLandmarksRaw(
            bbox_x: Double(bbox.origin.x),
            bbox_y: Double(bbox.origin.y),
            bbox_w: Double(bbox.size.width),
            bbox_h: Double(bbox.size.height),
            confidence: observation.confidence,
            roll: observation.roll?.floatValue ?? .nan,
            yaw: observation.yaw?.floatValue ?? .nan,
            pitch: observation.pitch?.floatValue ?? .nan,
            face_contour: fc, face_contour_count: fcN,
            left_eye: le, left_eye_count: leN,
            right_eye: re, right_eye_count: reN,
            left_eyebrow: leb, left_eyebrow_count: lebN,
            right_eyebrow: reb, right_eyebrow_count: rebN,
            nose: nose, nose_count: noseN,
            nose_crest: nc, nose_crest_count: ncN,
            median_line: ml, median_line_count: mlN,
            outer_lips: ol, outer_lips_count: olN,
            inner_lips: il, inner_lips_count: ilN,
            left_pupil: lp, left_pupil_count: lpN,
            right_pupil: rp, right_pupil_count: rpN
        ))
    }
    outArray.pointee = UnsafeMutableRawPointer(buffer)
    outCount.pointee = count
    return VN_OK
}

@_cdecl("vn_face_landmarks_free")
public func vn_face_landmarks_free(_ array: UnsafeMutableRawPointer?, _ count: Int) {
    guard let array = array else { return }
    let typed = array.assumingMemoryBound(to: VNFaceLandmarksRaw.self)
    for i in 0..<count {
        let face = typed.advanced(by: i).pointee
        face.face_contour?.deallocate()
        face.left_eye?.deallocate()
        face.right_eye?.deallocate()
        face.left_eyebrow?.deallocate()
        face.right_eyebrow?.deallocate()
        face.nose?.deallocate()
        face.nose_crest?.deallocate()
        face.median_line?.deallocate()
        face.outer_lips?.deallocate()
        face.inner_lips?.deallocate()
        face.left_pupil?.deallocate()
        face.right_pupil?.deallocate()
    }
    typed.deallocate()
}

// MARK: - Human body pose (v0.7)

private func bboxFromPoints(xs: [Double], ys: [Double]) -> CGRect {
    guard !xs.isEmpty else { return .zero }
    var minX = xs[0], maxX = xs[0], minY = ys[0], maxY = ys[0]
    for k in 1..<xs.count {
        if xs[k] < minX { minX = xs[k] }
        if xs[k] > maxX { maxX = xs[k] }
        if ys[k] < minY { minY = ys[k] }
        if ys[k] > maxY { maxY = ys[k] }
    }
    return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
}

@frozen
public struct VNPoseObservationRaw {
    public var bbox_x: Double
    public var bbox_y: Double
    public var bbox_w: Double
    public var bbox_h: Double
    public var confidence: Float
    // Parallel arrays of length joint_count.
    public var joint_names: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
    public var joint_xs: UnsafeMutablePointer<Double>?
    public var joint_ys: UnsafeMutablePointer<Double>?
    public var joint_confidences: UnsafeMutablePointer<Float>?
    public var joint_count: Int
}

private func emitPoseJoints(
    names: [String], xs: [Double], ys: [Double], confs: [Float]
) -> (
    UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>,
    UnsafeMutablePointer<Double>,
    UnsafeMutablePointer<Double>,
    UnsafeMutablePointer<Float>,
    Int
) {
    let n = names.count
    let nb = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>.allocate(capacity: n)
    let xb = UnsafeMutablePointer<Double>.allocate(capacity: n)
    let yb = UnsafeMutablePointer<Double>.allocate(capacity: n)
    let cb = UnsafeMutablePointer<Float>.allocate(capacity: n)
    for i in 0..<n {
        nb[i] = strdup(names[i])
        xb[i] = xs[i]
        yb[i] = ys[i]
        cb[i] = confs[i]
    }
    return (nb, xb, yb, cb, n)
}

@_cdecl("vn_detect_human_body_pose_in_path")
public func vn_detect_human_body_pose_in_path(
    _ path: UnsafePointer<CChar>,
    _ outArray: UnsafeMutablePointer<UnsafeMutableRawPointer?>,
    _ outCount: UnsafeMutablePointer<Int>,
    _ outErrorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    let pathStr = String(cString: path)
    guard let cgImage = loadCGImage(path: pathStr) else {
        outErrorMessage?.pointee = ffiString("could not load image at \(pathStr)")
        outArray.pointee = nil; outCount.pointee = 0
        return VN_IMAGE_LOAD_FAILED
    }
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    let request = VNDetectHumanBodyPoseRequest()
    do { try handler.perform([request]) } catch {
        outErrorMessage?.pointee = ffiString("body-pose request failed: \(error.localizedDescription)")
        outArray.pointee = nil; outCount.pointee = 0
        return VN_REQUEST_FAILED
    }
    guard let results = request.results, !results.isEmpty else {
        outArray.pointee = nil; outCount.pointee = 0; return VN_OK
    }
    let count = results.count
    let buf = UnsafeMutablePointer<VNPoseObservationRaw>.allocate(capacity: count)
    for (i, obs) in results.enumerated() {
        var names: [String] = []
        var xs: [Double] = []
        var ys: [Double] = []
        var cs: [Float] = []
        if let points = try? obs.recognizedPoints(.all) {
            for (key, p) in points where p.confidence > 0 {
                names.append("\(key.rawValue)")
                xs.append(Double(p.location.x))
                ys.append(Double(p.location.y))
                cs.append(p.confidence)
            }
        }
        let bbox = bboxFromPoints(xs: xs, ys: ys)
        let (nb, xb, yb, cb, n) = emitPoseJoints(names: names, xs: xs, ys: ys, confs: cs)
        buf.advanced(by: i).initialize(to: VNPoseObservationRaw(
            bbox_x: bbox.origin.x,
            bbox_y: bbox.origin.y,
            bbox_w: bbox.size.width,
            bbox_h: bbox.size.height,
            confidence: obs.confidence,
            joint_names: nb, joint_xs: xb, joint_ys: yb,
            joint_confidences: cb, joint_count: n
        ))
    }
    outArray.pointee = UnsafeMutableRawPointer(buf)
    outCount.pointee = count
    return VN_OK
}

@_cdecl("vn_detect_human_hand_pose_in_path")
public func vn_detect_human_hand_pose_in_path(
    _ path: UnsafePointer<CChar>,
    _ maxHands: Int,
    _ outArray: UnsafeMutablePointer<UnsafeMutableRawPointer?>,
    _ outCount: UnsafeMutablePointer<Int>,
    _ outErrorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    let pathStr = String(cString: path)
    guard let cgImage = loadCGImage(path: pathStr) else {
        outErrorMessage?.pointee = ffiString("could not load image at \(pathStr)")
        outArray.pointee = nil; outCount.pointee = 0
        return VN_IMAGE_LOAD_FAILED
    }
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    let request = VNDetectHumanHandPoseRequest()
    if maxHands > 0 { request.maximumHandCount = maxHands }
    do { try handler.perform([request]) } catch {
        outErrorMessage?.pointee = ffiString("hand-pose request failed: \(error.localizedDescription)")
        outArray.pointee = nil; outCount.pointee = 0
        return VN_REQUEST_FAILED
    }
    guard let results = request.results, !results.isEmpty else {
        outArray.pointee = nil; outCount.pointee = 0; return VN_OK
    }
    let count = results.count
    let buf = UnsafeMutablePointer<VNPoseObservationRaw>.allocate(capacity: count)
    for (i, obs) in results.enumerated() {
        var names: [String] = []
        var xs: [Double] = []
        var ys: [Double] = []
        var cs: [Float] = []
        if let points = try? obs.recognizedPoints(.all) {
            for (key, p) in points where p.confidence > 0 {
                names.append("\(key.rawValue)")
                xs.append(Double(p.location.x))
                ys.append(Double(p.location.y))
                cs.append(p.confidence)
            }
        }
        let bbox = bboxFromPoints(xs: xs, ys: ys)
        let (nb, xb, yb, cb, n) = emitPoseJoints(names: names, xs: xs, ys: ys, confs: cs)
        buf.advanced(by: i).initialize(to: VNPoseObservationRaw(
            bbox_x: bbox.origin.x,
            bbox_y: bbox.origin.y,
            bbox_w: bbox.size.width,
            bbox_h: bbox.size.height,
            confidence: obs.confidence,
            joint_names: nb, joint_xs: xb, joint_ys: yb,
            joint_confidences: cb, joint_count: n
        ))
    }
    outArray.pointee = UnsafeMutableRawPointer(buf)
    outCount.pointee = count
    return VN_OK
}

@_cdecl("vn_pose_observations_free")
public func vn_pose_observations_free(_ array: UnsafeMutableRawPointer?, _ count: Int) {
    guard let array = array else { return }
    let typed = array.assumingMemoryBound(to: VNPoseObservationRaw.self)
    for i in 0..<count {
        let r = typed.advanced(by: i).pointee
        if let nb = r.joint_names {
            for j in 0..<r.joint_count { if let s = nb[j] { free(s) } }
            nb.deallocate()
        }
        r.joint_xs?.deallocate()
        r.joint_ys?.deallocate()
        r.joint_confidences?.deallocate()
    }
    typed.deallocate()
}

// MARK: - Contours

@frozen
public struct VNContourRaw {
    public var point_xs: UnsafeMutablePointer<Double>?
    public var point_ys: UnsafeMutablePointer<Double>?
    public var point_count: Int
    public var child_count: Int
    public var aspect_ratio: Float
}

@_cdecl("vn_detect_contours_in_path")
public func vn_detect_contours_in_path(
    _ path: UnsafePointer<CChar>,
    _ contrastAdjustment: Float,
    _ detectsDarkOnLight: Bool,
    _ outArray: UnsafeMutablePointer<UnsafeMutableRawPointer?>,
    _ outCount: UnsafeMutablePointer<Int>,
    _ outErrorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    let pathStr = String(cString: path)
    guard let cgImage = loadCGImage(path: pathStr) else {
        outErrorMessage?.pointee = ffiString("could not load image at \(pathStr)")
        outArray.pointee = nil; outCount.pointee = 0
        return VN_IMAGE_LOAD_FAILED
    }
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    let request = VNDetectContoursRequest()
    request.contrastAdjustment = contrastAdjustment
    request.detectsDarkOnLight = detectsDarkOnLight
    do { try handler.perform([request]) } catch {
        outErrorMessage?.pointee = ffiString("contour request failed: \(error.localizedDescription)")
        outArray.pointee = nil; outCount.pointee = 0
        return VN_REQUEST_FAILED
    }
    guard let results = request.results, let observation = results.first else {
        outArray.pointee = nil; outCount.pointee = 0; return VN_OK
    }
    let top = observation.topLevelContours
    let count = top.count
    if count == 0 { outArray.pointee = nil; outCount.pointee = 0; return VN_OK }
    let buf = UnsafeMutablePointer<VNContourRaw>.allocate(capacity: count)
    for (i, contour) in top.enumerated() {
        let pts = contour.normalizedPoints
        let n = pts.count
        let xb = UnsafeMutablePointer<Double>.allocate(capacity: n)
        let yb = UnsafeMutablePointer<Double>.allocate(capacity: n)
        for k in 0..<n {
            xb[k] = Double(pts[k].x)
            yb[k] = Double(pts[k].y)
        }
        buf.advanced(by: i).initialize(to: VNContourRaw(
            point_xs: xb, point_ys: yb, point_count: n,
            child_count: contour.childContourCount,
            aspect_ratio: contour.aspectRatio
        ))
    }
    outArray.pointee = UnsafeMutableRawPointer(buf)
    outCount.pointee = count
    return VN_OK
}

@_cdecl("vn_contours_free")
public func vn_contours_free(_ array: UnsafeMutableRawPointer?, _ count: Int) {
    guard let array = array else { return }
    let typed = array.assumingMemoryBound(to: VNContourRaw.self)
    for i in 0..<count {
        let r = typed.advanced(by: i).pointee
        r.point_xs?.deallocate()
        r.point_ys?.deallocate()
    }
    typed.deallocate()
}

// MARK: - Animal recognition

@frozen
public struct VNRecognizedAnimalRaw {
    public var identifier: UnsafeMutablePointer<CChar>?
    public var confidence: Float
    public var bbox_x: Double
    public var bbox_y: Double
    public var bbox_w: Double
    public var bbox_h: Double
}

@_cdecl("vn_recognize_animals_in_path")
public func vn_recognize_animals_in_path(
    _ path: UnsafePointer<CChar>,
    _ outArray: UnsafeMutablePointer<UnsafeMutableRawPointer?>,
    _ outCount: UnsafeMutablePointer<Int>,
    _ outErrorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    let pathStr = String(cString: path)
    guard let cgImage = loadCGImage(path: pathStr) else {
        outErrorMessage?.pointee = ffiString("could not load image at \(pathStr)")
        outArray.pointee = nil; outCount.pointee = 0
        return VN_IMAGE_LOAD_FAILED
    }
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    let request = VNRecognizeAnimalsRequest()
    do { try handler.perform([request]) } catch {
        outErrorMessage?.pointee = ffiString("animal request failed: \(error.localizedDescription)")
        outArray.pointee = nil; outCount.pointee = 0
        return VN_REQUEST_FAILED
    }
    guard let results = request.results, !results.isEmpty else {
        outArray.pointee = nil; outCount.pointee = 0; return VN_OK
    }
    // Flatten labels: 1 observation -> N labels -> N rows.
    var flat: [VNRecognizedAnimalRaw] = []
    flat.reserveCapacity(results.count)
    for obs in results {
        let bbox = obs.boundingBox
        if let primary = obs.labels.first {
            flat.append(VNRecognizedAnimalRaw(
                identifier: ffiString(primary.identifier),
                confidence: primary.confidence,
                bbox_x: Double(bbox.origin.x),
                bbox_y: Double(bbox.origin.y),
                bbox_w: Double(bbox.size.width),
                bbox_h: Double(bbox.size.height)
            ))
        }
    }
    let count = flat.count
    if count == 0 { outArray.pointee = nil; outCount.pointee = 0; return VN_OK }
    let buf = UnsafeMutablePointer<VNRecognizedAnimalRaw>.allocate(capacity: count)
    for (i, r) in flat.enumerated() { buf.advanced(by: i).initialize(to: r) }
    outArray.pointee = UnsafeMutableRawPointer(buf)
    outCount.pointee = count
    return VN_OK
}

@_cdecl("vn_recognized_animals_free")
public func vn_recognized_animals_free(_ array: UnsafeMutableRawPointer?, _ count: Int) {
    guard let array = array else { return }
    let typed = array.assumingMemoryBound(to: VNRecognizedAnimalRaw.self)
    for i in 0..<count {
        let r = typed.advanced(by: i).pointee
        if let s = r.identifier { free(s) }
    }
    typed.deallocate()
}

// MARK: - Classify image (v0.8)

@frozen
public struct VNClassificationRaw {
    public var identifier: UnsafeMutablePointer<CChar>?
    public var confidence: Float
}

@_cdecl("vn_classify_image_in_path")
public func vn_classify_image_in_path(
    _ path: UnsafePointer<CChar>,
    _ outArray: UnsafeMutablePointer<UnsafeMutableRawPointer?>,
    _ outCount: UnsafeMutablePointer<Int>,
    _ outErrorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    let pathStr = String(cString: path)
    guard let cgImage = loadCGImage(path: pathStr) else {
        outErrorMessage?.pointee = ffiString("could not load image at \(pathStr)")
        outArray.pointee = nil; outCount.pointee = 0
        return VN_IMAGE_LOAD_FAILED
    }
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    let request = VNClassifyImageRequest()
    do { try handler.perform([request]) } catch {
        outErrorMessage?.pointee = ffiString("classify request failed: \(error.localizedDescription)")
        outArray.pointee = nil; outCount.pointee = 0
        return VN_REQUEST_FAILED
    }
    guard let results = request.results, !results.isEmpty else {
        outArray.pointee = nil; outCount.pointee = 0; return VN_OK
    }
    let count = results.count
    let buf = UnsafeMutablePointer<VNClassificationRaw>.allocate(capacity: count)
    for (i, obs) in results.enumerated() {
        buf.advanced(by: i).initialize(to: VNClassificationRaw(
            identifier: ffiString(obs.identifier),
            confidence: obs.confidence
        ))
    }
    outArray.pointee = UnsafeMutableRawPointer(buf)
    outCount.pointee = count
    return VN_OK
}

@_cdecl("vn_classifications_free")
public func vn_classifications_free(_ array: UnsafeMutableRawPointer?, _ count: Int) {
    guard let array = array else { return }
    let typed = array.assumingMemoryBound(to: VNClassificationRaw.self)
    for i in 0..<count {
        if let s = typed.advanced(by: i).pointee.identifier { free(s) }
    }
    typed.deallocate()
}

// MARK: - Detect rectangles + document segmentation (v0.8)

@frozen
public struct VNRectangleObservationRaw {
    public var bbox_x: Double
    public var bbox_y: Double
    public var bbox_w: Double
    public var bbox_h: Double
    public var confidence: Float
    public var tl_x: Double
    public var tl_y: Double
    public var tr_x: Double
    public var tr_y: Double
    public var bl_x: Double
    public var bl_y: Double
    public var br_x: Double
    public var br_y: Double
}

private func emitRectangleObservations(
    _ observations: [VNRectangleObservation]
) -> (UnsafeMutableRawPointer?, Int) {
    let count = observations.count
    if count == 0 { return (nil, 0) }
    let buf = UnsafeMutablePointer<VNRectangleObservationRaw>.allocate(capacity: count)
    for (i, obs) in observations.enumerated() {
        let b = obs.boundingBox
        buf.advanced(by: i).initialize(to: VNRectangleObservationRaw(
            bbox_x: Double(b.origin.x),
            bbox_y: Double(b.origin.y),
            bbox_w: Double(b.size.width),
            bbox_h: Double(b.size.height),
            confidence: obs.confidence,
            tl_x: Double(obs.topLeft.x),
            tl_y: Double(obs.topLeft.y),
            tr_x: Double(obs.topRight.x),
            tr_y: Double(obs.topRight.y),
            bl_x: Double(obs.bottomLeft.x),
            bl_y: Double(obs.bottomLeft.y),
            br_x: Double(obs.bottomRight.x),
            br_y: Double(obs.bottomRight.y)
        ))
    }
    return (UnsafeMutableRawPointer(buf), count)
}

@_cdecl("vn_detect_rectangles_in_path")
public func vn_detect_rectangles_in_path(
    _ path: UnsafePointer<CChar>,
    _ maxObservations: Int,
    _ minimumAspectRatio: Float,
    _ maximumAspectRatio: Float,
    _ minimumSize: Float,
    _ minimumConfidence: Float,
    _ outArray: UnsafeMutablePointer<UnsafeMutableRawPointer?>,
    _ outCount: UnsafeMutablePointer<Int>,
    _ outErrorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    let pathStr = String(cString: path)
    guard let cgImage = loadCGImage(path: pathStr) else {
        outErrorMessage?.pointee = ffiString("could not load image at \(pathStr)")
        outArray.pointee = nil; outCount.pointee = 0
        return VN_IMAGE_LOAD_FAILED
    }
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    let request = VNDetectRectanglesRequest()
    if maxObservations > 0 { request.maximumObservations = maxObservations }
    if minimumAspectRatio > 0 { request.minimumAspectRatio = VNAspectRatio(minimumAspectRatio) }
    if maximumAspectRatio > 0 { request.maximumAspectRatio = VNAspectRatio(maximumAspectRatio) }
    if minimumSize > 0 { request.minimumSize = minimumSize }
    if minimumConfidence > 0 { request.minimumConfidence = VNConfidence(minimumConfidence) }
    do { try handler.perform([request]) } catch {
        outErrorMessage?.pointee = ffiString("rectangle request failed: \(error.localizedDescription)")
        outArray.pointee = nil; outCount.pointee = 0
        return VN_REQUEST_FAILED
    }
    let results = request.results ?? []
    let (ptr, n) = emitRectangleObservations(results)
    outArray.pointee = ptr
    outCount.pointee = n
    return VN_OK
}

@_cdecl("vn_detect_document_segmentation_in_path")
public func vn_detect_document_segmentation_in_path(
    _ path: UnsafePointer<CChar>,
    _ outArray: UnsafeMutablePointer<UnsafeMutableRawPointer?>,
    _ outCount: UnsafeMutablePointer<Int>,
    _ outErrorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    let pathStr = String(cString: path)
    guard let cgImage = loadCGImage(path: pathStr) else {
        outErrorMessage?.pointee = ffiString("could not load image at \(pathStr)")
        outArray.pointee = nil; outCount.pointee = 0
        return VN_IMAGE_LOAD_FAILED
    }
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    let request = VNDetectDocumentSegmentationRequest()
    do { try handler.perform([request]) } catch {
        outErrorMessage?.pointee = ffiString("document seg request failed: \(error.localizedDescription)")
        outArray.pointee = nil; outCount.pointee = 0
        return VN_REQUEST_FAILED
    }
    let results = request.results ?? []
    let (ptr, n) = emitRectangleObservations(results)
    outArray.pointee = ptr
    outCount.pointee = n
    return VN_OK
}

@_cdecl("vn_rectangle_observations_free")
public func vn_rectangle_observations_free(_ array: UnsafeMutableRawPointer?, _ count: Int) {
    guard let array = array else { return }
    let typed = array.assumingMemoryBound(to: VNRectangleObservationRaw.self)
    _ = count
    typed.deallocate()
}

// MARK: - Detect horizon (v0.8)

/// Returns angle in radians. `has_value` is false when no horizon found.
@_cdecl("vn_detect_horizon_in_path")
public func vn_detect_horizon_in_path(
    _ path: UnsafePointer<CChar>,
    _ out_angle: UnsafeMutablePointer<Double>,
    _ out_has_value: UnsafeMutablePointer<Bool>,
    _ outErrorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    let pathStr = String(cString: path)
    guard let cgImage = loadCGImage(path: pathStr) else {
        outErrorMessage?.pointee = ffiString("could not load image at \(pathStr)")
        out_has_value.pointee = false
        return VN_IMAGE_LOAD_FAILED
    }
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    let request = VNDetectHorizonRequest()
    do { try handler.perform([request]) } catch {
        outErrorMessage?.pointee = ffiString("horizon request failed: \(error.localizedDescription)")
        out_has_value.pointee = false
        return VN_REQUEST_FAILED
    }
    guard let obs = request.results?.first else {
        out_has_value.pointee = false
        return VN_OK
    }
    out_angle.pointee = Double(obs.angle)
    out_has_value.pointee = true
    return VN_OK
}

// MARK: - Image feature print (v0.8)

@frozen
public struct VNFeaturePrintRaw {
    /// Element type — 1 = Float, 2 = Double.
    public var element_type: Int32
    public var element_count: Int
    /// Pointer to a freshly-allocated buffer of `element_count * 4` (Float)
    /// or `* 8` (Double) bytes. Caller frees via `vn_feature_print_free`.
    public var bytes: UnsafeMutableRawPointer?
}

@_cdecl("vn_generate_image_feature_print_in_path")
public func vn_generate_image_feature_print_in_path(
    _ path: UnsafePointer<CChar>,
    _ outFeature: UnsafeMutableRawPointer,
    _ outErrorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    let outTyped = outFeature.assumingMemoryBound(to: VNFeaturePrintRaw.self)
    let pathStr = String(cString: path)
    guard let cgImage = loadCGImage(path: pathStr) else {
        outErrorMessage?.pointee = ffiString("could not load image at \(pathStr)")
        return VN_IMAGE_LOAD_FAILED
    }
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    let request = VNGenerateImageFeaturePrintRequest()
    do { try handler.perform([request]) } catch {
        outErrorMessage?.pointee = ffiString("feature print request failed: \(error.localizedDescription)")
        return VN_REQUEST_FAILED
    }
    guard let obs = request.results?.first else {
        outTyped.pointee = VNFeaturePrintRaw(element_type: 0, element_count: 0, bytes: nil)
        return VN_OK
    }
    let data = obs.data
    let bytes = UnsafeMutableRawPointer.allocate(byteCount: data.count, alignment: 8)
    data.copyBytes(to: bytes.assumingMemoryBound(to: UInt8.self), count: data.count)
    outTyped.pointee = VNFeaturePrintRaw(
        element_type: Int32(obs.elementType.rawValue),
        element_count: obs.elementCount,
        bytes: bytes
    )
    return VN_OK
}

@_cdecl("vn_feature_print_free")
public func vn_feature_print_free(_ feature: UnsafeMutableRawPointer) {
    let typed = feature.assumingMemoryBound(to: VNFeaturePrintRaw.self)
    guard let bytes = typed.pointee.bytes else { return }
    bytes.deallocate()
    typed.pointee.bytes = nil
}

// MARK: - Detect humans (v0.8)

@frozen
public struct VNHumanObservationRaw {
    public var bbox_x: Double
    public var bbox_y: Double
    public var bbox_w: Double
    public var bbox_h: Double
    public var confidence: Float
    public var upper_body_only: Bool
}

@_cdecl("vn_detect_human_rectangles_in_path")
public func vn_detect_human_rectangles_in_path(
    _ path: UnsafePointer<CChar>,
    _ upperBodyOnly: Bool,
    _ outArray: UnsafeMutablePointer<UnsafeMutableRawPointer?>,
    _ outCount: UnsafeMutablePointer<Int>,
    _ outErrorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    let pathStr = String(cString: path)
    guard let cgImage = loadCGImage(path: pathStr) else {
        outErrorMessage?.pointee = ffiString("could not load image at \(pathStr)")
        outArray.pointee = nil; outCount.pointee = 0
        return VN_IMAGE_LOAD_FAILED
    }
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    let request = VNDetectHumanRectanglesRequest()
    if #available(macOS 12.0, *) {
        request.upperBodyOnly = upperBodyOnly
    }
    do { try handler.perform([request]) } catch {
        outErrorMessage?.pointee = ffiString("human rectangles failed: \(error.localizedDescription)")
        outArray.pointee = nil; outCount.pointee = 0
        return VN_REQUEST_FAILED
    }
    let results = request.results ?? []
    let count = results.count
    if count == 0 { outArray.pointee = nil; outCount.pointee = 0; return VN_OK }
    let buf = UnsafeMutablePointer<VNHumanObservationRaw>.allocate(capacity: count)
    for (i, obs) in results.enumerated() {
        let b = obs.boundingBox
        buf.advanced(by: i).initialize(to: VNHumanObservationRaw(
            bbox_x: Double(b.origin.x),
            bbox_y: Double(b.origin.y),
            bbox_w: Double(b.size.width),
            bbox_h: Double(b.size.height),
            confidence: obs.confidence,
            upper_body_only: upperBodyOnly
        ))
    }
    outArray.pointee = UnsafeMutableRawPointer(buf)
    outCount.pointee = count
    return VN_OK
}

@_cdecl("vn_human_observations_free")
public func vn_human_observations_free(_ array: UnsafeMutableRawPointer?, _ count: Int) {
    guard let array = array else { return }
    let typed = array.assumingMemoryBound(to: VNHumanObservationRaw.self)
    _ = count
    typed.deallocate()
}

// MARK: - Aesthetics + face capture quality (v0.9)

@frozen
public struct VNAestheticsScoresRaw {
    public var overall_score: Float
    public var is_utility: Bool
}

@_cdecl("vn_calculate_aesthetics_scores_in_path")
public func vn_calculate_aesthetics_scores_in_path(
    _ path: UnsafePointer<CChar>,
    _ outScoresRaw: UnsafeMutableRawPointer,
    _ outHasValue: UnsafeMutablePointer<Bool>,
    _ outErrorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    let outScores = outScoresRaw.assumingMemoryBound(to: VNAestheticsScoresRaw.self)
    if #unavailable(macOS 15.0) {
        outErrorMessage?.pointee = ffiString("aesthetics scores require macOS 15+")
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
    if #available(macOS 15.0, *) {
        let request = VNCalculateImageAestheticsScoresRequest()
        do { try handler.perform([request]) } catch {
            outErrorMessage?.pointee = ffiString("aesthetics request failed: \(error.localizedDescription)")
            outHasValue.pointee = false
            return VN_REQUEST_FAILED
        }
        guard let obs = request.results?.first else {
            outHasValue.pointee = false
            return VN_OK
        }
        outScores.pointee = VNAestheticsScoresRaw(
            overall_score: obs.overallScore,
            is_utility: obs.isUtility
        )
        outHasValue.pointee = true
    }
    return VN_OK
}

@frozen
public struct VNFaceQualityRaw {
    public var bbox_x: Double
    public var bbox_y: Double
    public var bbox_w: Double
    public var bbox_h: Double
    public var confidence: Float
    public var capture_quality: Float
    public var has_quality: Bool
}

@_cdecl("vn_detect_face_capture_quality_in_path")
public func vn_detect_face_capture_quality_in_path(
    _ path: UnsafePointer<CChar>,
    _ outArray: UnsafeMutablePointer<UnsafeMutableRawPointer?>,
    _ outCount: UnsafeMutablePointer<Int>,
    _ outErrorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    let pathStr = String(cString: path)
    guard let cgImage = loadCGImage(path: pathStr) else {
        outErrorMessage?.pointee = ffiString("could not load image at \(pathStr)")
        outArray.pointee = nil; outCount.pointee = 0
        return VN_IMAGE_LOAD_FAILED
    }
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    let request = VNDetectFaceCaptureQualityRequest()
    do { try handler.perform([request]) } catch {
        outErrorMessage?.pointee = ffiString("face quality request failed: \(error.localizedDescription)")
        outArray.pointee = nil; outCount.pointee = 0
        return VN_REQUEST_FAILED
    }
    let results = request.results ?? []
    let count = results.count
    if count == 0 { outArray.pointee = nil; outCount.pointee = 0; return VN_OK }
    let buf = UnsafeMutablePointer<VNFaceQualityRaw>.allocate(capacity: count)
    for (i, obs) in results.enumerated() {
        let b = obs.boundingBox
        let q = obs.faceCaptureQuality
        buf.advanced(by: i).initialize(to: VNFaceQualityRaw(
            bbox_x: Double(b.origin.x),
            bbox_y: Double(b.origin.y),
            bbox_w: Double(b.size.width),
            bbox_h: Double(b.size.height),
            confidence: obs.confidence,
            capture_quality: q ?? 0.0,
            has_quality: q != nil
        ))
    }
    outArray.pointee = UnsafeMutableRawPointer(buf)
    outCount.pointee = count
    return VN_OK
}

@_cdecl("vn_face_quality_observations_free")
public func vn_face_quality_observations_free(_ array: UnsafeMutableRawPointer?, _ count: Int) {
    guard let array = array else { return }
    let typed = array.assumingMemoryBound(to: VNFaceQualityRaw.self)
    _ = count
    typed.deallocate()
}

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
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    let request = VNGeneratePersonSegmentationRequest()
    if let lvl = VNGeneratePersonSegmentationRequest.QualityLevel(rawValue: UInt(qualityLevel)) {
        request.qualityLevel = lvl
    }
    // 8bppONE mask format (kCVPixelFormatType_OneComponent8).
    request.outputPixelFormat = 0x4f6e6538 // 'One8'
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
    let handler = VNImageRequestHandler(cgImage: aImage, options: [:])
    let request = VNGenerateOpticalFlowRequest(targetedCGImage: bImage, options: [:])
    if let lvl = VNGenerateOpticalFlowRequest.ComputationAccuracy(rawValue: UInt(computationAccuracy)) {
        request.computationAccuracy = lvl
    }
    do { try handler.perform([request]) } catch {
        outErrorMessage?.pointee = ffiString("optical flow request failed: \(error.localizedDescription)")
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
