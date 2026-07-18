use std::env;
use std::error::Error;
use std::fs;
use std::time::Duration;

use nockapp::driver::{make_driver, IODriverFn};
use nockapp::kernel::boot;
use nockapp::noun::slab::NounSlab;
use nockapp::{http_driver, NockApp};
use nockvm::noun::{D, T};
use nockvm_macros::tas;

/// Seconds a single cell may run before the watchdog kills the process.
const DEFAULT_CELL_TIMEOUT: u64 = 15;

/// Seconds to let the kernel boot before the watchdog starts probing.
const WATCHDOG_GRACE: u64 = 20;

/// Abort the process if the kernel stops responding for too long.
///
/// Nock computation here cannot be interrupted. nockvm reads its cancel
/// token in exactly two places -- entry to and exit from `interpret()`
/// (`interpreter.rs:451,1028`) -- and never in the opcode work loop, so
/// `BAIL_INTR` is dead code and `poke_timeout` only ever returns a timeout
/// to the *caller* while the serf thread keeps running. There is no %jinx
/// hint in this runtime, and %bout merely times and logs. So a cell cannot
/// be stopped; the process can only be killed and restarted.
///
/// This is that, done deliberately. Pokes and peeks are serialized through
/// the single serf thread, so a trivial peek cannot complete while a cell
/// is still evaluating. Probing once a second and finding no answer for
/// `timeout` means a cell has been running that long, and we abort. With
/// `save_interval` at 1s and a supervisor, the cost is a restart and about
/// a second of edits.
///
/// This bounds *time*, which is what the stack-exhaustion abort does not:
/// a cell that spins without allocating would otherwise run forever.
/// A legitimately slow cell is also killed -- raise CADERNO_CELL_TIMEOUT
/// if that is a problem, and see the README for the alternative (a
/// fuel-limited evaluator) that bounds work instead of wall clock.
fn watchdog_driver(timeout: Duration) -> IODriverFn {
    make_driver(move |handle| async move {
        tokio::time::sleep(Duration::from_secs(WATCHDOG_GRACE)).await;
        let mut interval = tokio::time::interval(Duration::from_secs(1));
        loop {
            interval.tick().await;

            let mut slab = NounSlab::new();
            let path = T(&mut slab, &[D(tas!(b"watchdog")), D(0)]);
            slab.set_root(path);

            if tokio::time::timeout(timeout, handle.peek(slab)).await.is_err() {
                eprintln!(
                    "caderno: kernel unresponsive for {}s -- a cell is most likely \
                     in a runaway loop, and nockvm cannot interrupt it. Aborting so \
                     the process can be restarted from its checkpoint.",
                    timeout.as_secs()
                );
                std::process::abort();
            }
        }
    })
}

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

    let cell_timeout = env::var("CADERNO_CELL_TIMEOUT")
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(DEFAULT_CELL_TIMEOUT);

    nockapp.add_io_driver(http_driver()).await;
    nockapp
        .add_io_driver(watchdog_driver(Duration::from_secs(cell_timeout)))
        .await;
    nockapp.run().await.expect("Failed to run app");

    Ok(())
}
