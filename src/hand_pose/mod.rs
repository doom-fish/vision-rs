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
use crate::recognized_points::RecognizedPointsObservation;
use crate::error::{from_swift, VisionError};
use crate::ffi;

/// The `VNChirality` reported by `VNHumanHandPoseObservation`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum HandChirality {
    Unknown,
    Left,
    Right,
}

/// A dedicated `VNHumanHandPoseObservation` wrapper.
#[derive(Debug, Clone, PartialEq)]
pub struct HumanHandPoseObservation {
    pub recognized_points: RecognizedPointsObservation,
    pub available_joint_names: Vec<String>,
    pub available_joint_group_names: Vec<String>,
    pub chirality: HandChirality,
}

impl HumanHandPoseObservation {
    #[must_use]
    pub const fn supported_joint_group_names() -> &'static [&'static str] {
        &["thumb", "indexFinger", "middleFinger", "ringFinger", "littleFinger", "all"]
    }

    #[must_use]
    pub fn into_detected_hand_pose(self) -> DetectedHandPose {
        self.into()
    }
}

impl From<DetectedHandPose> for HumanHandPoseObservation {
    fn from(value: DetectedHandPose) -> Self {
        let body = crate::body_pose::HumanBodyPoseObservation::from(value);
        Self {
            recognized_points: body.recognized_points,
            available_joint_names: body.available_joint_names,
            available_joint_group_names: Self::supported_joint_group_names()
                .iter()
                .map(|name| (*name).to_string())
                .collect(),
            chirality: HandChirality::Unknown,
        }
    }
}

impl From<HumanHandPoseObservation> for DetectedHandPose {
    fn from(value: HumanHandPoseObservation) -> Self {
        crate::body_pose::HumanBodyPoseObservation {
            recognized_points: value.recognized_points,
            available_joint_names: value.available_joint_names,
            available_joint_group_names: value.available_joint_group_names,
        }
        .into()
    }
}

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

/// Detect dedicated `VNHumanHandPoseObservation` wrappers in the image at `path`.
///
/// # Errors
///
/// Returns [`VisionError::ImageLoadFailed`] / [`VisionError::RequestFailed`].
pub fn detect_human_hand_pose_observations_in_path(
    path: impl AsRef<Path>,
    max_hands: usize,
) -> Result<Vec<HumanHandPoseObservation>, VisionError> {
    detect_human_hand_pose_in_path(path, max_hands)
        .map(|poses| poses.into_iter().map(Into::into).collect())
}
