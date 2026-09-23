#![allow(clippy::too_long_first_doc_paragraph)]
//! `VNGeneratePersonInstanceMaskRequest` — per-person instance mask
//! (macOS 14+).

use core::ffi::c_void;
use std::ffi::CString;
use std::path::Path;
use std::ptr;

use crate::error::{from_swift, VisionError};
use crate::ffi;
use crate::mask::take_scaled_mask;

/// A returned 8-bit grayscale mask.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PersonInstanceMask {
    width: usize,
    height: usize,
    bytes: Vec<u8>,
}

impl PersonInstanceMask {
    #[must_use]
    pub const fn width(&self) -> usize {
        self.width
    }

    #[must_use]
    pub const fn height(&self) -> usize {
        self.height
    }

    #[must_use]
    pub const fn bytes_per_row(&self) -> usize {
        self.width
    }

    /// Row-major byte view into the mask buffer.
    #[must_use]
    pub fn as_bytes(&self) -> &[u8] {
        &self.bytes
    }
}

/// Generate a person-instance mask for the image at `path`.
///
/// # Errors
///
/// Returns [`VisionError`] when the image fails to load or the
/// Vision request errors.
pub fn person_instance_mask(
    path: impl AsRef<Path>,
) -> Result<Option<PersonInstanceMask>, VisionError> {
    let path_str = path
        .as_ref()
        .to_str()
        .ok_or_else(|| VisionError::InvalidArgument("non-UTF-8 path".into()))?;
    let cpath = CString::new(path_str)
        .map_err(|e| VisionError::InvalidArgument(format!("path NUL byte: {e}")))?;
    let mut has_value = false;
    let mut width: i32 = 0;
    let mut height: i32 = 0;
    let mut handle: *mut c_void = ptr::null_mut();
    let mut err: *mut std::ffi::c_char = ptr::null_mut();
    // SAFETY: All pointer arguments are either null or valid out-parameters
    // populated by the Swift bridge on return.
    let status = unsafe {
        ffi::vn_person_instance_mask_begin(
            cpath.as_ptr(),
            &raw mut has_value,
            &raw mut width,
            &raw mut height,
            &raw mut handle,
            &raw mut err,
        )
    };
    if status != ffi::status::OK {
        return Err(unsafe { from_swift(status, err) });
    }
    if !has_value || handle.is_null() {
        return Ok(None);
    }
    let mask = take_scaled_mask(handle, width, height)?;
    Ok(Some(PersonInstanceMask {
        width: mask.width,
        height: mask.height,
        bytes: mask.bytes,
    }))
}
