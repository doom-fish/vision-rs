//! Generic recognized-point wrappers shared by pose observations.

use std::collections::HashMap;

use crate::request_base::NormalizedRect;

/// A single normalized `VNRecognizedPoint`.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct RecognizedPoint {
    pub x: f64,
    pub y: f64,
    pub confidence: f32,
}

/// A generic `VNRecognizedPointsObservation` wrapper.
#[derive(Debug, Clone, PartialEq)]
pub struct RecognizedPointsObservation {
    pub bounding_box: NormalizedRect,
    pub confidence: f32,
    pub available_keys: Vec<String>,
    pub available_group_keys: Vec<String>,
    pub points: HashMap<String, RecognizedPoint>,
}

impl RecognizedPointsObservation {
    #[must_use]
    pub fn point(&self, key: &str) -> Option<&RecognizedPoint> {
        self.points.get(key)
    }
}

/// A single normalized `VNRecognizedPoint3D` / `VNHumanBodyRecognizedPoint3D`.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct RecognizedPoint3D {
    pub x: f32,
    pub y: f32,
    pub z: f32,
    pub confidence: f32,
}

/// A generic `VNRecognizedPoints3DObservation` wrapper.
#[derive(Debug, Clone, PartialEq)]
pub struct RecognizedPoints3DObservation {
    pub confidence: f32,
    pub available_keys: Vec<String>,
    pub available_group_keys: Vec<String>,
    pub points: HashMap<String, RecognizedPoint3D>,
}

impl RecognizedPoints3DObservation {
    #[must_use]
    pub fn point(&self, key: &str) -> Option<&RecognizedPoint3D> {
        self.points.get(key)
    }
}
