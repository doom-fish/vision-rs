#![cfg(all(feature = "optical_flow", feature = "recognize_text"))]

use std::fs;

use apple_vision::recognize_text::_test_helper_render_text_png;
use apple_vision::{
    generate_optical_flow_in_paths, generate_optical_flow_observation_in_paths,
    OpticalFlowAccuracy, VisionError,
};

#[test]
fn optical_flow_is_a_float_displacement_field() -> Result<(), Box<dyn std::error::Error>> {
    let dir = std::env::current_dir()?
        .join("target")
        .join("vision-test-fixtures")
        .join("optical-flow");
    fs::create_dir_all(&dir)?;
    let first = dir.join("first.png");
    let second = dir.join("second.png");
    _test_helper_render_text_png("FLOW", 320, 160, &first)?;
    _test_helper_render_text_png("FLOW ", 320, 160, &second)?;

    let flow = match generate_optical_flow_in_paths(&first, &second, OpticalFlowAccuracy::Low) {
        Err(VisionError::RequestFailed(message))
            if message.contains("failed to analyze motion flow") =>
        {
            eprintln!("skipping: Vision cannot run its motion-flow network here: {message}");
            return Ok(());
        }
        result => result?.expect("optical flow always produces a field"),
    };
    assert!(flow.width() > 0 && flow.height() > 0);
    assert_eq!(flow.vectors().len(), flow.width() * flow.height());
    assert!(flow
        .vectors()
        .iter()
        .all(|[dx, dy]| dx.is_finite() && dy.is_finite()));
    assert_eq!(flow.vector_at(0, 0), flow.vectors().first().copied());

    let observation =
        generate_optical_flow_observation_in_paths(&first, &second, OpticalFlowAccuracy::Low)?
            .expect("optical flow always produces a field");
    assert_eq!(
        (observation.width, observation.height),
        (flow.width(), flow.height())
    );
    assert!(observation.bytes_per_row >= observation.width * 8);
    assert!(
        generate_optical_flow_in_paths("/missing/a.png", &second, OpticalFlowAccuracy::Low)
            .is_err()
    );
    Ok(())
}
