# vision

Safe Rust bindings for Apple's [Vision](https://developer.apple.com/documentation/vision) framework — on-device OCR, object detection, face landmarks, and other computer vision tasks on macOS.

> **Status:** v0.16.7 wraps the Objective-C Vision request surface and a Tier-1 `async_api` for one-shot OCR / face / barcode / segmentation / Core ML / pose / trajectory workflows. `COVERAGE.md` and `COVERAGE_AUDIT.md` track the `VN*` Objective-C API only; the Swift-only Vision API, including the macOS 26 `RecognizeDocumentsRequest` and `DetectLensSmudgeRequest`, is not wrapped.

## Requirements

- macOS 13 or later. Requests Apple added in macOS 14 (person-instance masks, animal and 3D human body pose, optical-flow and image-registration tracking, …) return an error on older systems.
- Xcode with the macOS SDK (the build compiles a Swift bridge).

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

All request-type modules can be enabled independently, and the default feature set still enables the full Vision surface. v0.16.7 also carries an optional `async` feature for executor-agnostic `Future` wrappers around the Tier-1 one-shot request surface.

## Async API

Enable `async` plus the request features you need:

```toml
apple-vision = { version = "0.16.7", features = ["async", "recognize_text"] }
```

```rust,ignore
use apple_vision::async_api::AsyncRecognizeText;
use apple_vision::RecognitionLevel;

# async fn example() -> Result<(), Box<dyn std::error::Error>> {
let texts = AsyncRecognizeText::new(RecognitionLevel::Accurate, true)
    .recognize_in_path("screenshot.png")
    .await?;
println!("found {} text observations", texts.len());
# Ok(())
# }
```

Tier-1 covers OCR, face detection, barcode detection, person segmentation, `VNCoreMLRequest`, `VNDetectHumanBodyPose3DRequest`, and `VNDetectTrajectoriesRequest`. Each future runs the synchronous request on the libdispatch global queue and resolves to exactly what the synchronous API returns, error variants included; a request that panics resolves with an error. Multi-fire delegate / stream-style Vision APIs remain future Tier-2 work.

## Image orientation

Path-based requests honor the image's EXIF orientation, so results are relative to the image as it is displayed (a portrait phone photo is analysed upright). `ImageRequestHandler::with_orientation` overrides the file's orientation.

## Core ML models

A `CoreMLModel` compiles its `.mlmodel` on first use and caches the result; clones share it, and the compiled output is deleted when the last clone is dropped. Precompiled `.mlmodelc` bundles are loaded directly.

## Roadmap

- [x] Single-image Vision requests (OCR, faces, landmarks, pose, contours, saliency, segmentation, Core ML, and the rest of the stateless request surface)
- [x] Pairwise image-registration requests (`VNTranslationalImageRegistrationRequest`, `VNHomographicImageRegistrationRequest`)
- [x] Stateful tracking requests (`VNTrackObjectRequest`, `VNTrackRectangleRequest`, `VNTrackOpticalFlowRequest`, `VNTrackTranslationalImageRegistrationRequest`, `VNTrackHomographicImageRegistrationRequest`)
- [x] Header-audited request + observation coverage matrix (`COVERAGE.md`) with dedicated wrappers for every current Objective-C request/observation type and a split Swift bridge (all bridge files stay under 500 lines); the Swift-only Vision API is not covered
- [x] Explicit `VNRequest` / `VNObservation` / request-handler / `VNVideoProcessor` wrappers for OCR pipelines, plus base request/observation helpers reused across the rest of the crate
- [x] Async API (Tier-1 `Future` wrappers for OCR, face detection, barcode detection, person segmentation, Core ML requests, human-body-pose 3D, and trajectory detection; Tier-2 stream/delegate surfaces still TBD)

## License

Licensed under either of [Apache-2.0](LICENSE-APACHE) or [MIT](LICENSE-MIT) at your option.
