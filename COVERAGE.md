# Vision SDK coverage audit

Audited against the current macOS Vision.framework headers from the active Xcode SDK and the crate's `src/` + `swift-bridge/` sources.

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
| VNCoreMLRequest | 🟡 partial | Exposed as `coreml_classify_in_path`; the current safe API handles classification outputs only. |
| VNDetectAnimalBodyPoseRequest | ✅ implemented | Exposed as `detect_animal_body_pose` (macOS 14+). |
| VNDetectBarcodesRequest | ✅ implemented | Exposed as `detect_barcodes_in_path`. |
| VNDetectContoursRequest | ✅ implemented | Exposed as `detect_contours_in_path`. |
| VNDetectDocumentSegmentationRequest | ✅ implemented | Exposed as `detect_document_segmentation_in_path`. |
| VNDetectFaceCaptureQualityRequest | ✅ implemented | Exposed as `detect_face_capture_quality_in_path`. |
| VNDetectFaceLandmarksRequest | ✅ implemented | Exposed as `detect_face_landmarks_in_path`. |
| VNDetectFaceRectanglesRequest | ✅ implemented | Exposed via `FaceDetector`. |
| VNDetectHorizonRequest | ✅ implemented | Exposed as `detect_horizon_in_path`. |
| VNDetectHumanBodyPose3DRequest | ✅ implemented | Exposed as `detect_human_body_pose_3d` (macOS 14+). |
| VNDetectHumanBodyPoseRequest | ✅ implemented | Exposed as `detect_human_body_pose_in_path`. |
| VNDetectHumanHandPoseRequest | ✅ implemented | Exposed as `detect_human_hand_pose_in_path`. |
| VNDetectHumanRectanglesRequest | ✅ implemented | Exposed as `detect_human_rectangles_in_path`. |
| VNDetectImageAestheticsScoresRequest | ⏭️ skipped | Current macOS SDK uses `VNCalculateImageAestheticsScoresRequest` instead. |
| VNDetectRectanglesRequest | ✅ implemented | Exposed as `detect_rectangles_in_path`. |
| VNDetectTextRectanglesRequest | 🟡 partial | Exposed as `detect_text_rectangles`; region boxes are surfaced today, while `characterBoxes` stays deferred. |
| VNDetectTrajectoriesRequest | ✅ implemented | Exposed as `detect_trajectories`. |
| VNGenerateAttentionBasedSaliencyImageRequest | ✅ implemented | Exposed as `attention_saliency_in_path`. |
| VNGenerateForegroundInstanceMaskRequest | ✅ implemented | Exposed as `generate_foreground_instance_mask_in_path`. |
| VNGenerateImageFeaturePrintRequest | ✅ implemented | Exposed as `generate_image_feature_print_in_path`. |
| VNGenerateObjectnessBasedSaliencyImageRequest | ✅ implemented | Exposed as `objectness_saliency`. |
| VNGenerateOpticalFlowRequest | ✅ implemented | Exposed as `generate_optical_flow_in_paths`. |
| VNGeneratePersonInstanceMaskRequest | ✅ implemented | Exposed as `person_instance_mask` (macOS 14+). |
| VNGeneratePersonSegmentationRequest | ✅ implemented | Exposed as `generate_person_segmentation_in_path`. |
| VNHomographicImageRegistrationRequest | ✅ implemented | Exposed as `register_homographic`. |
| VNImageBasedRequest | 🟡 partial | Shared image-request plumbing is reused throughout the bridge, but there is no standalone public base-class wrapper. |
| VNImageRegistrationRequest | 🟡 partial | Concrete translational + homographic registration wrappers are exposed; the abstract base class is not. |
| VNRecognizeAnimalsRequest | ✅ implemented | Exposed as `recognize_animals_in_path`. |
| VNRecognizeTextRequest | ✅ implemented | Exposed via `TextRecognizer`. |
| VNStatefulRequest | 🟡 partial | Concrete stateful requests and tracking sessions are exposed, but there is no standalone base-class handle. |
| VNTargetedImageRequest | 🟡 partial | Concrete targeted-image requests are covered; the abstract base class is not exposed directly. |
| VNTrackHomographicImageRegistrationRequest | ✅ implemented | Exposed via `HomographicImageTracker`. |
| VNTrackObjectRequest | ✅ implemented | Exposed via `ObjectTracker`. |
| VNTrackOpticalFlowRequest | ✅ implemented | Exposed via `OpticalFlowTracker`. |
| VNTrackingRequest | 🟡 partial | Concrete tracker types are covered; the abstract base class is not exposed directly. |
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
| VNContoursObservation | 🟡 partial | Exposed through `Contour` trees; indexed convenience lookups (`contourAtIndex*`) are not modelled directly. |
| VNCoreMLFeatureValueObservation | 🟡 partial | The current `VNCoreMLRequest` safe API returns classification observations only. |
| VNDetectedObjectObservation | ✅ implemented | Object tracking surfaces updated bounding boxes + confidences across frames. |
| VNFaceObservation | ✅ implemented | Face detection, landmarks, and capture-quality helpers all flow through face observations. |
| VNFeaturePrintObservation | ✅ implemented | Exposed through `FeaturePrint`, including element metadata + distance computation. |
| VNHorizonObservation | 🟡 partial | Exposed through `detect_horizon_in_path`; the horizon angle is surfaced directly, while transform helpers are deferred. |
| VNHumanBodyPose3DObservation | ✅ implemented | Exposed through `HumanJoint3D` results from `detect_human_body_pose_3d`. |
| VNHumanBodyPoseObservation | 🟡 partial | Exposed through `DetectedBodyPose`; joint dictionaries are surfaced, while the full observation type is flattened. |
| VNHumanHandPoseObservation | 🟡 partial | Exposed through `DetectedHandPose`; joint dictionaries are surfaced, while observation-specific extras (for example chirality) are deferred. |
| VNHumanObservation | ✅ implemented | Exposed through `DetectedHuman`. |
| VNImageAestheticsScoresObservation | ✅ implemented | Exposed through `AestheticsScores`. |
| VNImageAlignmentObservation | 🟡 partial | Concrete translation + homography alignment observations are exposed; the abstract base observation is not. |
| VNImageHomographicAlignmentObservation | ✅ implemented | Exposed through `HomographicAlignment`. |
| VNImageTranslationAlignmentObservation | ✅ implemented | Exposed through `TranslationalAlignment`. |
| VNInstanceMaskObservation | 🟡 partial | Mask bytes + instance counts are surfaced, while mask-generation convenience helpers are deferred. |
| VNObservation | 🟡 partial | Observation payloads are surfaced per-request, but there is no generic base observation wrapper carrying shared metadata like `uuid` / `timeRange`. |
| VNPixelBufferObservation | 🟡 partial | Pixel-buffer-backed results are surfaced as owned byte wrappers (`SegmentationMask`, `InstanceMask`, `OpticalFlowFrame`) rather than a generic `VNPixelBufferObservation` type. |
| VNRecognizedObjectObservation | ✅ implemented | Animal recognition surfaces the recognized label set + bounding box through `RecognizedAnimal`. |
| VNRecognizedPoints3DObservation | 🟡 partial | 3D recognized points are surfaced as flattened `HumanJoint3D` values. |
| VNRecognizedPointsObservation | 🟡 partial | 2D recognized points are surfaced as flattened joint maps for body / hand / animal pose APIs. |
| VNRecognizedTextObservation | ✅ implemented | Exposed through `RecognizedText`. |
| VNRectangleObservation | ✅ implemented | Exposed through `RectangleObservation`. |
| VNSaliencyImageObservation | ✅ implemented | Exposed through `SalientRegion` / `ObjectnessRegion` result sets. |
| VNTextObservation | 🟡 partial | Exposed through `TextRect`; the top-level text boxes are surfaced while `characterBoxes` stays deferred. |
| VNTrajectoryObservation | ✅ implemented | Exposed through `Trajectory` (detected/projected points, equation coefficients, confidence). |
