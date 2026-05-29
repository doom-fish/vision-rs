#![cfg(feature = "segmentation")]

use std::fs;
use std::path::PathBuf;

use apple_vision::recognize_text::_test_helper_render_text_png;
use apple_vision::segmentation::_test_helper_scaled_mask_to_one8;
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
fn scaled_mask_float_buffer_is_normalised_to_8bit() {
    // `generateScaledMaskForImage` returns a OneComponent32Float buffer
    // (0.0..=1.0). The bridge must convert it to tightly packed 8-bit alpha,
    // not memcpy raw float bytes through the u8 `SegmentationMask` contract.
    // Width 3 x height 2, with soft edge values.
    let floats = [0.0, 0.5, 1.0, 0.25, 0.75, 1.0];
    let mask = _test_helper_scaled_mask_to_one8(&floats, 3, 2);

    assert_eq!((mask.width, mask.height), (3, 2));
    assert_eq!(
        mask.bytes_per_row, 3,
        "must be tightly packed 8-bit (1 byte/pixel); width*4 means float bytes leaked",
    );
    assert_eq!(mask.bytes.len(), 6);
    // 0.5 * 255 ≈ 128 (rounded), 0.25 ≈ 64, 0.75 ≈ 191.
    assert_eq!(mask.bytes, vec![0, 128, 255, 64, 191, 255]);
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
        // Regression guard: `generateScaledMaskForImage` returns a
        // OneComponent32Float buffer. The bridge must normalise it to tightly
        // packed 8-bit alpha (one byte per pixel), not memcpy the raw float
        // bytes through the u8 `SegmentationMask` contract. A float passthrough
        // would surface here as bytes_per_row == width * 4.
        assert_eq!(
            mask.bytes_per_row, mask.width,
            "scaled mask must be tightly packed 8-bit (bytes_per_row == width); \
             a value of width*4 indicates raw float32 bytes leaked through",
        );
        assert_eq!(mask.bytes.len(), mask.height * mask.bytes_per_row);
        // A genuine alpha mask is not a single flat value; soft anti-aliased
        // edges mean both background (low) and foreground (high) samples exist.
        let min = mask.bytes.iter().copied().min().unwrap_or(0);
        let max = mask.bytes.iter().copied().max().unwrap_or(0);
        assert!(
            max > min,
            "expected a varying 0..=255 alpha mask, got a flat value {min}",
        );

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
