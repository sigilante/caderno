use std::env;
use std::error::Error;
use std::fs;

use nockapp::kernel::boot;
use nockapp::{http_driver, NockApp};

/// Make any panic fatal to the process.
///
/// Evaluating a cell that allocates without bound exhausts the NockStack,
/// which nockvm reports as a Rust `panic_any` rather than a %meme bail
/// (`nockvm/src/mem.rs`). That kills the `serf` thread but not the
/// process: the runtime stays up and NACKs every subsequent poke forever,
/// so the notebook is bricked while still answering on its port. Nothing
/// exits, so no supervisor restarts it, and a naive health check passes.
///
/// We cannot stop the panic from here without patching nockvm, but we can
/// stop it from being silent. Aborting turns a permanent, invisible wedge
/// into a crash the supervisor can restart from the last checkpoint,
/// losing only the poke that caused it.
fn abort_on_panic() {
    let default_hook = std::panic::take_hook();
    std::panic::set_hook(Box::new(move |info| {
        default_hook(info);
        let thread = std::thread::current();
        eprintln!(
            "caderno: fatal panic on thread {:?}; aborting so the process can be \
             restarted from its checkpoint rather than wedging",
            thread.name().unwrap_or("<unnamed>")
        );
        std::process::abort();
    }));
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    abort_on_panic();

    let mut cli = boot::default_boot_cli(false);

    // A graceful shutdown checkpoints on the way out, but an abort does not,
    // so everything since the last periodic save is lost -- and the default
    // interval is two minutes, which for a notebook is a whole working
    // session. Since abort_on_panic makes aborts a normal occurrence rather
    // than an exotic one, save often enough that a crash costs a second of
    // edits. The state is a handful of notebooks, so the write is cheap.
    cli.save_interval = 1_000;

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
