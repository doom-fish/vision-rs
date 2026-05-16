#![allow(clippy::cast_possible_wrap, clippy::cast_sign_loss)]
#![allow(clippy::too_long_first_doc_paragraph)]
//! `VNGeneratePersonInstanceMaskRequest` — per-person instance mask
//! (macOS 14+).

use std::ffi::{CStr, CString};
use std::path::Path;
use std::ptr;

use crate::error::VisionError;
use crate::ffi;

/// A returned 8-bit grayscale mask.
pub struct PersonInstanceMask {
    pub width: usize,
    pub height: usize,
    pub bytes_per_row: usize,
    data: *mut u8,
}

impl PersonInstanceMask {
    /// Row-major byte view into the mask buffer.
    #[must_use]
    pub const fn as_bytes(&self) -> &[u8] {
        unsafe { core::slice::from_raw_parts(self.data, self.bytes_per_row * self.height) }
    }
}

impl Drop for PersonInstanceMask {
    fn drop(&mut self) {
        if !self.data.is_null() {
            let size = (self.bytes_per_row * self.height) as isize;
            unsafe { ffi::vn_mask_buffer_free(self.data, size) };
            self.data = ptr::null_mut();
        }
    }
}

unsafe impl Send for PersonInstanceMask {}
unsafe impl Sync for PersonInstanceMask {}

/// Generate a person-instance mask for the image at `path`.
///
/// # Errors
///
/// Returns [`VisionError`] when the image fails to load or the
/// Vision request errors.
pub fn person_instance_mask(
    path: impl AsRef<Path>,
) -> Result<Option<PersonInstanceMask>, VisionError> {
    let path_str = path.as_ref().to_str().ok_or_else(|| VisionError::InvalidArgument("non-UTF-8 path".into()))?;
    let cpath = CString::new(path_str).map_err(|e| VisionError::InvalidArgument(format!("path NUL byte: {e}")))?;
    let mut w: isize = 0;
    let mut h: isize = 0;
    let mut bpr: isize = 0;
    let mut data: *mut u8 = ptr::null_mut();
    let mut err: *mut std::ffi::c_char = ptr::null_mut();
    let status = unsafe {
        ffi::vn_person_instance_mask_in_path(
            cpath.as_ptr(),
            &mut w,
            &mut h,
            &mut bpr,
            &mut data,
            &mut err,
        )
    };
    if status != ffi::status::OK {
        let msg = unsafe { take_err(err) };
        return Err(VisionError::RequestFailed(msg));
    }
    if data.is_null() {
        return Ok(None);
    }
    Ok(Some(PersonInstanceMask {
        width: w.max(0) as usize,
        height: h.max(0) as usize,
        bytes_per_row: bpr.max(0) as usize,
        data,
    }))
}

unsafe fn take_err(p: *mut std::ffi::c_char) -> String {
    if p.is_null() {
        return String::new();
    }
    let s = unsafe { CStr::from_ptr(p) }.to_string_lossy().into_owned();
    unsafe { libc::free(p.cast()) };
    s
}
