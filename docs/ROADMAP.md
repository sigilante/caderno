# Caderno Roadmap

Caderno is a Jupyter-style notebook platform native to Urbit. Cells execute against
a persistent Hoon (or other Nock-targeting language) session; outputs render in the
browser. The document is a Clay file; identity and sharing are the ship.

---

## Architecture decisions (locked)

### Kernels are `%shoe` sessions, not a bespoke eval loop

Each notebook kernel is a running `%shoe`-compliant Gall app. Caderno manages
sessions with those apps, forwards cell source as sole-input, and captures
`sole-effect` output. This makes every language that ships a `%shoe` REPL a
first-class Caderno kernel: `%dojo` (Hoon), `%north`, `%jock`, `%lua`
(~mopfel-winrux's Lua-on-Nock), and any future Nock ISA language.

Caderno does not implement evaluation itself. It is a session broker + output
capturer + notebook document store.

### A1: Incomplete expressions are errors

When a cell source is parsed by the shoe session and the session responds with a
continuation prompt instead of the main ready prompt, Caderno surfaces an error to
the user: **"Incomplete expression — all cells must be syntactically complete."**

It does NOT attempt to auto-complete the expression (that would be A2). It does NOT
wait for a subsequent cell to close the expression (that would be "continuation
mode," which breaks the cell-as-unit model).

Practical consequence for Hoon cells: binding runes (`=/`, `=+`, `=|`, etc.) require
an explicit body. Write `=/  x  42\n.` (`.` returns the augmented subject) rather
than a naked `=/  x  42`. Or use Dojo assignment syntax: `=x  42`.

### Continuation prompt detection (Option A, prompt-tag method)

`%shoe` sessions emit `%pro` (prompt) sole-effects with a `tag` field. The main
ready prompt has a distinct tag from the continuation prompt (the "waiting for more
input" state). Caderno watches for `%pro` effects after sending cell input; a
continuation-tag `%pro` triggers the A1 error; a ready-tag `%pro` signals execution
complete.

### Clay is the document store

Notebooks are `.caderno` files in Clay on the `%caderno` desk. Every save is a Clay
commit; the full revision history is free. The file format is a Hoon noun
(serialized via the `%caderno` mark) and can round-trip to/from Jupyter `.ipynb`
JSON via mark conversion arms.

---

## Phase 0 — Core eval loop, in-memory notebook (current)

**Goal**: prove out the evaluation model and data types before adding persistence or UI.

Scope:
- `/sur/caderno.hoon` — shared type definitions (cell, notebook, action, update)
- `/app/caderno.hoon` — Gall agent:
  - Single in-memory notebook (no Clay persistence yet)
  - Direct `++slap`/`++ream` evaluation against `!>(..add)` standard subject
    (Phase 0 stopgap; migrates to `%shoe` sessions in Phase 1)
  - No cross-cell subject accumulation in Phase 0 — each cell evaluates against
    the base standard library subject. Cells CAN reference names defined earlier
    within the same cell source, but not across cells. Documented limitation.
  - Output types: `%text` (pretty-printed noun) and `%error` (parse or eval failure)
  - Poke/watch interface for cell operations; testable from Dojo without a UI
- `/mar/caderno-action.hoon` — poke mark
- `/desk.bill` — agent manifest

Not in Phase 0: Clay persistence, web UI, cross-cell subject accumulation, shoe
session integration, multi-kernel support.

---

## Phase 1 — `%shoe` kernel integration + Clay persistence

- Replace `++slap` eval with `%shoe` session management against `%dojo`
- Continuous prompt-tag detection for A1 error and cell-complete signal
- Clay persistence: `%caderno` mark, save/load notebooks to desk files
- `%cell-done` / `%cell-error` properly wired from shoe output stream
- Cross-cell subject accumulation: Dojo maintains the session subject across cells
  natively; Caderno gains this for free when eval moves to shoe sessions

---

## Phase 2 — Rich output + minimal web UI

- HTML output type (sandboxed iframe): a cell can produce a `manx` (Hoon HTML AST)
  or raw HTML cord that renders inline
- SVG output type: for simple charts generated in Hoon
- Markdown cell preview rendering
- Minimal React SPA served via Eyre:
  - Cell list, per-cell editor (CodeMirror with Hoon grammar), output panel
  - Run / Run All / Interrupt buttons
  - SSE subscription for streaming cell output
- `desk.docket` for Grid/Landscape integration

---

## Phase 3 — Urbit integration

- Ship-to-ship notebook sharing via Ames (send/receive notebook files)
- Subscribe to another ship's notebook session (read-only live view)
- Scry cells (cell type `%scry`): execute `.^` queries inline in a cell
- Generator cells (cell type `%gen`): run Clay generators
- Khan thread cells (cell type `%thread`): async strands for IO-bound work
- Export to `.ipynb` JSON (Jupyter import/export via mark conversion arm)

---

## Phase 4 — Advanced

- Dependency graph analysis: static free-variable analysis on Hoon cells to build a
  DAG; changing a cell triggers automatic re-execution of dependents
- Multi-kernel notebooks: individual cells declare their kernel (`%hoon`, `%lua`,
  `%north`, etc.); Caderno maintains one shoe session per active kernel per notebook
- Shared noun store: a named namespace that any kernel session can read/write,
  enabling cross-kernel data flow
- Distributed computation: delegate a cell to a remote ship acting as a compute node
- Collaborative multi-ship sessions

---

## Open questions

- Exact `%shoe` wire path and poke/watch marks for opening a Dojo session from
  another Gall app (investigate on ~nec in Phase 1)
- Best initial subject for shoe sessions: Dojo's own initialization vs. `!>(..add)`
- Rendering: `~(sell ut p.vase) q.vase` vs. `(sell vase)` — verify on ~nec
- How `%north` and `%jock` expose shoe interfaces (coordinate with ~sigilante)
