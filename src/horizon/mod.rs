//! Horizon detection (`VNDetectHorizonRequest`).

use core::ffi::c_char;
use core::ptr;
use std::ffi::CString;
use std::path::Path;

use crate::error::{from_swift, VisionError};
use crate::ffi;

/// Detect the horizon angle (in radians) in the image at `path`.
/// Returns `None` if Apple can't find a strong horizon.
///
/// Positive values rotate the image clockwise to level the horizon.
///
/// # Errors
///
/// Returns [`VisionError::ImageLoadFailed`] / [`VisionError::RequestFailed`].
pub fn detect_horizon_in_path(path: impl AsRef<Path>) -> Result<Option<f64>, VisionError> {
    let path_str = path
        .as_ref()
        .to_str()
        .ok_or_else(|| VisionError::InvalidArgument("non-UTF-8 path".into()))?;
    let path_c = CString::new(path_str)
        .map_err(|e| VisionError::InvalidArgument(format!("path NUL byte: {e}")))?;

    let mut angle: f64 = 0.0;
    let mut has_value: bool = false;
    let mut err_msg: *mut c_char = ptr::null_mut();

    let status = unsafe {
        ffi::vn_detect_horizon_in_path(path_c.as_ptr(), &mut angle, &mut has_value, &mut err_msg)
    };
    if status != ffi::status::OK {
        return Err(unsafe { from_swift(status, err_msg) });
    }
    Ok(if has_value { Some(angle) } else { None })
}
