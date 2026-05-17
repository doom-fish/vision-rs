# apple-vision coverage audit (vs MacOSX26.2.sdk)

SDK_PUBLIC_SYMBOLS: 249
VERIFIED: 222
GAPS: 0
EXEMPT: 27
COVERAGE_PCT: 89.16%

Methodology note: per the audit instructions, this inventory covers Vision interfaces, protocols, enum/struct typedefs, exported constants, and top-level C functions. Alias-only typedefs are not counted separately. A symbol is **VERIFIED** only when `apple-vision` exposes a dedicated public Rust surface for it; symbols used only inside the Swift bridge or flattened into crate-specific data structures remain in **GAPS**.

## 🟢 VERIFIED
| Symbol | Kind | Header | Wrapped by |
| --- | --- | --- | --- |
| VNAnimalBodyPoseObservation | interface | VNObservation.h:790 | Exposed through the `AnimalJoint` result set returned by `detect_animal_body_pose`. |
| VNBarcodeObservation | interface | VNObservation.h:411 | Exposed through `DetectedBarcode` (payload, symbology, confidence, bounding box). |
| VNCalculateImageAestheticsScoresRequest | interface | VNCalculateImageAestheticsScoresRequest.h:19 | Exposed as `calculate_aesthetics_scores_in_path`; this is the current SDK spelling for image-aesthetics scoring. |
| VNChirality | enum | VNTypes.h:96 | Wrapped by `hand_pose::HandChirality` and mapped from Vision chirality values. |
| VNClassificationObservation | interface | VNObservation.h:148 | Exposed through `Classification`. |
| VNClassifyImageRequest | interface | VNClassifyImageRequest.h:23 | Exposed as `classify_image_in_path`. |
| VNContoursObservation | interface | VNObservation.h:612 | Exposed as `ContoursObservation`, including top-level contour trees plus contour counts. |
| VNCoreMLFeatureValueObservation | interface | VNObservation.h:218 | Exposed as `CoreMLFeatureValueObservation` via `CoreMLRequest::feature_value` / `coreml_feature_value_in_path`. |
| VNCoreMLModel | interface | VNCoreMLRequest.h:22 | Exposed as the dedicated `CoreMLModel` wrapper used by `CoreMLRequest`. |
| VNCoreMLRequest | interface | VNCoreMLRequest.h:55 | Exposed as `CoreMLRequest`, `coreml_classify_in_path`, and `coreml_feature_value_in_path`. |
| VNDetectAnimalBodyPoseRequest | interface | VNDetectAnimalBodyPoseRequest.h:19 | Exposed as `detect_animal_body_pose` (macOS 14+). |
| VNDetectBarcodesRequest | interface | VNDetectBarcodesRequest.h:21 | Exposed as `detect_barcodes_in_path`. |
| VNDetectContoursRequest | interface | VNDetectContoursRequest.h:21 | Exposed as `detect_contours_in_path`. |
| VNDetectDocumentSegmentationRequest | interface | VNDetectDocumentSegmentationRequest.h:18 | Exposed as `detect_document_segmentation_in_path`. |
| VNDetectFaceCaptureQualityRequest | interface | VNDetectFaceCaptureQualityRequest.h:25 | Exposed as `detect_face_capture_quality_in_path`. |
| VNDetectFaceLandmarksRequest | interface | VNDetectFaceLandmarksRequest.h:33 | Exposed as `detect_face_landmarks_in_path`. |
| VNDetectFaceRectanglesRequest | interface | VNDetectFaceRectanglesRequest.h:21 | Exposed via `FaceDetector`. |
| VNDetectHorizonRequest | interface | VNDetectHorizonRequest.h:21 | Exposed as `detect_horizon_in_path`. |
| VNDetectHumanBodyPose3DRequest | interface | VNDetectHumanBodyPose3DRequest.h:24 | Exposed as `detect_human_body_pose_3d` (macOS 14+). |
| VNDetectHumanBodyPoseRequest | interface | VNDetectHumanBodyPoseRequest.h:147 | Exposed as `detect_human_body_pose_in_path`. |
| VNDetectHumanHandPoseRequest | interface | VNDetectHumanHandPoseRequest.h:149 | Exposed as `detect_human_hand_pose_in_path`. |
| VNDetectHumanRectanglesRequest | interface | VNDetectHumanRectanglesRequest.h:24 | Exposed as `detect_human_rectangles_in_path`. |
| VNDetectRectanglesRequest | interface | VNDetectRectanglesRequest.h:21 | Exposed as `detect_rectangles_in_path`. |
| VNDetectTextRectanglesRequest | interface | VNDetectTextRectanglesRequest.h:21 | Exposed as `TextRectanglesRequest`, `detect_text_rectangles`, and `detect_text_observations`. |
| VNDetectTrajectoriesRequest | interface | VNDetectTrajectoriesRequest.h:21 | Exposed as `detect_trajectories`. |
| VNDetectedObjectObservation | interface | VNObservation.h:71 | Object tracking surfaces updated bounding boxes + confidences across frames. |
| VNFaceObservation | interface | VNObservation.h:101 | Face detection, landmarks, and capture-quality helpers all flow through face observations. |
| VNFeaturePrintObservation | interface | VNObservation.h:559 | Exposed through `FeaturePrint`, including element metadata + distance computation. |
| VNGenerateAttentionBasedSaliencyImageRequest | interface | VNGenerateAttentionBasedSaliencyImageRequest.h:20 | Exposed as `attention_saliency_in_path`. |
| VNGenerateForegroundInstanceMaskRequest | interface | VNGenerateForegroundInstanceMaskRequest.h:20 | Exposed as `generate_foreground_instance_mask_in_path`. |
| VNGenerateImageFeaturePrintRequest | interface | VNGenerateImageFeaturePrintRequest.h:21 | Exposed as `generate_image_feature_print_in_path`. |
| VNGenerateObjectnessBasedSaliencyImageRequest | interface | VNGenerateObjectnessBasedSaliencyImageRequest.h:19 | Exposed as `objectness_saliency`. |
| VNGenerateOpticalFlowRequest | interface | VNGenerateOpticalFlowRequest.h:54 | Exposed as `generate_optical_flow_in_paths`. |
| VNGenerateOpticalFlowRequestComputationAccuracy | enum | VNGenerateOpticalFlowRequest.h:19 | Wrapped by `optical_flow::OpticalFlowAccuracy` and mapped onto `VNGenerateOpticalFlowRequest.ComputationAccuracy` in the Swift bridge. |
| VNGeneratePersonInstanceMaskRequest | interface | VNGeneratePersonInstanceMaskRequest.h:20 | Exposed as `person_instance_mask` (macOS 14+). |
| VNGeneratePersonSegmentationRequest | interface | VNGeneratePersonSegmentationRequest.h:34 | Exposed as `generate_person_segmentation_in_path`. |
| VNGeneratePersonSegmentationRequestQualityLevel | enum | VNGeneratePersonSegmentationRequest.h:23 | Wrapped by `segmentation::SegmentationQuality` and mapped onto `VNGeneratePersonSegmentationRequest.QualityLevel` in the Swift bridge. |
| VNHomographicImageRegistrationRequest | interface | VNImageRegistrationRequest.h:52 | Exposed as `register_homographic`. |
| VNHorizonObservation | interface | VNObservation.h:481 | Exposed as `HorizonObservation`, including angle + affine transform helpers. |
| VNHumanBodyPose3DObservation | interface | VNObservation.h:888 | Exposed as `HumanBodyPose3DObservation` and `detect_human_body_pose_3d_observations`. |
| VNHumanBodyPoseObservation | interface | VNDetectHumanBodyPoseRequest.h:103 | Exposed as `HumanBodyPoseObservation` and `detect_human_body_pose_observations_in_path`. |
| VNHumanHandPoseObservation | interface | VNDetectHumanHandPoseRequest.h:101 | Exposed as `HumanHandPoseObservation` and `detect_human_hand_pose_observations_in_path`. |
| VNHumanObservation | interface | VNObservation.h:729 | Exposed through `DetectedHuman`. |
| VNImageAestheticsScoresObservation | interface | VNObservation.h:974 | Exposed through `AestheticsScores`. |
| VNImageAlignmentObservation | interface | VNObservation.h:509 | Exposed as the dedicated `ImageAlignmentObservation` base wrapper. |
| VNImageBasedRequest | interface | VNRequest.h:157 | Exposed as the standalone `ImageBasedRequest` base wrapper reused across request builders. |
| VNImageHomographicAlignmentObservation | interface | VNObservation.h:532 | Exposed through `HomographicAlignment`. |
| VNImageRegistrationRequest | interface | VNImageRegistrationRequest.h:21 | Exposed as `ImageRegistrationRequest`, alongside translational + homographic registration helpers. |
| VNImageRequestHandler | interface | VNRequestHandler.h:65 | Exposed as `ImageRequestHandler`, which runs `Request::recognize_text()` against a still image. |
| VNImageTranslationAlignmentObservation | interface | VNObservation.h:519 | Exposed through `TranslationalAlignment`. |
| VNInstanceMaskObservation | interface | VNObservation.h:746 | Exposed as `InstanceMaskObservation`, including `PixelBufferObservation` bytes + instance counts. |
| VNObservation | interface | VNObservation.h:42 | Exposed as `Observation`, carrying Vision's shared `uuid`, confidence, and optional `time_range` metadata. |
| VNPixelBufferObservation | interface | VNObservation.h:242 | Exposed as the generic `PixelBufferObservation` wrapper used by optical-flow and mask observations. |
| VNRecognizeAnimalsRequest | interface | VNRecognizeAnimalsRequest.h:27 | Exposed as `recognize_animals_in_path`. |
| VNRecognizeTextRequest | interface | VNRecognizeTextRequest.h:31 | Exposed via `TextRecognizer`. |
| VNRecognizedObjectObservation | interface | VNObservation.h:204 | Animal recognition surfaces the recognized label set + bounding box through `RecognizedAnimal`. |
| VNRecognizedPoints3DObservation | interface | VNObservation.h:838 | Exposed as `RecognizedPoints3DObservation` and `HumanBodyPose3DObservation`. |
| VNRecognizedPointsObservation | interface | VNObservation.h:669 | Exposed as `RecognizedPointsObservation` and the dedicated body/hand pose observation wrappers. |
| VNRecognizedTextObservation | interface | VNObservation.h:392 | Exposed through `RecognizedText`. |
| VNRectangleObservation | interface | VNObservation.h:267 | Exposed through `RectangleObservation`. |
| VNRequest | interface | VNRequest.h:40 | Exposed as `Request` / `RequestKind`, including revision + background/CPU settings for the explicit OCR pipeline. |
| VNRequestTextRecognitionLevel | enum | VNRecognizeTextRequest.h:17 | Wrapped by `recognize_text::RecognitionLevel` and mapped onto `VNRecognizeTextRequest.recognitionLevel` in the Swift bridge. |
| VNRequestTrackingLevel | enum | VNTrackingRequest.h:20 | Wrapped by `request_base::TrackingLevel` and mapped onto `VNTrackingRequest.trackingLevel`. |
| VNSaliencyImageObservation | interface | VNObservation.h:546 | Exposed through `SalientRegion` / `ObjectnessRegion` result sets. |
| VNSequenceRequestHandler | interface | VNRequestHandler.h:253 | Exposed as `SequenceRequestHandler`, which retains Vision sequence state across repeated `perform` calls. |
| VNStatefulRequest | interface | VNStatefulRequest.h:20 | Exposed as the standalone `StatefulRequest` base wrapper. |
| VNTargetedImageRequest | interface | VNTargetedImageRequest.h:24 | Exposed as the standalone `TargetedImageRequest` base wrapper. |
| VNTextObservation | interface | VNObservation.h:350 | Exposed as `TextObservation`, including top-level boxes plus optional `character_boxes`. |
| VNTrackHomographicImageRegistrationRequest | interface | VNTrackHomographicImageRegistrationRequest.h:19 | Exposed via `HomographicImageTracker`. |
| VNTrackObjectRequest | interface | VNTrackObjectRequest.h:22 | Exposed via `ObjectTracker`. |
| VNTrackOpticalFlowRequest | interface | VNTrackOpticalFlowRequest.h:63 | Exposed via `OpticalFlowTracker`. |
| VNTrackRectangleRequest | interface | VNTrackRectangleRequest.h:23 | Exposed via `RectangleTracker`. |
| VNTrackTranslationalImageRegistrationRequest | interface | VNTrackTranslationalImageRegistrationRequest.h:19 | Exposed via `TranslationalImageTracker`. |
| VNTrackingRequest | interface | VNTrackingRequest.h:32 | Exposed as the standalone `TrackingRequest` base wrapper plus `TrackingLevel`. |
| VNTrajectoryObservation | interface | VNObservation.h:314 | Exposed through `Trajectory` (detected/projected points, equation coefficients, confidence). |
| VNTranslationalImageRegistrationRequest | interface | VNImageRegistrationRequest.h:31 | Exposed as `register_translational`. |
| VNVideoProcessor | interface | VNVideoProcessor.h:75 | Exposed as `VideoProcessor`, including `VideoProcessingOptions` / `VideoCadence` for OCR over video files. |
| VNAnimalBodyPoseObservationJointNameLeftEarTop | const | VNTypes.h:133 | Wrapped by `animal_body_pose::AnimalBodyPoseJointName` and surfaced from `AnimalJoint::joint_name()` |
| VNAnimalBodyPoseObservationJointsGroupNameHead | const | VNTypes.h:162 | Wrapped by `animal_body_pose::AnimalBodyPoseJointGroupName` |
| VNAnimalIdentifierCat | const | VNRecognizeAnimalsRequest.h:18 | Wrapped by `sdk::AnimalIdentifier` and `animals::RecognizedAnimal::identifier_kind()` |
| VNAnimalIdentifierDog | const | VNRecognizeAnimalsRequest.h:17 | Wrapped by `sdk::AnimalIdentifier` and `animals::RecognizedAnimal::identifier_kind()` |
| VNBarcodeCompositeType | enum | VNTypes.h:115 | Wrapped by `sdk::BarcodeCompositeType` and re-exported alongside barcode detection helpers. |
| VNBarcodeSymbologyAztec | const | VNTypes.h:52 | Wrapped by `sdk::BarcodeSymbology` and `detect_barcodes::DetectedBarcode::symbology_kind()` |
| VNBarcodeSymbologyCodabar | const | VNTypes.h:70 | Wrapped by `sdk::BarcodeSymbology` and `detect_barcodes::DetectedBarcode::symbology_kind()` |
| VNBarcodeSymbologyCode128 | const | VNTypes.h:59 | Wrapped by `sdk::BarcodeSymbology` and `detect_barcodes::DetectedBarcode::symbology_kind()` |
| VNBarcodeSymbologyCode39 | const | VNTypes.h:53 | Wrapped by `sdk::BarcodeSymbology` and `detect_barcodes::DetectedBarcode::symbology_kind()` |
| VNBarcodeSymbologyCode39Checksum | const | VNTypes.h:54 | Wrapped by `sdk::BarcodeSymbology` and `detect_barcodes::DetectedBarcode::symbology_kind()` |
| VNBarcodeSymbologyCode39FullASCII | const | VNTypes.h:55 | Wrapped by `sdk::BarcodeSymbology` and `detect_barcodes::DetectedBarcode::symbology_kind()` |
| VNBarcodeSymbologyCode39FullASCIIChecksum | const | VNTypes.h:56 | Wrapped by `sdk::BarcodeSymbology` and `detect_barcodes::DetectedBarcode::symbology_kind()` |
| VNBarcodeSymbologyCode93 | const | VNTypes.h:57 | Wrapped by `sdk::BarcodeSymbology` and `detect_barcodes::DetectedBarcode::symbology_kind()` |
| VNBarcodeSymbologyCode93i | const | VNTypes.h:58 | Wrapped by `sdk::BarcodeSymbology` and `detect_barcodes::DetectedBarcode::symbology_kind()` |
| VNBarcodeSymbologyDataMatrix | const | VNTypes.h:60 | Wrapped by `sdk::BarcodeSymbology` and `detect_barcodes::DetectedBarcode::symbology_kind()` |
| VNBarcodeSymbologyEAN13 | const | VNTypes.h:62 | Wrapped by `sdk::BarcodeSymbology` and `detect_barcodes::DetectedBarcode::symbology_kind()` |
| VNBarcodeSymbologyEAN8 | const | VNTypes.h:61 | Wrapped by `sdk::BarcodeSymbology` and `detect_barcodes::DetectedBarcode::symbology_kind()` |
| VNBarcodeSymbologyGS1DataBar | const | VNTypes.h:71 | Wrapped by `sdk::BarcodeSymbology` and `detect_barcodes::DetectedBarcode::symbology_kind()` |
| VNBarcodeSymbologyGS1DataBarExpanded | const | VNTypes.h:72 | Wrapped by `sdk::BarcodeSymbology` and `detect_barcodes::DetectedBarcode::symbology_kind()` |
| VNBarcodeSymbologyGS1DataBarLimited | const | VNTypes.h:73 | Wrapped by `sdk::BarcodeSymbology` and `detect_barcodes::DetectedBarcode::symbology_kind()` |
| VNBarcodeSymbologyI2of5 | const | VNTypes.h:63 | Wrapped by `sdk::BarcodeSymbology` and `detect_barcodes::DetectedBarcode::symbology_kind()` |
| VNBarcodeSymbologyI2of5Checksum | const | VNTypes.h:64 | Wrapped by `sdk::BarcodeSymbology` and `detect_barcodes::DetectedBarcode::symbology_kind()` |
| VNBarcodeSymbologyITF14 | const | VNTypes.h:65 | Wrapped by `sdk::BarcodeSymbology` and `detect_barcodes::DetectedBarcode::symbology_kind()` |
| VNBarcodeSymbologyMSIPlessey | const | VNTypes.h:76 | Wrapped by `sdk::BarcodeSymbology` and `detect_barcodes::DetectedBarcode::symbology_kind()` |
| VNBarcodeSymbologyMicroPDF417 | const | VNTypes.h:74 | Wrapped by `sdk::BarcodeSymbology` and `detect_barcodes::DetectedBarcode::symbology_kind()` |
| VNBarcodeSymbologyMicroQR | const | VNTypes.h:75 | Wrapped by `sdk::BarcodeSymbology` and `detect_barcodes::DetectedBarcode::symbology_kind()` |
| VNBarcodeSymbologyPDF417 | const | VNTypes.h:66 | Wrapped by `sdk::BarcodeSymbology` and `detect_barcodes::DetectedBarcode::symbology_kind()` |
| VNBarcodeSymbologyQR | const | VNTypes.h:67 | Wrapped by `sdk::BarcodeSymbology` and `detect_barcodes::DetectedBarcode::symbology_kind()` |
| VNBarcodeSymbologyUPCE | const | VNTypes.h:68 | Wrapped by `sdk::BarcodeSymbology` and `detect_barcodes::DetectedBarcode::symbology_kind()` |
| VNCircle | interface | VNGeometry.h:199 | Wrapped by `geometry::VisionCircle` |
| VNComputeStageMain | const | VNTypes.h:36 | Wrapped by `sdk::ComputeStage` and surfaced from `processing::Request::supported_compute_stages()` |
| VNComputeStagePostProcessing | const | VNTypes.h:42 | Wrapped by `sdk::ComputeStage` and surfaced from `processing::Request::supported_compute_stages()` |
| VNContour | interface | VNGeometry.h:256 | Wrapped by `contours::Contour` and the explicit `VisionContour` alias. |
| VNDetectedPoint | interface | VNDetectedPoint.h:21 | Wrapped by `recognized_points::VisionDetectedPoint`. |
| VNElementType | enum | VNTypes.h:80 | Wrapped by `sdk::ElementType`. |
| VNElementTypeSize | function | VNUtils.h:195 | Wrapped by `geometry::element_type_size`. |
| VNErrorCode | enum | VNError.h:14 | Wrapped by `sdk::VisionErrorCode`. |
| VNErrorDomain | const | VNError.h:11 | Wrapped by `sdk::VISION_ERROR_DOMAIN`. |
| VNFaceLandmarkRegion | interface | VNFaceLandmarks.h:26 | Wrapped by `face_landmarks::FaceLandmarkRegion`. |
| VNFaceLandmarkRegion2D | interface | VNFaceLandmarks.h:45 | Wrapped by `face_landmarks::FaceLandmarkRegion2D`. |
| VNFaceLandmarks | interface | VNFaceLandmarks.h:97 | Wrapped by `face_landmarks::FaceLandmarks`. |
| VNFaceLandmarks2D | interface | VNFaceLandmarks.h:116 | Wrapped by `face_landmarks::FaceLandmarks2D`. |
| VNFaceObservationAccepting | protocol | VNFaceObservationAccepting.h:21 | Wrapped by the `face_landmarks::FaceObservationAccepting` trait and `FaceLandmarksRequest`. |
| VNGeometryUtils | interface | VNGeometryUtils.h:24 | Wrapped by the pure-Rust `geometry::VisionGeometryUtils` helper surface. |
| VNHumanBodyPose3DObservationHeightEstimation | enum | VNObservation.h:881 | Wrapped by the public alias `human_body_pose_3d::HumanBodyPose3DObservationHeightEstimation`. |
| VNHumanBodyPose3DObservationJointNameCenterHead | const | VNTypes.h:183 | Wrapped by `human_body_pose_3d::HumanBodyPose3DJointName`. |
| VNHumanBodyPose3DObservationJointNameCenterShoulder | const | VNTypes.h:182 | Wrapped by `human_body_pose_3d::HumanBodyPose3DJointName`. |
| VNHumanBodyPose3DObservationJointNameLeftAnkle | const | VNTypes.h:180 | Wrapped by `human_body_pose_3d::HumanBodyPose3DJointName`. |
| VNHumanBodyPose3DObservationJointNameLeftElbow | const | VNTypes.h:186 | Wrapped by `human_body_pose_3d::HumanBodyPose3DJointName`. |
| VNHumanBodyPose3DObservationJointNameLeftHip | const | VNTypes.h:178 | Wrapped by `human_body_pose_3d::HumanBodyPose3DJointName`. |
| VNHumanBodyPose3DObservationJointNameLeftKnee | const | VNTypes.h:179 | Wrapped by `human_body_pose_3d::HumanBodyPose3DJointName`. |
| VNHumanBodyPose3DObservationJointNameLeftShoulder | const | VNTypes.h:185 | Wrapped by `human_body_pose_3d::HumanBodyPose3DJointName`. |
| VNHumanBodyPose3DObservationJointNameLeftWrist | const | VNTypes.h:187 | Wrapped by `human_body_pose_3d::HumanBodyPose3DJointName`. |
| VNHumanBodyPose3DObservationJointNameRightAnkle | const | VNTypes.h:177 | Wrapped by `human_body_pose_3d::HumanBodyPose3DJointName`. |
| VNHumanBodyPose3DObservationJointNameRightElbow | const | VNTypes.h:189 | Wrapped by `human_body_pose_3d::HumanBodyPose3DJointName`. |
| VNHumanBodyPose3DObservationJointNameRightHip | const | VNTypes.h:175 | Wrapped by `human_body_pose_3d::HumanBodyPose3DJointName`. |
| VNHumanBodyPose3DObservationJointNameRightKnee | const | VNTypes.h:176 | Wrapped by `human_body_pose_3d::HumanBodyPose3DJointName`. |
| VNHumanBodyPose3DObservationJointNameRightShoulder | const | VNTypes.h:188 | Wrapped by `human_body_pose_3d::HumanBodyPose3DJointName`. |
| VNHumanBodyPose3DObservationJointNameRightWrist | const | VNTypes.h:190 | Wrapped by `human_body_pose_3d::HumanBodyPose3DJointName`. |
| VNHumanBodyPose3DObservationJointNameRoot | const | VNTypes.h:174 | Wrapped by `human_body_pose_3d::HumanBodyPose3DJointName`. |
| VNHumanBodyPose3DObservationJointNameSpine | const | VNTypes.h:181 | Wrapped by `human_body_pose_3d::HumanBodyPose3DJointName`. |
| VNHumanBodyPose3DObservationJointNameTopHead | const | VNTypes.h:184 | Wrapped by `human_body_pose_3d::HumanBodyPose3DJointName`. |
| VNHumanBodyPose3DObservationJointsGroupNameHead | const | VNTypes.h:193 | Wrapped by `human_body_pose_3d::HumanBodyPose3DJointGroupName`. |
| VNHumanBodyPoseObservationJointNameLeftAnkle | const | VNDetectHumanBodyPoseRequest.h:83 | Wrapped by `body_pose::HumanBodyPoseJointName`. |
| VNHumanBodyPoseObservationJointNameLeftEar | const | VNDetectHumanBodyPoseRequest.h:63 | Wrapped by `body_pose::HumanBodyPoseJointName`. |
| VNHumanBodyPoseObservationJointNameLeftElbow | const | VNDetectHumanBodyPoseRequest.h:70 | Wrapped by `body_pose::HumanBodyPoseJointName`. |
| VNHumanBodyPoseObservationJointNameLeftEye | const | VNDetectHumanBodyPoseRequest.h:60 | Wrapped by `body_pose::HumanBodyPoseJointName`. |
| VNHumanBodyPoseObservationJointNameLeftHip | const | VNDetectHumanBodyPoseRequest.h:76 | Wrapped by `body_pose::HumanBodyPoseJointName`. |
| VNHumanBodyPoseObservationJointNameLeftKnee | const | VNDetectHumanBodyPoseRequest.h:80 | Wrapped by `body_pose::HumanBodyPoseJointName`. |
| VNHumanBodyPoseObservationJointNameLeftShoulder | const | VNDetectHumanBodyPoseRequest.h:66 | Wrapped by `body_pose::HumanBodyPoseJointName`. |
| VNHumanBodyPoseObservationJointNameLeftWrist | const | VNDetectHumanBodyPoseRequest.h:73 | Wrapped by `body_pose::HumanBodyPoseJointName`. |
| VNHumanBodyPoseObservationJointNameNeck | const | VNDetectHumanBodyPoseRequest.h:68 | Wrapped by `body_pose::HumanBodyPoseJointName`. |
| VNHumanBodyPoseObservationJointNameNose | const | VNDetectHumanBodyPoseRequest.h:58 | Wrapped by `body_pose::HumanBodyPoseJointName`. |
| VNHumanBodyPoseObservationJointNameRightAnkle | const | VNDetectHumanBodyPoseRequest.h:84 | Wrapped by `body_pose::HumanBodyPoseJointName`. |
| VNHumanBodyPoseObservationJointNameRightEar | const | VNDetectHumanBodyPoseRequest.h:64 | Wrapped by `body_pose::HumanBodyPoseJointName`. |
| VNHumanBodyPoseObservationJointNameRightElbow | const | VNDetectHumanBodyPoseRequest.h:71 | Wrapped by `body_pose::HumanBodyPoseJointName`. |
| VNHumanBodyPoseObservationJointNameRightEye | const | VNDetectHumanBodyPoseRequest.h:61 | Wrapped by `body_pose::HumanBodyPoseJointName`. |
| VNHumanBodyPoseObservationJointNameRightHip | const | VNDetectHumanBodyPoseRequest.h:77 | Wrapped by `body_pose::HumanBodyPoseJointName`. |
| VNHumanBodyPoseObservationJointNameRightKnee | const | VNDetectHumanBodyPoseRequest.h:81 | Wrapped by `body_pose::HumanBodyPoseJointName`. |
| VNHumanBodyPoseObservationJointNameRightShoulder | const | VNDetectHumanBodyPoseRequest.h:67 | Wrapped by `body_pose::HumanBodyPoseJointName`. |
| VNHumanBodyPoseObservationJointNameRightWrist | const | VNDetectHumanBodyPoseRequest.h:74 | Wrapped by `body_pose::HumanBodyPoseJointName`. |
| VNHumanBodyPoseObservationJointNameRoot | const | VNDetectHumanBodyPoseRequest.h:78 | Wrapped by `body_pose::HumanBodyPoseJointName`. |
| VNHumanBodyPoseObservationJointsGroupNameFace | const | VNDetectHumanBodyPoseRequest.h:91 | Wrapped by `body_pose::HumanBodyPoseJointGroupName`. |
| VNHumanBodyRecognizedPoint3D | interface | VNHumanBodyRecognizedPoint3D.h:16 | Wrapped by `recognized_points::HumanBodyRecognizedPoint3D` and the `detect_human_body_recognized_points_3d` helper. |
| VNHumanHandPoseObservationJointNameIndexDIP | const | VNDetectHumanHandPoseRequest.h:68 | Wrapped by `hand_pose::HumanHandPoseJointName`. |
| VNHumanHandPoseObservationJointNameIndexMCP | const | VNDetectHumanHandPoseRequest.h:66 | Wrapped by `hand_pose::HumanHandPoseJointName`. |
| VNHumanHandPoseObservationJointNameIndexPIP | const | VNDetectHumanHandPoseRequest.h:67 | Wrapped by `hand_pose::HumanHandPoseJointName`. |
| VNHumanHandPoseObservationJointNameIndexTip | const | VNDetectHumanHandPoseRequest.h:69 | Wrapped by `hand_pose::HumanHandPoseJointName`. |
| VNHumanHandPoseObservationJointNameLittleDIP | const | VNDetectHumanHandPoseRequest.h:83 | Wrapped by `hand_pose::HumanHandPoseJointName`. |
| VNHumanHandPoseObservationJointNameLittleMCP | const | VNDetectHumanHandPoseRequest.h:81 | Wrapped by `hand_pose::HumanHandPoseJointName`. |
| VNHumanHandPoseObservationJointNameLittlePIP | const | VNDetectHumanHandPoseRequest.h:82 | Wrapped by `hand_pose::HumanHandPoseJointName`. |
| VNHumanHandPoseObservationJointNameLittleTip | const | VNDetectHumanHandPoseRequest.h:84 | Wrapped by `hand_pose::HumanHandPoseJointName`. |
| VNHumanHandPoseObservationJointNameMiddleDIP | const | VNDetectHumanHandPoseRequest.h:73 | Wrapped by `hand_pose::HumanHandPoseJointName`. |
| VNHumanHandPoseObservationJointNameMiddleMCP | const | VNDetectHumanHandPoseRequest.h:71 | Wrapped by `hand_pose::HumanHandPoseJointName`. |
| VNHumanHandPoseObservationJointNameMiddlePIP | const | VNDetectHumanHandPoseRequest.h:72 | Wrapped by `hand_pose::HumanHandPoseJointName`. |
| VNHumanHandPoseObservationJointNameMiddleTip | const | VNDetectHumanHandPoseRequest.h:74 | Wrapped by `hand_pose::HumanHandPoseJointName`. |
| VNHumanHandPoseObservationJointNameRingDIP | const | VNDetectHumanHandPoseRequest.h:78 | Wrapped by `hand_pose::HumanHandPoseJointName`. |
| VNHumanHandPoseObservationJointNameRingMCP | const | VNDetectHumanHandPoseRequest.h:76 | Wrapped by `hand_pose::HumanHandPoseJointName`. |
| VNHumanHandPoseObservationJointNameRingPIP | const | VNDetectHumanHandPoseRequest.h:77 | Wrapped by `hand_pose::HumanHandPoseJointName`. |
| VNHumanHandPoseObservationJointNameRingTip | const | VNDetectHumanHandPoseRequest.h:79 | Wrapped by `hand_pose::HumanHandPoseJointName`. |
| VNHumanHandPoseObservationJointNameThumbCMC | const | VNDetectHumanHandPoseRequest.h:61 | Wrapped by `hand_pose::HumanHandPoseJointName`. |
| VNHumanHandPoseObservationJointNameThumbIP | const | VNDetectHumanHandPoseRequest.h:63 | Wrapped by `hand_pose::HumanHandPoseJointName`. |
| VNHumanHandPoseObservationJointNameThumbMP | const | VNDetectHumanHandPoseRequest.h:62 | Wrapped by `hand_pose::HumanHandPoseJointName`. |
| VNHumanHandPoseObservationJointNameThumbTip | const | VNDetectHumanHandPoseRequest.h:64 | Wrapped by `hand_pose::HumanHandPoseJointName`. |
| VNHumanHandPoseObservationJointNameWrist | const | VNDetectHumanHandPoseRequest.h:59 | Wrapped by `hand_pose::HumanHandPoseJointName`. |
| VNHumanHandPoseObservationJointsGroupNameAll | const | VNDetectHumanHandPoseRequest.h:95 | Wrapped by `hand_pose::HumanHandPoseJointGroupName`. |
| VNHumanHandPoseObservationJointsGroupNameIndexFinger | const | VNDetectHumanHandPoseRequest.h:91 | Wrapped by `hand_pose::HumanHandPoseJointGroupName`. |
| VNHumanHandPoseObservationJointsGroupNameLittleFinger | const | VNDetectHumanHandPoseRequest.h:94 | Wrapped by `hand_pose::HumanHandPoseJointGroupName`. |
| VNHumanHandPoseObservationJointsGroupNameMiddleFinger | const | VNDetectHumanHandPoseRequest.h:92 | Wrapped by `hand_pose::HumanHandPoseJointGroupName`. |
| VNHumanHandPoseObservationJointsGroupNameRingFinger | const | VNDetectHumanHandPoseRequest.h:93 | Wrapped by `hand_pose::HumanHandPoseJointGroupName`. |
| VNHumanHandPoseObservationJointsGroupNameThumb | const | VNDetectHumanHandPoseRequest.h:90 | Wrapped by `hand_pose::HumanHandPoseJointGroupName`. |
| VNImageCropAndScaleOption | enum | VNTypes.h:19 | Wrapped by `sdk::ImageCropAndScaleOption` with conversions to/from `CoreMLImageCropAndScaleOption`. |
| VNImageOptionCIContext | const | VNRequestHandler.h:57 | Wrapped by `sdk::ImageOption` and surfaced from `ImageRequestHandler::supported_image_options()`. |
| VNImageOptionCameraIntrinsics | const | VNRequestHandler.h:51 | Wrapped by `sdk::ImageOption` and surfaced from `ImageRequestHandler::supported_image_options()`. |
| VNImageOptionProperties | const | VNRequestHandler.h:37 | Wrapped by `sdk::ImageOption` and surfaced from `ImageRequestHandler::supported_image_options()`. |
| VNImagePointForFaceLandmarkPoint | function | VNUtils.h:185 | Exposed through the dedicated geometry helper in src/geometry.rs: `geometry::image_point_for_face_landmark_point()`. |
| VNImagePointForNormalizedPoint | function | VNUtils.h:47 | Exposed through the dedicated geometry helper in src/geometry.rs: `geometry::image_point_for_normalized_point()`. |
| VNImagePointForNormalizedPointUsingRegionOfInterest | function | VNUtils.h:63 | Exposed through the dedicated geometry helper in src/geometry.rs: `geometry::image_point_for_normalized_point_using_region_of_interest()`. |
| VNImageRectForNormalizedRect | function | VNUtils.h:107 | Exposed through the dedicated geometry helper in src/geometry.rs: `geometry::image_rect_for_normalized_rect()`. |
| VNImageRectForNormalizedRectUsingRegionOfInterest | function | VNUtils.h:123 | Exposed through the dedicated geometry helper in src/geometry.rs: `geometry::image_rect_for_normalized_rect_using_region_of_interest()`. |
| VNNormalizedFaceBoundingBoxPointForLandmarkPoint | function | VNUtils.h:169 | Exposed through the dedicated geometry helper in src/geometry.rs: `geometry::normalized_face_bounding_box_point_for_landmark_point()`. |
| VNNormalizedIdentityRect | const | VNUtils.h:23 | Exposed through the dedicated geometry helper in src/geometry.rs: `geometry::normalized_identity_rect()`. |
| VNNormalizedPointForImagePoint | function | VNUtils.h:77 | Exposed through the dedicated geometry helper in src/geometry.rs: `geometry::normalized_point_for_image_point()`. |
| VNNormalizedPointForImagePointUsingRegionOfInterest | function | VNUtils.h:93 | Exposed through the dedicated geometry helper in src/geometry.rs: `geometry::normalized_point_for_image_point_using_region_of_interest()`. |
| VNNormalizedRectForImageRect | function | VNUtils.h:137 | Exposed through the dedicated geometry helper in src/geometry.rs: `geometry::normalized_rect_for_image_rect()`. |
| VNNormalizedRectForImageRectUsingRegionOfInterest | function | VNUtils.h:153 | Exposed through the dedicated geometry helper in src/geometry.rs: `geometry::normalized_rect_for_image_rect_using_region_of_interest()`. |
| VNNormalizedRectIsIdentityRect | function | VNUtils.h:33 | Exposed through the dedicated geometry helper in src/geometry.rs: `geometry::normalized_rect_is_identity_rect()`. |
| VNPoint | interface | VNGeometry.h:27 | Wrapped by `geometry::VisionPoint`. |
| VNPoint3D | interface | VNGeometry.h:93 | Wrapped by `geometry::VisionPoint3D`. |
| VNPointsClassification | enum | VNTypes.h:106 | Wrapped by `sdk::PointsClassification`. |
| VNRecognizedPoint | interface | VNDetectedPoint.h:44 | Wrapped by `recognized_points::VisionRecognizedPoint`. |
| VNRecognizedPoint3D | interface | VNRecognizedPoint3D.h:21 | Wrapped by `recognized_points::VisionRecognizedPoint3D`. |
| VNRecognizedPoint3DGroupKeyAll | const | VNObservation.h:830 | Wrapped by `sdk::RecognizedPoint3DGroupKey::All`. |
| VNRecognizedPointGroupKeyAll | const | VNObservation.h:660 | Wrapped by `sdk::RecognizedPointGroupKey::All`. |
| VNRecognizedText | interface | VNObservation.h:365 | Wrapped by `recognize_text::RecognizedTextCandidate` and `processing::RecognizedTextObservation::candidate()`. |
| VNRequestFaceLandmarksConstellation | enum | VNDetectFaceLandmarksRequest.h:19 | Wrapped by `face_landmarks::RequestFaceLandmarksConstellation` and `FaceLandmarksRequest`. |
| VNRequestProgressProviding | protocol | VNRequest.h:181 | Wrapped by `request_base::RequestProgress` and the `RequestProgressProviding` trait. |
| VNRequestRevisionProviding | protocol | VNRequestRevisionProviding.h:15 | Wrapped by the `request_base::RequestRevisionProviding` trait across base request wrappers plus explicit request builders. |
| VNTrackOpticalFlowRequestComputationAccuracy | enum | VNTrackOpticalFlowRequest.h:19 | Wrapped by `tracking::TrackOpticalFlowRequestComputationAccuracy`. |
| VNVector | interface | VNGeometry.h:109 | Wrapped by `geometry::VisionVector`. |
| VNVideoProcessorCadence | interface | VNVideoProcessor.h:23 | Wrapped by `processing::VideoProcessorCadence`. |
| VNVideoProcessorFrameRateCadence | interface | VNVideoProcessor.h:32 | Wrapped by `processing::VideoProcessorFrameRateCadence`. |
| VNVideoProcessorRequestProcessingOptions | interface | VNVideoProcessor.h:57 | Wrapped by `processing::VideoProcessorRequestProcessingOptions`. |
| VNVideoProcessorTimeIntervalCadence | interface | VNVideoProcessor.h:44 | Wrapped by `processing::VideoProcessorTimeIntervalCadence`. |
| VNVisionVersionNumber | const | Vision.h:62 | Wrapped by the public accessor `sdk::vision_version_number()`. |

