# Caderno Roadmap

Status as of the sole-sessions / kernel-picker / Clay-import work.

## Done

- **Hoon kernel** — cells evaluate in-process via `slap` against a persisted
  per-notebook subject (Jupyter-style accumulation); errors caught with `mule`.
- **Shoe kernels** — `%north` (and any `/lib/shoe` agent that implements the
  `%eval-command` poke) driven over a sole session: subscribe
  `/sole/[our]/[ses]`, poke `%eval-command`, collect `%sole-effect` output until
  the `%pro` prompt signals completion.
- **Multi-notebook** — notebooks keyed by `@ta` id, switcher in the index.
- **Editable title**, reset-subject, cell insert/delete/type, run-all (hoon).
- **Kernel discovery** — `[%x %agents ~]` scry lists running agents across
  desks; the UI probes each with the shoe `/x/sole/sessions` scry and offers the
  shoe agents (minus a blacklist, e.g. `%shoe`) plus the in-process `hoon`
  kernel. Nothing is hardcoded — a kernel appears only if detected.
- **Sessions panel** — live view of the kernel agent's caderno-owned sessions.
- **Host ship** shown in the header; notebooks sorted alphabetically in the
  index.
- **Clay persistence** — a `%caderno-log` desk. `MOUNT` creates + mounts it,
  `COMMIT` writes every notebook as JSON text, and `IMPORT` (`%import-log`)
  reads those files back into agent state. Round-trips title / kernel / cells.

## Remaining for launch

- [ ] **Upload glob** — publish `ui/dist/` to the caderno desk and verify it
  renders in Landscape.
- [ ] **Kernel claims** — caderno drives kernels via the `%eval-command` poke,
  which is north-specific (not part of upstream `lib/shoe`, and dojo is
  drum-based, not shoe). Either implement the generic `%sole-action` typing path
  so "any shoe agent" / "Dojo" actually evaluate, or scope the README and picker
  to `hoon` + `north`. **The README currently overclaims.**
- [ ] **`run-all` on shoe kernels** — emits a placeholder error; either
  implement it (sequential eval over the session) or hide the button for
  non-hoon kernels.
- [ ] **upstream [urbit#7379](https://github.com/urbit/urbit/pull/7379)** — the
  `/x/sole/sessions` scry + `%sole-sessions` mark must merge and deploy for
  kernel discovery to work on ships without the local patch.

## Known gaps / parked

- **Shoe session teardown** — `lib/shoe` never prunes `soles` on `%leave`, so
  sessions accumulate and `/x/sole/sessions` lists dead ones. The fix is a
  base-dev `on-leave` prune (raised with core-dev). This blocks per-notebook
  sessions (`ses=caderno-<id>`), which are parked until it lands.
- **Import overwrites** — `%import-log` overrides in-memory notebooks that share
  an id with the log; unsaved edits to an open notebook are lost on import.
- **Number round-trip** — `scot %ud` dot-separates values ≥ 1000; `json-numb`
  strips the dots on import, but the exported JSON is technically non-standard
  for large ids / exec-counts.

## Post-launch

Slated from the Gnome/Angel code review:

- **`cnb-update` mark** — updates are currently hand-serialized to `%json` on the
  agent side and hand-parsed on the TS side (~130 lines, no shared source of
  truth). Introduce a real `cnb-update` mark owning `+$update ⇆ json`, and have
  `broadcast`/`pub-fact`/`catalog-fact` give facts with it. Makes the protocol
  symmetric with `cnb-action` and extensible. (The UI already *named* this mark.)
- **Fork provenance** — `notebook` has no origin field, so "forked from ~ship/id"
  is unrepresentable. Add `origin=(unit [who=@p id=@t nbformat=@ud])`, stamp it on
  fork, surface a "forked from ~ship" ribbon. Foundation for the explorer.
- **Generic `%sole-action` kernel driver** — to make "any `/lib/shoe` agent" a
  real kernel without each agent implementing `%eval-command`: drive the sole
  command line generically (`%det` to type source, `%ret` to submit, collect
  `%sole-effect` until `%pro`). Alternatively, upstream `%eval-command` into
  `/lib/shoe`.
- **Sanitize fork ids** — a hostile publisher can publish an id with illegal knot
  bytes; a fork inherits it and a later `%commit-log` can bail. Guard the id when
  forking.
- Minor/known: split the shared `counter` (cell-ids vs exec-counts); async shoe
  output lands on the active notebook at result-time (switch-during-eval edge);
  brittle `%mount-log` base-mar reads.

Product:

- Multiple outputs per cell (only `outputs[0]` is shown); markdown cell
  rendering; cell reordering; `.ipynb`-compatible export.
- **Distribution / explorer** — a companion `caderno-explorer` agent that indexes
  published notebooks from ships you follow (contacts/groups as the trust layer)
  into one browsable directory — the network-discovery layer above by-ship
  lookup. Per-notebook ACLs (the `on-watch` gate already localizes the check).
