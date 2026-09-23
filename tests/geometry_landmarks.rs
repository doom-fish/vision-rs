use apple_vision::{
    image_point_for_face_landmark_point, image_point_for_normalized_point,
    normalized_face_bounding_box_point_for_landmark_point, NormalizedRect, VisionPoint,
};

fn assert_close(actual: VisionPoint, expected: (f64, f64)) {
    assert!(
        (actual.x - expected.0).abs() < 1e-3 && (actual.y - expected.1).abs() < 1e-3,
        "expected {expected:?}, got ({}, {})",
        actual.x,
        actual.y
    );
}

const FACE: NormalizedRect = NormalizedRect::new(0.25, 0.5, 0.5, 0.25);

#[test]
fn landmark_points_map_into_image_coordinates() {
    for (landmark, expected) in [
        ((0.5, 0.5), (500.0, 500.0)),
        ((0.0, 0.0), (250.0, 400.0)),
        ((1.0, 1.0), (750.0, 600.0)),
        ((0.2, 0.8), (350.0, 560.0)),
    ] {
        let point = VisionPoint::new(landmark.0, landmark.1);
        assert_close(
            image_point_for_face_landmark_point(point, FACE, 1000, 800),
            expected,
        );
    }
}

#[test]
fn landmark_points_map_into_face_bounding_box_coordinates() {
    for (landmark, expected) in [
        ((0.5, 0.5), (250.0, 100.0)),
        ((0.0, 0.0), (0.0, 0.0)),
        ((1.0, 1.0), (500.0, 200.0)),
        ((0.2, 0.8), (100.0, 160.0)),
    ] {
        let point = VisionPoint::new(landmark.0, landmark.1);
        assert_close(
            normalized_face_bounding_box_point_for_landmark_point(point, FACE, 1000, 800),
            expected,
        );
    }
}

#[test]
fn landmark_image_points_agree_with_normalized_point_conversion() {
    let landmark = VisionPoint::new(0.3, 0.6);
    let normalized = VisionPoint::new(
        landmark.x.mul_add(FACE.width, FACE.x),
        landmark.y.mul_add(FACE.height, FACE.y),
    );
    let expected = image_point_for_normalized_point(normalized, 640, 480);
    assert_close(
        image_point_for_face_landmark_point(landmark, FACE, 640, 480),
        (expected.x, expected.y),
    );
}
