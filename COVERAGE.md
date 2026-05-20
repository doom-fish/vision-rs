# Vision SDK coverage audit

Audited against `MacOSX26.5.sdk` (Xcode 26.5) plus the crate's `src/` + `swift-bridge/` sources.

Phase 32 also refreshes the Tier-1 async notes for `VNCoreMLRequest`, `VNDetectHumanBodyPose3DRequest`, and `VNDetectTrajectoriesRequest`.

Legend:

- ✅ implemented — the crate exposes a safe Rust entry point for the request / observation type.
- 🟡 partial — the type is covered through a narrowed or shared wrapper, but some SDK-specific surface is intentionally not modelled directly.
- ⏭️ skipped — legacy / renamed / absent from the current macOS SDK.

## Requests

| Symbol | Status | Notes |
| --- | --- | --- |
| VNAnimalDetectionRequest | ⏭️ skipped | Not present in the current macOS SDK; animal support is exposed through `VNRecognizeAnimalsRequest`. |
| VNCalculateImageAestheticsScoresRequest | ✅ implemented | Exposed as `calculate_aesthetics_scores_in_path`; this is the current SDK spelling for image-aesthetics scoring. |
| VNClassifyImageRequest | ✅ implemented | Exposed as `classify_image_in_path`. |
| VNCoreMLRequest | ✅ implemented | Exposed as `CoreMLRequest`, `coreml_classify_in_path`, `coreml_feature_value_in_path`, and the async `AsyncCoreMLRequest::{classify_in_path, feature_value_in_path}` wrappers. |
| VNDetectAnimalBodyPoseRequest | ✅ implemented | Exposed as `detect_animal_body_pose` (macOS 14+). |
| VNDetectBarcodesRequest | ✅ implemented | Exposed as `detect_barcodes_in_path`. |
| VNDetectContoursRequest | ✅ implemented | Exposed as `detect_contours_in_path`. |
| VNDetectDocumentSegmentationRequest | ✅ implemented | Exposed as `detect_document_segmentation_in_path`. |
| VNDetectFaceCaptureQualityRequest | ✅ implemented | Exposed as `detect_face_capture_quality_in_path`. |
| VNDetectFaceLandmarksRequest | ✅ implemented | Exposed as `detect_face_landmarks_in_path`. |
| VNDetectFaceRectanglesRequest | ✅ implemented | Exposed via `FaceDetector`. |
| VNDetectHorizonRequest | ✅ implemented | Exposed as `detect_horizon_in_path`. |
| VNDetectHumanBodyPose3DRequest | ✅ implemented | Exposed as `detect_human_body_pose_3d` plus `AsyncDetectHumanBodyPose3D::detect_in_path` (macOS 14+). |
| VNDetectHumanBodyPoseRequest | ✅ implemented | Exposed as `detect_human_body_pose_in_path`. |
| VNDetectHumanHandPoseRequest | ✅ implemented | Exposed as `detect_human_hand_pose_in_path`. |
| VNDetectHumanRectanglesRequest | ✅ implemented | Exposed as `detect_human_rectangles_in_path`. |
| VNDetectImageAestheticsScoresRequest | ⏭️ skipped | Current macOS SDK uses `VNCalculateImageAestheticsScoresRequest` instead. |
| VNDetectRectanglesRequest | ✅ implemented | Exposed as `detect_rectangles_in_path`. |
| VNDetectTextRectanglesRequest | ✅ implemented | Exposed as `TextRectanglesRequest`, `detect_text_rectangles`, and `detect_text_observations`, including `character_boxes`. |
| VNDetectTrajectoriesRequest | ✅ implemented | Exposed as `detect_trajectories` plus `AsyncDetectTrajectories::detect_in_path`. |
| VNGenerateAttentionBasedSaliencyImageRequest | ✅ implemented | Exposed as `attention_saliency_in_path`. |
| VNGenerateForegroundInstanceMaskRequest | ✅ implemented | Exposed as `generate_foreground_instance_mask_in_path`. |
| VNGenerateImageFeaturePrintRequest | ✅ implemented | Exposed as `generate_image_feature_print_in_path`. |
| VNGenerateObjectnessBasedSaliencyImageRequest | ✅ implemented | Exposed as `objectness_saliency`. |
| VNGenerateOpticalFlowRequest | ✅ implemented | Exposed as `generate_optical_flow_in_paths`. |
| VNGeneratePersonInstanceMaskRequest | ✅ implemented | Exposed as `person_instance_mask` (macOS 14+). |
| VNGeneratePersonSegmentationRequest | ✅ implemented | Exposed as `generate_person_segmentation_in_path`. |
| VNHomographicImageRegistrationRequest | ✅ implemented | Exposed as `register_homographic`. |
| VNImageBasedRequest | ✅ implemented | Exposed as the standalone `ImageBasedRequest` base wrapper reused across request builders. |
| VNImageRegistrationRequest | ✅ implemented | Exposed as `ImageRegistrationRequest`, alongside translational + homographic registration helpers. |
| VNRecognizeAnimalsRequest | ✅ implemented | Exposed as `recognize_animals_in_path`. |
| VNRecognizeTextRequest | ✅ implemented | Exposed via `TextRecognizer`. |
| VNStatefulRequest | ✅ implemented | Exposed as the standalone `StatefulRequest` base wrapper. |
| VNTargetedImageRequest | ✅ implemented | Exposed as the standalone `TargetedImageRequest` base wrapper. |
| VNTrackHomographicImageRegistrationRequest | ✅ implemented | Exposed via `HomographicImageTracker`. |
| VNTrackObjectRequest | ✅ implemented | Exposed via `ObjectTracker`. |
| VNTrackOpticalFlowRequest | ✅ implemented | Exposed via `OpticalFlowTracker`. |
| VNTrackingRequest | ✅ implemented | Exposed as the standalone `TrackingRequest` base wrapper plus `TrackingLevel`. |
| VNTrackRectangleRequest | ✅ implemented | Exposed via `RectangleTracker`. |
| VNTrackTranslationalImageRegistrationRequest | ✅ implemented | Exposed via `TranslationalImageTracker`. |
| VNTranslationalImageRegistrationRequest | ✅ implemented | Exposed as `register_translational`. |
| VNTrajectoryRequest | ⏭️ skipped | No standalone `VNTrajectoryRequest` exists in the current macOS SDK; trajectory support is exposed via `VNDetectTrajectoriesRequest`. |

