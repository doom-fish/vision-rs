//! Image feature print (`VNGenerateImageFeaturePrintRequest`) —
//! semantic image embedding for content-based similarity.

use core::ffi::c_char;
use core::ptr;
use std::ffi::CString;
use std::path::Path;

use crate::error::{from_swift, VisionError};
use crate::ffi;

/// A semantic image embedding produced by Apple's vision pipeline.
///
/// Distances between two prints (e.g. cosine or L2) measure
/// content similarity — useful for clustering, deduplication, and
/// content-based image search.
#[derive(Debug, Clone, PartialEq)]
#[allow(clippy::derive_partial_eq_without_eq)]
pub struct FeaturePrint {
    /// Underlying element type — `1 = Float32`, `2 = Float64`.
    pub element_type: i32,
    /// Vector dimensionality.
    pub element_count: usize,
    /// Raw element bytes (length = `element_count * 4` or `* 8`).
    pub data: Vec<u8>,
}

impl FeaturePrint {
    /// Decode the vector as `f32` (only valid when
    /// `element_type == 1` and `data` holds `element_count` values).
    #[must_use]
    pub fn as_f32(&self) -> Option<Vec<f32>> {
        if self.element_type != 1 || self.element_count.checked_mul(4) != Some(self.data.len()) {
            return None;
        }
        let mut out = Vec::with_capacity(self.element_count);
        for chunk in self.data.chunks_exact(4) {
            let arr: [u8; 4] = chunk.try_into().ok()?;
            out.push(f32::from_le_bytes(arr));
        }
        Some(out)
    }

    /// Decode the vector as `f64` (only valid when
    /// `element_type == 2` and `data` holds `element_count` values).
    #[must_use]
    pub fn as_f64(&self) -> Option<Vec<f64>> {
        if self.element_type != 2 || self.element_count.checked_mul(8) != Some(self.data.len()) {
            return None;
        }
        let mut out = Vec::with_capacity(self.element_count);
        for chunk in self.data.chunks_exact(8) {
            let arr: [u8; 8] = chunk.try_into().ok()?;
            out.push(f64::from_le_bytes(arr));
        }
        Some(out)
    }

    /// Compute Euclidean (L2) distance to another print. Smaller =
    /// more similar.
    ///
    /// # Errors
    ///
    /// Returns [`VisionError::InvalidArgument`] if the two prints
    /// have different element types or counts, or data that does not match them.
    pub fn l2_distance(&self, other: &Self) -> Result<f64, VisionError> {
        if self.element_type != other.element_type || self.element_count != other.element_count {
            return Err(VisionError::InvalidArgument(
                "feature print element type / count mismatch".into(),
            ));
        }
        let malformed = || {
            VisionError::InvalidArgument(
                "feature print data does not match its element type and count".into(),
            )
        };
        let sumsq: f64 = match self.element_type {
            1 => {
                let lhs = self.as_f32().ok_or_else(malformed)?;
                let rhs = other.as_f32().ok_or_else(malformed)?;
                lhs.iter()
                    .zip(&rhs)
                    .map(|(a, b)| f64::from(a - b).powi(2))
                    .sum()
            }
            2 => {
                let lhs = self.as_f64().ok_or_else(malformed)?;
                let rhs = other.as_f64().ok_or_else(malformed)?;
                lhs.iter().zip(&rhs).map(|(a, b)| (a - b).powi(2)).sum()
            }
            _ => return Err(malformed()),
        };
        Ok(sumsq.sqrt())
    }
}

