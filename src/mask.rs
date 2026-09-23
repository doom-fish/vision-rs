use core::ffi::c_void;
use core::ptr;

use crate::error::VisionError;
use crate::ffi;

pub struct ScaledMask {
    pub width: usize,
    pub height: usize,
    pub bytes: Vec<u8>,
}

pub fn take_scaled_mask(
    handle: *mut c_void,
    width: i32,
    height: i32,
) -> Result<ScaledMask, VisionError> {
    let dimensions = usize::try_from(width)
        .ok()
        .zip(usize::try_from(height).ok())
        .and_then(|(width, height)| Some((width, height, width.checked_mul(height)?)));
    let Some((width, height, len)) = dimensions else {
        unsafe { ffi::vn_scaled_foreground_mask_finish(handle, ptr::null_mut(), 0) };
        return Err(VisionError::RequestFailed(format!(
            "mask has invalid dimensions {width}x{height}"
        )));
    };
    let mut bytes = vec![0u8; len];
    let status = unsafe { ffi::vn_scaled_foreground_mask_finish(handle, bytes.as_mut_ptr(), len) };
    if status != ffi::status::OK {
        return Err(VisionError::RequestFailed(
            "could not convert the mask to 8-bit alpha".into(),
        ));
    }
    Ok(ScaledMask {
        width,
        height,
        bytes,
    })
}
