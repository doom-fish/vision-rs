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

#[cfg(feature = "saliency")]
#[cfg_attr(docsrs, doc(cfg(feature = "saliency")))]
pub mod saliency;

#[cfg(feature = "face_landmarks")]
#[cfg_attr(docsrs, doc(cfg(feature = "face_landmarks")))]
pub mod face_landmarks;

#[cfg(feature = "body_pose")]
#[cfg_attr(docsrs, doc(cfg(feature = "body_pose")))]
pub mod body_pose;

#[cfg(feature = "hand_pose")]
#[cfg_attr(docsrs, doc(cfg(feature = "hand_pose")))]
pub mod hand_pose;

#[cfg(feature = "contours")]
#[cfg_attr(docsrs, doc(cfg(feature = "contours")))]
pub mod contours;

#[cfg(feature = "animals")]
#[cfg_attr(docsrs, doc(cfg(feature = "animals")))]
pub mod animals;

pub use error::VisionError;

#[cfg(feature = "recognize_text")]
pub use recognize_text::{BoundingBox, RecognitionLevel, RecognizedText, TextRecognizer};

#[cfg(feature = "detect_faces")]
pub use detect_faces::{DetectedFace, FaceDetector};

#[cfg(feature = "detect_barcodes")]
pub use detect_barcodes::{detect_barcodes_in_path, DetectedBarcode};

#[cfg(feature = "saliency")]
pub use saliency::{attention_saliency_in_path, SalientRegion};

#[cfg(feature = "face_landmarks")]
pub use face_landmarks::{detect_face_landmarks_in_path, FaceWithLandmarks, LandmarkPoint};

#[cfg(feature = "body_pose")]
pub use body_pose::{detect_human_body_pose_in_path, DetectedBodyPose, JointPoint};

#[cfg(feature = "hand_pose")]
pub use hand_pose::{detect_human_hand_pose_in_path, DetectedHandPose};

#[cfg(feature = "contours")]
pub use contours::{detect_contours_in_path, Contour, ContourOptions};

#[cfg(feature = "animals")]
pub use animals::{recognize_animals_in_path, RecognizedAnimal};

/// Common imports.
pub mod prelude {
    #[cfg(feature = "animals")]
    pub use crate::animals::{recognize_animals_in_path, RecognizedAnimal};
    #[cfg(feature = "body_pose")]
    pub use crate::body_pose::{detect_human_body_pose_in_path, DetectedBodyPose, JointPoint};
    #[cfg(feature = "contours")]
    pub use crate::contours::{detect_contours_in_path, Contour, ContourOptions};
    #[cfg(feature = "detect_barcodes")]
    pub use crate::detect_barcodes::{detect_barcodes_in_path, DetectedBarcode};
    #[cfg(feature = "detect_faces")]
    pub use crate::detect_faces::{DetectedFace, FaceDetector};
    pub use crate::error::VisionError;
    #[cfg(feature = "face_landmarks")]
    pub use crate::face_landmarks::{
        detect_face_landmarks_in_path, FaceWithLandmarks, LandmarkPoint,
    };
    #[cfg(feature = "hand_pose")]
    pub use crate::hand_pose::{detect_human_hand_pose_in_path, DetectedHandPose};
    #[cfg(feature = "recognize_text")]
    pub use crate::recognize_text::{
        BoundingBox, RecognitionLevel, RecognizedText, TextRecognizer,
    };
    #[cfg(feature = "saliency")]
    pub use crate::saliency::{attention_saliency_in_path, SalientRegion};
}
