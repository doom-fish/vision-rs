# Changelog

All notable changes to this project will be documented in this file.

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
