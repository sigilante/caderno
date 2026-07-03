import { useRef, useEffect, useState } from 'react'
import type { NbEntry, CellEntry } from '../App'

interface Props {
  nb: NbEntry
  running: Set<number>
  onRunCell: (id: number) => void
  onDelete: (id: number) => void
  onInsertAfter: (id: number) => void
  onUpdateSrc: (id: number, src: string) => void
  onToggleEdit: (id: number) => void
  onAddCode: () => void
  onSetCellType: (id: number, cellType: 'code' | 'markdown') => void
  onRename: (title: string) => void
}

export function NotebookView({ nb, running, onRunCell, onDelete, onInsertAfter, onUpdateSrc, onToggleEdit, onAddCode, onSetCellType, onRename }: Props) {
  const codeCells = nb.cells.filter(c => c.type === 'code')
  const okCount   = codeCells.filter(c => c.out?.ok).length
  const errCount  = codeCells.filter(c => c.out && !c.out.ok).length

  const [editingTitle, setEditingTitle] = useState(false)
  const [titleDraft, setTitleDraft] = useState(nb.name)
  useEffect(() => { if (!editingTitle) setTitleDraft(nb.name) }, [nb.name, editingTitle])

  const commitTitle = () => {
    setEditingTitle(false)
    if (titleDraft !== nb.name) onRename(titleDraft)
  }

  return (
    <div
      className="lc-scroll"
      style={{ position: 'absolute', top: 116, left: 256, right: 176, bottom: 10, overflowY: 'auto' }}
    >
      <div style={{ padding: '2px 24px 80px' }}>
        {/* title row */}
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 14, padding: '0 4px 12px', borderBottom: '1px solid #1a1814', marginBottom: 16 }}>
          {editingTitle ? (
            <input
              value={titleDraft}
              onChange={e => setTitleDraft(e.target.value)}
              onBlur={commitTitle}
              onKeyDown={e => {
                if (e.key === 'Enter') commitTitle()
                if (e.key === 'Escape') { setEditingTitle(false); setTitleDraft(nb.name) }
              }}
              autoFocus
              style={{ fontFamily: "'Antonio', sans-serif", fontSize: 28, fontWeight: 600, color: '#ffd9a8', background: 'transparent', border: 'none', borderBottom: '1px solid #ffd9a880', outline: 'none', minWidth: 120 }}
            />
          ) : (
            <span
              className="lc-press"
              onClick={() => { setTitleDraft(nb.name); setEditingTitle(true) }}
              title="click to rename"
              style={{ fontFamily: "'Antonio', sans-serif", fontSize: 28, fontWeight: 600, color: '#ffd9a8', cursor: 'text' }}
            >{nb.name}</span>
          )}
          <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 11, color: '#6b5a3c', letterSpacing: '.16em' }}>
            {codeCells.length} CODE · {okCount} OK · {errCount} ERR
          </span>
        </div>

        {/* column header */}
        <div style={{ display: 'flex', fontFamily: "'JetBrains Mono', monospace", fontSize: 10, color: '#6b5a3c', letterSpacing: '.18em', padding: '0 4px 8px' }}>
          <span style={{ flex: '0 0 150px' }}>STATE</span>
          <span style={{ flex: 1 }}>SOURCE · OUTPUT</span>
          <span style={{ flex: '0 0 80px', textAlign: 'right' }}>EXEC</span>
        </div>

        {/* cells */}
        {nb.cells.map(cell => (
          <CellRow
            key={cell.id}
            cell={cell}
            isRunning={running.has(cell.id)}
            onRun={() => onRunCell(cell.id)}
            onDelete={() => onDelete(cell.id)}
            onInsert={() => onInsertAfter(cell.id)}
            onUpdateSrc={(src) => onUpdateSrc(cell.id, src)}
            onToggleEdit={() => onToggleEdit(cell.id)}
            onToggleType={() => onSetCellType(cell.id, cell.type === 'code' ? 'markdown' : 'code')}
          />
        ))}

        {/* append affordance */}
        <div
          className="lc-press"
          onClick={onAddCode}
          style={{ margin: '18px 0 0 160px', maxWidth: 280, height: 40, border: '1px dashed #2c2820', borderRadius: 6, color: '#6b5a3c', fontFamily: "'JetBrains Mono', monospace", fontSize: 11, letterSpacing: '.14em', display: 'flex', alignItems: 'center', justifyContent: 'center' }}
        >+ APPEND CELL</div>
      </div>
    </div>
  )
}

