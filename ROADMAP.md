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
