# caderno-nockapp

A NockApp port of the %caderno executable notebook platform: the same
notebook model and the same Hoon evaluator, served from a single binary
instead of an Urbit ship.

**Status: working kernel, no UI yet.** Notebooks, cells, Hoon evaluation
with an accumulating subject, and a JSON API all work and persist across
restarts. The React UI in `../../ui` has not been pointed at it.

## Building

Requires `hoonc` and `nockup`, plus the nightly pinned in
`rust-toolchain.toml`.

```bash
nockup package install          # from the parent dir; fetches urbit/zuse + lull
hoonc hoon/app/app.hoon hoon    # -> out.jam
cargo build --release
./target/release/caderno        # listens on 127.0.0.1:8080
```

The kernel is read from `out.jam` in the working directory at *runtime*,
so re-run `hoonc` after any Hoon change. `hoonc` prints a success banner
even when the compile failed — the real signal is that `out.jam` was
rewritten.

## API

Everything is POST, and every API response is **201, not 200**. That is
load-bearing: the driver caches responses in a single global slot (not a
map -- there is no URI key), writing it on any effect whose status is
exactly 200 and reading it on any GET. A 200 from `POST /api/state` would
therefore become the response to `GET /`. Answering 201 keeps the API out
of that slot entirely.

```bash
curl -XPOST localhost:8080/api/state
curl -XPOST localhost:8080/api/action -d '{"run-cell":{"id":1}}'
curl -XPOST localhost:8080/api/action -d '{"run-all":true}'
curl -XPOST localhost:8080/api/action -d '{"insert-cell":{"after":1,"type":"code"}}'
curl -XPOST localhost:8080/api/action -d '{"update-source":{"id":1,"src":"(add 2 2)"}}'
curl -XPOST localhost:8080/api/action -d '{"delete-cell":{"id":1}}'
curl -XPOST localhost:8080/api/action -d '{"set-cell-type":{"id":1,"type":"markdown"}}'
curl -XPOST localhost:8080/api/action -d '{"set-title":{"title":"Hoon School"}}'
curl -XPOST localhost:8080/api/action -d '{"reset-subject":true}'
curl -XPOST localhost:8080/api/action -d '{"new-notebook":true}'
curl -XPOST localhost:8080/api/action -d '{"switch-notebook":{"id":"main"}}'
curl -XPOST localhost:8080/api/action -d '{"delete-notebook":{"id":"nb-105"}}'
```

The action envelope is the one `desk/mar/cnb-action.hoon` accepts, so
existing UI payloads carry over. Every action responds with a full state
snapshot rather than an incremental update: there is no Eyre channel
here, and at notebook scale a snapshot is cheap and removes a class of
client/server drift.

## What differs from the Urbit desk

| Urbit | here |
|---|---|
| Gall agent + Eyre channel facts | HTTP request/response, full snapshots |
| `%cnb-action` mark | `+json-to-action`, same JSON envelope |
| Clay `%caderno-log` mirror | NockApp checkpointing (state persists free) |
| `/seed/*.json` scried from Clay | one starter notebook in `+blank-notebook` |
| shoe/sole remote kernels | **dropped** — no Gall agents to delegate to |
| publish / follow over Ames | **dropped** — no Ames |
| `!>(..add)` subject | `!>(.)` — see below |

`!>(..add)` climbs to the chapter core containing `+add`, which sees only
earlier chapters of `hoon.hoon`; `+sort` and `+turn` are out of scope
under it. `!>(.)` captures the whole stdlib. The Urbit desk uses the
`..add` form and appears to have the same gap.

`+$json` is not in the NockApp ambient subject, and `zuse.hoon` will not
compile standalone, so `hoon/lib/json.hoon` vendors `+$json` from
`lull.hoon` and `++json:html` from `zuse.hoon` @k409.

## Bounding runaway cells

**Nock computation here cannot be interrupted.** nockvm reads its cancel
token in exactly two places — entry to and exit from `interpret()`
(`interpreter.rs:451,1028`) — and never in the opcode work loop, so
`BAIL_INTR` is dead code and `poke_timeout` returns a timeout to the
caller while the serf thread keeps running. There is no `%jinx` hint in
this runtime, and `%bout` only times and logs. A cell cannot be stopped;
the process can only be killed and restarted.

So that is what happens, deliberately, by two mechanisms:

- **`abort_on_panic`** — a cell that allocates without bound exhausts the
  NockStack, which nockvm reports as a Rust `panic_any`
  (`nockvm/src/mem.rs`) rather than a %meme bail, killing the `serf`
  thread. Left alone the process stays up and NACKs every poke forever,
  bricked but still answering on its port. The panic hook aborts instead.
- **`watchdog_driver`** — pokes and peeks are serialized through the one
  serf thread, so a trivial peek cannot complete while a cell is running.
  The watchdog probes once a second; no answer for `CADERNO_CELL_TIMEOUT`
  seconds (default 15) means a cell has been running that long, and it
  aborts. This is the *time* bound: a cell that spins without exhausting
  memory would otherwise run forever.

With `save_interval` at 1s, a crash costs a restart and up to a second of
edits. Verified end to end: with a 5s limit the watchdog fires at ~5s,
ahead of stack exhaustion; the process restarts clean with no crash loop
from replay, state returns from the checkpoint, and evaluation works
afterwards.

Caveats on the caveats:

- **The edit that caused the crash may or may not survive.** It depends
  on whether a checkpoint landed between the edit and the run. Both
  outcomes observed.
- **A legitimately slow cell is killed too.** Raise
  `CADERNO_CELL_TIMEOUT` if that bites.
- **The denial of service remains, by design.** Anyone who can run a
  cell can restart the process at will. This is intended to run locally,
  where the person who can type into a cell is the person who owns the
  process, so a runaway cell costs them a restart and nothing else. Do
  not expose it publicly without bounding work as well as time.
- **The first `WATCHDOG_GRACE` seconds after boot are unprobed**, so the
  kernel is not held to the limit while it is still starting up.

Bounding *work* rather than wall clock would mean a fuel-limited
evaluator: vendoring `+mink` without its `~%` hint and threading a step
counter, so `eval-hoon` runs the compiled formula under it instead of
`slap`'s `.*`. Entirely doable on our side, but dropping the jet means
user code becomes interpreted Nock-in-Nock — `add` would run the Hoon
decrement loop — so it wants to be a mode, not the default. Not done.

## Other caveats

**Serve JS/CSS bundles from `WEB_DIR`, not from Hoon.** The driver's
response path uses `to_bytes_until_nul` and then `copy_from_slice`, so
any response body containing a `0x00` byte panics it — which, with the
panic hook, now takes the process down.