/// Generate a feature print for the image at `path`.
///
/// # Errors
///
/// Returns [`VisionError::ImageLoadFailed`] / [`VisionError::RequestFailed`].
pub fn generate_image_feature_print_in_path(
    path: impl AsRef<Path>,
) -> Result<Option<FeaturePrint>, VisionError> {
    let path_str = path
        .as_ref()
        .to_str()
        .ok_or_else(|| VisionError::InvalidArgument("non-UTF-8 path".into()))?;
    let path_c = CString::new(path_str)
        .map_err(|e| VisionError::InvalidArgument(format!("path NUL byte: {e}")))?;

    let mut raw = ffi::FeaturePrintRaw {
        element_type: 0,
        element_count: 0,
        bytes: ptr::null_mut(),
    };
    let mut err_msg: *mut c_char = ptr::null_mut();
    // SAFETY: all pointer arguments are valid stack locations or null-initialised out-params; strings are valid C strings for the duration of the call.
    let status = unsafe {
        ffi::vn_generate_image_feature_print_in_path(
            path_c.as_ptr(),
            &raw mut raw,
            &raw mut err_msg,
        )
    };
    if status != ffi::status::OK {
        // SAFETY: the error pointer is either null or a bridge-allocated C string; `from_swift` frees it.
        return Err(unsafe { from_swift(status, err_msg) });
    }
    if raw.bytes.is_null() {
        return Ok(None);
    }
    let len = match raw.element_type {
        1 => raw.element_count.checked_mul(4),
        2 => raw.element_count.checked_mul(8),
        _ => None,
    };
    // SAFETY: `raw.bytes` is valid for `len` bytes as guaranteed by the Swift bridge.
    let data =
        len.map(|len| unsafe { core::slice::from_raw_parts(raw.bytes.cast::<u8>(), len) }.to_vec());
    // SAFETY: `raw` was populated by the bridge and has not been freed yet; unique free site.
    unsafe { ffi::vn_feature_print_free(&raw mut raw) };
    let Some(data) = data else {
        return Err(VisionError::RequestFailed(format!(
            "feature print has unsupported element type {}",
            raw.element_type
        )));
    };
    if data.is_empty() {
        return Ok(None);
    }

    Ok(Some(FeaturePrint {
        element_type: raw.element_type,
        element_count: raw.element_count,
        data,
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn float_print(values: &[f32]) -> FeaturePrint {
        FeaturePrint {
            element_type: 1,
            element_count: values.len(),
            data: values
                .iter()
                .flat_map(|value| value.to_le_bytes())
                .collect(),
        }
    }

    fn double_print(values: &[f64]) -> FeaturePrint {
        FeaturePrint {
            element_type: 2,
            element_count: values.len(),
            data: values
                .iter()
                .flat_map(|value| value.to_le_bytes())
                .collect(),
        }
    }

    #[test]
    fn distances_cover_every_element() {
        let origin = float_print(&[0.0, 3.0]);
        let target = float_print(&[4.0, 0.0]);
        assert_eq!(origin.as_f32(), Some(vec![0.0, 3.0]));
        assert!((origin.l2_distance(&target).unwrap() - 5.0).abs() < 1e-9);
        let near = double_print(&[2.0]);
        let far = double_print(&[0.5]);
        assert_eq!(near.as_f64(), Some(vec![2.0]));
        assert!((near.l2_distance(&far).unwrap() - 1.5).abs() < 1e-12);
    }

    #[test]
    fn prints_whose_data_does_not_match_their_shape_are_rejected() {
        let whole = float_print(&[1.0, 2.0]);
        let mut truncated = whole.clone();
        truncated.data.truncate(4);
        assert_eq!(truncated.as_f32(), None);
        assert!(matches!(
            truncated.l2_distance(&whole),
            Err(VisionError::InvalidArgument(_))
        ));
        assert!(matches!(
            whole.l2_distance(&truncated),
            Err(VisionError::InvalidArgument(_))
        ));

        let unknown = FeaturePrint {
            element_type: 0,
            ..whole.clone()
        };
        assert!(matches!(
            unknown.l2_distance(&unknown),
            Err(VisionError::InvalidArgument(_))
        ));

        let overflowing = FeaturePrint {
            element_count: usize::MAX,
            ..whole.clone()
        };
        assert_eq!(overflowing.as_f32(), None);
        assert_eq!(double_print(&[1.0]).as_f32(), None);
        assert_eq!(whole.as_f64(), None);
    }
}
