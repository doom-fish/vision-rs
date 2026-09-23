#![cfg(feature = "recognize_text")]

use std::fs;
use std::path::PathBuf;

use apple_vision::recognize_text::{
    _test_helper_render_sideways_text_jpeg, _test_helper_render_text_png,
};
use apple_vision::{
    ImageOrientation, ImageRequestHandler, RecognitionLevel, Request, TextRecognizer,
};

fn fixtures_dir() -> Result<PathBuf, Box<dyn std::error::Error>> {
    let dir = std::env::current_dir()?
        .join("target")
        .join("vision-test-fixtures")
        .join("orientation");
    fs::create_dir_all(&dir)?;
    Ok(dir)
}

#[test]
fn exif_orientation_is_applied_to_path_based_requests() -> Result<(), Box<dyn std::error::Error>> {
    let dir = fixtures_dir()?;
    let sideways = dir.join("sideways.jpg");
    _test_helper_render_sideways_text_jpeg("ROTATED", 960, 240, &sideways)?;

    let texts = TextRecognizer::new().recognize_in_path(&sideways)?;
    let line = texts
        .iter()
        .find(|text| text.text.to_ascii_uppercase().contains("ROTATED"))
        .unwrap_or_else(|| panic!("text should be read upright, got {texts:?}"));
    assert!(
        line.bounding_box.width > line.bounding_box.height,
        "the text line must be horizontal in the upright image: {:?}",
        line.bounding_box
    );

    let request = Request::recognize_text().with_recognition_level(RecognitionLevel::Accurate);
    let observations = ImageRequestHandler::new(&sideways).perform(&request)?;
    assert!(observations
        .iter()
        .any(|observation| observation.text.to_ascii_uppercase().contains("ROTATED")));
    Ok(())
}

#[test]
fn request_handler_orientation_overrides_the_file() -> Result<(), Box<dyn std::error::Error>> {
    let dir = fixtures_dir()?;
    let upright = dir.join("upright.png");
    _test_helper_render_text_png("UPRIGHT", 960, 240, &upright)?;
    let request = Request::recognize_text().with_recognition_level(RecognitionLevel::Accurate);

    let handler = ImageRequestHandler::new(&upright);
    assert_eq!(handler.orientation(), None);
    for (orientation, horizontal) in [
        (None, true),
        (Some(ImageOrientation::Up), true),
        (Some(ImageOrientation::Right), false),
        (Some(ImageOrientation::Left), false),
    ] {
        let handler = orientation.map_or_else(
            || handler.clone(),
            |orientation| handler.clone().with_orientation(orientation),
        );
        assert_eq!(handler.orientation(), orientation);
        let observations = handler.perform(&request)?;
        let line = observations
            .iter()
            .find(|observation| observation.text.to_ascii_uppercase().contains("UPRIGHT"))
            .unwrap_or_else(|| panic!("{orientation:?}: text not found in {observations:?}"));
        let bounding_box = line.bounding_box;
        assert_eq!(
            bounding_box.width > bounding_box.height,
            horizontal,
            "{orientation:?}: {bounding_box:?}"
        );
    }
    Ok(())
}
