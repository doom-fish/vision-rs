//! Optical flow generation (`VNGenerateOpticalFlowRequest`).
//!
//! Apple's optical flow request runs over **two** frames (A and B)
//! and returns a per-pixel displacement field describing how pixels
//! in A moved to land in B. The field is returned as an [`OpticalFlow`]
//! of `(dx, dy)` vectors, one per pixel.

use core::ffi::c_char;
use core::ptr;
use std::ffi::CString;
use std::path::Path;

use crate::error::{from_swift, VisionError};
use crate::ffi;
use crate::request_base::PixelBufferObservation;

/// `VNGenerateOpticalFlowRequest.ComputationAccuracy`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum OpticalFlowAccuracy {
    Low = 0,
    Medium = 1,
    High = 2,
    VeryHigh = 3,
}

#[derive(Debug, Clone, PartialEq)]
pub struct OpticalFlow {
    width: usize,
    height: usize,
    vectors: Vec<[f32; 2]>,
}

impl OpticalFlow {
    #[must_use]
    pub const fn width(&self) -> usize {
        self.width
    }

    #[must_use]
    pub const fn height(&self) -> usize {
        self.height
    }

    #[must_use]
    pub fn vectors(&self) -> &[[f32; 2]] {
        &self.vectors
    }

    #[must_use]
    pub fn vector_at(&self, x: usize, y: usize) -> Option<[f32; 2]> {
        if x >= self.width {
            return None;
        }
        self.vectors
            .get(y.checked_mul(self.width)?.checked_add(x)?)
            .copied()
    }

    fn from_two_component_f32(
        width: usize,
        height: usize,
        bytes_per_row: usize,
        bytes: &[u8],
    ) -> Result<Self, VisionError> {
        let invalid = || {
            VisionError::RequestFailed(format!(
                "optical flow buffer {width}x{height} with {bytes_per_row} bytes per row \
                 does not hold two f32 values per pixel"
            ))
        };
        let row_len = width.checked_mul(8).ok_or_else(invalid)?;
        if bytes_per_row < row_len
            || bytes.len() != bytes_per_row.checked_mul(height).ok_or_else(invalid)?
        {
            return Err(invalid());
        }
        let mut vectors = Vec::with_capacity(width.saturating_mul(height));
        for row in bytes.chunks_exact(bytes_per_row.max(1)).take(height) {
            for pixel in row[..row_len].chunks_exact(8) {
                let (dx, dy) = pixel.split_at(4);
                vectors.push([
                    f32::from_ne_bytes(dx.try_into().map_err(|_| invalid())?),
                    f32::from_ne_bytes(dy.try_into().map_err(|_| invalid())?),
                ]);
            }
        }
        Ok(Self {
            width,
            height,
            vectors,
        })
    }
}

fn optical_flow_buffer(
    path_a: &Path,
    path_b: &Path,
    accuracy: OpticalFlowAccuracy,
) -> Result<Option<PixelBufferObservation>, VisionError> {
    let a_str = path_a
        .to_str()
        .ok_or_else(|| VisionError::InvalidArgument("non-UTF-8 path A".into()))?;
    let b_str = path_b
        .to_str()
        .ok_or_else(|| VisionError::InvalidArgument("non-UTF-8 path B".into()))?;
    let a_c = CString::new(a_str)
        .map_err(|e| VisionError::InvalidArgument(format!("path A NUL byte: {e}")))?;
    let b_c = CString::new(b_str)
        .map_err(|e| VisionError::InvalidArgument(format!("path B NUL byte: {e}")))?;

    let mut raw = ffi::SegmentationMaskRaw {
        width: 0,
        height: 0,
        bytes_per_row: 0,
        bytes: ptr::null_mut(),
    };
    let mut has_value = false;
    let mut err_msg: *mut c_char = ptr::null_mut();
    // SAFETY: all pointer arguments are valid stack locations or bridge-owned handles; strings are valid C strings for the duration of the call.
    let status = unsafe {
        ffi::vn_generate_optical_flow_in_paths(
            a_c.as_ptr(),
            b_c.as_ptr(),
            accuracy as i32,
            &raw mut raw,
            &raw mut has_value,
            &raw mut err_msg,
        )
    };
    if status != ffi::status::OK {
        // SAFETY: the error pointer is either null or a bridge-allocated C string; `from_swift` frees it.
        return Err(unsafe { from_swift(status, err_msg) });
    }
    if !has_value || raw.bytes.is_null() {
        return Ok(None);
    }
    let len = raw.height.saturating_mul(raw.bytes_per_row);
    // SAFETY: `raw.bytes` is valid for `len` bytes as guaranteed by the Swift bridge.
    let slice = unsafe { core::slice::from_raw_parts(raw.bytes.cast::<u8>(), len) };
    let bytes = slice.to_vec();
    // SAFETY: `raw` was populated by the bridge and has not been freed yet; unique free site.
    unsafe { ffi::vn_segmentation_mask_free(&raw mut raw) };
    Ok(Some(PixelBufferObservation::new(
        raw.width,
        raw.height,
        raw.bytes_per_row,
        bytes,
    )))
}

