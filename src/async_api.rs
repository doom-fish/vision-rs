//! Async Vision API — Future-based wrappers for `VNImageRequestHandler` and friends.
//!
//! Enable with `features = ["async"]`. Each wrapper dispatches the synchronous
//! Vision request on a background queue (via `DispatchQueue.global`) and returns
//! a `std::future::Future` that resolves when the request completes.
//!
//! ## Tier-2 note
//!
//! Multi-fire delegates, KVO, and continuous observation streams (e.g.
//! `VNVideoProcessor` frame-by-frame callbacks, optical-flow streaming) are
//! **not** included here — they follow a Stream pattern and belong in a
//! future Tier-2 module.
//!
//! ## Example
//!
//! ```rust,no_run
//! # async fn example() -> Result<(), Box<dyn std::error::Error>> {
//! use apple_vision::async_api::AsyncRecognizeText;
//! use apple_vision::recognize_text::RecognitionLevel;
//!
//! let texts = AsyncRecognizeText::new(RecognitionLevel::Accurate, true)
//!     .recognize_in_path("/path/to/image.png")
//!     .await?;
//! for text in &texts {
//!     println!("{}", text.text);
//! }
//! # Ok(())
//! # }
//! ```

use std::{
    ffi::{c_void, CString},
    future::Future,
    path::Path,
    pin::Pin,
    task::{Context, Poll},
};

use doom_fish_utils::completion::{error_from_cstr, AsyncCompletion, AsyncCompletionFuture};

use crate::{error::VisionError, ffi};

#[cfg(feature = "detect_barcodes")]
use crate::detect_barcodes::DetectedBarcode;
#[cfg(feature = "detect_faces")]
use crate::detect_faces::DetectedFace;
#[cfg(feature = "recognize_text")]
use crate::recognize_text::{RecognitionLevel, RecognizedText};
#[cfg(feature = "segmentation")]
use crate::segmentation::{SegmentationMask, SegmentationQuality};

enum FutureState<T> {
    Ready(Option<Result<T, VisionError>>),
    Pending(AsyncCompletionFuture<T>),
}

impl<T> FutureState<T> {
    const fn ready_err(error: VisionError) -> Self {
        Self::Ready(Some(Err(error)))
    }

    const fn pending(future: AsyncCompletionFuture<T>) -> Self {
        Self::Pending(future)
    }
}

impl<T: Unpin> Future for FutureState<T> {
    type Output = Result<T, VisionError>;

    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        match self.as_mut().get_mut() {
            Self::Ready(result) => Poll::Ready(
                result
                    .take()
                    .expect("async Vision future polled after completion"),
            ),
            Self::Pending(future) => Pin::new(future)
                .poll(cx)
                .map(|result| result.map_err(VisionError::RequestFailed)),
        }
    }
}

fn path_to_cstring(path: impl AsRef<Path>) -> Result<CString, VisionError> {
    let path_str = path
        .as_ref()
        .to_str()
        .ok_or_else(|| VisionError::InvalidArgument("non-UTF-8 path".into()))?;
    CString::new(path_str)
        .map_err(|error| VisionError::InvalidArgument(format!("path NUL byte: {error}")))
}

// ============================================================================
// Text Recognition Future
// ============================================================================

#[cfg(feature = "recognize_text")]
extern "C" fn text_result_cb(result: *const c_void, error: *const i8, ctx: *mut c_void) {
    if !error.is_null() {
        let message = unsafe { error_from_cstr(error) };
        unsafe { AsyncCompletion::<Vec<RecognizedText>>::complete_err(ctx, message) };
        return;
    }
    if result.is_null() {
        unsafe {
            AsyncCompletion::<Vec<RecognizedText>>::complete_err(
                ctx,
                "text recognition returned null".into(),
            );
        };
        return;
    }

    let raw = unsafe { &*(result.cast::<ffi::AsyncArrayResultRaw>()) };
    let texts = if raw.array.is_null() || raw.count == 0 {
        Vec::new()
    } else {
        let typed = raw.array.cast::<ffi::RecognizedTextRaw>();
        let mut out = Vec::with_capacity(raw.count);
        for index in 0..raw.count {
            let entry = unsafe { &*typed.add(index) };
            let text = if entry.text.is_null() {
                String::new()
            } else {
                unsafe { std::ffi::CStr::from_ptr(entry.text) }
                    .to_string_lossy()
                    .into_owned()
            };
            out.push(RecognizedText {
                text,
                confidence: entry.confidence,
                bounding_box: crate::recognize_text::BoundingBox {
                    x: entry.bbox_x,
                    y: entry.bbox_y,
                    width: entry.bbox_w,
                    height: entry.bbox_h,
                },
            });
        }
        unsafe { ffi::vn_recognized_text_free(raw.array, raw.count) };
        out
    };

    unsafe { ffi::vn_async_array_result_free(result.cast_mut()) };
    unsafe { AsyncCompletion::complete_ok(ctx, texts) };
}

