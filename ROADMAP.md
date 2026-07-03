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

- Multiple outputs per cell (only `outputs[0]` is shown); markdown cell
  rendering; cell reordering; `.ipynb`-compatible export.
- **Distribution** — publish notebooks via Clay desk subscription (the export
  half exists; needs the subscribe / import-from-remote half) or a Gall
  `/notebook` follow for live mirroring. A companion `caderno-explorer` agent
  would index notebooks from ships you follow and drive a discovery pane. (See
  git history for the fuller sketch.)
