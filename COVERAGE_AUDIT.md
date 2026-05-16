# apple-vision coverage audit (vs MacOSX26.2.sdk)

SDK_PUBLIC_SYMBOLS: 249
VERIFIED: 51
GAPS: 171
EXEMPT: 27
COVERAGE_PCT: 22.97%

Methodology note: per the audit instructions, this inventory covers Vision interfaces, protocols, enum/struct typedefs, exported constants, and top-level C functions. Alias-only typedefs are not counted separately. A symbol is **VERIFIED** only when `apple-vision` exposes a dedicated public Rust surface for it; symbols used only inside the Swift bridge or flattened into crate-specific data structures remain in **GAPS**.

## 🟢 VERIFIED
| Symbol | Kind | Header | Wrapped by |
| --- | --- | --- | --- |
| VNAnimalBodyPoseObservation | interface | VNObservation.h:790 | Exposed through the `AnimalJoint` result set returned by `detect_animal_body_pose`. |
| VNBarcodeObservation | interface | VNObservation.h:411 | Exposed through `DetectedBarcode` (payload, symbology, confidence, bounding box). |
| VNCalculateImageAestheticsScoresRequest | interface | VNCalculateImageAestheticsScoresRequest.h:19 | Exposed as `calculate_aesthetics_scores_in_path`; this is the current SDK spelling for image-aesthetics scoring. |
| VNClassificationObservation | interface | VNObservation.h:148 | Exposed through `Classification`. |
| VNClassifyImageRequest | interface | VNClassifyImageRequest.h:23 | Exposed as `classify_image_in_path`. |
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
| VNHumanBodyPose3DObservation | interface | VNObservation.h:888 | Exposed through `HumanJoint3D` results from `detect_human_body_pose_3d`. |
| VNHumanObservation | interface | VNObservation.h:729 | Exposed through `DetectedHuman`. |
| VNImageAestheticsScoresObservation | interface | VNObservation.h:974 | Exposed through `AestheticsScores`. |
| VNImageHomographicAlignmentObservation | interface | VNObservation.h:532 | Exposed through `HomographicAlignment`. |
| VNImageTranslationAlignmentObservation | interface | VNObservation.h:519 | Exposed through `TranslationalAlignment`. |
| VNRecognizeAnimalsRequest | interface | VNRecognizeAnimalsRequest.h:27 | Exposed as `recognize_animals_in_path`. |
| VNRecognizeTextRequest | interface | VNRecognizeTextRequest.h:31 | Exposed via `TextRecognizer`. |
| VNRecognizedObjectObservation | interface | VNObservation.h:204 | Animal recognition surfaces the recognized label set + bounding box through `RecognizedAnimal`. |
| VNRecognizedTextObservation | interface | VNObservation.h:392 | Exposed through `RecognizedText`. |
| VNRectangleObservation | interface | VNObservation.h:267 | Exposed through `RectangleObservation`. |
| VNRequestTextRecognitionLevel | enum | VNRecognizeTextRequest.h:17 | Wrapped by `recognize_text::RecognitionLevel` and mapped onto `VNRecognizeTextRequest.recognitionLevel` in the Swift bridge. |
| VNSaliencyImageObservation | interface | VNObservation.h:546 | Exposed through `SalientRegion` / `ObjectnessRegion` result sets. |
| VNTrackHomographicImageRegistrationRequest | interface | VNTrackHomographicImageRegistrationRequest.h:19 | Exposed via `HomographicImageTracker`. |
| VNTrackObjectRequest | interface | VNTrackObjectRequest.h:22 | Exposed via `ObjectTracker`. |
| VNTrackOpticalFlowRequest | interface | VNTrackOpticalFlowRequest.h:63 | Exposed via `OpticalFlowTracker`. |
| VNTrackRectangleRequest | interface | VNTrackRectangleRequest.h:23 | Exposed via `RectangleTracker`. |
| VNTrackTranslationalImageRegistrationRequest | interface | VNTrackTranslationalImageRegistrationRequest.h:19 | Exposed via `TranslationalImageTracker`. |
| VNTrajectoryObservation | interface | VNObservation.h:314 | Exposed through `Trajectory` (detected/projected points, equation coefficients, confidence). |
| VNTranslationalImageRegistrationRequest | interface | VNImageRegistrationRequest.h:31 | Exposed as `register_translational`. |

