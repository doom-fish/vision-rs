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
    ffi::c_void,
    future::Future,
    path::{Path, PathBuf},
    pin::Pin,
    task::{Context, Poll},
};

use doom_fish_utils::completion::{AsyncCompletion, AsyncCompletionFuture};
use doom_fish_utils::panic_safe::catch_user_panic_result;

use crate::{error::VisionError, ffi};

#[cfg(feature = "coreml")]
use crate::classify::Classification;
#[cfg(feature = "coreml")]
use crate::coreml::{CoreMLFeatureValueObservation, CoreMLRequest};
#[cfg(feature = "detect_barcodes")]
use crate::detect_barcodes::DetectedBarcode;
#[cfg(feature = "detect_faces")]
use crate::detect_faces::{DetectedFace, FaceDetector};
use crate::human_body_pose_3d::HumanBodyPose3DObservation;
#[cfg(feature = "recognize_text")]
use crate::recognize_text::{RecognitionLevel, RecognizedText, TextRecognizer};
#[cfg(feature = "segmentation")]
use crate::segmentation::{SegmentationMask, SegmentationQuality};
use crate::trajectories::Trajectory;

const QOS_CLASS_USER_INITIATED: isize = 0x19;

extern "C" {
    fn dispatch_get_global_queue(identifier: isize, flags: usize) -> *mut c_void;
    fn dispatch_async_f(
        queue: *mut c_void,
        context: *mut c_void,
        work: unsafe extern "C" fn(*mut c_void),
    );
}

struct WorkerFuture<T> {
    inner: AsyncCompletionFuture<Result<T, VisionError>>,
}

impl<T> std::fmt::Debug for WorkerFuture<T> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("WorkerFuture").finish_non_exhaustive()
    }
}

impl<T> Future for WorkerFuture<T> {
    type Output = Result<T, VisionError>;

    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        Pin::new(&mut self.inner).poll(cx).map(|result| {
            result.unwrap_or_else(|message| {
                Err(VisionError::Unknown {
                    code: ffi::status::UNKNOWN,
                    message,
                })
            })
        })
    }
}

struct Job<F> {
    work: F,
    completion: *mut c_void,
}

unsafe extern "C" fn run_job<T, F>(context: *mut c_void)
where
    T: Send + 'static,
    F: FnOnce() -> Result<T, VisionError> + Send + 'static,
{
    let job = unsafe { Box::from_raw(context.cast::<Job<F>>()) };
    let Job { work, completion } = *job;
    let result = catch_user_panic_result("async Vision request", work).unwrap_or_else(|| {
        Err(VisionError::Unknown {
            code: ffi::status::UNKNOWN,
            message: "the Vision request panicked".into(),
        })
    });
    unsafe { AsyncCompletion::<Result<T, VisionError>>::complete_ok(completion, result) };
}

fn run_on_dispatch_queue<T, F>(work: F) -> WorkerFuture<T>
where
    T: Send + 'static,
    F: FnOnce() -> Result<T, VisionError> + Send + 'static,
{
    let (inner, completion) = AsyncCompletion::<Result<T, VisionError>>::create();
    let job = Box::into_raw(Box::new(Job { work, completion })).cast::<c_void>();
    unsafe {
        dispatch_async_f(
            dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0),
            job,
            run_job::<T, F>,
        );
    }
    WorkerFuture { inner }
}

#[cfg(feature = "coreml")]
pub struct CoreMLClassifyFuture {
    inner: WorkerFuture<Vec<Classification>>,
}

#[cfg(feature = "coreml")]
impl std::fmt::Debug for CoreMLClassifyFuture {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("CoreMLClassifyFuture")
            .finish_non_exhaustive()
    }
}

#[cfg(feature = "coreml")]
impl Future for CoreMLClassifyFuture {
    type Output = Result<Vec<Classification>, VisionError>;

    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        Pin::new(&mut self.inner).poll(cx)
    }
}

#[cfg(feature = "coreml")]
pub struct CoreMLFeatureValueFuture {
    inner: WorkerFuture<Option<CoreMLFeatureValueObservation>>,
}

