# Changelog

All notable changes to this project will be documented in this file.

## [0.3.0] - Unreleased

### Added

- **Face detection** — `FaceDetector` wraps `VNDetectFaceRectanglesRequest`.
  Both `detect_in_path(&Path)` and `detect_in_pixel_buffer(&CVPixelBuffer)`
  are supported. `DetectedFace` carries bounding box, confidence, and
  `Option<f32>` roll/yaw/pitch (optionals reflect older request revisions
  that don't report all three angles).
- `detect_faces` feature flag (on by default).
- Smoke test `03_face_detect` runs on a blank image (asserting 0 faces) and
  optionally on a user-supplied image path.
- API harness extended to `VNDetectFaceRectanglesRequest` and
  `VNFaceObservation` — 6/6 tests at 100% coverable.

## [0.2.0] - Unreleased

### Added (BREAKING — adds dependency)

- **`apple-cf` as a dependency** (with `cv` + `iosurface` features) so the
  bridge can speak `CVPixelBuffer` directly.
- `TextRecognizer::recognize_in_pixel_buffer(&CVPixelBuffer)` — zero-copy
  OCR path for live capture pipelines (screencapturekit / videotoolbox
  decoder / AVCaptureSession). No PNG round-trip, no bytes copied between
  Vision and the pixel data.
- `vn_recognize_text_in_pixel_buffer` `@_cdecl` export driving
  `VNImageRequestHandler(cvPixelBuffer:)`.
- Smoke test `02_ocr_pixel_buffer` runs OCR through both the file and
  pixel-buffer paths against the same render, proving Vision accepts a
  CVPixelBuffer end-to-end.

## [0.1.0] - Initial release

### Added

- `TextRecognizer` wraps `VNRecognizeTextRequest` for image-file OCR.
- `RecognitionLevel { Fast, Accurate }` mirrors `VNRequestTextRecognitionLevel`.
- `RecognizedText { text, confidence, bounding_box }` carries Vision's
  observations; `BoundingBox` is in normalised (0..=1) image coordinates
  with origin at the bottom-left.
- `recognize_text` feature flag (on by default) lets future detect/classify
  features stay independently optional.
- Swift bridge wraps `VNImageRequestHandler` + `VNRecognizeTextRequest`
  behind a single synchronous `vn_recognize_text_in_path` call. Result
  arrays are heap-allocated and freed via `vn_recognized_text_free`.
- Smoke test `01_ocr_smoke` renders 'HELLO WORLD' to a PNG via a Swift
  CGContext helper, OCRs it, and asserts on the returned text.
  Verified: confidence 1.00, exact match, normalized bbox.
- API coverage harness verifies our wrappers against
  `VNRecognizeTextRequest` / `VNRecognizedTextObservation` /
  `VNImageRequestHandler` / `VNRequestTextRecognitionLevel` from the
  Vision `.swiftinterface`. 4/4 tests pass at 100% coverable.
