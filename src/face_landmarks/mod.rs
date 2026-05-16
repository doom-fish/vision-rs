//! [`detect_face_landmarks_in_path`] — wraps `VNDetectFaceLandmarksRequest`.
//!
//! Returns each face's bounding box, optional roll/yaw/pitch, and the
//! detected landmark regions (eyes, eyebrows, nose, lips, pupils, …).
//! Each region is exposed as a list of normalised `(x, y)` points in
//! Vision's bottom-left coordinate system.

use core::ffi::c_char;
use core::ptr;
use std::ffi::CString;
use std::path::Path;

use crate::error::{from_swift, VisionError};
use crate::ffi;
use crate::recognize_text::BoundingBox;

/// A 2-D point in Vision's normalised image space (`0.0..=1.0`,
/// bottom-left origin).
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct LandmarkPoint {
    pub x: f64,
    pub y: f64,
}

/// One face plus its detected landmarks. Any region with no points
/// detected is returned as an empty `Vec`.
#[derive(Debug, Clone, PartialEq)]
pub struct FaceWithLandmarks {
    pub bounding_box: BoundingBox,
    pub confidence: f32,
    pub roll: Option<f32>,
    pub yaw: Option<f32>,
    pub pitch: Option<f32>,
    pub face_contour: Vec<LandmarkPoint>,
    pub left_eye: Vec<LandmarkPoint>,
    pub right_eye: Vec<LandmarkPoint>,
    pub left_eyebrow: Vec<LandmarkPoint>,
    pub right_eyebrow: Vec<LandmarkPoint>,
    pub nose: Vec<LandmarkPoint>,
    pub nose_crest: Vec<LandmarkPoint>,
    pub median_line: Vec<LandmarkPoint>,
    pub outer_lips: Vec<LandmarkPoint>,
    pub inner_lips: Vec<LandmarkPoint>,
    pub left_pupil: Vec<LandmarkPoint>,
    pub right_pupil: Vec<LandmarkPoint>,
}

unsafe fn copy_region(ptr: *mut f64, n: usize) -> Vec<LandmarkPoint> {
    if ptr.is_null() || n == 0 {
        return Vec::new();
    }
    let mut v = Vec::with_capacity(n);
    for i in 0..n {
        let x = unsafe { *ptr.add(i * 2) };
        let y = unsafe { *ptr.add(i * 2 + 1) };
        v.push(LandmarkPoint { x, y });
    }
    v
}

/// Detect faces and their landmark regions in the image at `path`.
///
/// # Errors
///
/// Returns [`VisionError::ImageLoadFailed`] or
/// [`VisionError::RequestFailed`] on Apple-side failures.
pub fn detect_face_landmarks_in_path(
    path: impl AsRef<Path>,
) -> Result<Vec<FaceWithLandmarks>, VisionError> {
    let path_str = path
        .as_ref()
        .to_str()
        .ok_or_else(|| VisionError::InvalidArgument("non-UTF-8 path".into()))?;
    let path_c = CString::new(path_str)
        .map_err(|e| VisionError::InvalidArgument(format!("path NUL byte: {e}")))?;

    let mut out_array: *mut core::ffi::c_void = ptr::null_mut();
    let mut out_count: usize = 0;
    let mut err_msg: *mut c_char = ptr::null_mut();

    let status = unsafe {
        ffi::vn_detect_face_landmarks_in_path(
            path_c.as_ptr(),
            &mut out_array,
            &mut out_count,
            &mut err_msg,
        )
    };
    if status != ffi::status::OK {
        return Err(unsafe { from_swift(status, err_msg) });
    }
    if out_array.is_null() || out_count == 0 {
        return Ok(Vec::new());
    }
    let typed = out_array.cast::<ffi::FaceLandmarksRaw>();
    let mut faces = Vec::with_capacity(out_count);
    for i in 0..out_count {
        let raw = unsafe { &*typed.add(i) };
        faces.push(FaceWithLandmarks {
            bounding_box: BoundingBox {
                x: raw.bbox_x,
                y: raw.bbox_y,
                width: raw.bbox_w,
                height: raw.bbox_h,
            },
            confidence: raw.confidence,
            roll: if raw.roll.is_nan() { None } else { Some(raw.roll) },
            yaw: if raw.yaw.is_nan() { None } else { Some(raw.yaw) },
            pitch: if raw.pitch.is_nan() {
                None
            } else {
                Some(raw.pitch)
            },
            face_contour: unsafe { copy_region(raw.face_contour, raw.face_contour_count) },
            left_eye: unsafe { copy_region(raw.left_eye, raw.left_eye_count) },
            right_eye: unsafe { copy_region(raw.right_eye, raw.right_eye_count) },
            left_eyebrow: unsafe { copy_region(raw.left_eyebrow, raw.left_eyebrow_count) },
            right_eyebrow: unsafe { copy_region(raw.right_eyebrow, raw.right_eyebrow_count) },
            nose: unsafe { copy_region(raw.nose, raw.nose_count) },
            nose_crest: unsafe { copy_region(raw.nose_crest, raw.nose_crest_count) },
            median_line: unsafe { copy_region(raw.median_line, raw.median_line_count) },
            outer_lips: unsafe { copy_region(raw.outer_lips, raw.outer_lips_count) },
            inner_lips: unsafe { copy_region(raw.inner_lips, raw.inner_lips_count) },
            left_pupil: unsafe { copy_region(raw.left_pupil, raw.left_pupil_count) },
            right_pupil: unsafe { copy_region(raw.right_pupil, raw.right_pupil_count) },
        });
    }
    unsafe { ffi::vn_face_landmarks_free(out_array, out_count) };
    Ok(faces)
}
