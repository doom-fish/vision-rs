//! API-surface coverage harness for `vision`.
//!
//! Verifies our Vision-framework wrappers against Apple's Swift textual
//! interface. Same regex-driven approach as the other doom-fish crates.

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

fn extract_type_surface(swiftinterface: &str, type_name: &str) -> BTreeSet<String> {
    let needle =
        regex_lite::Regex::new(&format!(r"\b(class|struct|enum)\s+{type_name}\b")).unwrap();
    let Some(start) = needle.find(swiftinterface) else {
        return BTreeSet::new();
    };
    let bytes = swiftinterface.as_bytes();
    let mut depth = 0i32;
    let mut found_open = false;
    let mut end = start.end();
    for (i, &b) in bytes.iter().enumerate().skip(start.end()) {
        match b {
            b'{' => {
                depth += 1;
                found_open = true;
            }
            b'}' => {
                depth -= 1;
                if found_open && depth == 0 {
                    end = i;
                    break;
                }
            }
            _ => {}
        }
    }
    let body = &swiftinterface[start.end()..end];
    let mut out = BTreeSet::new();
    if regex_lite::Regex::new(r"\bpublic\s+(?:convenience\s+)?init\b")
        .unwrap()
        .is_match(body)
    {
        out.insert("init".to_string());
    }
    let func_re = regex_lite::Regex::new(
        r"\bpublic\s+(?:[a-zA-Z@_][\w@()<>=, ]*\s+)?func\s+([a-zA-Z_][A-Za-z0-9_]*)",
    )
    .unwrap();
    for c in func_re.captures_iter(body) {
        out.insert(c[1].to_string());
    }
    let var_re = regex_lite::Regex::new(
        r"\bpublic\s+(?:static\s+|class\s+|final\s+)*(?:var|let)\s+([a-zA-Z_][A-Za-z0-9_]*)",
    )
    .unwrap();
    for c in var_re.captures_iter(body) {
        out.insert(c[1].to_string());
    }
    let case_re = regex_lite::Regex::new(r"\bcase\s+([a-zA-Z_][A-Za-z0-9_]*)").unwrap();
    for c in case_re.captures_iter(body) {
        out.insert(c[1].to_string());
    }
    out
}

fn references_in_bridge(symbols: &BTreeSet<String>) -> BTreeSet<String> {
    let bridge = read_bridge();
    symbols
        .iter()
        .filter(|name| {
            let pattern = format!(r"\b{}", regex_lite::escape(name));
            regex_lite::Regex::new(&pattern).unwrap().is_match(&bridge)
        })
        .cloned()
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

fn read_swiftinterface() -> String {
    let sdk = sdk_root();
    for arch in ["arm64", "arm64e", "x86_64"] {
        let path = sdk.join(format!(
            "System/Library/Frameworks/Vision.framework/\
             Modules/Vision.swiftmodule/{arch}-apple-macos.swiftinterface"
        ));
        if path.exists() {
            return read(&path);
        }
    }
    panic!("no Vision.swiftinterface found in SDK")
}

// ---- Tests ----

#[test]
fn vn_recognize_text_request_coverage() {
    let si = read_swiftinterface();
    let apple = extract_type_surface(&si, "VNRecognizeTextRequest");
    let referenced = references_in_bridge(&apple);
    let omitted: BTreeSet<String> = [
        "init",
        "results",
        "supportedRecognitionLanguages",
        "preferBackgroundProcessing",
        "automaticallyDetectsLanguage",
        "minimumTextHeight",
        "customWords",
        "recognitionLanguages",
        "revision",
        "currentRevision",
        "defaultRevision",
        "supportedRevisions",
        "ResultsStream",
        "Configuration",
    ]
    .into_iter()
    .map(String::from)
    .collect();
    report("VNRecognizeTextRequest", &apple, &referenced, &omitted);
}

#[test]
fn vn_recognized_text_observation_coverage() {
    let si = read_swiftinterface();
    let apple = extract_type_surface(&si, "VNRecognizedTextObservation");
    let referenced = references_in_bridge(&apple);
    let omitted: BTreeSet<String> = [
        "init",
        "supportedRecognitionLanguages",
        "supportedRevisions",
        "defaultRevision",
        "currentRevision",
        "Snapshot",
        "PartiallyGenerated",
    ]
    .into_iter()
    .map(String::from)
    .collect();
    report("VNRecognizedTextObservation", &apple, &referenced, &omitted);
}

#[test]
fn vn_image_request_handler_coverage() {
    let si = read_swiftinterface();
    let apple = extract_type_surface(&si, "VNImageRequestHandler");
    let referenced = references_in_bridge(&apple);
    let omitted: BTreeSet<String> = ["init"].into_iter().map(String::from).collect();
    report("VNImageRequestHandler", &apple, &referenced, &omitted);
}

#[test]
fn vn_recognition_level_coverage() {
    let si = read_swiftinterface();
    let apple = extract_type_surface(&si, "VNRequestTextRecognitionLevel");
    let referenced = references_in_bridge(&apple);
    let omitted: BTreeSet<String> = ["init", "rawValue", "hash", "RawValue"]
        .into_iter()
        .map(String::from)
        .collect();
    report(
        "VNRequestTextRecognitionLevel",
        &apple,
        &referenced,
        &omitted,
    );
}
