#![allow(clippy::cast_possible_wrap, clippy::cast_sign_loss)]
#![allow(clippy::too_long_first_doc_paragraph)]
//! `VNDetectTextRectanglesRequest` — text-region detection (no OCR).

use std::ffi::{CStr, CString};
use std::path::Path;
use std::ptr;

use crate::error::VisionError;
use crate::ffi;

/// A detected text rectangle in normalised (0..1) image coordinates,
/// origin bottom-left (Vision convention).
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct TextRect {
    pub x: f64,
    pub y: f64,
    pub w: f64,
    pub h: f64,
    pub confidence: f32,
}

/// Detect text-region rectangles in the image at `path`. Set
/// `report_character_boxes` to true if you want the per-character
/// bounding boxes (currently unused by this binding, kept for
/// parity with Apple's flag).
///
/// # Errors
///
/// Returns [`VisionError`] when the image fails to load or the
/// Vision request errors.
pub fn detect_text_rectangles(
    path: impl AsRef<Path>,
    report_character_boxes: bool,
) -> Result<Vec<TextRect>, VisionError> {
    let path_str = path.as_ref().to_str().ok_or_else(|| VisionError::InvalidArgument("non-UTF-8 path".into()))?;
    let cpath = CString::new(path_str).map_err(|e| VisionError::InvalidArgument(format!("path NUL byte: {e}")))?;
    let mut rects_ptr: *mut ffi::SimpleRectRaw = ptr::null_mut();
    let mut count: isize = 0;
    let mut err: *mut std::ffi::c_char = ptr::null_mut();
    let status = unsafe {
        ffi::vn_detect_text_rectangles_in_path(
            cpath.as_ptr(),
            report_character_boxes,
            &mut rects_ptr,
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
        let r = unsafe { rects_ptr.offset(i).read() };
        out.push(TextRect {
            x: r.x,
            y: r.y,
            w: r.w,
            h: r.h,
            confidence: r.confidence,
        });
    }
    if !rects_ptr.is_null() {
        unsafe { ffi::vn_simple_rects_free(rects_ptr, count) };
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
