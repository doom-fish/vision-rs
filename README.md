# vision

Safe Rust bindings for Apple's [Vision](https://developer.apple.com/documentation/vision) framework — on-device OCR, object detection, face landmarks, and other computer vision tasks on macOS.

> **Status:** v0.15.2 keeps the full Vision request surface, adds explicit base-class + observation wrappers for the remaining request/observation gaps, and ships a fully-implemented request/observation coverage matrix (`COVERAGE.md`) plus a gold-standard multi-file Swift bridge.

## Quick start — OCR

```rust,no_run
use apple_vision::prelude::*;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let recognizer = TextRecognizer::new()
        .with_recognition_level(RecognitionLevel::Accurate)
        .with_language_correction(true);

    let observations = recognizer.recognize_in_path("screenshot.png")?;
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

All request-type modules can be enabled independently, and the default feature set still enables the full Vision surface. v0.15.2 completes the audited `COVERAGE.md` matrix with explicit base request wrappers (`ImageBasedRequest`, `StatefulRequest`, `TrackingRequest`, `CoreMLRequest`, etc.) plus dedicated observation wrappers for the remaining Vision request/observation types in the macOS SDK.

## Roadmap

- [x] Single-image Vision requests (OCR, faces, landmarks, pose, contours, saliency, segmentation, Core ML, and the rest of the stateless request surface)
- [x] Pairwise image-registration requests (`VNTranslationalImageRegistrationRequest`, `VNHomographicImageRegistrationRequest`)
- [x] Stateful tracking requests (`VNTrackObjectRequest`, `VNTrackRectangleRequest`, `VNTrackOpticalFlowRequest`, `VNTrackTranslationalImageRegistrationRequest`, `VNTrackHomographicImageRegistrationRequest`)
- [x] Header-audited request + observation coverage matrix (`COVERAGE.md`) with dedicated wrappers for every current request/observation type and a split Swift bridge (all bridge files stay under 500 lines)
- [x] Explicit `VNRequest` / `VNObservation` / request-handler / `VNVideoProcessor` wrappers for OCR pipelines, plus base request/observation helpers reused across the rest of the crate
- [ ] Async API (`VNRequest` completion handlers exposed via `async fn`)

## License

Licensed under either of [Apache-2.0](LICENSE-APACHE) or [MIT](LICENSE-MIT) at your option.