#[cfg(feature = "coreml")]
impl std::fmt::Debug for CoreMLFeatureValueFuture {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("CoreMLFeatureValueFuture")
            .finish_non_exhaustive()
    }
}

#[cfg(feature = "coreml")]
impl Future for CoreMLFeatureValueFuture {
    type Output = Result<Option<CoreMLFeatureValueObservation>, VisionError>;

    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        Pin::new(&mut self.inner).poll(cx)
    }
}

#[cfg(feature = "coreml")]
#[derive(Debug, Clone)]
pub struct AsyncCoreMLRequest {
    request: CoreMLRequest,
}

#[cfg(feature = "coreml")]
impl AsyncCoreMLRequest {
    #[must_use]
    pub const fn new(request: CoreMLRequest) -> Self {
        Self { request }
    }

    #[must_use]
    pub fn classify_in_path(&self, path: impl AsRef<Path>) -> CoreMLClassifyFuture {
        let request = self.request.clone();
        let path = path.as_ref().to_path_buf();
        CoreMLClassifyFuture {
            inner: run_on_dispatch_queue(move || request.classify(path.as_path())),
        }
    }

    #[must_use]
    pub fn feature_value_in_path(&self, path: impl AsRef<Path>) -> CoreMLFeatureValueFuture {
        let request = self.request.clone();
        let path = path.as_ref().to_path_buf();
        CoreMLFeatureValueFuture {
            inner: run_on_dispatch_queue(move || request.feature_value(path.as_path())),
        }
    }
}

pub struct DetectHumanBodyPose3DFuture {
    inner: WorkerFuture<Vec<HumanBodyPose3DObservation>>,
}

impl std::fmt::Debug for DetectHumanBodyPose3DFuture {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("DetectHumanBodyPose3DFuture")
            .finish_non_exhaustive()
    }
}

impl Future for DetectHumanBodyPose3DFuture {
    type Output = Result<Vec<HumanBodyPose3DObservation>, VisionError>;

    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        Pin::new(&mut self.inner).poll(cx)
    }
}

#[derive(Debug, Clone, Copy, Default)]
pub struct AsyncDetectHumanBodyPose3D;

impl AsyncDetectHumanBodyPose3D {
    #[must_use]
    pub const fn new() -> Self {
        Self
    }

    #[must_use]
    pub fn detect_in_path(&self, path: impl AsRef<Path>) -> DetectHumanBodyPose3DFuture {
        let path = path.as_ref().to_path_buf();
        DetectHumanBodyPose3DFuture {
            inner: run_on_dispatch_queue(move || {
                crate::human_body_pose_3d::detect_human_body_pose_3d_observations(path.as_path())
            }),
        }
    }
}

pub struct DetectTrajectoriesFuture {
    inner: WorkerFuture<Vec<Trajectory>>,
}

impl std::fmt::Debug for DetectTrajectoriesFuture {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("DetectTrajectoriesFuture")
            .finish_non_exhaustive()
    }
}

impl Future for DetectTrajectoriesFuture {
    type Output = Result<Vec<Trajectory>, VisionError>;

    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        Pin::new(&mut self.inner).poll(cx)
    }
}

#[derive(Debug, Clone)]
pub struct AsyncDetectTrajectories {
    trajectory_length: usize,
}

impl AsyncDetectTrajectories {
    #[must_use]
    pub const fn new(trajectory_length: usize) -> Self {
        Self { trajectory_length }
    }

    #[must_use]
    pub fn detect_in_path(&self, path: impl AsRef<Path>) -> DetectTrajectoriesFuture {
        let path: PathBuf = path.as_ref().to_path_buf();
        let trajectory_length = self.trajectory_length;
        DetectTrajectoriesFuture {
            inner: run_on_dispatch_queue(move || {
                crate::trajectories::detect_trajectories(path.as_path(), trajectory_length)
            }),
        }
    }
}

// ============================================================================
// Text Recognition Future
// ============================================================================

