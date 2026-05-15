//! API-surface coverage harness for `apple-vision`.
//!
//! Vision is an Obj-C framework with proper headers under
//! `Vision.framework/Headers/`. This harness reads the canonical
//! `@interface TypeName ... @end` block per Apple class and verifies the
//! method/property names we wrap are referenced by our Swift bridge
//! (`swift-bridge/Sources/VisionBridge/Vision.swift`).
//!
//! Every other crate in the doom-fish family follows the same shape
//! (`sdk_root` → `read_header` → `extract_member_surface` → `report`):
//!
//! * **Header-based, C function regex**: `apple-cf` + `videotoolbox` (pure
//!   C frameworks — `IOSurface`, `CoreMedia`, `CoreVideo`, `VideoToolbox`).
//! * **Header-based, Obj-C `@interface`**: `apple-vision` + `speech` +
//!   `avassetwriter` (Obj-C frameworks — Vision, Speech, `AVFoundation`).
//! * **Swift textual-interface only**: `foundation-models` (Swift-only
//!   framework with no Obj-C headers).
//!
//! The Obj-C / Swift-interface approaches share an identical test loop —
//! Apple symbols ∩ bridge references ⇒ wrapped, with per-test
//! `omitted_set([...])` allowlist for explicit non-goals.

#![allow(clippy::cast_precision_loss, clippy::iter_on_single_items)]

use std::collections::BTreeSet;
use std::path::PathBuf;
use std::process::Command;

fn sdk_root() -> PathBuf {
    let out = Command::new("xcrun")
        .args(["--sdk", "macosx", "--show-sdk-path"])
        .output()
        .expect("xcrun");
    assert!(out.status.success());
    PathBuf::from(String::from_utf8(out.stdout).unwrap().trim().to_string())
}

fn read(path: &PathBuf) -> String {
    std::fs::read_to_string(path).unwrap_or_else(|e| panic!("read {}: {e}", path.display()))
}

fn read_bridge() -> String {
    read(
        &PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("swift-bridge/Sources/VisionBridge/Vision.swift"),
    )
}

fn read_header(name: &str) -> String {
    read(&sdk_root().join(format!(
        "System/Library/Frameworks/Vision.framework/Headers/{name}.h"
    )))
}

/// Extract the `@interface TypeName ... @end` block for an Obj-C class.
fn extract_interface(header: &str, type_name: &str) -> String {
    let needle = regex_lite::Regex::new(&format!(r"@interface\s+{type_name}\b")).unwrap();
    let Some(start) = needle.find(header) else {
        return String::new();
    };
    let rest = &header[start.start()..];
    let Some(end_off) = rest.find("@end") else {
        return rest.to_string();
    };
    rest[..end_off].to_string()
}

/// Extract the `typedef NS_ENUM(..., TypeName) { ... };` body for an
/// Obj-C-style C enum so we can collect its `case`-equivalent constants.
fn extract_ns_enum(header: &str, type_name: &str) -> String {
    let needle = regex_lite::Regex::new(&format!(
        r"typedef\s+NS_ENUM\s*\([^,]+,\s*{type_name}\s*\)"
    ))
    .unwrap();
    let Some(start) = needle.find(header) else {
        return String::new();
    };
    let rest = &header[start.end()..];
    let Some(open) = rest.find('{') else {
        return String::new();
    };
    let after_open = &rest[open + 1..];
    let Some(close) = after_open.find('}') else {
        return after_open.to_string();
    };
    after_open[..close].to_string()
}

/// Extract method + property names from an Obj-C `@interface` body.
///
/// - `+/-` methods: keep the first selector segment (before the first `:`).
/// - `@property`: the identifier after the closing `)` of the attribute list.
/// - `getter=...`: the alternate accessor name (e.g. `isAvailable`).
fn extract_member_surface(interface_body: &str) -> BTreeSet<String> {
    let mut out = BTreeSet::new();

    let method_re = regex_lite::Regex::new(
        r"(?m)^\s*[+\-]\s*\([^\)]*\)\s*([A-Za-z_][A-Za-z0-9_]*)",
    )
    .unwrap();
    for c in method_re.captures_iter(interface_body) {
        out.insert(c[1].to_string());
    }

    let prop_re = regex_lite::Regex::new(
        r"(?m)^\s*@property\s*(?:\([^\)]*\))?\s*[^;]*?\b([A-Za-z_][A-Za-z0-9_]*)\s*(?:NS_|API_|;)",
    )
    .unwrap();
    for c in prop_re.captures_iter(interface_body) {
        out.insert(c[1].to_string());
    }

    let getter_re = regex_lite::Regex::new(r"getter\s*=\s*([A-Za-z_][A-Za-z0-9_]*)").unwrap();
    for c in getter_re.captures_iter(interface_body) {
        out.insert(c[1].to_string());
    }

    out
}

