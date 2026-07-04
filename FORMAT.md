# The `cnb` notebook format

This specifies the caderno notebook format — **cnb** (Caderno NoteBook): what a
notebook *is*, its JSON encoding, and the versioning policy. It is the contract
shared by the caderno agent, the `tools/import-docs` converter, hand-edited seed
files, the Clay log, and notebooks that travel between ships over publish/follow.

The source of truth is `desk/sur/caderno.hoon` (the Hoon types) and the
`*-to-json` / `json-to-*` arms in `desk/app/caderno.hoon` (the encoding). This
document tracks them — if they disagree, the code wins; fix this file.

## Data model

A **notebook** is an ordered list of cells, plus a title and a kernel
(`sur/caderno.hoon`):

```
+$  notebook  [cells=(list cell) kernel=@tas title=@t]
+$  cell      [id=@ud type=?(%code %markdown) source=@t outputs=(list output) exec-count=(unit @ud)]
+$  output    $%([%text data=@t] [%error ename=@t evalue=@t])
```

## JSON encoding

Notebooks are exchanged and stored as JSON. A notebook object:

```json
{
  "nbformat": 1,
  "title":    "…",
  "kernel":   "hoon",
  "cells":    [ <cell>, … ]
}
```

| field | JSON type | meaning |
|-------|-----------|---------|
| `nbformat` | number | schema version (see [Versioning](#versioning)). Absent ⇒ `1`. |
| `title` | string | notebook title. |
| `kernel` | string | `"hoon"` (in-process) or a shoe agent name, e.g. `"north"`. |
| `cells` | array | ordered cells. |

A **cell** object:

```json
{
  "id":         1,
  "type":       "code",
  "source":     "…",
  "exec_count": null,
  "outputs":    [ <output>, … ]
}
```

| field | JSON type | meaning |
|-------|-----------|---------|
| `id` | number | unique within the notebook; stable cell identity. |
| `type` | string | `"code"` or `"markdown"`. |
| `source` | string | code cell → kernel input; markdown cell → markdown (below). |
| `exec_count` | number \| null | execution count, or `null` if never run. |
| `outputs` | array | cell outputs; empty for markdown cells. |

An **output** object is one of:

```json
{ "text": "…" }                       // success
{ "ename": "…", "evalue": "…" }        // error: name, value
```

## Markdown subset

`markdown` cells render a deliberate subset (`renderMd` in `NotebookView.tsx`):

- Headings `#`/`##`/`###`, paragraphs, `-`/`*` and `1.` lists, `>` blockquotes.
- Inline **bold**, *italic*, `` `code` ``, and `[links](…)`.
- Fenced code blocks.
- **Tables** — a `|header|` row, a `|---|---|` separator, then `|body|` rows.
- **Images** — `![alt](src)`.

Because notebook source is attacker-authored (a followed/forked notebook carries
another ship's text, rendered via `dangerouslySetInnerHTML`), `src` and link
hrefs are scheme-restricted:

- **Image `src`**: raster data URIs (`data:image/png|jpeg|gif|webp`), `https:`
  URLs, and site-relative paths. **`data:image/svg+xml` is blocked** (SVG is
  executable), as is every other scheme.
- **Link href**: `http(s):`, `mailto:`, or relative only.

Data-URI images are self-contained, so they travel embedded with a published
notebook; `https:` images are fetched by the reader.

## Number encoding

Integers (`id`, `exec_count`, `nbformat`) are produced with `scot %ud`, which
renders values ≥ 1000 with dot separators (e.g. `1.000`) — **not** standard JSON
number syntax. Readers must tolerate this: caderno's `json-numb` strips dots
before parsing. Third-party producers should emit plain digits; the reader
accepts both.

## Identity

- **Cell id** — an integer, unique within a notebook (above).
- **Notebook id** — a `@ta` (knot) that keys the notebook in a ship's state and
  in Clay paths. It is **not** inside the notebook object; the container carries
  it:
  - **Seed files** (`desk/seed/<id>.json`) — id is the **filename**; the file is
    a bare notebook object.
  - **Clay log & wire** — id rides in a `state` envelope:
    `{ "state": { "id": "<id>", "nb": <notebook> } }`.

## Representations & transport

| where | shape | mark |
|-------|-------|------|
| agent state | the `notebook` Hoon type | — |
| UI / channel facts | update JSON on `/notebook` (incl. `{state:{id,nb}}`) | `%json` |
| edit pokes | action JSON | `cnb-action` |
| Clay log (`%caderno-log`) | `{state:{id,nb}}` per `/notebook/<id>.txt` | `txt` |
| seed files | bare notebook object per `/seed/<id>.json` | `json` |
| publish / follow | `{state:{id,nb}}` fact over Ames | `%json` |

Facts are currently raw `%json`; a typed `cnb-update` mark is roadmapped.

## Versioning

`nbformat` is a single integer, currently **1**.

- **Producers** stamp the current `nbformat` into every notebook.
- **Readers** gate on it: a notebook whose `nbformat` is **greater** than the
  reader understands is **rejected**, not misparsed — on import it is skipped,
  and a follow of it is refused. A missing `nbformat` is treated as `1`
  (pre-versioning legacy).
- **Bump `nbformat`** when the notebook or cell shape changes incompatibly; add a
  branch in `json-to-notebook` / `json-to-cell` for the old version while
  continuing to produce the new one.

The version rides *with* the notebook (wire, Clay, seed), so a newer publisher
and an older follower degrade safely rather than corrupt.

## `.ipynb` kinship

The shape is deliberately close to Jupyter's `nbformat`: a versioned envelope,
cells carrying `source` / `outputs` / `exec_count`, and text/error outputs. This
anchors the roadmapped `.ipynb` import/export — the mapping is largely
mechanical (Jupyter `cell_type` ⇆ `type`, a multi-line `source` array ⇆ a single
string, rich output MIME bundles ⇆ caderno's `{text}` / `{ename,evalue}`).

## Example

```json
{
  "nbformat": 1,
  "title": "Hello",
  "kernel": "hoon",
  "cells": [
    { "id": 1, "type": "markdown", "source": "# Hello\n\nAdd two numbers:", "exec_count": null, "outputs": [] },
    { "id": 2, "type": "code", "source": "(add 2 2)", "exec_count": 1, "outputs": [ { "text": "4" } ] }
  ]
}
```
