#![cfg(feature = "segmentation")]

use std::fs;
use std::path::PathBuf;

use apple_vision::recognize_text::_test_helper_render_text_png;
use apple_vision::{
    generate_foreground_instance_mask_in_path, generate_scaled_foreground_mask_in_path,
};

fn fixtures_dir() -> Result<PathBuf, Box<dyn std::error::Error>> {
    let dir = std::env::current_dir()?
        .join("target")
        .join("vision-test-fixtures")
        .join("segmentation");
    fs::create_dir_all(&dir)?;
    Ok(dir)
}

#[test]
fn scaled_foreground_mask_invalid_path_errors() {
    let result = generate_scaled_foreground_mask_in_path("/this/path/does/not/exist.png");
    assert!(result.is_err(), "expected error for nonexistent path");
}

#[test]
fn scaled_foreground_mask_dimensions_match_source(
) -> Result<(), Box<dyn std::error::Error>> {
    let dir = fixtures_dir()?;
    let image = dir.join("scaled-mask.png");
    _test_helper_render_text_png("HELLO", 640, 480, &image)?;

    let scaled = generate_scaled_foreground_mask_in_path(&image)?;
    if let Some(mask) = scaled {
        assert_eq!(
            (mask.width, mask.height),
            (640, 480),
            "scaled mask must match the source image dimensions, not the inference resolution",
        );
        assert!(
            mask.bytes_per_row >= mask.width,
            "bytes_per_row must cover at least one byte per pixel",
        );
        assert_eq!(mask.bytes.len(), mask.height * mask.bytes_per_row);

        let raw = generate_foreground_instance_mask_in_path(&image)?
            .expect("raw mask should also be present when scaled mask is");
        assert!(
            mask.width >= raw.mask.width && mask.height >= raw.mask.height,
            "scaled mask ({}x{}) must be at least the raw mask size ({}x{})",
            mask.width,
            mask.height,
            raw.mask.width,
            raw.mask.height,
        );
    }
    Ok(())
}