## 🔴 GAPS
| Symbol | Kind | Header | Notes |
| --- | --- | --- | --- |
| VNAnimalBodyPoseObservationJointNameLeftEarTop | const | VNTypes.h:133 | No dedicated public Rust wrapper in the crate. |
| VNAnimalBodyPoseObservationJointsGroupNameHead | const | VNTypes.h:162 | No dedicated public Rust wrapper in the crate. |
| VNAnimalIdentifierCat | const | VNRecognizeAnimalsRequest.h:18 | No dedicated public Rust wrapper in the crate. |
| VNAnimalIdentifierDog | const | VNRecognizeAnimalsRequest.h:17 | No dedicated public Rust wrapper in the crate. |
| VNBarcodeCompositeType | enum | VNTypes.h:115 | No dedicated public Rust wrapper in the crate. |
| VNBarcodeSymbologyAztec | const | VNTypes.h:52 | Referenced internally in the Swift bridge or Rust internals, but not exposed as a dedicated public Rust wrapper. |
| VNBarcodeSymbologyCodabar | const | VNTypes.h:70 | No dedicated public Rust wrapper in the crate. |
| VNBarcodeSymbologyCode128 | const | VNTypes.h:59 | No dedicated public Rust wrapper in the crate. |
| VNBarcodeSymbologyCode39 | const | VNTypes.h:53 | No dedicated public Rust wrapper in the crate. |
| VNBarcodeSymbologyCode39Checksum | const | VNTypes.h:54 | No dedicated public Rust wrapper in the crate. |
| VNBarcodeSymbologyCode39FullASCII | const | VNTypes.h:55 | No dedicated public Rust wrapper in the crate. |
| VNBarcodeSymbologyCode39FullASCIIChecksum | const | VNTypes.h:56 | No dedicated public Rust wrapper in the crate. |
| VNBarcodeSymbologyCode93 | const | VNTypes.h:57 | No dedicated public Rust wrapper in the crate. |
| VNBarcodeSymbologyCode93i | const | VNTypes.h:58 | No dedicated public Rust wrapper in the crate. |
| VNBarcodeSymbologyDataMatrix | const | VNTypes.h:60 | No dedicated public Rust wrapper in the crate. |
| VNBarcodeSymbologyEAN13 | const | VNTypes.h:62 | Referenced internally in the Swift bridge or Rust internals, but not exposed as a dedicated public Rust wrapper. |
| VNBarcodeSymbologyEAN8 | const | VNTypes.h:61 | No dedicated public Rust wrapper in the crate. |
| VNBarcodeSymbologyGS1DataBar | const | VNTypes.h:71 | No dedicated public Rust wrapper in the crate. |
| VNBarcodeSymbologyGS1DataBarExpanded | const | VNTypes.h:72 | No dedicated public Rust wrapper in the crate. |
| VNBarcodeSymbologyGS1DataBarLimited | const | VNTypes.h:73 | No dedicated public Rust wrapper in the crate. |
| VNBarcodeSymbologyI2of5 | const | VNTypes.h:63 | No dedicated public Rust wrapper in the crate. |
| VNBarcodeSymbologyI2of5Checksum | const | VNTypes.h:64 | No dedicated public Rust wrapper in the crate. |
| VNBarcodeSymbologyITF14 | const | VNTypes.h:65 | No dedicated public Rust wrapper in the crate. |
| VNBarcodeSymbologyMSIPlessey | const | VNTypes.h:76 | No dedicated public Rust wrapper in the crate. |
| VNBarcodeSymbologyMicroPDF417 | const | VNTypes.h:74 | No dedicated public Rust wrapper in the crate. |
| VNBarcodeSymbologyMicroQR | const | VNTypes.h:75 | No dedicated public Rust wrapper in the crate. |
| VNBarcodeSymbologyPDF417 | const | VNTypes.h:66 | No dedicated public Rust wrapper in the crate. |
| VNBarcodeSymbologyQR | const | VNTypes.h:67 | Referenced internally in the Swift bridge or Rust internals, but not exposed as a dedicated public Rust wrapper. |
| VNBarcodeSymbologyUPCE | const | VNTypes.h:68 | No dedicated public Rust wrapper in the crate. |
| VNChirality | enum | VNTypes.h:96 | No dedicated public Rust wrapper in the crate. |
| VNCircle | interface | VNGeometry.h:199 | No dedicated public Rust wrapper in the crate. |
| VNComputeStageMain | const | VNTypes.h:36 | No dedicated public Rust wrapper in the crate. |
| VNComputeStagePostProcessing | const | VNTypes.h:42 | No dedicated public Rust wrapper in the crate. |
| VNContour | interface | VNGeometry.h:256 | No dedicated public Rust wrapper in the crate. |
| VNContoursObservation | interface | VNObservation.h:612 | Exposed through `Contour` trees; indexed convenience lookups (`contourAtIndex*`) are not modelled directly. |
| VNCoreMLFeatureValueObservation | interface | VNObservation.h:218 | The current `VNCoreMLRequest` safe API returns classification observations only. |
| VNCoreMLModel | interface | VNCoreMLRequest.h:22 | Referenced internally in the Swift bridge or Rust internals, but not exposed as a dedicated public Rust wrapper. |
| VNCoreMLRequest | interface | VNCoreMLRequest.h:55 | Exposed as `coreml_classify_in_path`; the current safe API handles classification outputs only. |
| VNDetectTextRectanglesRequest | interface | VNDetectTextRectanglesRequest.h:21 | Exposed as `detect_text_rectangles`; region boxes are surfaced today, while `characterBoxes` stays deferred. |
| VNDetectedPoint | interface | VNDetectedPoint.h:21 | No dedicated public Rust wrapper in the crate. |
| VNElementType | enum | VNTypes.h:80 | No dedicated public Rust wrapper in the crate. |
| VNElementTypeSize | function | VNUtils.h:195 | No dedicated public Rust wrapper in the crate. |
| VNErrorCode | enum | VNError.h:14 | No dedicated public Rust wrapper in the crate. |
| VNErrorDomain | const | VNError.h:11 | No dedicated public Rust wrapper in the crate. |
| VNFaceLandmarkRegion | interface | VNFaceLandmarks.h:26 | No dedicated public Rust wrapper in the crate. |
| VNFaceLandmarkRegion2D | interface | VNFaceLandmarks.h:45 | Referenced internally in the Swift bridge or Rust internals, but not exposed as a dedicated public Rust wrapper. |
| VNFaceLandmarks | interface | VNFaceLandmarks.h:97 | No dedicated public Rust wrapper in the crate. |
| VNFaceLandmarks2D | interface | VNFaceLandmarks.h:116 | No dedicated public Rust wrapper in the crate. |
| VNFaceObservationAccepting | protocol | VNFaceObservationAccepting.h:21 | No dedicated public Rust wrapper in the crate. |
| VNGeometryUtils | interface | VNGeometryUtils.h:24 | No dedicated public Rust wrapper in the crate. |
| VNHorizonObservation | interface | VNObservation.h:481 | Exposed through `detect_horizon_in_path`; the horizon angle is surfaced directly, while transform helpers are deferred. |
| VNHumanBodyPose3DObservationHeightEstimation | enum | VNObservation.h:881 | No dedicated public Rust wrapper in the crate. |
| VNHumanBodyPose3DObservationJointNameCenterHead | const | VNTypes.h:183 | No dedicated public Rust wrapper in the crate. |
| VNHumanBodyPose3DObservationJointNameCenterShoulder | const | VNTypes.h:182 | No dedicated public Rust wrapper in the crate. |
| VNHumanBodyPose3DObservationJointNameLeftAnkle | const | VNTypes.h:180 | No dedicated public Rust wrapper in the crate. |
| VNHumanBodyPose3DObservationJointNameLeftElbow | const | VNTypes.h:186 | No dedicated public Rust wrapper in the crate. |
| VNHumanBodyPose3DObservationJointNameLeftHip | const | VNTypes.h:178 | No dedicated public Rust wrapper in the crate. |
| VNHumanBodyPose3DObservationJointNameLeftKnee | const | VNTypes.h:179 | No dedicated public Rust wrapper in the crate. |
| VNHumanBodyPose3DObservationJointNameLeftShoulder | const | VNTypes.h:185 | No dedicated public Rust wrapper in the crate. |
| VNHumanBodyPose3DObservationJointNameLeftWrist | const | VNTypes.h:187 | No dedicated public Rust wrapper in the crate. |
| VNHumanBodyPose3DObservationJointNameRightAnkle | const | VNTypes.h:177 | No dedicated public Rust wrapper in the crate. |
| VNHumanBodyPose3DObservationJointNameRightElbow | const | VNTypes.h:189 | No dedicated public Rust wrapper in the crate. |
| VNHumanBodyPose3DObservationJointNameRightHip | const | VNTypes.h:175 | No dedicated public Rust wrapper in the crate. |
| VNHumanBodyPose3DObservationJointNameRightKnee | const | VNTypes.h:176 | No dedicated public Rust wrapper in the crate. |
| VNHumanBodyPose3DObservationJointNameRightShoulder | const | VNTypes.h:188 | No dedicated public Rust wrapper in the crate. |
| VNHumanBodyPose3DObservationJointNameRightWrist | const | VNTypes.h:190 | No dedicated public Rust wrapper in the crate. |
| VNHumanBodyPose3DObservationJointNameRoot | const | VNTypes.h:174 | No dedicated public Rust wrapper in the crate. |
| VNHumanBodyPose3DObservationJointNameSpine | const | VNTypes.h:181 | No dedicated public Rust wrapper in the crate. |
| VNHumanBodyPose3DObservationJointNameTopHead | const | VNTypes.h:184 | No dedicated public Rust wrapper in the crate. |
| VNHumanBodyPose3DObservationJointsGroupNameHead | const | VNTypes.h:193 | No dedicated public Rust wrapper in the crate. |
| VNHumanBodyPoseObservation | interface | VNDetectHumanBodyPoseRequest.h:103 | Exposed through `DetectedBodyPose`; joint dictionaries are surfaced, while the full observation type is flattened. |
| VNHumanBodyPoseObservationJointNameLeftAnkle | const | VNDetectHumanBodyPoseRequest.h:83 | No dedicated public Rust wrapper in the crate. |
| VNHumanBodyPoseObservationJointNameLeftEar | const | VNDetectHumanBodyPoseRequest.h:63 | No dedicated public Rust wrapper in the crate. |
| VNHumanBodyPoseObservationJointNameLeftElbow | const | VNDetectHumanBodyPoseRequest.h:70 | No dedicated public Rust wrapper in the crate. |
| VNHumanBodyPoseObservationJointNameLeftEye | const | VNDetectHumanBodyPoseRequest.h:60 | No dedicated public Rust wrapper in the crate. |
| VNHumanBodyPoseObservationJointNameLeftHip | const | VNDetectHumanBodyPoseRequest.h:76 | No dedicated public Rust wrapper in the crate. |
| VNHumanBodyPoseObservationJointNameLeftKnee | const | VNDetectHumanBodyPoseRequest.h:80 | No dedicated public Rust wrapper in the crate. |
| VNHumanBodyPoseObservationJointNameLeftShoulder | const | VNDetectHumanBodyPoseRequest.h:66 | No dedicated public Rust wrapper in the crate. |
| VNHumanBodyPoseObservationJointNameLeftWrist | const | VNDetectHumanBodyPoseRequest.h:73 | No dedicated public Rust wrapper in the crate. |
| VNHumanBodyPoseObservationJointNameNeck | const | VNDetectHumanBodyPoseRequest.h:68 | No dedicated public Rust wrapper in the crate. |
| VNHumanBodyPoseObservationJointNameNose | const | VNDetectHumanBodyPoseRequest.h:58 | No dedicated public Rust wrapper in the crate. |
| VNHumanBodyPoseObservationJointNameRightAnkle | const | VNDetectHumanBodyPoseRequest.h:84 | No dedicated public Rust wrapper in the crate. |
| VNHumanBodyPoseObservationJointNameRightEar | const | VNDetectHumanBodyPoseRequest.h:64 | No dedicated public Rust wrapper in the crate. |
| VNHumanBodyPoseObservationJointNameRightElbow | const | VNDetectHumanBodyPoseRequest.h:71 | No dedicated public Rust wrapper in the crate. |
| VNHumanBodyPoseObservationJointNameRightEye | const | VNDetectHumanBodyPoseRequest.h:61 | No dedicated public Rust wrapper in the crate. |
| VNHumanBodyPoseObservationJointNameRightHip | const | VNDetectHumanBodyPoseRequest.h:77 | No dedicated public Rust wrapper in the crate. |
| VNHumanBodyPoseObservationJointNameRightKnee | const | VNDetectHumanBodyPoseRequest.h:81 | No dedicated public Rust wrapper in the crate. |
| VNHumanBodyPoseObservationJointNameRightShoulder | const | VNDetectHumanBodyPoseRequest.h:67 | No dedicated public Rust wrapper in the crate. |
| VNHumanBodyPoseObservationJointNameRightWrist | const | VNDetectHumanBodyPoseRequest.h:74 | No dedicated public Rust wrapper in the crate. |
| VNHumanBodyPoseObservationJointNameRoot | const | VNDetectHumanBodyPoseRequest.h:78 | No dedicated public Rust wrapper in the crate. |
| VNHumanBodyPoseObservationJointsGroupNameFace | const | VNDetectHumanBodyPoseRequest.h:91 | No dedicated public Rust wrapper in the crate. |
| VNHumanBodyRecognizedPoint3D | interface | VNHumanBodyRecognizedPoint3D.h:16 | No dedicated public Rust wrapper in the crate. |
| VNHumanHandPoseObservation | interface | VNDetectHumanHandPoseRequest.h:101 | Exposed through `DetectedHandPose`; joint dictionaries are surfaced, while observation-specific extras (for example chirality) are deferred. |
| VNHumanHandPoseObservationJointNameIndexDIP | const | VNDetectHumanHandPoseRequest.h:68 | No dedicated public Rust wrapper in the crate. |
| VNHumanHandPoseObservationJointNameIndexMCP | const | VNDetectHumanHandPoseRequest.h:66 | No dedicated public Rust wrapper in the crate. |
| VNHumanHandPoseObservationJointNameIndexPIP | const | VNDetectHumanHandPoseRequest.h:67 | No dedicated public Rust wrapper in the crate. |
| VNHumanHandPoseObservationJointNameIndexTip | const | VNDetectHumanHandPoseRequest.h:69 | No dedicated public Rust wrapper in the crate. |
| VNHumanHandPoseObservationJointNameLittleDIP | const | VNDetectHumanHandPoseRequest.h:83 | No dedicated public Rust wrapper in the crate. |
| VNHumanHandPoseObservationJointNameLittleMCP | const | VNDetectHumanHandPoseRequest.h:81 | No dedicated public Rust wrapper in the crate. |
| VNHumanHandPoseObservationJointNameLittlePIP | const | VNDetectHumanHandPoseRequest.h:82 | No dedicated public Rust wrapper in the crate. |
| VNHumanHandPoseObservationJointNameLittleTip | const | VNDetectHumanHandPoseRequest.h:84 | No dedicated public Rust wrapper in the crate. |
| VNHumanHandPoseObservationJointNameMiddleDIP | const | VNDetectHumanHandPoseRequest.h:73 | No dedicated public Rust wrapper in the crate. |
| VNHumanHandPoseObservationJointNameMiddleMCP | const | VNDetectHumanHandPoseRequest.h:71 | No dedicated public Rust wrapper in the crate. |
| VNHumanHandPoseObservationJointNameMiddlePIP | const | VNDetectHumanHandPoseRequest.h:72 | No dedicated public Rust wrapper in the crate. |
| VNHumanHandPoseObservationJointNameMiddleTip | const | VNDetectHumanHandPoseRequest.h:74 | No dedicated public Rust wrapper in the crate. |
| VNHumanHandPoseObservationJointNameRingDIP | const | VNDetectHumanHandPoseRequest.h:78 | No dedicated public Rust wrapper in the crate. |
| VNHumanHandPoseObservationJointNameRingMCP | const | VNDetectHumanHandPoseRequest.h:76 | No dedicated public Rust wrapper in the crate. |
| VNHumanHandPoseObservationJointNameRingPIP | const | VNDetectHumanHandPoseRequest.h:77 | No dedicated public Rust wrapper in the crate. |
| VNHumanHandPoseObservationJointNameRingTip | const | VNDetectHumanHandPoseRequest.h:79 | No dedicated public Rust wrapper in the crate. |
| VNHumanHandPoseObservationJointNameThumbCMC | const | VNDetectHumanHandPoseRequest.h:61 | No dedicated public Rust wrapper in the crate. |
| VNHumanHandPoseObservationJointNameThumbIP | const | VNDetectHumanHandPoseRequest.h:63 | No dedicated public Rust wrapper in the crate. |
| VNHumanHandPoseObservationJointNameThumbMP | const | VNDetectHumanHandPoseRequest.h:62 | No dedicated public Rust wrapper in the crate. |
| VNHumanHandPoseObservationJointNameThumbTip | const | VNDetectHumanHandPoseRequest.h:64 | No dedicated public Rust wrapper in the crate. |
| VNHumanHandPoseObservationJointNameWrist | const | VNDetectHumanHandPoseRequest.h:59 | No dedicated public Rust wrapper in the crate. |
| VNHumanHandPoseObservationJointsGroupNameAll | const | VNDetectHumanHandPoseRequest.h:95 | No dedicated public Rust wrapper in the crate. |
| VNHumanHandPoseObservationJointsGroupNameIndexFinger | const | VNDetectHumanHandPoseRequest.h:91 | No dedicated public Rust wrapper in the crate. |
| VNHumanHandPoseObservationJointsGroupNameLittleFinger | const | VNDetectHumanHandPoseRequest.h:94 | No dedicated public Rust wrapper in the crate. |
| VNHumanHandPoseObservationJointsGroupNameMiddleFinger | const | VNDetectHumanHandPoseRequest.h:92 | No dedicated public Rust wrapper in the crate. |
| VNHumanHandPoseObservationJointsGroupNameRingFinger | const | VNDetectHumanHandPoseRequest.h:93 | No dedicated public Rust wrapper in the crate. |
| VNHumanHandPoseObservationJointsGroupNameThumb | const | VNDetectHumanHandPoseRequest.h:90 | No dedicated public Rust wrapper in the crate. |
| VNImageAlignmentObservation | interface | VNObservation.h:509 | Concrete translation + homography alignment observations are exposed; the abstract base observation is not. |
| VNImageBasedRequest | interface | VNRequest.h:157 | Shared image-request plumbing is reused throughout the bridge, but there is no standalone public base-class wrapper. |
| VNImageCropAndScaleOption | enum | VNTypes.h:19 | No dedicated public Rust wrapper in the crate. |
| VNImageOptionCIContext | const | VNRequestHandler.h:57 | No dedicated public Rust wrapper in the crate. |
| VNImageOptionCameraIntrinsics | const | VNRequestHandler.h:51 | No dedicated public Rust wrapper in the crate. |
| VNImageOptionProperties | const | VNRequestHandler.h:37 | No dedicated public Rust wrapper in the crate. |
| VNImagePointForFaceLandmarkPoint | function | VNUtils.h:185 | No dedicated public Rust wrapper in the crate. |
| VNImagePointForNormalizedPoint | function | VNUtils.h:47 | No dedicated public Rust wrapper in the crate. |
| VNImagePointForNormalizedPointUsingRegionOfInterest | function | VNUtils.h:63 | No dedicated public Rust wrapper in the crate. |
| VNImageRectForNormalizedRect | function | VNUtils.h:107 | No dedicated public Rust wrapper in the crate. |
| VNImageRectForNormalizedRectUsingRegionOfInterest | function | VNUtils.h:123 | No dedicated public Rust wrapper in the crate. |
| VNImageRegistrationRequest | interface | VNImageRegistrationRequest.h:21 | Concrete translational + homographic registration wrappers are exposed; the abstract base class is not. |
| VNImageRequestHandler | interface | VNRequestHandler.h:65 | Referenced internally in the Swift bridge or Rust internals, but not exposed as a dedicated public Rust wrapper. |
| VNInstanceMaskObservation | interface | VNObservation.h:746 | Mask bytes + instance counts are surfaced, while mask-generation convenience helpers are deferred. |
| VNNormalizedFaceBoundingBoxPointForLandmarkPoint | function | VNUtils.h:169 | No dedicated public Rust wrapper in the crate. |
| VNNormalizedIdentityRect | const | VNUtils.h:23 | No dedicated public Rust wrapper in the crate. |
| VNNormalizedPointForImagePoint | function | VNUtils.h:77 | No dedicated public Rust wrapper in the crate. |
| VNNormalizedPointForImagePointUsingRegionOfInterest | function | VNUtils.h:93 | No dedicated public Rust wrapper in the crate. |
| VNNormalizedRectForImageRect | function | VNUtils.h:137 | No dedicated public Rust wrapper in the crate. |
| VNNormalizedRectForImageRectUsingRegionOfInterest | function | VNUtils.h:153 | No dedicated public Rust wrapper in the crate. |
| VNNormalizedRectIsIdentityRect | function | VNUtils.h:33 | No dedicated public Rust wrapper in the crate. |
| VNObservation | interface | VNObservation.h:42 | Observation payloads are surfaced per-request, but there is no generic base observation wrapper carrying shared metadata like `uuid` / `timeRange`. |
| VNPixelBufferObservation | interface | VNObservation.h:242 | Pixel-buffer-backed results are surfaced as owned byte wrappers (`SegmentationMask`, `InstanceMask`, `OpticalFlowFrame`) rather than a generic `VNPixelBufferObservation` type. |
| VNPoint | interface | VNGeometry.h:27 | No dedicated public Rust wrapper in the crate. |
| VNPoint3D | interface | VNGeometry.h:93 | No dedicated public Rust wrapper in the crate. |
| VNPointsClassification | enum | VNTypes.h:106 | No dedicated public Rust wrapper in the crate. |
| VNRecognizedPoint | interface | VNDetectedPoint.h:44 | No dedicated public Rust wrapper in the crate. |
| VNRecognizedPoint3D | interface | VNRecognizedPoint3D.h:21 | No dedicated public Rust wrapper in the crate. |
| VNRecognizedPoint3DGroupKeyAll | const | VNObservation.h:830 | No dedicated public Rust wrapper in the crate. |
| VNRecognizedPointGroupKeyAll | const | VNObservation.h:660 | No dedicated public Rust wrapper in the crate. |
| VNRecognizedPoints3DObservation | interface | VNObservation.h:838 | 3D recognized points are surfaced as flattened `HumanJoint3D` values. |
| VNRecognizedPointsObservation | interface | VNObservation.h:669 | 2D recognized points are surfaced as flattened joint maps for body / hand / animal pose APIs. |
| VNRecognizedText | interface | VNObservation.h:365 | No dedicated public Rust wrapper in the crate. |
| VNRequest | interface | VNRequest.h:40 | No dedicated public Rust wrapper in the crate. |
| VNRequestFaceLandmarksConstellation | enum | VNDetectFaceLandmarksRequest.h:19 | No dedicated public Rust wrapper in the crate. |
| VNRequestProgressProviding | protocol | VNRequest.h:181 | No dedicated public Rust wrapper in the crate. |
| VNRequestRevisionProviding | protocol | VNRequestRevisionProviding.h:15 | No dedicated public Rust wrapper in the crate. |
| VNRequestTrackingLevel | enum | VNTrackingRequest.h:20 | No dedicated public Rust wrapper in the crate. |
| VNSequenceRequestHandler | interface | VNRequestHandler.h:253 | Referenced internally in the Swift bridge or Rust internals, but not exposed as a dedicated public Rust wrapper. |
| VNStatefulRequest | interface | VNStatefulRequest.h:20 | Concrete stateful requests and tracking sessions are exposed, but there is no standalone base-class handle. |
| VNTargetedImageRequest | interface | VNTargetedImageRequest.h:24 | Concrete targeted-image requests are covered; the abstract base class is not exposed directly. |
| VNTextObservation | interface | VNObservation.h:350 | Exposed through `TextRect`; the top-level text boxes are surfaced while `characterBoxes` stays deferred. |
| VNTrackOpticalFlowRequestComputationAccuracy | enum | VNTrackOpticalFlowRequest.h:19 | No dedicated public Rust wrapper in the crate. |
| VNTrackingRequest | interface | VNTrackingRequest.h:32 | Concrete tracker types are covered; the abstract base class is not exposed directly. |
| VNVector | interface | VNGeometry.h:109 | No dedicated public Rust wrapper in the crate. |
| VNVideoProcessor | interface | VNVideoProcessor.h:75 | No dedicated public Rust wrapper in the crate. |
| VNVideoProcessorCadence | interface | VNVideoProcessor.h:23 | No dedicated public Rust wrapper in the crate. |
| VNVideoProcessorFrameRateCadence | interface | VNVideoProcessor.h:32 | No dedicated public Rust wrapper in the crate. |
| VNVideoProcessorRequestProcessingOptions | interface | VNVideoProcessor.h:57 | No dedicated public Rust wrapper in the crate. |
| VNVideoProcessorTimeIntervalCadence | interface | VNVideoProcessor.h:44 | No dedicated public Rust wrapper in the crate. |
| VNVisionVersionNumber | const | Vision.h:62 | No dedicated public Rust wrapper in the crate. |

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
