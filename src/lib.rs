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
//! v0.15 keeps the full Apple Vision request surface and adds an
//! audited request/observation coverage matrix plus a split Swift bridge.

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

#[cfg(feature = "classify")]
#[cfg_attr(docsrs, doc(cfg(feature = "classify")))]
pub mod classify;

#[cfg(feature = "rectangles")]
#[cfg_attr(docsrs, doc(cfg(feature = "rectangles")))]
pub mod rectangles;

#[cfg(feature = "horizon")]
#[cfg_attr(docsrs, doc(cfg(feature = "horizon")))]
pub mod horizon;

#[cfg(feature = "feature_print")]
#[cfg_attr(docsrs, doc(cfg(feature = "feature_print")))]
pub mod feature_print;

#[cfg(feature = "humans")]
#[cfg_attr(docsrs, doc(cfg(feature = "humans")))]
pub mod humans;

#[cfg(feature = "aesthetics")]
#[cfg_attr(docsrs, doc(cfg(feature = "aesthetics")))]
pub mod aesthetics;

#[cfg(feature = "segmentation")]
#[cfg_attr(docsrs, doc(cfg(feature = "segmentation")))]
pub mod segmentation;

#[cfg(feature = "optical_flow")]
#[cfg_attr(docsrs, doc(cfg(feature = "optical_flow")))]
pub mod optical_flow;

#[cfg(feature = "coreml")]
#[cfg_attr(docsrs, doc(cfg(feature = "coreml")))]
pub mod coreml;

#[cfg(feature = "tracking")]
#[cfg_attr(docsrs, doc(cfg(feature = "tracking")))]
pub mod tracking;

// v0.13: new request types
pub mod animal_body_pose;
pub mod human_body_pose_3d;
pub mod text_rectangles;
pub mod objectness_saliency;
pub mod person_instance_mask;
pub mod trajectories;
pub mod registration;

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

#[cfg(feature = "classify")]
pub use classify::{classify_image_in_path, Classification};

#[cfg(feature = "rectangles")]
pub use rectangles::{
    detect_document_segmentation_in_path, detect_rectangles_in_path, RectangleObservation,
    RectangleOptions,
};

#[cfg(feature = "horizon")]
pub use horizon::detect_horizon_in_path;

#[cfg(feature = "feature_print")]
pub use feature_print::{generate_image_feature_print_in_path, FeaturePrint};

#[cfg(feature = "humans")]
pub use humans::{detect_human_rectangles_in_path, DetectedHuman};

#[cfg(feature = "aesthetics")]
pub use aesthetics::{
    calculate_aesthetics_scores_in_path, detect_face_capture_quality_in_path,
    AestheticsScores, FaceCaptureQuality,
};

#[cfg(feature = "segmentation")]
pub use segmentation::{
    generate_foreground_instance_mask_in_path, generate_person_segmentation_in_path,
    InstanceMask, SegmentationMask, SegmentationQuality,
};

#[cfg(feature = "optical_flow")]
pub use optical_flow::{generate_optical_flow_in_paths, OpticalFlowAccuracy};

#[cfg(feature = "coreml")]
pub use coreml::coreml_classify_in_path;

pub use animal_body_pose::{detect_animal_body_pose, AnimalJoint};
pub use human_body_pose_3d::{detect_human_body_pose_3d, HumanJoint3D};
pub use text_rectangles::{detect_text_rectangles, TextRect};
pub use objectness_saliency::{objectness_saliency, ObjectnessRegion};
pub use person_instance_mask::{person_instance_mask, PersonInstanceMask};
pub use trajectories::{detect_trajectories, Trajectory};
pub use registration::{
    register_homographic, register_translational, HomographicAlignment, TranslationalAlignment,
};

#[cfg(feature = "tracking")]
pub use tracking::{
    HomographicImageTracker, ObjectTracker, OpticalFlowFrame, OpticalFlowTracker,
    RectangleTracker, TranslationalImageTracker,
};

/// Common imports.
pub mod prelude {
    #[cfg(feature = "animals")]
    pub use crate::animals::{recognize_animals_in_path, RecognizedAnimal};
    #[cfg(feature = "body_pose")]
    pub use crate::body_pose::{detect_human_body_pose_in_path, DetectedBodyPose, JointPoint};
    #[cfg(feature = "classify")]
    pub use crate::classify::{classify_image_in_path, Classification};
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
    #[cfg(feature = "feature_print")]
    pub use crate::feature_print::{generate_image_feature_print_in_path, FeaturePrint};
    #[cfg(feature = "hand_pose")]
    pub use crate::hand_pose::{detect_human_hand_pose_in_path, DetectedHandPose};
    #[cfg(feature = "horizon")]
    pub use crate::horizon::detect_horizon_in_path;
    #[cfg(feature = "humans")]
    pub use crate::humans::{detect_human_rectangles_in_path, DetectedHuman};
    #[cfg(feature = "rectangles")]
    pub use crate::rectangles::{
        detect_document_segmentation_in_path, detect_rectangles_in_path, RectangleObservation,
        RectangleOptions,
    };
    #[cfg(feature = "recognize_text")]
    pub use crate::recognize_text::{
        BoundingBox, RecognitionLevel, RecognizedText, TextRecognizer,
    };
    #[cfg(feature = "saliency")]
    pub use crate::saliency::{attention_saliency_in_path, SalientRegion};
    #[cfg(feature = "tracking")]
    pub use crate::tracking::{
        HomographicImageTracker, ObjectTracker, OpticalFlowFrame, OpticalFlowTracker,
        RectangleTracker, TranslationalImageTracker,
    };
}
