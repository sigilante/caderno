#!/usr/bin/env node
// import-docs.mjs
//
// Build caderno seed notebooks (desk/seed/*.json) from Markdown source — e.g. a
// local checkout of github.com/urbit/docs.urbit.org.
//
//   node tools/import-docs.mjs <md-dir-or-file> [options]
//
// Options
//   --out <dir>         output dir for seed JSON (default: desk/seed)
//   --map <file>        JSON overrides for id/title/order/include (see seed-map.example.json)
//   --image-base <url>  rewrite unresolved relative images to <url>/<path>
//                       (else they are embedded as data: URIs, or left as-is)
//   --kernel <name>     notebook kernel (default: hoon)
//   --dry               print what would be written; write nothing
//
// Behaviour
//   - Every *.md under <md-dir> becomes one notebook; id = filename slug, unless
//     a --map entry overrides it. A single .md file also works.
//   - Prose → markdown cells; ```hoon and unlabeled fences → runnable code cells
//     (verbatim — review dojo-transcript blocks by hand; they aren't stripped).
//   - Relative images (raster: png/jpe?g/gif/webp) are read from disk and inlined
//     as data: URIs so they travel with a published notebook. Missing images fall
//     back to --image-base, or are left untouched.

import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { mdToNotebook } from './md-to-notebook.mjs'

const HERE = path.dirname(fileURLToPath(import.meta.url))
const REPO = path.resolve(HERE, '..')

// ── args ──────────────────────────────────────────────────────────────────────
const argv = process.argv.slice(2)
if (!argv.length || argv[0].startsWith('-')) {
  console.error('usage: node tools/import-docs.mjs <md-dir-or-file> [--out dir] [--map file] [--image-base url] [--kernel name] [--dry]')
  process.exit(1)
}
const opt = (name, def) => { const i = argv.indexOf(name); return i >= 0 ? argv[i + 1] : def }
const srcArg = argv[0]
const outDir = path.resolve(REPO, opt('--out', 'desk/seed'))
const mapFile = opt('--map', null)
const imageBase = opt('--image-base', null)
const kernel = opt('--kernel', 'hoon')
const dry = argv.includes('--dry')

// ── which files → which notebooks ──────────────────────────────────────────────
const slug = f => path.basename(f, '.md').toLowerCase().replace(/[^a-z0-9-]+/g, '-').replace(/^-|-$/g, '')

function listMd(p) {
  const st = fs.statSync(p)
  if (st.isFile()) return [p]
  return fs.readdirSync(p)
    .filter(f => f.endsWith('.md'))
    .sort()
    .map(f => path.join(p, f))
}

let map = null
if (mapFile) map = JSON.parse(fs.readFileSync(path.resolve(REPO, mapFile), 'utf8'))

// Build the work list: [{ src, id, title? }]
let work
if (map && Array.isArray(map.notebooks)) {
  const base = fs.statSync(srcArg).isDirectory() ? srcArg : path.dirname(srcArg)
  work = map.notebooks
    .filter(n => n.include !== false)
    .map(n => ({ src: path.resolve(base, n.src), id: n.id ?? slug(n.src), title: n.title }))
} else {
  work = listMd(srcArg).map(f => ({ src: f, id: slug(f) }))
}

// ── image embedding ─────────────────────────────────────────────────────────────
const MIME = { png: 'image/png', jpg: 'image/jpeg', jpeg: 'image/jpeg', gif: 'image/gif', webp: 'image/webp' }

function embedImages(source, mdDir) {
  return source.replace(/!\[([^\]]*)\]\(([^)\s]+)([^)]*)\)/g, (m, alt, url) => {
    if (/^(https?:|data:)/i.test(url)) return m           // already a URL / data URI
    const abs = path.resolve(mdDir, url.replace(/^\//, ''))
    const mime = MIME[path.extname(abs).slice(1).toLowerCase()]
    if (mime && fs.existsSync(abs)) {
      const b64 = fs.readFileSync(abs).toString('base64')
      return `![${alt}](data:${mime};base64,${b64})`
    }
    if (imageBase) return `![${alt}](${imageBase.replace(/\/$/, '')}/${url.replace(/^\.?\//, '')})`
    return m                                               // leave untouched (renderer blocks unknown schemes)
  })
}

// ── run ─────────────────────────────────────────────────────────────────────────
if (!dry) fs.mkdirSync(outDir, { recursive: true })
for (const { src, id, title } of work) {
  if (!fs.existsSync(src)) { console.warn(`skip (missing): ${src}`); continue }
  const md = fs.readFileSync(src, 'utf8')
  const nb = mdToNotebook(md, { title, kernel })
  for (const c of nb.cells) if (c.type === 'markdown') c.source = embedImages(c.source, path.dirname(src))
  const codeCells = nb.cells.filter(c => c.type === 'code').length
  const dest = path.join(outDir, `${id}.json`)
  console.log(`${dry ? '[dry] ' : ''}${id}.json  title=${JSON.stringify(nb.title)}  cells=${nb.cells.length} (${codeCells} code)`)
  if (!dry) fs.writeFileSync(dest, JSON.stringify(nb))
}
console.log(dry ? '\n(dry run — nothing written)' : `\nwrote ${work.length} notebook(s) to ${path.relative(REPO, outDir)}/`)