// ── cell row ─────────────────────────────────────────────────────────────────

interface CellRowProps {
  cell: CellEntry
  isRunning: boolean
  onRun: () => void
  onDelete: () => void
  onInsert: () => void
  onUpdateSrc: (src: string) => void
  onToggleEdit: () => void
  onToggleType: () => void
}

function cellStateBg(cell: CellEntry, isRunning: boolean): string {
  if (isRunning) return '#6c8cff'
  if (cell.type === 'markdown') return '#d9a441'
  if (!cell.out) return '#5f6b7a'
  return cell.out.ok ? '#9bb267' : '#cc5a3a'
}

function cellStateWord(cell: CellEntry, isRunning: boolean): string {
  if (isRunning) return 'EXEC'
  if (cell.type === 'markdown') return 'TEXT'
  if (!cell.out) return 'IDLE'
  return cell.out.ok ? 'RUN' : 'FAIL'
}

function cellInLabel(cell: CellEntry): string {
  if (cell.type === 'markdown') return 'TXT'
  return cell.count != null ? 'IN ' + cell.count : 'IN ··'
}

function CellRow({ cell, isRunning, onRun, onDelete, onInsert, onUpdateSrc, onToggleEdit, onToggleType }: CellRowProps) {
  const textareaRef = useRef<HTMLTextAreaElement>(null)

  // auto-height
  useEffect(() => {
    const el = textareaRef.current
    if (el) { el.style.height = 'auto'; el.style.height = el.scrollHeight + 'px' }
  }, [cell.src, cell.editing])

  const onKey = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && (e.shiftKey || e.ctrlKey || e.metaKey)) {
      e.preventDefault()
      onRun()
    }
  }

  const stateBg   = cellStateBg(cell, isRunning)
  const stateWord = cellStateWord(cell, isRunning)
  const inLabel   = cellInLabel(cell)

  return (
    <div style={{ display: 'flex', gap: 10, marginBottom: 8, alignItems: 'stretch' }}>
      {/* state tab */}
      <div style={{ flex: '0 0 150px', background: stateBg, borderRadius: '0 0 0 22px', color: '#000', padding: '13px 16px', display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
        <span style={{ fontFamily: "'Antonio', sans-serif", fontSize: 21, fontWeight: 700, lineHeight: .9, letterSpacing: '.02em' }}>{stateWord}</span>
        <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 10, letterSpacing: '.08em', fontWeight: 700 }}>{inLabel}</span>
      </div>

      {/* body */}
      <div style={{ flex: 1, minWidth: 0, background: '#0b0b0d', border: '1px solid #161616', borderRadius: '0 6px 6px 0', padding: '12px 16px' }}>
        {cell.type === 'code' ? (
          <>
            <textarea
              ref={textareaRef}
              className="lc-src"
              spellCheck={false}
              rows={Math.max(1, (cell.src.match(/\n/g) ?? []).length + 1)}
              value={cell.src}
              onChange={e => onUpdateSrc(e.target.value)}
              onKeyDown={onKey}
              autoFocus={!!cell.fresh}
              style={{ fontSize: 15, color: '#ffd9a8' }}
            />
            {cell.out && (
              <div style={{ marginTop: 10, paddingTop: 9, borderTop: '1px solid #1a1814', display: 'flex', gap: 12 }}>
                <span style={{ flex: '0 0 40px', fontFamily: "'JetBrains Mono', monospace", fontSize: 10, fontWeight: 700, color: cell.out.ok ? '#66ccff' : '#cc5a3a', letterSpacing: '.06em', paddingTop: 2 }}>
                  {cell.out.ok ? 'OUT' : 'ERR'}
                </span>
                <pre style={{ flex: 1, margin: 0, fontFamily: "'JetBrains Mono', monospace", fontSize: 14, lineHeight: 1.5, color: cell.out.ok ? '#bde2c4' : '#ff9d80', whiteSpace: 'pre-wrap', wordBreak: 'break-word' }}>
                  {cell.out.text}
                </pre>
              </div>
            )}
          </>
        ) : (
          <>
            {cell.editing ? (
              <textarea
                ref={textareaRef}
                className="lc-src"
                spellCheck={false}
                rows={Math.max(1, (cell.src.match(/\n/g) ?? []).length + 1)}
                value={cell.src}
                onChange={e => onUpdateSrc(e.target.value)}
                onKeyDown={e => {
                  if (e.key === 'Enter' && (e.shiftKey || e.ctrlKey || e.metaKey)) { e.preventDefault(); onToggleEdit() }
                }}
                onBlur={onToggleEdit}
                autoFocus
                style={{ fontSize: 14, color: '#d9c3a6' }}
              />
            ) : (
              <div
                className="lc-press"
                onClick={onToggleEdit}
                style={{ color: '#d9c3a6', fontSize: 16 }}
                title="click to edit"
                dangerouslySetInnerHTML={{ __html: renderMd(cell.src, '#cc88ff') }}
              />
            )}
          </>
        )}
      </div>

      {/* gutter */}
      <div style={{ flex: '0 0 80px', display: 'flex', flexDirection: 'column', gap: 5, alignItems: 'flex-end', paddingTop: 2 }}>
        <button
          className="lc-press"
          onClick={onRun}
          title="run (Shift-Enter)"
          style={{ width: 34, height: 28, borderRadius: 14, background: '#cc88ff', color: '#000', border: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 12, cursor: 'pointer' }}
        >▶</button>
        <button
          className="lc-press"
          onClick={onInsert}
          title="insert code below"
          style={{ width: 34, height: 28, borderRadius: 14, background: '#23211c', color: '#6c8cff', border: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 16, cursor: 'pointer' }}
        >+</button>
        <button
          className="lc-press"
          onClick={onToggleType}
          title={cell.type === 'code' ? 'switch to markdown' : 'switch to code'}
          style={{ width: 34, height: 28, borderRadius: 14, background: '#23211c', color: cell.type === 'code' ? '#d9a441' : '#6c8cff', border: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 9, cursor: 'pointer', fontFamily: "'JetBrains Mono', monospace", letterSpacing: '.04em', fontWeight: 700 }}
        >{cell.type === 'code' ? 'TXT' : 'COD'}</button>
        <button
          className="lc-press"
          onClick={onDelete}
          title="delete"
          style={{ width: 34, height: 28, borderRadius: 14, background: '#23211c', color: '#cc5a3a', border: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 12, cursor: 'pointer' }}
        >✕</button>
      </div>
    </div>
  )
}

