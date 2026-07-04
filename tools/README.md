# caderno tools

Build-time helpers. These run on your machine (Node ≥ 18, no dependencies) and
are **not** part of the shipped desk.

## `import-docs.mjs` — Markdown → seed notebooks

Turn a Markdown source tree into caderno seed notebooks (`desk/seed/*.json`),
which `on-init` loads on a fresh install. Intended for porting docs — e.g. a
local checkout of [github.com/urbit/docs.urbit.org](https://github.com/urbit/docs.urbit.org).

```sh
# auto-import every *.md in a directory (id = filename slug)
node tools/import-docs.mjs /path/to/docs.urbit.org/content/courses/hoon-school

# or curate ids/titles/order with a map, and preview first
cp tools/seed-map.example.json tools/seed-map.json   # then edit the src paths
node tools/import-docs.mjs /path/to/docs.urbit.org --map tools/seed-map.json --dry
node tools/import-docs.mjs /path/to/docs.urbit.org --map tools/seed-map.json
```

### How it maps
- **Prose** (headings, paragraphs, lists, tables, images) → markdown cells.
- **Code fences** in a runnable language (```` ```hoon ```` and unlabeled) →
  **code cells**, verbatim. Other languages (```` ```bash ````, output blocks)
  stay as fenced code inside a markdown cell.
- **Title** comes from `--map`, else YAML frontmatter `title:`, else the first
  `#` heading.
- **Images**: relative raster images (`png`/`jpg`/`gif`/`webp`) are read from
  disk and inlined as `data:` URIs so they travel with a published notebook.
  Missing ones fall back to `--image-base <url>` (rewritten to that host) or are
  left untouched. `https:`/`data:` images pass through. (SVG is intentionally not
  embedded — the renderer blocks `data:image/svg+xml`.)

### Review pass (not fully automatic)
The converter is faithful, not clever. Before shipping the seeds, skim for:
- **Dojo transcripts** — a ```` ```hoon ```` block that's a `>`-prompted session
  with output becomes one code cell containing the prompts + output, which won't
  run as-is. Split it into runnable cells (drop `> ` and output lines) by hand.
- **Non-hoon runnable examples** — mark their fences with a language so they stay
  prose, or adjust `runnable` in `md-to-notebook.mjs`.
- **Oversized images** — data URIs live in agent state and every fact over Ames;
  keep diagrams reasonably sized, or use `--image-base` to reference them.

### Options
| flag | meaning |
|------|---------|
| `--out <dir>` | output dir (default `desk/seed`) |
| `--map <file>` | id/title/order/include overrides |
| `--image-base <url>` | rewrite unresolved relative images to `<url>/<path>` |
| `--kernel <name>` | notebook kernel (default `hoon`) |
| `--dry` | print the plan, write nothing |

## `md-to-notebook.mjs`

The pure converter (`mdToNotebook(md, opts) → notebook`) used by `import-docs`.
Import it directly if you want to script conversions.
