# caderno

A Hoon notebook for Urbit — Jupyter-style cells backed by a live ship.

## Kernels

- **Hoon** — built-in, evaluates cells directly via `slap`
- **North** (`%north`) — Forth REPL via shoe session
- **Dojo** (`%dojo`) — standard Dojo REPL via shoe session
- **Other** — any agent built on `/lib/shoe` can be used as a kernel

> **Note:** Kernel discovery (probing which shoe agents are running) requires
> [urbit/urbit#7379](https://github.com/urbit/urbit/pull/7379) to be merged
> and deployed to your ship. Until then, `%north` and `%dojo` pills appear
> dimmed but can still be selected manually — connection errors surface as
> cell output.

## Setup

### Development

```
cd ui
npm install
SHIP_URL=http://<your-ship>:<port> npm run dev
```

Then in your ship:

```
|install our %caderno
```

### Desk dependencies

The caderno desk requires the following files from base:

- `lib/sole.hoon`, `sur/sole.hoon` — sole protocol
- `mar/json.hoon` — JSON mark (from `%yard`)

And from `%landscape`:

- `lib/docket.hoon`, `mar/docket-0.hoon` — docket support

## Architecture

- `desk/app/caderno.hoon` — Gall agent. Manages notebook state, routes `%hoon` cells through `slap`, delegates shoe kernels via sole session client.
- `desk/sur/caderno.hoon` — shared types (`notebook`, `cell`, `action`, `update`)
- `ui/src/` — Vite + React frontend communicating via Eyre channel API