/// Extract the bare enumerator names from an `NS_ENUM` body
/// (e.g. `VNRequestTextRecognitionLevelAccurate = 0,` → `Accurate`).
fn extract_ns_enum_cases(enum_body: &str, prefix: &str) -> BTreeSet<String> {
    let pattern = format!(r"\b{}([A-Za-z][A-Za-z0-9]*)\b", regex_lite::escape(prefix));
    let re = regex_lite::Regex::new(&pattern).unwrap();
    re.captures_iter(enum_body)
        .map(|c| c[1].to_string())
        .collect()
}

fn references_in_bridge(symbols: &BTreeSet<String>) -> BTreeSet<String> {
    let bridge = read_bridge();
    let aliases = swift_aliases();
    symbols
        .iter()
        .filter(|name| {
            let pattern = format!(r"\b{}\b", regex_lite::escape(name));
            if regex_lite::Regex::new(&pattern).unwrap().is_match(&bridge) {
                return true;
            }
            // Obj-C → Swift bridged form: `initWithCGImage:` becomes
            // `init(cgImage:)`, written at call sites as `Type(cgImage:`.
            if let Some(swift_form) = aliases.get(name.as_str()) {
                return bridge.contains(swift_form);
            }
            false
        })
        .cloned()
        .collect()
}

/// Obj-C selector → Swift-bridged textual form. Swift drops the leading
/// `init` and lowercases the first letter of the noun.
fn swift_aliases() -> std::collections::BTreeMap<&'static str, &'static str> {
    [
        ("initWithCGImage", "(cgImage:"),
        ("initWithCVPixelBuffer", "(cvPixelBuffer:"),
        ("initWithCIImage", "(ciImage:"),
        ("initWithURL", "(url:"),
        ("initWithData", "(data:"),
        ("initWithCMSampleBuffer", "(sampleBuffer:"),
    ]
    .into_iter()
    .collect()
}

fn report(
    name: &str,
    apple: &BTreeSet<String>,
    ours: &BTreeSet<String>,
    omitted: &BTreeSet<String>,
) {
    let wrapped: BTreeSet<&String> = apple.intersection(ours).collect();
    let missing: BTreeSet<&String> = apple
        .difference(ours)
        .filter(|s| !omitted.contains(*s))
        .collect();
    let coverable = wrapped.len() + missing.len();
    let pct = if coverable == 0 {
        100.0
    } else {
        wrapped.len() as f64 / coverable as f64 * 100.0
    };
    println!(
        "\n=== {name} ===\n  apple={}, omitted={}, coverable={coverable}, wrapped={}, missing={}, pct={pct:.1}%",
        apple.len(),
        omitted.len(),
        wrapped.len(),
        missing.len(),
    );
    if !missing.is_empty() {
        for s in &missing {
            println!("  - {s}");
        }
    }
    assert!(pct >= 100.0, "{name}: {pct:.1}%");
}

fn omitted_set<const N: usize>(items: [&str; N]) -> BTreeSet<String> {
    items.into_iter().map(String::from).collect()
}

// ---- Tests ----

#[test]
fn vn_recognize_text_request_coverage() {
    let header = read_header("VNRecognizeTextRequest");
    let body = extract_interface(&header, "VNRecognizeTextRequest");
    let apple = extract_member_surface(&body);
    let ours = references_in_bridge(&apple);
    // v0.3 wraps recognitionLevel + usesLanguageCorrection. Other tunables
    // (custom words, language hints, results pipeline, multi-revision) land
    // in v0.4.
    let omitted = omitted_set([
        "supportedRecognitionLanguagesForTextRecognitionLevel",
        "supportedRecognitionLanguagesAndReturnError",
        "recognitionLanguages",
        "customWords",
        "automaticallyDetectsLanguage",
        "minimumTextHeight",
        // VNImageBasedRequest / VNRequest base-class accessors — surfaced
        // via the request handler, not directly:
        "results",
        "preferBackgroundProcessing",
        "revision",
        "currentRevision",
        "defaultRevision",
        "supportedRevisions",
    ]);
    report("VNRecognizeTextRequest", &apple, &ours, &omitted);
}

