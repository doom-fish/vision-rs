#![allow(clippy::cast_possible_wrap, clippy::cast_sign_loss)]
#![allow(clippy::too_long_first_doc_paragraph)]
//! `VNDetectAnimalBodyPoseRequest` — body-pose keypoints for cats,
//! dogs and similar quadrupeds. Available on macOS 14+.

use std::ffi::{CStr, CString};
use std::path::Path;
use std::ptr;

use crate::error::VisionError;
use crate::ffi;

/// One labelled keypoint on a detected animal body.
#[derive(Debug, Clone, PartialEq)]
pub struct AnimalJoint {
    pub name: String,
    pub x: f64,
    pub y: f64,
    pub confidence: f32,
}

/// Detect quadruped body-pose keypoints in the image at `path`.
///
/// # Errors
///
/// Returns [`VisionError`] when the image fails to load or the
/// Vision request errors.
pub fn detect_animal_body_pose(path: impl AsRef<Path>) -> Result<Vec<AnimalJoint>, VisionError> {
    let path_str = path.as_ref().to_str().ok_or_else(|| VisionError::InvalidArgument("non-UTF-8 path".into()))?;
    let cpath = CString::new(path_str).map_err(|e| VisionError::InvalidArgument(format!("path NUL byte: {e}")))?;
    let mut joints_ptr: *mut ffi::AnimalJointRaw = ptr::null_mut();
    let mut count: isize = 0;
    let mut err: *mut std::ffi::c_char = ptr::null_mut();
    let status = unsafe {
        ffi::vn_detect_animal_body_pose_in_path(
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
        out.push(AnimalJoint {
            name,
            x: j.x,
            y: j.y,
            confidence: j.confidence,
        });
    }
    if !joints_ptr.is_null() {
        unsafe { ffi::vn_animal_joints_free(joints_ptr, count) };
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
