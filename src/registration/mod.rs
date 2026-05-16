#![allow(clippy::cast_possible_wrap, clippy::cast_sign_loss)]
#![allow(clippy::too_long_first_doc_paragraph)]
//! `VNTranslationalImageRegistrationRequest` +
//! `VNHomographicImageRegistrationRequest` — pixel-space alignment
//! between two images.

use std::ffi::{CStr, CString};
use std::path::Path;
use std::ptr;

use crate::error::VisionError;
use crate::ffi;

/// 2D translation in source-image coordinates needed to align the
/// floating image to the target.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct TranslationalAlignment {
    pub tx: f64,
    pub ty: f64,
}

/// 3×3 row-major homography matrix that warps the floating image
/// into the target's coordinate system.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct HomographicAlignment {
    pub matrix: [[f32; 3]; 3],
}

/// Compute a translational alignment from `floating` to `target`.
///
/// # Errors
///
/// Returns [`VisionError`] when either image fails to load or the
/// Vision request errors.
pub fn register_translational(
    target: impl AsRef<Path>,
    floating: impl AsRef<Path>,
) -> Result<TranslationalAlignment, VisionError> {
    let target_str = target.as_ref().to_str().ok_or_else(|| VisionError::InvalidArgument("non-UTF-8 target path".into()))?;
    let tp = CString::new(target_str).map_err(|e| VisionError::InvalidArgument(format!("target path NUL byte: {e}")))?;
    let floating_str = floating.as_ref().to_str().ok_or_else(|| VisionError::InvalidArgument("non-UTF-8 floating path".into()))?;
    let fp = CString::new(floating_str).map_err(|e| VisionError::InvalidArgument(format!("floating path NUL byte: {e}")))?;
    let mut out = ffi::TranslationalAlignmentRaw { tx: 0.0, ty: 0.0 };
    let mut err: *mut std::ffi::c_char = ptr::null_mut();
    let status = unsafe {
        ffi::vn_register_translational_in_paths(tp.as_ptr(), fp.as_ptr(), &mut out, &mut err)
    };
    if status != ffi::status::OK {
        let msg = unsafe { take_err(err) };
        return Err(VisionError::RequestFailed(msg));
    }
    Ok(TranslationalAlignment {
        tx: out.tx,
        ty: out.ty,
    })
}

/// Compute a homographic (perspective) alignment from `floating` to
/// `target`.
///
/// # Errors
///
/// Returns [`VisionError`] when either image fails to load or the
/// Vision request errors.
pub fn register_homographic(
    target: impl AsRef<Path>,
    floating: impl AsRef<Path>,
) -> Result<HomographicAlignment, VisionError> {
    let target_str = target.as_ref().to_str().ok_or_else(|| VisionError::InvalidArgument("non-UTF-8 target path".into()))?;
    let tp = CString::new(target_str).map_err(|e| VisionError::InvalidArgument(format!("target path NUL byte: {e}")))?;
    let floating_str = floating.as_ref().to_str().ok_or_else(|| VisionError::InvalidArgument("non-UTF-8 floating path".into()))?;
    let fp = CString::new(floating_str).map_err(|e| VisionError::InvalidArgument(format!("floating path NUL byte: {e}")))?;
    let mut out = ffi::HomographicAlignmentRaw {
        m00: 0.0,
        m01: 0.0,
        m02: 0.0,
        m10: 0.0,
        m11: 0.0,
        m12: 0.0,
        m20: 0.0,
        m21: 0.0,
        m22: 0.0,
        _pad: 0.0,
    };
    let mut err: *mut std::ffi::c_char = ptr::null_mut();
    let status = unsafe {
        ffi::vn_register_homographic_in_paths(tp.as_ptr(), fp.as_ptr(), &mut out, &mut err)
    };
    if status != ffi::status::OK {
        let msg = unsafe { take_err(err) };
        return Err(VisionError::RequestFailed(msg));
    }
    Ok(HomographicAlignment {
        matrix: [
            [out.m00, out.m01, out.m02],
            [out.m10, out.m11, out.m12],
            [out.m20, out.m21, out.m22],
        ],
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
