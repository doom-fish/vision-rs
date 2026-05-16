//! `CoreML` inference via Vision (`VNCoreMLRequest`).
//!
//! Loads a Core ML model file, wraps it in `VNCoreMLModel`, runs
//! `VNCoreMLRequest` against an image, and returns the resulting
//! `VNClassificationObservation` list. Compatible with any image
//! classification `.mlmodel` / `.mlpackage`.

use core::ffi::c_char;
use core::ptr;
use std::ffi::CString;
use std::path::Path;

use crate::classify::Classification;
use crate::error::{from_swift, VisionError};
use crate::ffi;

/// Run a Core ML classifier model on the image at `path`.
///
/// # Errors
///
/// Returns [`VisionError::ImageLoadFailed`] / [`VisionError::RequestFailed`].
pub fn coreml_classify_in_path(
    image_path: impl AsRef<Path>,
    model_path: impl AsRef<Path>,
) -> Result<Vec<Classification>, VisionError> {
    let img = image_path
        .as_ref()
        .to_str()
        .ok_or_else(|| VisionError::InvalidArgument("non-UTF-8 image path".into()))?;
    let model = model_path
        .as_ref()
        .to_str()
        .ok_or_else(|| VisionError::InvalidArgument("non-UTF-8 model path".into()))?;
    let img_c = CString::new(img)
        .map_err(|e| VisionError::InvalidArgument(format!("image path NUL byte: {e}")))?;
    let model_c = CString::new(model)
        .map_err(|e| VisionError::InvalidArgument(format!("model path NUL byte: {e}")))?;

    let mut out_array: *mut core::ffi::c_void = ptr::null_mut();
    let mut out_count: usize = 0;
    let mut err_msg: *mut c_char = ptr::null_mut();

    let status = unsafe {
        ffi::vn_coreml_classify_in_path(
            img_c.as_ptr(),
            model_c.as_ptr(),
            &mut out_array,
            &mut out_count,
            &mut err_msg,
        )
    };
    if status != ffi::status::OK {
        return Err(unsafe { from_swift(status, err_msg) });
    }
    if out_array.is_null() || out_count == 0 {
        return Ok(Vec::new());
    }
    let typed = out_array.cast::<ffi::ClassificationRaw>();
    let mut v = Vec::with_capacity(out_count);
    for i in 0..out_count {
        let raw = unsafe { &*typed.add(i) };
        let id = if raw.identifier.is_null() {
            String::new()
        } else {
            unsafe { core::ffi::CStr::from_ptr(raw.identifier) }
                .to_string_lossy()
                .into_owned()
        };
        v.push(Classification {
            identifier: id,
            confidence: raw.confidence,
        });
    }
    unsafe { ffi::vn_classifications_free(out_array, out_count) };
    Ok(v)
}