## Observations

| Symbol | Status | Notes |
| --- | --- | --- |
| VNAnimalBodyPoseObservation | ✅ implemented | Exposed through the `AnimalJoint` result set returned by `detect_animal_body_pose`. |
| VNBarcodeObservation | ✅ implemented | Exposed through `DetectedBarcode` (payload, symbology, confidence, bounding box). |
| VNClassificationObservation | ✅ implemented | Exposed through `Classification`. |
| VNContoursObservation | ✅ implemented | Exposed as `ContoursObservation`, including top-level contour trees plus contour counts. |
| VNCoreMLFeatureValueObservation | ✅ implemented | Exposed as `CoreMLFeatureValueObservation` via `CoreMLRequest::feature_value` / `coreml_feature_value_in_path`. |
| VNDetectedObjectObservation | ✅ implemented | Object tracking surfaces updated bounding boxes + confidences across frames. |
| VNFaceObservation | ✅ implemented | Face detection, landmarks, and capture-quality helpers all flow through face observations. |
| VNFeaturePrintObservation | ✅ implemented | Exposed through `FeaturePrint`, including element metadata + distance computation. |
| VNHorizonObservation | ✅ implemented | Exposed as `HorizonObservation`, including angle + affine transform helpers. |
| VNHumanBodyPose3DObservation | ✅ implemented | Exposed as `HumanBodyPose3DObservation` and `detect_human_body_pose_3d_observations`. |
| VNHumanBodyPoseObservation | ✅ implemented | Exposed as `HumanBodyPoseObservation` and `detect_human_body_pose_observations_in_path`. |
| VNHumanHandPoseObservation | ✅ implemented | Exposed as `HumanHandPoseObservation` and `detect_human_hand_pose_observations_in_path`. |
| VNHumanObservation | ✅ implemented | Exposed through `DetectedHuman`. |
| VNImageAestheticsScoresObservation | ✅ implemented | Exposed through `AestheticsScores`. |
| VNImageAlignmentObservation | ✅ implemented | Exposed as the dedicated `ImageAlignmentObservation` base wrapper. |
| VNImageHomographicAlignmentObservation | ✅ implemented | Exposed through `HomographicAlignment`. |
| VNImageTranslationAlignmentObservation | ✅ implemented | Exposed through `TranslationalAlignment`. |
| VNInstanceMaskObservation | ✅ implemented | Exposed as `InstanceMaskObservation`, including `PixelBufferObservation` bytes + instance counts. |
| VNObservation | ✅ implemented | Exposed as the generic `Observation` wrapper carrying `uuid`, confidence, and optional `time_range`. |
| VNPixelBufferObservation | ✅ implemented | Exposed as the generic `PixelBufferObservation` wrapper used by optical-flow and mask observations. |
| VNRecognizedObjectObservation | ✅ implemented | Animal recognition surfaces the recognized label set + bounding box through `RecognizedAnimal`. |
| VNRecognizedPoints3DObservation | ✅ implemented | Exposed as `RecognizedPoints3DObservation` and `HumanBodyPose3DObservation`. |
| VNRecognizedPointsObservation | ✅ implemented | Exposed as `RecognizedPointsObservation` and the dedicated body/hand pose observation wrappers. |
| VNRecognizedTextObservation | ✅ implemented | Exposed through `RecognizedText`. |
| VNRectangleObservation | ✅ implemented | Exposed through `RectangleObservation`. |
| VNSaliencyImageObservation | ✅ implemented | Exposed through `SalientRegion` / `ObjectnessRegion` result sets. |
| VNTextObservation | ✅ implemented | Exposed as `TextObservation`, including top-level boxes plus optional `character_boxes`. |
| VNTrajectoryObservation | ✅ implemented | Exposed through `Trajectory` (detected/projected points, equation coefficients, confidence). |
