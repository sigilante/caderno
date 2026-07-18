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

## Caveats

**A runaway cell kills the process — but it recovers.** A cell that
allocates without bound exhausts the NockStack, which nockvm reports as a
Rust `panic_any` (`nockvm/src/mem.rs`) rather than a %meme bail, killing
the `serf` thread. Left alone the process stays up and NACKs every poke
forever, bricked but still answering on its port.

`main.rs` installs a panic hook that aborts instead, and sets
`save_interval` to 1s, so the failure mode is now: process dies, a
supervisor restarts it, state comes back from the last checkpoint about a
second old, and the offending cell's source is preserved so it can be
edited. Verified end to end, including that the killer poke is not
replayed into a crash loop.

Both shapes of runaway hit this — one that grows an atom, and a
tail-recursive loop that does not — so in practice runaway cells fail
loudly and recoverably rather than silently and permanently. What this
does *not* do is prevent the denial of service: anyone who can run a cell
can restart the process at will. That needs either a fuel-limited
evaluator in Hoon (vendoring `+mink` without its jet hint and threading a
step counter, at a large interpretation cost) or a nockvm patch making
the interpreter poll its cancel token. Neither is done.

**Serve JS/CSS bundles from `WEB_DIR`, not from Hoon.** The driver's
response path uses `to_bytes_until_nul` and then `copy_from_slice`, so
any response body containing a `0x00` byte panics it — which, with the
panic hook, now takes the process down.
