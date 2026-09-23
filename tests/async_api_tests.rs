//! Tests for the `async_api` module.
//!
//! These tests require the `async` feature plus the relevant per-request
//! features. Run with: `cargo test --all-features`

#![cfg(feature = "async")]

#[cfg(feature = "recognize_text")]
#[test]
fn async_recognize_text_nonexistent_path() {
    let result = pollster::block_on(async {
        apple_vision::async_api::AsyncRecognizeText::default()
            .recognize_in_path("/this/path/does/not/exist.png")
            .await
    });
    assert!(result.is_err(), "expected error for nonexistent path");
}

#[cfg(feature = "detect_faces")]
#[test]
fn async_detect_faces_nonexistent_path() {
    let result = pollster::block_on(async {
        apple_vision::async_api::AsyncDetectFaces::new()
            .detect_in_path("/nonexistent/image.jpg")
            .await
    });
    assert!(result.is_err());
}

#[cfg(feature = "detect_barcodes")]
#[test]
fn async_detect_barcodes_nonexistent_path() {
    let result = pollster::block_on(async {
        apple_vision::async_api::AsyncDetectBarcodes::new()
            .detect_in_path("/nonexistent/image.jpg")
            .await
    });
    assert!(result.is_err());
}

#[cfg(feature = "segmentation")]
#[test]
fn async_person_segmentation_nonexistent_path() {
    let result = pollster::block_on(async {
        apple_vision::async_api::AsyncPersonSegmentation::default()
            .generate_in_path("/nonexistent/image.jpg")
            .await
    });
    assert!(result.is_err());
}

#[cfg(feature = "recognize_text")]
#[test]
fn async_recognize_text_invalid_path_nul() {
    let result = pollster::block_on(async {
        apple_vision::async_api::AsyncRecognizeText::default()
            .recognize_in_path("path/with\0nul")
            .await
    });
    assert!(result.is_err());
}

#[cfg(feature = "recognize_text")]
#[test]
fn async_errors_keep_their_variant() {
    use apple_vision::async_api::AsyncRecognizeText;
    use apple_vision::VisionError;

    let missing = pollster::block_on(
        AsyncRecognizeText::default().recognize_in_path("/this/path/does/not/exist.png"),
    );
    assert!(
        matches!(missing, Err(VisionError::ImageLoadFailed(_))),
        "{missing:?}"
    );
    let nul = pollster::block_on(AsyncRecognizeText::default().recognize_in_path("path/with\0nul"));
    assert!(
        matches!(nul, Err(VisionError::InvalidArgument(_))),
        "{nul:?}"
    );
}

#[cfg(all(feature = "recognize_text", feature = "segmentation"))]
#[test]
fn async_results_match_the_sync_api() -> Result<(), Box<dyn std::error::Error>> {
    use apple_vision::async_api::{AsyncPersonSegmentation, AsyncRecognizeText};
    use apple_vision::recognize_text::_test_helper_render_text_png;
    use apple_vision::segmentation::{generate_person_segmentation_in_path, SegmentationQuality};
    use apple_vision::TextRecognizer;

    let dir = std::env::current_dir()?
        .join("target")
        .join("vision-test-fixtures")
        .join("async");
    std::fs::create_dir_all(&dir)?;
    let image = dir.join("async.png");
    _test_helper_render_text_png("ASYNC", 640, 200, &image)?;

    let sync_text = TextRecognizer::new().recognize_in_path(&image)?;
    let async_text = pollster::block_on(AsyncRecognizeText::default().recognize_in_path(&image))?;
    let texts = |results: &[apple_vision::RecognizedText]| {
        results
            .iter()
            .map(|result| result.text.clone())
            .collect::<Vec<_>>()
    };
    assert_eq!(texts(&async_text), texts(&sync_text));
    assert!(texts(&async_text).iter().any(|text| text.contains("ASYNC")));

    let sync_mask = generate_person_segmentation_in_path(&image, SegmentationQuality::Fast)?;
    let async_mask = pollster::block_on(
        AsyncPersonSegmentation::new(SegmentationQuality::Fast).generate_in_path(&image),
    )?;
    assert_eq!(
        sync_mask.map(|mask| (mask.width, mask.height, mask.bytes_per_row)),
        async_mask.map(|mask| (mask.width, mask.height, mask.bytes_per_row))
    );
    Ok(())
}