/// Future resolving to a `Vec<RecognizedText>`.
#[cfg(feature = "recognize_text")]
pub struct RecognizeTextFuture {
    inner: WorkerFuture<Vec<RecognizedText>>,
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
    /// Resolves to the same errors as [`TextRecognizer::recognize_in_path`].
    pub fn recognize_in_path(&self, path: impl AsRef<Path>) -> RecognizeTextFuture {
        let recognizer = TextRecognizer::new()
            .with_recognition_level(self.recognition_level)
            .with_language_correction(self.uses_language_correction);
        let path = path.as_ref().to_path_buf();
        RecognizeTextFuture {
            inner: run_on_dispatch_queue(move || recognizer.recognize_in_path(path)),
        }
    }
}

// ============================================================================
// Face Detection Future
// ============================================================================

#[cfg(feature = "detect_faces")]
pub struct DetectFacesFuture {
    inner: WorkerFuture<Vec<DetectedFace>>,
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

#[cfg(feature = "detect_faces")]
#[derive(Debug, Clone, Copy, Default)]
pub struct AsyncDetectFaces;

#[cfg(feature = "detect_faces")]
impl AsyncDetectFaces {
    #[must_use]
    pub const fn new() -> Self {
        Self
    }

    pub fn detect_in_path(&self, path: impl AsRef<Path>) -> DetectFacesFuture {
        let path = path.as_ref().to_path_buf();
        DetectFacesFuture {
            inner: run_on_dispatch_queue(move || FaceDetector::new().detect_in_path(path)),
        }
    }
}

// ============================================================================
// Barcode Detection Future
// ============================================================================

#[cfg(feature = "detect_barcodes")]
pub struct DetectBarcodesFuture {
    inner: WorkerFuture<Vec<DetectedBarcode>>,
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

#[cfg(feature = "detect_barcodes")]
#[derive(Debug, Clone, Copy, Default)]
pub struct AsyncDetectBarcodes;

#[cfg(feature = "detect_barcodes")]
impl AsyncDetectBarcodes {
    #[must_use]
    pub const fn new() -> Self {
        Self
    }

    pub fn detect_in_path(&self, path: impl AsRef<Path>) -> DetectBarcodesFuture {
        let path = path.as_ref().to_path_buf();
        DetectBarcodesFuture {
            inner: run_on_dispatch_queue(move || {
                crate::detect_barcodes::detect_barcodes_in_path(path)
            }),
        }
    }
}

// ============================================================================
// Person Segmentation Future
// ============================================================================

/// Future resolving to an `Option<SegmentationMask>`.
#[cfg(feature = "segmentation")]
pub struct PersonSegmentationFuture {
    inner: WorkerFuture<Option<SegmentationMask>>,
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
    type Output = Result<Option<SegmentationMask>, VisionError>;

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
    /// Resolves to the same result and errors as
    /// [`generate_person_segmentation_in_path`](crate::segmentation::generate_person_segmentation_in_path).
    pub fn generate_in_path(&self, path: impl AsRef<Path>) -> PersonSegmentationFuture {
        let path = path.as_ref().to_path_buf();
        let quality = self.quality;
        PersonSegmentationFuture {
            inner: run_on_dispatch_queue(move || {
                crate::segmentation::generate_person_segmentation_in_path(path, quality)
            }),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_panicking_request_resolves_with_an_error() {
        let future: WorkerFuture<()> = run_on_dispatch_queue(|| panic!("request exploded"));
        assert!(matches!(
            pollster::block_on(future),
            Err(VisionError::Unknown {
                code: ffi::status::UNKNOWN,
                ..
            })
        ));
    }

    #[test]
    fn requests_run_off_the_calling_thread() {
        let caller = std::thread::current().id();
        let worker = pollster::block_on(run_on_dispatch_queue(move || {
            Ok(std::thread::current().id())
        }))
        .expect("worker result");
        assert_ne!(worker, caller);
    }

    #[test]
    fn many_requests_share_the_dispatch_pool() {
        let mut futures = Vec::new();
        for value in 0..64_usize {
            futures.push(run_on_dispatch_queue(move || Ok(value * 2)));
        }
        for (value, future) in futures.into_iter().enumerate() {
            assert_eq!(
                pollster::block_on(future).expect("worker result"),
                value * 2
            );
        }
    }
}
