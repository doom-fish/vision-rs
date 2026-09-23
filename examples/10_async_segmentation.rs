fn main() -> Result<(), Box<dyn std::error::Error>> {
    pollster::block_on(async {
        let path = std::env::args().nth(1);
        if let Some(path) = path {
            match apple_vision::async_api::AsyncPersonSegmentation::default()
                .generate_in_path(&path)
                .await?
            {
                Some(mask) => println!("Segmentation mask: {}x{}", mask.width, mask.height),
                None => println!("No segmentation mask"),
            }
        } else {
            println!("No image path supplied — async plumbing OK");
        }
        Ok::<(), Box<dyn std::error::Error>>(())
    })
}
