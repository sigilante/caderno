// md-to-notebook.mjs
//
// Convert a Markdown document into a caderno notebook object:
//   { nbformat, title, kernel, cells: [{ id, type, source, outputs, exec_count }] }
//
// Prose (headings, lists, tables, paragraphs, images) becomes markdown cells;
// fenced code blocks in a "runnable" language become code cells. Everything is
// verbatim — no lossy transforms — so the output round-trips through caderno's
// own json-to-notebook. Pure and dependency-free; the driver handles fs/images.

const NBFORMAT = 1

// Strip YAML frontmatter, returning { body, meta } where meta is a shallow map
// of top-level `key: value` lines (enough to pull a `title`).
function splitFrontmatter(md) {
  const m = md.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?/)
  if (!m) return { body: md, meta: {} }
  const meta = {}
  for (const line of m[1].split(/\r?\n/)) {
    const kv = line.match(/^([A-Za-z0-9_-]+):\s*(.*)$/)
    if (kv) meta[kv[1]] = kv[2].trim().replace(/^["']|["']$/g, '')
  }
  return { body: md.slice(m[0].length), meta }
}

/**
 * @param {string} md               raw markdown
 * @param {object} [opts]
 * @param {string} [opts.title]     override title (else frontmatter title, else first # heading)
 * @param {string} [opts.kernel]    notebook kernel (default 'hoon')
 * @param {string[]} [opts.runnable] fence languages that become code cells
 *                                   (default ['hoon', ''] — hoon and unlabeled)
 * @returns {{nbformat:number,title:string,kernel:string,cells:object[]}}
 */
export function mdToNotebook(md, opts = {}) {
  const kernel = opts.kernel ?? 'hoon'
  const runnable = (opts.runnable ?? ['hoon', '']).map(s => s.toLowerCase())

  const { body, meta } = splitFrontmatter(md)
  let title = opts.title ?? meta.title
  if (!title) {
    const h1 = body.match(/^#\s+(.+)$/m)
    title = h1 ? h1[1].trim() : 'Untitled'
  }

  const cells = []
  let id = 1
  let prose = []

  const flushProse = () => {
    const text = prose.join('\n').replace(/\n{3,}/g, '\n\n').trim()
    prose = []
    if (text) cells.push({ id: id++, type: 'markdown', source: text, outputs: [], exec_count: null })
  }

  const lines = body.split('\n')
  for (let i = 0; i < lines.length; i++) {
    const open = lines[i].match(/^```(\S*)\s*$/)
    if (open) {
      const lang = open[1].toLowerCase()
      const code = []
      i++
      while (i < lines.length && !/^```\s*$/.test(lines[i])) { code.push(lines[i]); i++ }
      const src = code.join('\n')
      if (runnable.includes(lang)) {
        flushProse()
        cells.push({ id: id++, type: 'code', source: src, outputs: [], exec_count: null })
      } else {
        // non-runnable fence (bash, output, etc.): keep it as a fenced block in prose
        prose.push('```' + open[1], src, '```')
      }
    } else {
      prose.push(lines[i])
    }
  }
  flushProse()

  return { nbformat: NBFORMAT, title, kernel, cells }
}