## 🔴 GAPS
| Symbol | Kind | Header | Notes |
| --- | --- | --- | --- |

## ⏭️ EXEMPT
| Symbol | Kind | Header | Reason | SDK attribute |
| --- | --- | --- | --- | --- |
| VNBodyLandmarkKeyLeftAnkle | const | VNDetectHumanBodyPoseRequest.h:40 | Deprecated in the current macOS SDK; excluded per audit instructions. | API_DEPRECATED_WITH_REPLACEMENT("VNHumanBodyPoseObservationJointNameLeftAnkle", macos(11.0, 11.0), ios(14.0, 14.0), tvos(14.0, 14.0)) |
| VNBodyLandmarkKeyLeftEar | const | VNDetectHumanBodyPoseRequest.h:20 | Deprecated in the current macOS SDK; excluded per audit instructions. | API_DEPRECATED_WITH_REPLACEMENT("VNHumanBodyPoseObservationJointNameLeftEar", macos(11.0, 11.0), ios(14.0, 14.0), tvos(14.0, 14.0)) |
| VNBodyLandmarkKeyLeftElbow | const | VNDetectHumanBodyPoseRequest.h:27 | Deprecated in the current macOS SDK; excluded per audit instructions. | API_DEPRECATED_WITH_REPLACEMENT("VNHumanBodyPoseObservationJointNameLeftElbow", macos(11.0, 11.0), ios(14.0, 14.0), tvos(14.0, 14.0)) |
| VNBodyLandmarkKeyLeftEye | const | VNDetectHumanBodyPoseRequest.h:17 | Deprecated in the current macOS SDK; excluded per audit instructions. | API_DEPRECATED_WITH_REPLACEMENT("VNHumanBodyPoseObservationJointNameLeftEye", macos(11.0, 11.0), ios(14.0, 14.0), tvos(14.0, 14.0)) |
| VNBodyLandmarkKeyLeftHip | const | VNDetectHumanBodyPoseRequest.h:33 | Deprecated in the current macOS SDK; excluded per audit instructions. | API_DEPRECATED_WITH_REPLACEMENT("VNHumanBodyPoseObservationJointNameLeftHip", macos(11.0, 11.0), ios(14.0, 14.0), tvos(14.0, 14.0)) |
| VNBodyLandmarkKeyLeftKnee | const | VNDetectHumanBodyPoseRequest.h:37 | Deprecated in the current macOS SDK; excluded per audit instructions. | API_DEPRECATED_WITH_REPLACEMENT("VNHumanBodyPoseObservationJointNameLeftKnee", macos(11.0, 11.0), ios(14.0, 14.0), tvos(14.0, 14.0)) |
| VNBodyLandmarkKeyLeftShoulder | const | VNDetectHumanBodyPoseRequest.h:23 | Deprecated in the current macOS SDK; excluded per audit instructions. | API_DEPRECATED_WITH_REPLACEMENT("VNHumanBodyPoseObservationJointNameLeftShoulder", macos(11.0, 11.0), ios(14.0, 14.0), tvos(14.0, 14.0)) |
| VNBodyLandmarkKeyLeftWrist | const | VNDetectHumanBodyPoseRequest.h:30 | Deprecated in the current macOS SDK; excluded per audit instructions. | API_DEPRECATED_WITH_REPLACEMENT("VNHumanBodyPoseObservationJointNameLeftWrist", macos(11.0, 11.0), ios(14.0, 14.0), tvos(14.0, 14.0)) |
| VNBodyLandmarkKeyNeck | const | VNDetectHumanBodyPoseRequest.h:25 | Deprecated in the current macOS SDK; excluded per audit instructions. | API_DEPRECATED_WITH_REPLACEMENT("VNHumanBodyPoseObservationJointNameNeck", macos(11.0, 11.0), ios(14.0, 14.0), tvos(14.0, 14.0)) |
| VNBodyLandmarkKeyNose | const | VNDetectHumanBodyPoseRequest.h:15 | Deprecated in the current macOS SDK; excluded per audit instructions. | API_DEPRECATED_WITH_REPLACEMENT("VNHumanBodyPoseObservationJointNameNose", macos(11.0, 11.0), ios(14.0, 14.0), tvos(14.0, 14.0)) |
| VNBodyLandmarkKeyRightAnkle | const | VNDetectHumanBodyPoseRequest.h:41 | Deprecated in the current macOS SDK; excluded per audit instructions. | API_DEPRECATED_WITH_REPLACEMENT("VNHumanBodyPoseObservationJointNameRightAnkle", macos(11.0, 11.0), ios(14.0, 14.0), tvos(14.0, 14.0)) |
| VNBodyLandmarkKeyRightEar | const | VNDetectHumanBodyPoseRequest.h:21 | Deprecated in the current macOS SDK; excluded per audit instructions. | API_DEPRECATED_WITH_REPLACEMENT("VNHumanBodyPoseObservationJointNameRightEar", macos(11.0, 11.0), ios(14.0, 14.0), tvos(14.0, 14.0)) |
| VNBodyLandmarkKeyRightElbow | const | VNDetectHumanBodyPoseRequest.h:28 | Deprecated in the current macOS SDK; excluded per audit instructions. | API_DEPRECATED_WITH_REPLACEMENT("VNHumanBodyPoseObservationJointNameRightElbow", macos(11.0, 11.0), ios(14.0, 14.0), tvos(14.0, 14.0)) |
| VNBodyLandmarkKeyRightEye | const | VNDetectHumanBodyPoseRequest.h:18 | Deprecated in the current macOS SDK; excluded per audit instructions. | API_DEPRECATED_WITH_REPLACEMENT("VNHumanBodyPoseObservationJointNameRightEye", macos(11.0, 11.0), ios(14.0, 14.0), tvos(14.0, 14.0)) |
| VNBodyLandmarkKeyRightHip | const | VNDetectHumanBodyPoseRequest.h:34 | Deprecated in the current macOS SDK; excluded per audit instructions. | API_DEPRECATED_WITH_REPLACEMENT("VNHumanBodyPoseObservationJointNameRightHip", macos(11.0, 11.0), ios(14.0, 14.0), tvos(14.0, 14.0)) |
| VNBodyLandmarkKeyRightKnee | const | VNDetectHumanBodyPoseRequest.h:38 | Deprecated in the current macOS SDK; excluded per audit instructions. | API_DEPRECATED_WITH_REPLACEMENT("VNHumanBodyPoseObservationJointNameRightKnee", macos(11.0, 11.0), ios(14.0, 14.0), tvos(14.0, 14.0)) |
| VNBodyLandmarkKeyRightShoulder | const | VNDetectHumanBodyPoseRequest.h:24 | Deprecated in the current macOS SDK; excluded per audit instructions. | API_DEPRECATED_WITH_REPLACEMENT("VNHumanBodyPoseObservationJointNameRightShoulder", macos(11.0, 11.0), ios(14.0, 14.0), tvos(14.0, 14.0)) |
| VNBodyLandmarkKeyRightWrist | const | VNDetectHumanBodyPoseRequest.h:31 | Deprecated in the current macOS SDK; excluded per audit instructions. | API_DEPRECATED_WITH_REPLACEMENT("VNHumanBodyPoseObservationJointNameRightWrist", macos(11.0, 11.0), ios(14.0, 14.0), tvos(14.0, 14.0)) |
| VNBodyLandmarkKeyRoot | const | VNDetectHumanBodyPoseRequest.h:35 | Deprecated in the current macOS SDK; excluded per audit instructions. | API_DEPRECATED_WITH_REPLACEMENT("VNHumanBodyPoseObservationJointNameRoot", macos(11.0, 11.0), ios(14.0, 14.0), tvos(14.0, 14.0)) |
| VNBodyLandmarkRegionKeyFace | const | VNDetectHumanBodyPoseRequest.h:44 | Deprecated in the current macOS SDK; excluded per audit instructions. | API_DEPRECATED_WITH_REPLACEMENT("VNHumanBodyPoseObservationJointsGroupNameFace", macos(11.0, 11.0), ios(14.0, 14.0), tvos(14.0, 14.0)) |
| VNBodyLandmarkRegionKeyLeftArm | const | VNDetectHumanBodyPoseRequest.h:46 | Deprecated in the current macOS SDK; excluded per audit instructions. | API_DEPRECATED_WITH_REPLACEMENT("VNHumanBodyPoseObservationJointsGroupNameLeftArm", macos(11.0, 11.0), ios(14.0, 14.0), tvos(14.0, 14.0)) |
| VNBodyLandmarkRegionKeyLeftLeg | const | VNDetectHumanBodyPoseRequest.h:48 | Deprecated in the current macOS SDK; excluded per audit instructions. | API_DEPRECATED_WITH_REPLACEMENT("VNHumanBodyPoseObservationJointsGroupNameLeftLeg", macos(11.0, 11.0), ios(14.0, 14.0), tvos(14.0, 14.0)) |
| VNBodyLandmarkRegionKeyRightArm | const | VNDetectHumanBodyPoseRequest.h:47 | Deprecated in the current macOS SDK; excluded per audit instructions. | API_DEPRECATED_WITH_REPLACEMENT("VNHumanBodyPoseObservationJointsGroupNameRightArm", macos(11.0, 11.0), ios(14.0, 14.0), tvos(14.0, 14.0)) |
| VNBodyLandmarkRegionKeyRightLeg | const | VNDetectHumanBodyPoseRequest.h:49 | Deprecated in the current macOS SDK; excluded per audit instructions. | API_DEPRECATED_WITH_REPLACEMENT("VNHumanBodyPoseObservationJointsGroupNameRightLeg", macos(11.0, 11.0), ios(14.0, 14.0), tvos(14.0, 14.0)) |
| VNBodyLandmarkRegionKeyTorso | const | VNDetectHumanBodyPoseRequest.h:45 | Deprecated in the current macOS SDK; excluded per audit instructions. | API_DEPRECATED_WITH_REPLACEMENT("VNHumanBodyPoseObservationJointsGroupNameTorso", macos(11.0, 11.0), ios(14.0, 14.0), tvos(14.0, 14.0)) |
| VNVideoProcessingOptionFrameCadence | const | VNTypes.h:91 | Deprecated in the current macOS SDK; excluded per audit instructions. | API_DEPRECATED_WITH_REPLACEMENT("VNVideoProcessorRequestProcessingOptions", macos(11.0, 11.0), ios(14.0, 14.0), tvos(14.0, 14.0)) |
| VNVideoProcessingOptionTimeInterval | const | VNTypes.h:92 | Deprecated in the current macOS SDK; excluded per audit instructions. | API_DEPRECATED_WITH_REPLACEMENT("VNVideoProcessorRequestProcessingOptions", macos(11.0, 11.0), ios(14.0, 14.0), tvos(14.0, 14.0)) |
