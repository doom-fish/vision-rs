use std::fs;
use std::path::PathBuf;

use apple_vision::recognize_text::_test_helper_render_text_png;
use apple_vision::{
    detect_contours_observation_in_path, detect_horizon_observation_in_path,
    detect_human_body_pose_3d_observations, detect_human_body_pose_observations_in_path,
    detect_human_hand_pose_observations_in_path, CoreMLImageCropAndScaleOption, CoreMLModel,
    CoreMLRequest, ImageAlignmentObservation, ImageBasedRequest, ImageRegistrationRequest,
    NormalizedRect, PixelBufferObservation, StatefulRequest, TargetedImageRequest,
    TextRectanglesRequest, TrackingLevel, TrackingRequest, TranslationalAlignment,
};
use apple_vision::ContourOptions;

fn fixtures_dir() -> Result<PathBuf, Box<dyn std::error::Error>> {
    let dir = std::env::current_dir()?
        .join("target")
        .join("vision-test-fixtures")
        .join("request-observations");
    fs::create_dir_all(&dir)?;
    Ok(dir)
}

#[test]
fn request_and_observation_wrappers_smoke() -> Result<(), Box<dyn std::error::Error>> {
    let dir = fixtures_dir()?;
    let image = dir.join("vision.png");
    _test_helper_render_text_png("VISION", 960, 540, &image)?;

    let image_based = ImageBasedRequest::new()
        .with_region_of_interest(NormalizedRect::new(0.1, 0.1, 0.8, 0.8))
        .with_prefer_background_processing(true)
        .with_uses_cpu_only(true)
        .with_revision(1);
    assert!((image_based.region_of_interest().unwrap().width - 0.8).abs() < f64::EPSILON);

    let targeted = TargetedImageRequest::new(&image);
    assert_eq!(targeted.targeted_image_path(), image.as_path());

    let stateful = StatefulRequest::new()
        .with_frame_analysis_spacing_seconds(0.5)
        .with_minimum_latency_frame_count(2);
    assert_eq!(stateful.minimum_latency_frame_count(), 2);

    let tracking = TrackingRequest::new()
        .with_tracking_level(TrackingLevel::Accurate)
        .with_last_frame(true)
        .with_input_observation(NormalizedRect::new(0.2, 0.2, 0.4, 0.4));
    assert!(tracking.is_last_frame());

    let registration = ImageRegistrationRequest::new(&image);
    assert_eq!(
        registration.targeted_image_request().targeted_image_path(),
        image.as_path()
    );

    let request = TextRectanglesRequest::new()
        .with_image_based_request(image_based.clone())
        .with_report_character_boxes(true);
    let text_observations = request.perform(&image)?;
    assert!(!text_observations.is_empty());

    let contours = detect_contours_observation_in_path(&image, ContourOptions::default())?;
    assert_eq!(contours.top_level_contour_count, contours.top_level_contours.len());

    let horizon = detect_horizon_observation_in_path(&image)?;
    if let Some(observation) = horizon {
        let transform = observation.transform_for_image(960.0, 540.0);
        assert!(transform.a.is_finite());
    }

    let _body_poses = detect_human_body_pose_observations_in_path(&image)?;
    let _hand_poses = detect_human_hand_pose_observations_in_path(&image, 2)?;
    let _body_poses_3d = detect_human_body_pose_3d_observations(&image)?;

    let coreml_request = CoreMLRequest::new("model.mlmodel")
        .with_model(CoreMLModel::new("model.mlmodel").with_input_image_feature_name("image"))
        .with_image_based_request(image_based)
        .with_image_crop_and_scale_option(CoreMLImageCropAndScaleOption::ScaleFit);
    assert_eq!(
        coreml_request.image_crop_and_scale_option(),
        CoreMLImageCropAndScaleOption::ScaleFit
    );
    assert_eq!(coreml_request.model().input_image_feature_name(), Some("image"));

    let pixel_buffer = PixelBufferObservation::new(2, 2, 2, vec![0, 1, 2, 3])
        .with_feature_name("mask");
    assert_eq!(pixel_buffer.as_bytes(), &[0, 1, 2, 3]);
    assert_eq!(pixel_buffer.feature_name.as_deref(), Some("mask"));

    let alignment =
        ImageAlignmentObservation::translational(TranslationalAlignment { tx: 0.0, ty: 0.0 });
    match alignment {
        ImageAlignmentObservation::Translational(value) => {
            assert!(value.tx.abs() < f64::EPSILON);
        }
        ImageAlignmentObservation::Homographic(_) => unreachable!(),
    }

    Ok(())
}
