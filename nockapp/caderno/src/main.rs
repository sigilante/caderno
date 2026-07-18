use std::env;
use std::error::Error;
use std::fs;

use nockapp::kernel::boot;
use nockapp::{http_driver, NockApp};

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    let cli = boot::default_boot_cli(false);
    boot::init_default_tracing(&cli);

    // The http driver's response cache is keyed on URI alone, with no
    // per-response opt-out, and it defaults to caching forever. Worse, a
    // non-GET 200 can land in the GET cache: POST /api/state will start
    // being served for GET /. Bounding the TTL to one second is the only
    // lever the driver exposes, so the staleness window is one second
    // rather than the process lifetime.
    //
    // Do not set this to 0 -- the driver builds a tokio interval from it,
    // and Duration::ZERO panics the cache-invalidation task.
    if env::var("EXPIRE_CACHE").is_err() {
        env::set_var("EXPIRE_CACHE", "1");
    }

    let kernel = fs::read("out.jam").map_err(|e| format!("Failed to read out.jam: {}", e))?;

    let mut nockapp: NockApp = boot::setup(&kernel, Some(cli), &[], "caderno", None)
        .await
        .map_err(|e| format!("Kernel setup failed: {}", e))?;

    nockapp.add_io_driver(http_driver()).await;
    nockapp.run().await.expect("Failed to run app");

    Ok(())
}
