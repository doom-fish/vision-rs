#![cfg(feature = "coreml")]

use std::fs;
use std::path::{Path, PathBuf};

use apple_vision::coreml::{CoreMLModel, CoreMLRequest};
use apple_vision::recognize_text::_test_helper_render_text_png;
use apple_vision::VisionError;

fn fixture(name: &str) -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("tests")
        .join("fixtures")
        .join("coreml")
        .join(name)
}

fn owned_compile_dirs() -> Vec<PathBuf> {
    fs::read_dir(std::env::temp_dir())
        .map(|entries| {
            entries
                .filter_map(Result::ok)
                .map(|entry| entry.path())
                .filter(|path| {
                    path.file_name().is_some_and(|name| {
                        name.to_string_lossy().starts_with("apple-vision-coreml-")
                    })
                })
                .collect()
        })
        .unwrap_or_default()
}

#[test]
fn models_compile_once_and_remove_their_compiled_output() -> Result<(), Box<dyn std::error::Error>>
{
    let dir = std::env::current_dir()?
        .join("target")
        .join("vision-test-fixtures")
        .join("coreml");
    fs::create_dir_all(&dir)?;
    let image = dir.join("input.png");
    _test_helper_render_text_png("CORE ML", 128, 128, &image)?;

    assert!(CoreMLRequest::new("/this/model/does/not/exist.mlmodel")
        .classify(&image)
        .is_err());

    let before = owned_compile_dirs();
    let regressor = CoreMLRequest::new(fixture("regressor.mlmodel")).classify(&image);
    assert!(
        matches!(regressor, Err(VisionError::RequestFailed(_))),
        "{regressor:?}"
    );
    assert!(!std::env::temp_dir().join("regressor.mlmodelc").exists());
    assert!(owned_compile_dirs()
        .iter()
        .all(|path| before.contains(path)));

    let model = CoreMLModel::new(fixture("colors.mlmodel"));
    assert!(!model.is_loaded());
    let request = CoreMLRequest::new(model.model_path()).with_model(model.clone());
    let first = match request.classify(&image) {
        Ok(first) => first,
        Err(error) => {
            eprintln!("SKIP: this OS cannot load the Core ML fixture: {error}");
            return Ok(());
        }
    };
    assert!(model.is_loaded());
    let second = CoreMLRequest::new(model.model_path())
        .with_model(model.clone())
        .classify(&image)?;
    for results in [&first, &second] {
        assert!(results
            .iter()
            .all(|result| result.identifier == "red" || result.identifier == "blue"));
        assert!(!results.is_empty());
    }

    let created: Vec<PathBuf> = owned_compile_dirs()
        .into_iter()
        .filter(|path| !before.contains(path))
        .collect();
    assert_eq!(
        created.len(),
        1,
        "the model must be compiled exactly once: {created:?}"
    );
    assert!(created[0].exists());

    let renamed = model.clone().with_input_image_feature_name("image");
    assert!(!renamed.is_loaded());
    assert_eq!(renamed.input_image_feature_name(), Some("image"));

    drop(request);
    assert!(created[0].exists(), "a live clone keeps the compiled model");
    drop(model);
    assert!(
        !created[0].exists(),
        "the last clone removes the compiled model"
    );
    Ok(())
}
