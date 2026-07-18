# caderno-nockapp

A NockApp port of the %caderno executable notebook platform: the same notebook
model, served from a single binary instead of an Urbit ship.

**Status: Phase 0 spike.** This currently runs a bare Hoon evaluator over HTTP,
not a notebook. Its purpose is to prove the load-bearing assumptions before the
port proper. It does.

## Building

Requires `hoonc` (from `nockup`) and the pinned nightly in `rust-toolchain.toml`.

```bash
hoonc hoon/app/app.hoon hoon    # -> out.jam
cargo build --release
./target/release/caderno        # listens on 127.0.0.1:8080
```

The kernel is read from `out.jam` in the working directory at runtime, so
re-run `hoonc` after any Hoon change. Note `hoonc` prints a success banner even
when the compile failed — the real signal is that `out.jam` was rewritten.

## Trying it

```bash
curl -s -XPOST localhost:8080/eval -d '(add 2 2)'
curl -s -XPOST localhost:8080/eval -d '(sort ~[3 1 2] lth)'
curl -s -XPOST localhost:8080/eval -d '=/(x 7 (mul x x))'
curl -s -XPOST localhost:8080/eval -d '-'          # prior result, via +slop
curl -s -XPOST localhost:8080/eval -d '(dec 0)'    # crash, trapped by +mule
curl -s -XPOST localhost:8080/reset                # drop accumulated subject
```

## What the spike established

- **`ream`/`slap`/`sell`/`slop`/`mule` all work in a hoonc-compiled kernel.**
  caderno's `+eval-hoon` (`desk/app/caderno.hoon:66`) ports over unchanged.
- **`+mule` reliably traps user-code crashes**, including `!!` and `(dec 0)`,
  returning a `tang` rather than killing the kernel.
- **Subject accumulation works.** `(slop result subject)` puts cell N's value at
  `-` for cell N+1, exactly as on Urbit.
- **`!>(..add)` is the wrong subject.** It climbs to the *chapter core
  containing `add`*, which sees only earlier chapters of `hoon.hoon` — `sort`,
  `turn` and friends are out of scope. `!>(.)` captures the full stdlib. This
  is likely a latent bug in the Urbit caderno too, worth checking there.
- **JSON needs no vendoring.** `+$json` lives in `lull.hoon` and
  `en:json:html` / `de:json:html` in `zuse.hoon`; both are available as nockup
  packages (`urbit/lull`, `urbit/zuse`).

## Known blocker: runaway cells wedge the app permanently

A cell that loops while allocating exhausts the NockStack, which is a Rust
`panic_any` in `nockvm/src/mem.rs`, not a `%meme` bail. The `serf` thread dies;
the process stays up; **every subsequent poke NACKs forever**. Reproduced:

```bash
curl -s -m 5 -XPOST localhost:8080/eval -d '=/(f |=(a=@ $(a +(a))) (f 0))'
# ... thereafter every /eval returns HTTP 400, permanently
```

This is worse than a crash operationally — the process never exits, so a
supervisor won't restart it, and `GET /` keeps returning 200 from the response
cache, so a naive health check still passes.

Non-allocating infinite loops are a second, distinct case: `poke_timeout`
returns `Timeout` to the Rust caller while the serf thread spins at 100% CPU
forever, because `BAIL_INTR` is defined in `nockvm`'s interpreter and never
used — the opcode loop never polls the cancel token.

Both must be addressed before this is usable by anyone who can type into a
cell.
