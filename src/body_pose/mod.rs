//! Human body pose detection (`VNDetectHumanBodyPoseRequest`).

use core::ffi::c_char;
use core::ptr;
use std::collections::HashMap;
use std::ffi::CString;
use std::path::Path;

use crate::error::{from_swift, VisionError};
use crate::ffi;
use crate::recognize_text::BoundingBox;

/// A single detected joint in normalised image coordinates
/// (`0.0..=1.0`, bottom-left origin).
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct JointPoint {
    pub x: f64,
    pub y: f64,
    pub confidence: f32,
}

/// One detected human body with its recognised joints.
///
/// `joints` keys use Apple's `VNHumanBodyPoseObservationJointName`
/// values: `"head_joint"`, `"left_shoulder_joint"`, `"right_wrist_joint"`,
/// `"left_hip_joint"`, `"root"`, etc.
#[derive(Debug, Clone, PartialEq)]
pub struct DetectedBodyPose {
    pub bounding_box: BoundingBox,
    pub confidence: f32,
    pub joints: HashMap<String, JointPoint>,
}

/// Detect human body poses in the image at `path`.
///
/// # Errors
///
/// Returns [`VisionError::ImageLoadFailed`] / [`VisionError::RequestFailed`].
pub fn detect_human_body_pose_in_path(
    path: impl AsRef<Path>,
) -> Result<Vec<DetectedBodyPose>, VisionError> {
    unsafe { run(path, ffi::vn_detect_human_body_pose_in_path) }
}

pub(crate) unsafe fn run(
    path: impl AsRef<Path>,
    f: unsafe extern "C" fn(
        *const c_char,
        *mut *mut core::ffi::c_void,
        *mut usize,
        *mut *mut c_char,
    ) -> i32,
) -> Result<Vec<DetectedBodyPose>, VisionError> {
    let path_str = path
        .as_ref()
        .to_str()
        .ok_or_else(|| VisionError::InvalidArgument("non-UTF-8 path".into()))?;
    let path_c = CString::new(path_str)
        .map_err(|e| VisionError::InvalidArgument(format!("path NUL byte: {e}")))?;

    let mut out_array: *mut core::ffi::c_void = ptr::null_mut();
    let mut out_count: usize = 0;
    let mut err_msg: *mut c_char = ptr::null_mut();
    let status = f(path_c.as_ptr(), &mut out_array, &mut out_count, &mut err_msg);
    if status != ffi::status::OK {
        return Err(from_swift(status, err_msg));
    }
    Ok(collect(out_array, out_count))
}

pub(crate) unsafe fn collect(
    out_array: *mut core::ffi::c_void,
    out_count: usize,
) -> Vec<DetectedBodyPose> {
    if out_array.is_null() || out_count == 0 {
        return Vec::new();
    }
    let typed = out_array.cast::<ffi::PoseObservationRaw>();
    let mut v = Vec::with_capacity(out_count);
    for i in 0..out_count {
        let raw = &*typed.add(i);
        let mut joints = HashMap::with_capacity(raw.joint_count);
        for j in 0..raw.joint_count {
            let name_ptr = *raw.joint_names.add(j);
            if name_ptr.is_null() {
                continue;
            }
            let name = core::ffi::CStr::from_ptr(name_ptr)
                .to_string_lossy()
                .into_owned();
            joints.insert(
                name,
                JointPoint {
                    x: *raw.joint_xs.add(j),
                    y: *raw.joint_ys.add(j),
                    confidence: *raw.joint_confidences.add(j),
                },
            );
        }
        v.push(DetectedBodyPose {
            bounding_box: BoundingBox {
                x: raw.bbox_x,
                y: raw.bbox_y,
                width: raw.bbox_w,
                height: raw.bbox_h,
            },
            confidence: raw.confidence,
            joints,
        });
    }
    ffi::vn_pose_observations_free(out_array, out_count);
    v
}
