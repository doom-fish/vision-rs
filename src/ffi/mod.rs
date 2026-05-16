//! Raw FFI declarations matching the Swift bridge in
//! `swift-bridge/Sources/VisionBridge/Vision.swift`.

#![allow(missing_docs, non_camel_case_types)]

use core::ffi::{c_char, c_void};

/// Mirrors `VNRecognizedTextRaw` in Vision.swift. Layout-compatible.
#[repr(C)]
pub struct RecognizedTextRaw {
    pub text: *mut c_char,
    pub confidence: f32,
    pub bbox_x: f64,
    pub bbox_y: f64,
    pub bbox_w: f64,
    pub bbox_h: f64,
}

/// Mirrors `VNDetectedFaceRaw` in Vision.swift. Layout-compatible.
#[repr(C)]
pub struct DetectedFaceRaw {
    pub bbox_x: f64,
    pub bbox_y: f64,
    pub bbox_w: f64,
    pub bbox_h: f64,
    pub confidence: f32,
    pub roll: f32,
    pub yaw: f32,
    pub pitch: f32,
}

/// Mirrors `VNDetectedBarcodeRaw` in Vision.swift. Layout-compatible.
#[repr(C)]
pub struct DetectedBarcodeRaw {
    pub payload: *mut c_char,
    pub symbology: *mut c_char,
    pub confidence: f32,
    pub bbox_x: f64,
    pub bbox_y: f64,
    pub bbox_w: f64,
    pub bbox_h: f64,
}

/// Mirrors `VNSaliencyRegionRaw` in Vision.swift. Layout-compatible.
#[repr(C)]
pub struct SaliencyRegionRaw {
    pub confidence: f32,
    pub bbox_x: f64,
    pub bbox_y: f64,
    pub bbox_w: f64,
    pub bbox_h: f64,
}

extern "C" {
    pub fn vn_string_free(s: *mut c_char);

    pub fn vn_recognize_text_in_path(
        path: *const c_char,
        recognition_level: i32,
        uses_language_correction: bool,
        out_array: *mut *mut c_void,
        out_count: *mut usize,
        out_error_message: *mut *mut c_char,
    ) -> i32;

    pub fn vn_recognize_text_in_pixel_buffer(
        pixel_buffer: *mut c_void,
        recognition_level: i32,
        uses_language_correction: bool,
        out_array: *mut *mut c_void,
        out_count: *mut usize,
        out_error_message: *mut *mut c_char,
    ) -> i32;

    pub fn vn_recognized_text_free(array: *mut c_void, count: usize);

    pub fn vn_detect_faces_in_path(
        path: *const c_char,
        out_array: *mut *mut c_void,
        out_count: *mut usize,
        out_error_message: *mut *mut c_char,
    ) -> i32;

    pub fn vn_detect_faces_in_pixel_buffer(
        pixel_buffer: *mut c_void,
        out_array: *mut *mut c_void,
        out_count: *mut usize,
        out_error_message: *mut *mut c_char,
    ) -> i32;

    pub fn vn_detected_faces_free(array: *mut c_void, count: usize);

    pub fn vn_detect_barcodes_in_path(
        path: *const c_char,
        out_array: *mut *mut c_void,
        out_count: *mut usize,
        out_error_message: *mut *mut c_char,
    ) -> i32;

    pub fn vn_detected_barcodes_free(array: *mut c_void, count: usize);

    pub fn vn_attention_saliency_in_path(
        path: *const c_char,
        out_array: *mut *mut c_void,
        out_count: *mut usize,
        out_error_message: *mut *mut c_char,
    ) -> i32;

    pub fn vn_saliency_regions_free(array: *mut c_void, count: usize);

    pub fn vn_test_helper_render_text_png(
        text: *const c_char,
        width: i32,
        height: i32,
        output_path: *const c_char,
    ) -> i32;
}

pub mod status {
    pub const OK: i32 = 0;
    pub const INVALID_ARGUMENT: i32 = -1;
    pub const IMAGE_LOAD_FAILED: i32 = -2;
    pub const REQUEST_FAILED: i32 = -3;
    pub const UNKNOWN: i32 = -99;
}

// silence unused
const _: () = {
    let _ = core::mem::size_of::<*mut c_void>();
};
