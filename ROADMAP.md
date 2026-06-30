# Caderno Roadmap

## Immediate (finish Phase 1 deploy)

- [ ] Upload glob: `http://localhost:8080/docket/upload` → caderno desk → `ui/dist/`
- [ ] Verify UI appears in Landscape and title bar / sidebar render correctly

---

## Phase 1 remaining work

### Hoon kernel — cell execution

`desk/app/caderno.hoon` `on-poke` handles `%run-cell` but the body just crashes.
Need to implement:

1. Grab the cell source from notebook state by id
2. Build an evaluation subject (start with `!>(~)` or a persisted subject per notebook)
3. Call `slap` (or `slym` for a clean subject) to evaluate the source cord
4. Catch crashes with `mule`
5. Format the result noun as a `%cell-output` update and `%give %fact` to subscribers
6. Track a per-notebook subject so successive cells build on prior results (Jupyter semantics)

### Shoe session client — North / Dojo kernels

When `kernel` is `north` or `dojo`, `%run-cell` must route through the sole protocol instead of `slap`.

The session client lives in `app/caderno.hoon` and needs:

1. **Subscribe**: on `%set-kernel` to a shoe agent, subscribe `/sole/~our/session-name`
2. **Send input**: poke the shoe agent with `%sole-action [%det ler=clock source=cell-src]` — the vector clock `ler` is `[own=their-clock his=our-clock]`
3. **Collect output**: on `%sole-effect` facts, collect `%blit` effects until a prompt blit arrives (signals completion), then assemble the output and emit a `%cell-output` update
4. **Session discovery**: the `/x/sole/sessions` scry (PR #7379) returns active session names; use this to populate the shoe session to attach to

Key types from `sur/sole.hoon`:
- `sole-clock=[own=@ud his=@ud]`
- `%det` poke: `[%det ler=sole-clock msg=@t]`
- `%blit` effect: list of `blit` — `[%lin p=tape]`, `[%mor ~]`, `[%pro p=tape]` (prompt)

### Frontend — title editable

The title bar input is currently `readOnly`. Wire it up:
- Add `%set-title` action to `sur/caderno.hoon` and `mar/caderno-action.hoon`
- Handle in `on-poke` (update state, broadcast `%state`)
- Remove `readOnly` from `App.tsx` title input and call `actions.setTitle` on blur

---

## Phase 2

### Persistence

Cells are held in agent state (in-memory). On agent crash or upgrade, state is lost.
Options:
- Serialize notebook to a Clay file on each mutation (`%pass %arvo %c %writ`)
- Or keep in-memory and treat it as a scratch pad (simpler, acceptable for v1)

### Multi-notebook

Currently one notebook per ship. To support multiple:
- Notebook keyed by `@ta` name (e.g. `%scratch`, `%project-x`)
- Clay stores one file per notebook: `/notebook/<name>/hoon`
- Eyre subscription path includes notebook id: `/notebook/<name>`
- UI adds a notebook switcher to the sidebar

### PR #7379

[urbit/urbit#7379](https://github.com/urbit/urbit/pull/7379) — adds `/x/sole/sessions` scry to `lib/shoe.hoon`. Until merged:
- Kernel pills for North/Dojo appear dimmed on ships without the patch
- The locally patched `nec/base/lib/shoe.hoon` (committed via `|commit %base`) works on ~nec

Once merged and deployed, kernel discovery works everywhere without any local patch.

---

## Nice-to-haves (Phase 3+)

- **Multiple outputs per cell** — currently only `outputs[0]` is shown
- **Markdown cells** — render `%md` cells with a markdown renderer
- **Cell reordering** — drag-and-drop or move up/down buttons
- **Export** — serialize notebook to `.ipynb`-compatible JSON or a Hoon file
- **Shared notebooks** — subscribe to another ship's `/notebook` path

---

## Phase 4: Distribution

### Philosophy

Notebooks should travel the same paths as Urbit apps. The two-layer model:

1. **Clay desk subscription** — v1 distribution. A ship publishes a `notebooks` desk; other ships subscribe to get a live-synced copy. Caderno's existing Clay sync already writes notebooks as JSON files, so the publishing half is nearly done. Subscribers get the notebook read-only; mutations are local forks.

2. **Gall subscription** — v2, real-time collaboration. Caderno already broadcasts mutations on `/notebook`. A remote ship's caderno subscribes to `/notebook/<name>` on a publisher and receives diffs as they happen. The UI exposes this as "follow" (live mirror) vs. "fork" (take a local copy).

### Notebook Explorer

Discovery is the missing piece. A thin companion agent — separate from caderno — indexes notebook metadata from ships you follow and exposes a browsable directory:

- Subscribes to a `/notebook-index` path on trusted ships (sponsor, contacts, groups)
- Collects `[title tags kernel author]` metadata tuples
- Exposes a scry endpoint that the Caderno UI reads to render the explorer pane
- One-click **subscribe** (Gall follow) or **install** (Clay desk pull)

The explorer mirrors Landscape's app grid: your social graph seeds the trust layer; caderno handles execution once you've chosen a notebook.

### Implementation sketch

```
/app/caderno-explorer.hoon   companion agent; manages remote subscriptions & index
/sur/caderno-index.hoon      shared types: notebook-meta, index-update
/app/caderno.hoon            gains %publish / %unpublish actions + /notebook-index watch path
```

Publish flow: `%publish` action marks a notebook public, writes metadata to `/notebook-index`, and opens the path to remote subscribers.  
Subscribe flow: explorer agent subscribes to a remote `/notebook-index`; user picks a notebook; caderno issues a Clay `%pull` or a Gall subscription depending on whether they want a snapshot or live updates.
