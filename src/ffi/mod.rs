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

/// Mirrors `VNFaceLandmarksRaw` in Vision.swift. Layout-compatible.
///
/// All `*_count` fields are NUMBER OF POINTS; each point buffer is an
/// interleaved `[x0, y0, x1, y1, …]` array of doubles, length
/// `count * 2`. A NULL pointer + 0 count means the region wasn't
/// produced for this face.
#[repr(C)]
pub struct FaceLandmarksRaw {
    pub bbox_x: f64,
    pub bbox_y: f64,
    pub bbox_w: f64,
    pub bbox_h: f64,
    pub confidence: f32,
    pub roll: f32,
    pub yaw: f32,
    pub pitch: f32,

    pub face_contour: *mut f64,
    pub face_contour_count: usize,
    pub left_eye: *mut f64,
    pub left_eye_count: usize,
    pub right_eye: *mut f64,
    pub right_eye_count: usize,
    pub left_eyebrow: *mut f64,
    pub left_eyebrow_count: usize,
    pub right_eyebrow: *mut f64,
    pub right_eyebrow_count: usize,
    pub nose: *mut f64,
    pub nose_count: usize,
    pub nose_crest: *mut f64,
    pub nose_crest_count: usize,
    pub median_line: *mut f64,
    pub median_line_count: usize,
    pub outer_lips: *mut f64,
    pub outer_lips_count: usize,
    pub inner_lips: *mut f64,
    pub inner_lips_count: usize,
    pub left_pupil: *mut f64,
    pub left_pupil_count: usize,
    pub right_pupil: *mut f64,
    pub right_pupil_count: usize,
}

/// Mirrors `VNPoseObservationRaw` in Vision.swift. Layout-compatible.
#[repr(C)]
pub struct PoseObservationRaw {
    pub bbox_x: f64,
    pub bbox_y: f64,
    pub bbox_w: f64,
    pub bbox_h: f64,
    pub confidence: f32,
    pub joint_names: *mut *mut c_char,
    pub joint_xs: *mut f64,
    pub joint_ys: *mut f64,
    pub joint_confidences: *mut f32,
    pub joint_count: usize,
}

/// Mirrors `VNContourRaw` in Vision.swift. Layout-compatible.
#[repr(C)]
pub struct ContourRaw {
    pub point_xs: *mut f64,
    pub point_ys: *mut f64,
    pub point_count: usize,
    pub child_count: isize,
    pub aspect_ratio: f32,
}

/// Mirrors `VNRecognizedAnimalRaw` in Vision.swift. Layout-compatible.
#[repr(C)]
pub struct RecognizedAnimalRaw {
    pub identifier: *mut c_char,
    pub confidence: f32,
    pub bbox_x: f64,
    pub bbox_y: f64,
    pub bbox_w: f64,
    pub bbox_h: f64,
}

/// Mirrors `VNClassificationRaw` in Vision.swift. Layout-compatible.
#[repr(C)]
pub struct ClassificationRaw {
    pub identifier: *mut c_char,
    pub confidence: f32,
}

/// Mirrors `VNRectangleObservationRaw` in Vision.swift. Layout-compatible.
#[repr(C)]
pub struct RectangleObservationRaw {
    pub bbox_x: f64,
    pub bbox_y: f64,
    pub bbox_w: f64,
    pub bbox_h: f64,
    pub confidence: f32,
    pub tl_x: f64,
    pub tl_y: f64,
    pub tr_x: f64,
    pub tr_y: f64,
    pub bl_x: f64,
    pub bl_y: f64,
    pub br_x: f64,
    pub br_y: f64,
}

/// Mirrors `VNFeaturePrintRaw` in Vision.swift. Layout-compatible.
#[repr(C)]
pub struct FeaturePrintRaw {
    pub element_type: i32,
    pub element_count: usize,
    pub bytes: *mut c_void,
}

/// Mirrors `VNHumanObservationRaw` in Vision.swift. Layout-compatible.
#[repr(C)]
pub struct HumanObservationRaw {
    pub bbox_x: f64,
    pub bbox_y: f64,
    pub bbox_w: f64,
    pub bbox_h: f64,
    pub confidence: f32,
    pub upper_body_only: bool,
}

/// Mirrors `VNAestheticsScoresRaw` in Vision.swift. Layout-compatible.
#[repr(C)]
pub struct AestheticsScoresRaw {
    pub overall_score: f32,
    pub is_utility: bool,
}