// ── markdown renderer ──────────────────────────────────────────────────────────

function renderMd(src: string, accent: string): string {
  // Escape all five HTML-significant chars — including quotes, so a link href
  // can't break out of its attribute. Notebook source is attacker-controlled
  // (followed/forked from other ships), rendered via dangerouslySetInnerHTML.
  const esc = (x: string) => x.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;')
  // Only allow safe link schemes; block javascript:/data:/vbscript: etc.
  const safeHref = (h: string) => /^(?:https?:\/\/|mailto:|\/|#)/i.test(h.trim()) ? h : '#'
  // Images travel embedded in published notebooks: allow raster data: URIs
  // (self-contained) and https/relative URLs. Block data:image/svg+xml — SVG is
  // an executable document — and every other scheme.
  const safeSrc = (s: string) => {
    const t = s.trim()
    if (/^data:image\/(?:png|jpe?g|gif|webp);/i.test(t)) return t
    if (/^(?:https:\/\/|\/)/i.test(t)) return t
    return ''
  }
  const inl = (x: string) => esc(x)
    // image before link (![..](..) is a superset of the link pattern)
    .replace(/!\[([^\]]*)\]\(([^)]+)\)/g, (_m: string, alt: string, s: string) => {
      const safe = safeSrc(s)
      return safe
        ? `<img src="${safe}" alt="${alt}" loading="lazy" style="max-width:100%;border-radius:6px;margin:6px 0;border:1px solid #1a1814" />`
        : '<span style="color:#cc5a3a;font-family:monospace;font-size:.82em">[blocked image]</span>'
    })
    .replace(/\*\*([^*]+)\*\*/g, `<b style="color:${accent};font-weight:700">$1</b>`)
    .replace(/`([^`]+)`/g, `<code style="font-family:'JetBrains Mono',monospace;background:#1d1712;color:${accent};padding:1px 6px;border-radius:4px;font-size:.84em">$1</code>`)
    .replace(/\*([^*]+)\*/g, '<i style="color:#e9c9a0">$1</i>')
    .replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_m: string, txt: string, href: string) =>
      `<a href="${safeHref(href)}" style="color:${accent};text-decoration:underline" target="_blank" rel="noopener noreferrer">${txt}</a>`)

  const lines = src.split('\n')
  let html = ''
  let inUl = false, inOl = false, inCode = false
  let codeLines: string[] = []

  const closeUl = () => { if (inUl) { html += '</ul>'; inUl = false } }
  const closeOl = () => { if (inOl) { html += '</ol>'; inOl = false } }
  const closeLists = () => { closeUl(); closeOl() }
  const flushCode = () => {
    html += `<pre style="margin:8px 0;background:#1d1712;border-radius:6px;padding:10px 14px;overflow-x:auto"><code style="font-family:'JetBrains Mono',monospace;font-size:.84em;color:#ffd9a8;line-height:1.5">${codeLines.map(esc).join('\n')}</code></pre>`
    codeLines = []
  }

  // markdown tables: a |header| row, a |---|---| separator, then |body| rows
  const rowCells = (r: string) => r.trim().replace(/^\||\|$/g, '').split('|').map(c => c.trim())
  const isTableSep = (s: string) => /-/.test(s) && /^\s*\|?[\s:|-]+\|[\s:|-]*$/.test(s)

  for (let i = 0; i < lines.length; i++) {
    const ln = lines[i]
    if (!inCode && /^\s*\|.*\|\s*$/.test(ln) && i + 1 < lines.length && isTableSep(lines[i + 1])) {
      closeLists()
      const header = rowCells(ln)
      let j = i + 2
      const body: string[][] = []
      while (j < lines.length && /^\s*\|.*\|\s*$/.test(lines[j])) { body.push(rowCells(lines[j])); j++ }
      const cs = 'padding:5px 12px;border:1px solid #2c2820;text-align:left;line-height:1.4'
      const ths = header.map(c => `<th style="${cs};color:${accent};font-weight:700">${inl(c)}</th>`).join('')
      const trs = body.map(r => `<tr>${r.map(c => `<td style="${cs};color:#d8c4a0">${inl(c)}</td>`).join('')}</tr>`).join('')
      html += `<table style="border-collapse:collapse;margin:10px 0;font-size:.88em"><thead><tr>${ths}</tr></thead><tbody>${trs}</tbody></table>`
      i = j - 1
      continue
    }
    if (/^```/.test(ln)) {
      if (!inCode) { closeLists(); inCode = true; codeLines = [] }
      else { flushCode(); inCode = false }
    } else if (inCode) {
      codeLines.push(ln)
    } else if (/^### /.test(ln)) {
      closeLists()
      html += `<div style="font-family:Antonio,sans-serif;text-transform:uppercase;letter-spacing:.05em;color:${accent};font-size:17px;font-weight:600;margin:14px 0 5px">${inl(ln.slice(4))}</div>`
    } else if (/^## /.test(ln)) {
      closeLists()
      html += `<div style="font-family:Antonio,sans-serif;text-transform:uppercase;letter-spacing:.04em;color:${accent};font-size:23px;font-weight:600;margin:18px 0 7px">${inl(ln.slice(3))}</div>`
    } else if (/^# /.test(ln)) {
      closeLists()
      html += `<div style="font-family:Antonio,sans-serif;text-transform:uppercase;letter-spacing:.03em;color:${accent};font-size:33px;font-weight:700;line-height:1;margin:4px 0 10px">${inl(ln.slice(2))}</div>`
    } else if (/^[-*] /.test(ln)) {
      closeOl()
      if (!inUl) { html += '<ul style="margin:5px 0;padding-left:20px">'; inUl = true }
      html += `<li style="margin:3px 0;line-height:1.45">${inl(ln.slice(2))}</li>`
    } else if (/^\d+\. /.test(ln)) {
      closeUl()
      if (!inOl) { html += '<ol style="margin:5px 0;padding-left:20px">'; inOl = true }
      html += `<li style="margin:3px 0;line-height:1.45">${inl(ln.replace(/^\d+\. /, ''))}</li>`
    } else if (/^> /.test(ln)) {
      closeLists()
      html += `<blockquote style="margin:7px 0;padding:4px 12px;border-left:3px solid ${accent};color:#c0a882;font-style:italic">${inl(ln.slice(2))}</blockquote>`
    } else if (ln.trim() === '') {
      closeLists()
    } else {
      closeLists()
      html += `<p style="margin:7px 0;line-height:1.5">${inl(ln)}</p>`
    }
  }

  if (inCode) flushCode()
  closeLists()
  return html
}
