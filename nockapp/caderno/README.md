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

Everything is POST. The http driver's response cache is consulted only
for GET, so keeping the API on POST sidesteps it (see Caveats).

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

**A runaway cell wedges the app permanently.** A cell that loops while
allocating exhausts the NockStack, which is a Rust `panic_any` in
`nockvm/src/mem.rs` rather than a `%meme` bail. The `serf` thread dies,
the process stays up, and every subsequent poke NACKs forever:

```bash
curl -m 5 -XPOST localhost:8080/api/action \
  -d '{"update-source":{"id":1,"src":"=/(f |=(a=@ $(a +(a))) (f 0))"}}'
# then run that cell; thereafter every request 400s, permanently
```

Because the process never exits, a supervisor will not restart it. A
non-allocating infinite loop is a distinct case: 100% CPU forever, since
`BAIL_INTR` is defined in nockvm's interpreter and never used — the
opcode loop never polls the cancel token. **Do not expose this to input
you do not trust** until one of those is fixed.

**A POST response can be served for `GET /`.** The driver's response
cache is keyed on URI alone with no per-response opt-out, and a non-GET
200 can land in the GET cache. `main.rs` forces `EXPIRE_CACHE=1`, which
bounds the staleness window to one second rather than the process
lifetime; it does not eliminate it. Fixing it properly means patching the
driver to key on method.

**Serve JS/CSS bundles from `WEB_DIR`, not from Hoon.** The driver's
response path uses `to_bytes_until_nul` and then `copy_from_slice`, so
any response body containing a `0x00` byte panics it.
