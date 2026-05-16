# vision

Safe Rust bindings for Apple's [Vision](https://developer.apple.com/documentation/vision) framework — on-device OCR, object detection, face landmarks, and other computer vision tasks on macOS.

> **Status:** v0.14 ships the full Apple Vision request surface, including all five stateful tracking requests.

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

All request-type modules can be enabled independently, but the default feature set now enables the full Vision surface, including the new `tracking` module in v0.14.

## Roadmap

- [x] Single-image Vision requests (OCR, faces, landmarks, pose, contours, saliency, segmentation, Core ML, and the rest of the stateless request surface)
- [x] Pairwise image-registration requests (`VNTranslationalImageRegistrationRequest`, `VNHomographicImageRegistrationRequest`)
- [x] Stateful tracking requests (`VNTrackObjectRequest`, `VNTrackRectangleRequest`, `VNTrackOpticalFlowRequest`, `VNTrackTranslationalImageRegistrationRequest`, `VNTrackHomographicImageRegistrationRequest`)
- [ ] Async API (`VNRequest` completion handlers exposed via `async fn`)

## License

Licensed under either of [Apache-2.0](LICENSE-APACHE) or [MIT](LICENSE-MIT) at your option.