/// Future resolving to a `Vec<RecognizedText>`.
#[cfg(feature = "recognize_text")]
pub struct RecognizeTextFuture {
    inner: FutureState<Vec<RecognizedText>>,
}

#[cfg(feature = "recognize_text")]
impl std::fmt::Debug for RecognizeTextFuture {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("RecognizeTextFuture")
            .finish_non_exhaustive()
    }
}

#[cfg(feature = "recognize_text")]
impl Future for RecognizeTextFuture {
    type Output = Result<Vec<RecognizedText>, VisionError>;

    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        Pin::new(&mut self.inner).poll(cx)
    }
}

/// Async wrapper for `VNRecognizeTextRequest`.
///
/// Runs text recognition on a background `DispatchQueue` and returns a
/// [`RecognizeTextFuture`] that resolves when the request completes.
#[cfg(feature = "recognize_text")]
#[derive(Debug, Clone)]
pub struct AsyncRecognizeText {
    recognition_level: RecognitionLevel,
    uses_language_correction: bool,
}

#[cfg(feature = "recognize_text")]
impl Default for AsyncRecognizeText {
    fn default() -> Self {
        Self::new(RecognitionLevel::Accurate, true)
    }
}

#[cfg(feature = "recognize_text")]
impl AsyncRecognizeText {
    #[must_use]
    pub const fn new(recognition_level: RecognitionLevel, uses_language_correction: bool) -> Self {
        Self {
            recognition_level,
            uses_language_correction,
        }
    }

    /// Recognize text in the image at `path` asynchronously.
    ///
    /// # Errors
    ///
    /// Returns [`VisionError::RequestFailed`] if Vision fails, or
    /// [`VisionError::InvalidArgument`] if the path cannot be encoded.
    pub fn recognize_in_path(&self, path: impl AsRef<Path>) -> RecognizeTextFuture {
        match path_to_cstring(path) {
            Err(error) => RecognizeTextFuture {
                inner: FutureState::ready_err(error),
            },
            Ok(path_c) => {
                let (future, ctx) = AsyncCompletion::create();
                unsafe {
                    ffi::vn_recognize_text_in_path_async(
                        path_c.as_ptr(),
                        self.recognition_level.as_raw(),
                        self.uses_language_correction,
                        text_result_cb,
                        ctx,
                    );
                };
                RecognizeTextFuture {
                    inner: FutureState::pending(future),
                }
            }
        }
    }
}

// ============================================================================
// Face Detection Future
// ============================================================================

#[cfg(feature = "detect_faces")]
extern "C" fn face_result_cb(result: *const c_void, error: *const i8, ctx: *mut c_void) {
    if !error.is_null() {
        let message = unsafe { error_from_cstr(error) };
        unsafe { AsyncCompletion::<Vec<DetectedFace>>::complete_err(ctx, message) };
        return;
    }
    if result.is_null() {
        unsafe {
            AsyncCompletion::<Vec<DetectedFace>>::complete_err(
                ctx,
                "face detection returned null".into(),
            );
        };
        return;
    }

    let raw = unsafe { &*(result.cast::<ffi::AsyncArrayResultRaw>()) };
    let faces = if raw.array.is_null() || raw.count == 0 {
        Vec::new()
    } else {
        let typed = raw.array.cast::<ffi::DetectedFaceRaw>();
        let mut out = Vec::with_capacity(raw.count);
        let nan_to_none = |value: f32| if value.is_nan() { None } else { Some(value) };
        for index in 0..raw.count {
            let entry = unsafe { &*typed.add(index) };
            out.push(DetectedFace {
                bounding_box: crate::recognize_text::BoundingBox {
                    x: entry.bbox_x,
                    y: entry.bbox_y,
                    width: entry.bbox_w,
                    height: entry.bbox_h,
                },
                confidence: entry.confidence,
                roll: nan_to_none(entry.roll),
                yaw: nan_to_none(entry.yaw),
                pitch: nan_to_none(entry.pitch),
            });
        }
        unsafe { ffi::vn_detected_faces_free(raw.array, raw.count) };
        out
    };

    unsafe { ffi::vn_async_array_result_free(result.cast_mut()) };
    unsafe { AsyncCompletion::complete_ok(ctx, faces) };
}

