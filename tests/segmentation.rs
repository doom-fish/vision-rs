#![cfg(feature = "segmentation")]

use std::fs;
use std::path::PathBuf;

use apple_vision::recognize_text::_test_helper_render_text_png;
use apple_vision::segmentation::{
    _test_helper_fill_one8, generate_person_segmentation_in_path, SegmentationQuality,
};
use apple_vision::{
    generate_foreground_instance_mask_in_path, generate_scaled_foreground_mask_in_path,
    person_instance_mask, VisionError,
};

const ONE_COMPONENT_8: u32 = u32::from_be_bytes(*b"L008");
const ONE_COMPONENT_16_HALF: u32 = u32::from_be_bytes(*b"L00h");
const ONE_COMPONENT_32_FLOAT: u32 = u32::from_be_bytes(*b"L00f");

fn float_bytes(values: &[f32]) -> Vec<u8> {
    values
        .iter()
        .flat_map(|value| value.to_ne_bytes())
        .collect()
}

fn half_bytes(values: &[u16]) -> Vec<u8> {
    values
        .iter()
        .flat_map(|value| value.to_ne_bytes())
        .collect()
}

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
    let mask = _test_helper_fill_one8(&float_bytes(&floats), ONE_COMPONENT_32_FLOAT, 4, 3, 2)
        .expect("float mask converts");

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
fn non_finite_and_out_of_range_floats_are_clamped() {
    let floats = [
        f32::NAN,
        f32::INFINITY,
        f32::NEG_INFINITY,
        1.5,
        -0.5,
        -f32::NAN,
    ];
    let mask = _test_helper_fill_one8(&float_bytes(&floats), ONE_COMPONENT_32_FLOAT, 4, 6, 1)
        .expect("non-finite values must not trap");
    assert_eq!(mask.bytes, vec![0, 255, 0, 255, 0, 0]);
}

#[test]
fn half_float_masks_are_converted_not_over_read() {
    let halves = [
        0x0000, 0x3800, 0x3C00, 0x3400, 0x7E00, 0x0001, 0xBC00, 0x7C00,
    ];
    let mask = _test_helper_fill_one8(&half_bytes(&halves), ONE_COMPONENT_16_HALF, 2, 4, 2)
        .expect("half mask converts");
    assert_eq!(mask.bytes, vec![0, 128, 255, 64, 0, 0, 0, 255]);
}

#[test]
fn eight_bit_masks_are_copied() {
    let values = [0_u8, 7, 128, 255, 1, 2];
    let mask = _test_helper_fill_one8(&values, ONE_COMPONENT_8, 1, 2, 3).expect("8-bit mask");
    assert_eq!(mask.bytes, values);
    assert_eq!(mask.bytes_per_row, 2);
}

#[test]
fn unsupported_mask_formats_are_rejected() {
    let bgra = [0_u8; 16];
    let result = _test_helper_fill_one8(&bgra, u32::from_be_bytes(*b"BGRA"), 4, 2, 2);
    assert!(
        matches!(result, Err(VisionError::RequestFailed(_))),
        "{result:?}"
    );
}

#[test]
fn mismatched_mask_lengths_are_rejected() {
    let floats = float_bytes(&[0.0; 5]);
    for (width, height) in [(3, 2), (0, 5), (usize::MAX, 2)] {
        let result = _test_helper_fill_one8(&floats, ONE_COMPONENT_32_FLOAT, 4, width, height);
        assert!(
            matches!(result, Err(VisionError::InvalidArgument(_))),
            "{result:?}"
        );
    }
}

#[test]
fn person_instance_mask_reports_errors_and_consistent_masks(
) -> Result<(), Box<dyn std::error::Error>> {
    assert!(person_instance_mask("/this/path/does/not/exist.png").is_err());

    let dir = fixtures_dir()?;
    let image = dir.join("person-instance-mask.png");
    _test_helper_render_text_png("NOBODY HERE", 320, 240, &image)?;
    if let Some(mask) = person_instance_mask(&image)? {
        assert_eq!((mask.width(), mask.height()), (320, 240));
        assert_eq!(mask.bytes_per_row(), mask.width());
        assert_eq!(mask.as_bytes().len(), mask.width() * mask.height());
    }
    Ok(())
}

#[test]
fn person_segmentation_returns_an_8_bit_mask() -> Result<(), Box<dyn std::error::Error>> {
    let dir = fixtures_dir()?;
    let image = dir.join("person-segmentation.png");
    _test_helper_render_text_png("SEGMENT", 320, 240, &image)?;
    for quality in [
        SegmentationQuality::Fast,
        SegmentationQuality::Balanced,
        SegmentationQuality::Accurate,
    ] {
        let mask = generate_person_segmentation_in_path(&image, quality)?
            .expect("person segmentation always produces a mask");
        assert!(mask.width > 0 && mask.height > 0);
        assert!(
            mask.bytes_per_row >= mask.width && mask.bytes_per_row < mask.width * 2,
            "expected one byte per pixel, got {} bytes per row for width {}",
            mask.bytes_per_row,
            mask.width
        );
        assert_eq!(mask.bytes.len(), mask.height * mask.bytes_per_row);
    }
    Ok(())
}

#[test]
fn scaled_foreground_mask_dimensions_match_source() -> Result<(), Box<dyn std::error::Error>> {
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
