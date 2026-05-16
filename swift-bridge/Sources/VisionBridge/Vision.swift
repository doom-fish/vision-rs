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
