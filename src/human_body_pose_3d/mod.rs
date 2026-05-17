#![allow(clippy::cast_possible_wrap, clippy::cast_sign_loss)]
#![allow(clippy::too_long_first_doc_paragraph)]
//! `VNDetectHumanBodyPose3DRequest` — 3D human-body keypoints
//! (macOS 14+).

use std::ffi::{CStr, CString};
use std::path::Path;
use std::ptr;

use crate::error::VisionError;
use crate::ffi;
use crate::recognized_points::{RecognizedPoint3D, RecognizedPoints3DObservation};

/// One 3D body keypoint (joint).
#[derive(Debug, Clone, PartialEq)]
pub struct HumanJoint3D {
    pub name: String,
    pub x: f32,
    pub y: f32,
    pub z: f32,
    pub confidence: f32,
}

/// Mirrors `VNHumanBodyPose3DObservation.HeightEstimation`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum BodyHeightEstimation {
    Reference,
    Measured,
}

/// A dedicated `VNHumanBodyPose3DObservation` wrapper.
#[derive(Debug, Clone, PartialEq)]
pub struct HumanBodyPose3DObservation {
    pub recognized_points: RecognizedPoints3DObservation,
    pub available_joint_names: Vec<String>,
    pub available_joint_group_names: Vec<String>,
    pub height_estimation: Option<BodyHeightEstimation>,
    pub body_height_meters: Option<f32>,
}

impl HumanBodyPose3DObservation {
    #[must_use]
    pub fn into_joints(self) -> Vec<HumanJoint3D> {
        self.into()
    }
}

impl From<Vec<HumanJoint3D>> for HumanBodyPose3DObservation {
    fn from(value: Vec<HumanJoint3D>) -> Self {
        let mut available_joint_names = value.iter().map(|joint| joint.name.clone()).collect::<Vec<_>>();
        available_joint_names.sort();
        Self {
            recognized_points: RecognizedPoints3DObservation {
                confidence: 1.0,
                available_keys: available_joint_names.clone(),
                available_group_keys: vec!["all".to_string()],
                points: value
                    .iter()
                    .map(|joint| {
                        (
                            joint.name.clone(),
                            RecognizedPoint3D {
                                x: joint.x,
                                y: joint.y,
                                z: joint.z,
                                confidence: joint.confidence,
                            },
                        )
                    })
                    .collect(),
            },
            available_joint_names,
            available_joint_group_names: vec!["all".to_string()],
            height_estimation: None,
            body_height_meters: None,
        }
    }
}

impl From<HumanBodyPose3DObservation> for Vec<HumanJoint3D> {
    fn from(value: HumanBodyPose3DObservation) -> Self {
        value
            .recognized_points
            .points
            .into_iter()
            .map(|(name, point)| HumanJoint3D {
                name,
                x: point.x,
                y: point.y,
                z: point.z,
                confidence: point.confidence,
            })
            .collect()
    }
}

/// Detect 3D body-pose keypoints in the image at `path`.
///
/// # Errors
///
/// Returns [`VisionError`] when the image fails to load or the
/// Vision request errors.
pub fn detect_human_body_pose_3d(path: impl AsRef<Path>) -> Result<Vec<HumanJoint3D>, VisionError> {
    let path_str = path.as_ref().to_str().ok_or_else(|| VisionError::InvalidArgument("non-UTF-8 path".into()))?;
    let cpath = CString::new(path_str).map_err(|e| VisionError::InvalidArgument(format!("path NUL byte: {e}")))?;
    let mut joints_ptr: *mut ffi::HumanJoint3DRaw = ptr::null_mut();
    let mut count: isize = 0;
    let mut err: *mut std::ffi::c_char = ptr::null_mut();
    let status = unsafe {
        ffi::vn_detect_human_body_pose_3d_in_path(
            cpath.as_ptr(),
            &mut joints_ptr,
            &mut count,
            &mut err,
        )
    };
    if status != ffi::status::OK {
        let msg = unsafe { take_err(err) };
        return Err(VisionError::RequestFailed(msg));
    }
    let mut out = Vec::with_capacity(count.max(0) as usize);
    for i in 0..count {
        let j = unsafe { joints_ptr.offset(i).read() };
        let name = if j.name.is_null() {
            String::new()
        } else {
            unsafe { CStr::from_ptr(j.name) }.to_string_lossy().into_owned()
        };
        out.push(HumanJoint3D {
            name,
            x: j.x,
            y: j.y,
            z: j.z,
            confidence: j.confidence,
        });
    }
    if !joints_ptr.is_null() {
        unsafe { ffi::vn_human_joints_3d_free(joints_ptr, count) };
    }
    Ok(out)
}

/// Detect dedicated `VNRecognizedPoints3DObservation` /
/// `VNHumanBodyPose3DObservation` wrappers in the image at `path`.
///
/// # Errors
///
/// Returns [`VisionError`] when the image fails to load or the Vision request
/// errors.
pub fn detect_human_body_pose_3d_observations(
    path: impl AsRef<Path>,
) -> Result<Vec<HumanBodyPose3DObservation>, VisionError> {
    detect_human_body_pose_3d(path).map(|joints| {
        if joints.is_empty() {
            Vec::new()
        } else {
            vec![HumanBodyPose3DObservation::from(joints)]
        }
    })
}

unsafe fn take_err(p: *mut std::ffi::c_char) -> String {
    if p.is_null() {
        return String::new();
    }
    let s = unsafe { CStr::from_ptr(p) }.to_string_lossy().into_owned();
    unsafe { libc::free(p.cast()) };
    s
}