/// Future resolving to a `Vec<DetectedFace>`.
#[cfg(feature = "detect_faces")]
pub struct DetectFacesFuture {
    inner: FutureState<Vec<DetectedFace>>,
}

#[cfg(feature = "detect_faces")]
impl std::fmt::Debug for DetectFacesFuture {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("DetectFacesFuture").finish_non_exhaustive()
    }
}

#[cfg(feature = "detect_faces")]
impl Future for DetectFacesFuture {
    type Output = Result<Vec<DetectedFace>, VisionError>;

    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        Pin::new(&mut self.inner).poll(cx)
    }
}

/// Async wrapper for `VNDetectFaceRectanglesRequest`.
#[cfg(feature = "detect_faces")]
#[derive(Debug, Clone, Copy, Default)]
pub struct AsyncDetectFaces;

#[cfg(feature = "detect_faces")]
impl AsyncDetectFaces {
    #[must_use]
    pub const fn new() -> Self {
        Self
    }

    /// Detect faces in the image at `path` asynchronously.
    ///
    /// # Errors
    ///
    /// Returns [`VisionError::RequestFailed`] if Vision fails.
    pub fn detect_in_path(&self, path: impl AsRef<Path>) -> DetectFacesFuture {
        match path_to_cstring(path) {
            Err(error) => DetectFacesFuture {
                inner: FutureState::ready_err(error),
            },
            Ok(path_c) => {
                let (future, ctx) = AsyncCompletion::create();
                unsafe {
                    ffi::vn_detect_faces_in_path_async(path_c.as_ptr(), face_result_cb, ctx);
                };
                DetectFacesFuture {
                    inner: FutureState::pending(future),
                }
            }
        }
    }
}

// ============================================================================
// Barcode Detection Future
// ============================================================================

#[cfg(feature = "detect_barcodes")]
extern "C" fn barcode_result_cb(result: *const c_void, error: *const i8, ctx: *mut c_void) {
    if !error.is_null() {
        let message = unsafe { error_from_cstr(error) };
        unsafe { AsyncCompletion::<Vec<DetectedBarcode>>::complete_err(ctx, message) };
        return;
    }
    if result.is_null() {
        unsafe {
            AsyncCompletion::<Vec<DetectedBarcode>>::complete_err(
                ctx,
                "barcode detection returned null".into(),
            );
        };
        return;
    }

    let raw = unsafe { &*(result.cast::<ffi::AsyncArrayResultRaw>()) };
    let barcodes = if raw.array.is_null() || raw.count == 0 {
        Vec::new()
    } else {
        let typed = raw.array.cast::<ffi::DetectedBarcodeRaw>();
        let mut out = Vec::with_capacity(raw.count);
        for index in 0..raw.count {
            let entry = unsafe { &*typed.add(index) };
            let payload = if entry.payload.is_null() {
                String::new()
            } else {
                unsafe { std::ffi::CStr::from_ptr(entry.payload) }
                    .to_string_lossy()
                    .into_owned()
            };
            let symbology = if entry.symbology.is_null() {
                String::new()
            } else {
                unsafe { std::ffi::CStr::from_ptr(entry.symbology) }
                    .to_string_lossy()
                    .into_owned()
            };
            out.push(DetectedBarcode {
                payload,
                symbology,
                confidence: entry.confidence,
                bounding_box: crate::recognize_text::BoundingBox {
                    x: entry.bbox_x,
                    y: entry.bbox_y,
                    width: entry.bbox_w,
                    height: entry.bbox_h,
                },
            });
        }
        unsafe { ffi::vn_detected_barcodes_free(raw.array, raw.count) };
        out
    };

    unsafe { ffi::vn_async_array_result_free(result.cast_mut()) };
    unsafe { AsyncCompletion::complete_ok(ctx, barcodes) };
}

/// Future resolving to a `Vec<DetectedBarcode>`.
#[cfg(feature = "detect_barcodes")]
pub struct DetectBarcodesFuture {
    inner: FutureState<Vec<DetectedBarcode>>,
}

#[cfg(feature = "detect_barcodes")]
impl std::fmt::Debug for DetectBarcodesFuture {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("DetectBarcodesFuture")
            .finish_non_exhaustive()
    }
}

#[cfg(feature = "detect_barcodes")]
impl Future for DetectBarcodesFuture {
    type Output = Result<Vec<DetectedBarcode>, VisionError>;

    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        Pin::new(&mut self.inner).poll(cx)
    }
}

