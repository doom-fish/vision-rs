# vision

Safe Rust bindings for Apple's [Vision](https://developer.apple.com/documentation/vision) framework — on-device OCR, object detection, face landmarks, and other computer vision tasks on macOS.

> **Status:** experimental. v0.1 ships text recognition (OCR); object/face detection, classification, barcode scanning land in v0.2.

## Quick start — OCR

```rust,no_run
use apple_vision::prelude::*;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let recognizer = TextRecognizer::new()
        .with_recognition_level(RecognitionLevel::Accurate)
        .with_language_correction(true);

    let observations = recognizer.recognize_in_path("/tmp/screenshot.png")?;
    for obs in &observations {
        println!("[{:.2}] '{}'", obs.confidence, obs.text);
    }
    Ok(())
}
```

## Composes with the rest of the doom-fish stack

```text
screencapturekit-rs / capture ──► IOSurface / PNG ──► vision ──► text
                                                          │
                                                          ▼
                                                  foundation-models
                                                  ("summarise this")
```

## Feature flags

| Feature        | Status |
|----------------|--------|
| `recognize_text` (default) | ✅ |
| `detect_faces` (default)   | ✅ |
| `detect_rectangles`        | 🚧 v0.4 |
| `classify_image`           | 🚧 v0.4 |
| `detect_barcodes`          | 🚧 v0.4 |

## Roadmap

- [x] `VNRecognizeTextRequest` (OCR) via `TextRecognizer`
- [x] `VNDetectFaceRectanglesRequest` via `FaceDetector` (returns bounding box + roll/yaw/pitch)
- [x] CGImage / CVPixelBuffer ingest (file path AND zero-copy CVPixelBuffer paths)
- [ ] `VNDetectFaceLandmarksRequest` (face landmark points)
- [ ] `VNDetectRectanglesRequest`
- [ ] `VNClassifyImageRequest`
- [ ] `VNDetectBarcodesRequest`
- [ ] Async API (`VNRequest` completion handlers exposed via `async fn`)

## License

Licensed under either of [Apache-2.0](LICENSE-APACHE) or [MIT](LICENSE-MIT) at your option.
