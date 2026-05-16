#![doc = include_str!("../README.md")]
//!
//! ---
//!
//! # API Documentation
//!
//! Safe Rust bindings for Apple's
//! [Vision](https://developer.apple.com/documentation/vision) framework —
//! OCR, object detection, face landmarks, and other on-device computer
//! vision tasks.
//!
//! v0.1 ships text recognition (OCR) only. Object/face detection lands
//! in v0.2.

#![cfg_attr(docsrs, feature(doc_cfg))]

pub mod error;
pub mod ffi;

#[cfg(feature = "recognize_text")]
#[cfg_attr(docsrs, doc(cfg(feature = "recognize_text")))]
pub mod recognize_text;

#[cfg(feature = "detect_faces")]
#[cfg_attr(docsrs, doc(cfg(feature = "detect_faces")))]
pub mod detect_faces;

#[cfg(feature = "detect_barcodes")]
#[cfg_attr(docsrs, doc(cfg(feature = "detect_barcodes")))]
pub mod detect_barcodes;

pub use error::VisionError;

#[cfg(feature = "recognize_text")]
pub use recognize_text::{BoundingBox, RecognitionLevel, RecognizedText, TextRecognizer};

#[cfg(feature = "detect_faces")]
pub use detect_faces::{DetectedFace, FaceDetector};

#[cfg(feature = "detect_barcodes")]
pub use detect_barcodes::{detect_barcodes_in_path, DetectedBarcode};

/// Common imports.
pub mod prelude {
    #[cfg(feature = "detect_barcodes")]
    pub use crate::detect_barcodes::{detect_barcodes_in_path, DetectedBarcode};
    #[cfg(feature = "detect_faces")]
    pub use crate::detect_faces::{DetectedFace, FaceDetector};
    pub use crate::error::VisionError;
    #[cfg(feature = "recognize_text")]
    pub use crate::recognize_text::{
        BoundingBox, RecognitionLevel, RecognizedText, TextRecognizer,
    };
}