#[test]
fn vn_detect_face_rectangles_request_coverage() {
    let header = read_header("VNDetectFaceRectanglesRequest");
    let body = extract_interface(&header, "VNDetectFaceRectanglesRequest");
    let apple = extract_member_surface(&body);
    let ours = references_in_bridge(&apple);
    let omitted = omitted_set([
        "results",
        "revision",
        "currentRevision",
        "defaultRevision",
        "supportedRevisions",
    ]);
    report("VNDetectFaceRectanglesRequest", &apple, &ours, &omitted);
}

#[test]
fn vn_face_observation_coverage() {
    let header = read_header("VNObservation");
    let body = extract_interface(&header, "VNFaceObservation");
    let apple = extract_member_surface(&body);
    let ours = references_in_bridge(&apple);
    // We surface bbox + confidence + roll/yaw/pitch only. Landmarks,
    // face-capture quality, chin/eye/lip/nose region accessors land in v0.4+.
    let omitted = omitted_set([
        "faceObservationWithRequestRevision",
        "landmarks",
        "faceCaptureQuality",
    ]);
    report("VNFaceObservation", &apple, &ours, &omitted);
}

#[test]
fn vn_recognized_text_observation_coverage() {
    let header = read_header("VNObservation");
    let body = extract_interface(&header, "VNRecognizedTextObservation");
    let apple = extract_member_surface(&body);
    let ours = references_in_bridge(&apple);
    // v0.3 surface: topCandidates + boundingBox (inherited via
    // VNDetectedObjectObservation which is an inheritance chain we read
    // from the base type below).
    let omitted = omitted_set([
        "supportedRecognitionLanguages",
    ]);
    report("VNRecognizedTextObservation", &apple, &ours, &omitted);
}

#[test]
fn vn_image_request_handler_coverage() {
    let header = read_header("VNRequestHandler");
    let body = extract_interface(&header, "VNImageRequestHandler");
    let apple = extract_member_surface(&body);
    let ours = references_in_bridge(&apple);
    // We use the cgImage:options: + cvPixelBuffer:options: init forms.
    // Other ingest paths (CIImage, CMSampleBuffer, NSURL, NSData,
    // NSURL+orientation, file backing) land as needed.
    let omitted = omitted_set([
        // The bare `init` is `NS_UNAVAILABLE` (Apple disallows it) and we
        // never call `VNImageRequestHandler()` — we always use a labelled init.
        "init",
        // Designated-init variants we don't use in v0.3:
        "initWithCIImage",
        "initWithURL",
        "initWithData",
        "initWithCMSampleBuffer",
        // performRequests:onImage* convenience variants — we always go
        // through `[handler perform:[request]]` after constructing.
        "performRequests",
    ]);
    report("VNImageRequestHandler", &apple, &ours, &omitted);
}

#[test]
fn vn_recognition_level_coverage() {
    // VNRequestTextRecognitionLevel is a `typedef NS_ENUM(NSInteger, ...)`
    // declared in VNRecognizeTextRequest.h. Verify the enumerators we
    // surface in our `RecognitionLevel` Rust enum are real.
    let header = read_header("VNRecognizeTextRequest");
    let body = extract_ns_enum(&header, "VNRequestTextRecognitionLevel");
    let apple = extract_ns_enum_cases(&body, "VNRequestTextRecognitionLevel");
    // Bridge passes the enum cases by name (e.g. `.fast`, `.accurate`) —
    // accept either capitalisation since Swift lowercases the first char.
    let bridge = read_bridge();
    let ours: BTreeSet<String> = apple
        .iter()
        .filter(|c| {
            let lower = format!(
                "{}{}",
                c.chars().next().unwrap().to_ascii_lowercase(),
                &c[1..]
            );
            let dotted_lower = format!(".{lower}");
            let dotted_orig = format!(".{c}");
            bridge.contains(&dotted_lower) || bridge.contains(&dotted_orig)
        })
        .cloned()
        .collect();
    let omitted = BTreeSet::new();
    report("VNRequestTextRecognitionLevel", &apple, &ours, &omitted);
}