/// Mirrors `VNFaceQualityRaw` in Vision.swift. Layout-compatible.
#[repr(C)]
pub struct FaceQualityRaw {
    pub bbox_x: f64,
    pub bbox_y: f64,
    pub bbox_w: f64,
    pub bbox_h: f64,
    pub confidence: f32,
    pub capture_quality: f32,
    pub has_quality: bool,
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

    pub fn vn_detect_face_landmarks_in_path(
        path: *const c_char,
        out_array: *mut *mut c_void,
        out_count: *mut usize,
        out_error_message: *mut *mut c_char,
    ) -> i32;

    pub fn vn_face_landmarks_free(array: *mut c_void, count: usize);

    pub fn vn_detect_human_body_pose_in_path(
        path: *const c_char,
        out_array: *mut *mut c_void,
        out_count: *mut usize,
        out_error_message: *mut *mut c_char,
    ) -> i32;

    pub fn vn_detect_human_hand_pose_in_path(
        path: *const c_char,
        max_hands: usize,
        out_array: *mut *mut c_void,
        out_count: *mut usize,
        out_error_message: *mut *mut c_char,
    ) -> i32;

    pub fn vn_pose_observations_free(array: *mut c_void, count: usize);

    pub fn vn_detect_contours_in_path(
        path: *const c_char,
        contrast_adjustment: f32,
        detects_dark_on_light: bool,
        out_array: *mut *mut c_void,
        out_count: *mut usize,
        out_error_message: *mut *mut c_char,
    ) -> i32;

    pub fn vn_contours_free(array: *mut c_void, count: usize);

    pub fn vn_recognize_animals_in_path(
        path: *const c_char,
        out_array: *mut *mut c_void,
        out_count: *mut usize,
        out_error_message: *mut *mut c_char,
    ) -> i32;

    pub fn vn_recognized_animals_free(array: *mut c_void, count: usize);

    pub fn vn_classify_image_in_path(
        path: *const c_char,
        out_array: *mut *mut c_void,
        out_count: *mut usize,
        out_error_message: *mut *mut c_char,
    ) -> i32;
    pub fn vn_classifications_free(array: *mut c_void, count: usize);

    pub fn vn_detect_rectangles_in_path(
        path: *const c_char,
        max_observations: usize,
        minimum_aspect_ratio: f32,
        maximum_aspect_ratio: f32,
        minimum_size: f32,
        minimum_confidence: f32,
        out_array: *mut *mut c_void,
        out_count: *mut usize,
        out_error_message: *mut *mut c_char,
    ) -> i32;

    pub fn vn_detect_document_segmentation_in_path(
        path: *const c_char,
        out_array: *mut *mut c_void,
        out_count: *mut usize,
        out_error_message: *mut *mut c_char,
    ) -> i32;

    pub fn vn_rectangle_observations_free(array: *mut c_void, count: usize);

    pub fn vn_detect_horizon_in_path(
        path: *const c_char,
        out_angle: *mut f64,
        out_has_value: *mut bool,
        out_error_message: *mut *mut c_char,
    ) -> i32;

    pub fn vn_generate_image_feature_print_in_path(
        path: *const c_char,
        out_feature: *mut FeaturePrintRaw,
        out_error_message: *mut *mut c_char,
    ) -> i32;
    pub fn vn_feature_print_free(feature: *mut FeaturePrintRaw);

    pub fn vn_detect_human_rectangles_in_path(
        path: *const c_char,
        upper_body_only: bool,
        out_array: *mut *mut c_void,
        out_count: *mut usize,
        out_error_message: *mut *mut c_char,
    ) -> i32;
    pub fn vn_human_observations_free(array: *mut c_void, count: usize);

    pub fn vn_calculate_aesthetics_scores_in_path(
        path: *const c_char,
        out_scores: *mut AestheticsScoresRaw,
        out_has_value: *mut bool,
        out_error_message: *mut *mut c_char,
    ) -> i32;

    pub fn vn_detect_face_capture_quality_in_path(
        path: *const c_char,
        out_array: *mut *mut c_void,
        out_count: *mut usize,
        out_error_message: *mut *mut c_char,
    ) -> i32;

    pub fn vn_face_quality_observations_free(array: *mut c_void, count: usize);

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