/// Compute the optical flow between `path_a` (start) and `path_b`
/// (end) as one `(dx, dy)` displacement vector per pixel.
///
/// # Errors
///
/// Returns [`VisionError::ImageLoadFailed`] / [`VisionError::RequestFailed`].
pub fn generate_optical_flow_in_paths(
    path_a: impl AsRef<Path>,
    path_b: impl AsRef<Path>,
    accuracy: OpticalFlowAccuracy,
) -> Result<Option<OpticalFlow>, VisionError> {
    optical_flow_buffer(path_a.as_ref(), path_b.as_ref(), accuracy)?
        .map(|buffer| {
            OpticalFlow::from_two_component_f32(
                buffer.width,
                buffer.height,
                buffer.bytes_per_row,
                &buffer.bytes,
            )
        })
        .transpose()
}

/// Compute the optical flow and wrap the result as a generic
/// `VNPixelBufferObservation`.
///
/// # Errors
///
/// Returns [`VisionError::ImageLoadFailed`] / [`VisionError::RequestFailed`].
pub fn generate_optical_flow_observation_in_paths(
    path_a: impl AsRef<Path>,
    path_b: impl AsRef<Path>,
    accuracy: OpticalFlowAccuracy,
) -> Result<Option<PixelBufferObservation>, VisionError> {
    optical_flow_buffer(path_a.as_ref(), path_b.as_ref(), accuracy)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn pixel_bytes(values: &[[f32; 2]], padding: usize) -> Vec<u8> {
        values
            .iter()
            .flat_map(|[dx, dy]| dx.to_ne_bytes().into_iter().chain(dy.to_ne_bytes()))
            .chain(std::iter::repeat_n(0, padding))
            .collect()
    }

    #[test]
    fn two_component_buffers_decode_row_by_row() {
        let mut bytes = pixel_bytes(&[[1.0, -1.0], [0.5, 2.0]], 8);
        bytes.extend(pixel_bytes(&[[-3.0, 0.25], [0.0, 0.0]], 8));
        let flow = OpticalFlow::from_two_component_f32(2, 2, 24, &bytes).expect("valid buffer");
        assert_eq!((flow.width(), flow.height()), (2, 2));
        assert_eq!(
            flow.vectors(),
            &[[1.0, -1.0], [0.5, 2.0], [-3.0, 0.25], [0.0, 0.0]]
        );
        assert_eq!(flow.vector_at(0, 1), Some([-3.0, 0.25]));
        assert_eq!(flow.vector_at(2, 0), None);
        assert_eq!(flow.vector_at(0, 2), None);
    }

    #[test]
    fn malformed_buffers_are_rejected() {
        let bytes = pixel_bytes(&[[1.0, 1.0]], 0);
        for (width, height, bytes_per_row) in [(2, 1, 8), (1, 2, 8), (1, 1, 4), (usize::MAX, 1, 8)]
        {
            assert!(
                OpticalFlow::from_two_component_f32(width, height, bytes_per_row, &bytes).is_err(),
                "{width}x{height} @ {bytes_per_row}"
            );
        }
    }
}
