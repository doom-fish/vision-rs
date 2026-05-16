//! Human hand pose detection (`VNDetectHumanHandPoseRequest`).
//!
//! Re-uses [`crate::body_pose::DetectedBodyPose`] / [`JointPoint`] as the
//! result shape — only the joint names differ (Apple's
//! `VNHumanHandPoseObservationJointName`: `"wrist_joint"`,
//! `"thumb_tip_joint"`, `"index_pip_joint"`, …).

use core::ffi::c_char;
use core::ptr;
use std::ffi::CString;
use std::path::Path;

use crate::body_pose::{collect, DetectedBodyPose};
pub use crate::body_pose::{DetectedBodyPose as DetectedHandPose, JointPoint};
use crate::error::{from_swift, VisionError};
use crate::ffi;

/// Detect up to `max_hands` (use `0` for "no limit") in the image at
/// `path`.
///
/// # Errors
///
/// Returns [`VisionError::ImageLoadFailed`] / [`VisionError::RequestFailed`].
pub fn detect_human_hand_pose_in_path(
    path: impl AsRef<Path>,
    max_hands: usize,
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
    let status = unsafe {
        ffi::vn_detect_human_hand_pose_in_path(
            path_c.as_ptr(),
            max_hands,
            &mut out_array,
            &mut out_count,
            &mut err_msg,
        )
    };
    if status != ffi::status::OK {
        return Err(unsafe { from_swift(status, err_msg) });
    }
    Ok(unsafe { collect(out_array, out_count) })
}
