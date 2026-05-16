#![allow(clippy::cast_possible_wrap, clippy::cast_sign_loss)]
#![allow(clippy::too_long_first_doc_paragraph)]
//! `VNDetectHumanBodyPose3DRequest` — 3D human-body keypoints
//! (macOS 14+).

use std::ffi::{CStr, CString};
use std::path::Path;
use std::ptr;

use crate::error::VisionError;
use crate::ffi;

/// One 3D body keypoint (joint).
#[derive(Debug, Clone, PartialEq)]
pub struct HumanJoint3D {
    pub name: String,
    pub x: f32,
    pub y: f32,
    pub z: f32,
    pub confidence: f32,
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

unsafe fn take_err(p: *mut std::ffi::c_char) -> String {
    if p.is_null() {
        return String::new();
    }
    let s = unsafe { CStr::from_ptr(p) }.to_string_lossy().into_owned();
    unsafe { libc::free(p.cast()) };
    s
}
