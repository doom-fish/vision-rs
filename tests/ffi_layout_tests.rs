//! ABI layout assertions for the `#[repr(C)]` structs shared with the Swift bridge.
//!
//! These structs cross the Rust <-> Swift `@_cdecl` FFI boundary (by value, via
//! out-params, or through packed arrays). If their size or alignment ever drifts
//! from what the Swift side expects, the data marshalling silently corrupts.
//! These tests pin the layout so accidental field reordering / type changes are
//! caught at `cargo test` time rather than as runtime garbage.

use core::mem::{align_of, size_of};

use apple_vision::ffi::{
    verify_ffi_layout, AestheticsScoresRaw, AnimalJointRaw, ClassificationRaw, ContourRaw,
    CoreMLFeatureValueRaw, DetectedBarcodeRaw, DetectedFaceRaw, FaceLandmarksRaw, FaceQualityRaw,
    FeaturePrintRaw, HomographicAlignmentRaw, HumanJoint3DRaw, HumanObservationRaw,
    PoseObservationRaw, RecognizedAnimalRaw, RecognizedTextRaw, RectangleObservationRaw,
    RequestObservationRaw, SaliencyRegionRaw, SegmentationMaskRaw, SimpleRectRaw,
    TextObservationRaw, TrajectoryRaw, TranslationalAlignmentRaw,
};

macro_rules! layout_test {
    ($name:ident, $t:ty, $size:expr, $align:expr) => {
        #[test]
        fn $name() {
            assert_eq!(
                size_of::<$t>(),
                $size,
                concat!(stringify!($t), " size drifted")
            );
            assert_eq!(
                align_of::<$t>(),
                $align,
                concat!(stringify!($t), " alignment drifted")
            );
        }
    };
}

layout_test!(recognized_text_layout, RecognizedTextRaw, 48, 8);
layout_test!(request_observation_layout, RequestObservationRaw, 72, 8);
layout_test!(detected_face_layout, DetectedFaceRaw, 48, 8);
layout_test!(detected_barcode_layout, DetectedBarcodeRaw, 56, 8);
layout_test!(saliency_region_layout, SaliencyRegionRaw, 40, 8);
layout_test!(face_landmarks_layout, FaceLandmarksRaw, 240, 8);
layout_test!(pose_observation_layout, PoseObservationRaw, 80, 8);
layout_test!(contour_layout, ContourRaw, 40, 8);
layout_test!(recognized_animal_layout, RecognizedAnimalRaw, 48, 8);
layout_test!(classification_layout, ClassificationRaw, 16, 8);
layout_test!(
    rectangle_observation_layout,
    RectangleObservationRaw,
    104,
    8
);
layout_test!(feature_print_layout, FeaturePrintRaw, 24, 8);
layout_test!(human_observation_layout, HumanObservationRaw, 40, 8);
layout_test!(aesthetics_scores_layout, AestheticsScoresRaw, 8, 4);
layout_test!(face_quality_layout, FaceQualityRaw, 48, 8);
layout_test!(segmentation_mask_layout, SegmentationMaskRaw, 32, 8);
layout_test!(core_ml_feature_value_layout, CoreMLFeatureValueRaw, 80, 8);
layout_test!(animal_joint_layout, AnimalJointRaw, 32, 8);
layout_test!(human_joint_3d_layout, HumanJoint3DRaw, 48, 8);
layout_test!(simple_rect_layout, SimpleRectRaw, 40, 8);
layout_test!(text_observation_layout, TextObservationRaw, 56, 8);
layout_test!(trajectory_layout, TrajectoryRaw, 64, 8);
layout_test!(
    translational_alignment_layout,
    TranslationalAlignmentRaw,
    16,
    8
);
layout_test!(homographic_alignment_layout, HomographicAlignmentRaw, 40, 4);

/// Aggregate ABI check: `verify_ffi_layout` re-validates the size and alignment
/// of every boundary-crossing struct at runtime. A `false` return means the
/// Rust and Swift layouts genuinely disagree, which is a real ABI bug.
#[test]
fn ffi_layout_self_consistent() {
    assert!(
        verify_ffi_layout(),
        "FFI struct layout drifted from the pinned ABI"
    );
}