/// Async wrapper for `VNDetectBarcodesRequest`.
#[cfg(feature = "detect_barcodes")]
#[derive(Debug, Clone, Copy, Default)]
pub struct AsyncDetectBarcodes;

#[cfg(feature = "detect_barcodes")]
impl AsyncDetectBarcodes {
    #[must_use]
    pub const fn new() -> Self {
        Self
    }

    /// Detect barcodes in the image at `path` asynchronously.
    ///
    /// # Errors
    ///
    /// Returns [`VisionError::RequestFailed`] if Vision fails.
    pub fn detect_in_path(&self, path: impl AsRef<Path>) -> DetectBarcodesFuture {
        match path_to_cstring(path) {
            Err(error) => DetectBarcodesFuture {
                inner: FutureState::ready_err(error),
            },
            Ok(path_c) => {
                let (future, ctx) = AsyncCompletion::create();
                unsafe {
                    ffi::vn_detect_barcodes_in_path_async(path_c.as_ptr(), barcode_result_cb, ctx);
                };
                DetectBarcodesFuture {
                    inner: FutureState::pending(future),
                }
            }
        }
    }
}

// ============================================================================
// Person Segmentation Future
// ============================================================================

#[cfg(feature = "segmentation")]
extern "C" fn seg_result_cb(result: *const c_void, error: *const i8, ctx: *mut c_void) {
    if !error.is_null() {
        let message = unsafe { error_from_cstr(error) };
        unsafe { AsyncCompletion::<SegmentationMask>::complete_err(ctx, message) };
        return;
    }
    if result.is_null() {
        unsafe {
            AsyncCompletion::<SegmentationMask>::complete_err(
                ctx,
                "segmentation returned null".into(),
            );
        };
        return;
    }

    let raw = unsafe { &*(result.cast::<ffi::AsyncSegResultRaw>()) };
    if raw.bytes.is_null() {
        unsafe { ffi::vn_async_seg_result_free(result.cast_mut()) };
        unsafe {
            AsyncCompletion::<SegmentationMask>::complete_err(
                ctx,
                "segmentation bytes were null".into(),
            );
        };
        return;
    }

    let len = raw.height.saturating_mul(raw.bytes_per_row);
    let bytes = unsafe { core::slice::from_raw_parts(raw.bytes, len) }.to_vec();
    let mask = SegmentationMask {
        width: raw.width,
        height: raw.height,
        bytes_per_row: raw.bytes_per_row,
        bytes,
    };

    unsafe { ffi::vn_async_seg_result_free(result.cast_mut()) };
    unsafe { AsyncCompletion::complete_ok(ctx, mask) };
}

/// Future resolving to a `SegmentationMask`.
#[cfg(feature = "segmentation")]
pub struct PersonSegmentationFuture {
    inner: FutureState<SegmentationMask>,
}

#[cfg(feature = "segmentation")]
impl std::fmt::Debug for PersonSegmentationFuture {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("PersonSegmentationFuture")
            .finish_non_exhaustive()
    }
}

#[cfg(feature = "segmentation")]
impl Future for PersonSegmentationFuture {
    type Output = Result<SegmentationMask, VisionError>;

    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        Pin::new(&mut self.inner).poll(cx)
    }
}

/// Async wrapper for `VNGeneratePersonSegmentationRequest`.
#[cfg(feature = "segmentation")]
#[derive(Debug, Clone, Copy)]
pub struct AsyncPersonSegmentation {
    quality: SegmentationQuality,
}

#[cfg(feature = "segmentation")]
impl Default for AsyncPersonSegmentation {
    fn default() -> Self {
        Self::new(SegmentationQuality::Balanced)
    }
}

#[cfg(feature = "segmentation")]
impl AsyncPersonSegmentation {
    #[must_use]
    pub const fn new(quality: SegmentationQuality) -> Self {
        Self { quality }
    }

    /// Generate a person segmentation mask for the image at `path` asynchronously.
    ///
    /// # Errors
    ///
    /// Returns [`VisionError::RequestFailed`] if Vision fails.
    pub fn generate_in_path(&self, path: impl AsRef<Path>) -> PersonSegmentationFuture {
        match path_to_cstring(path) {
            Err(error) => PersonSegmentationFuture {
                inner: FutureState::ready_err(error),
            },
            Ok(path_c) => {
                let (future, ctx) = AsyncCompletion::create();
                unsafe {
                    ffi::vn_generate_person_segmentation_async(
                        path_c.as_ptr(),
                        self.quality as i32,
                        seg_result_cb,
                        ctx,
                    );
                };
                PersonSegmentationFuture {
                    inner: FutureState::pending(future),
                }
            }
        }
    }
}
