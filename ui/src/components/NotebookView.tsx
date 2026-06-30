import { useRef, useEffect } from 'react'
import type { NbEntry, CellEntry } from '../App'

interface Props {
  nb: NbEntry
  onRunCell: (id: number) => void
  onDelete: (id: number) => void
  onInsertAfter: (id: number) => void
  onUpdateSrc: (id: number, src: string) => void
  onToggleEdit: (id: number) => void
  onAddCode: () => void
}

export function NotebookView({ nb, onRunCell, onDelete, onInsertAfter, onUpdateSrc, onToggleEdit, onAddCode }: Props) {
  const codeCells = nb.cells.filter(c => c.type === 'code')
  const okCount   = codeCells.filter(c => c.out?.ok).length
  const errCount  = codeCells.filter(c => c.out && !c.out.ok).length

  return (
    <div
      className="lc-scroll"
      style={{ position: 'absolute', top: 116, left: 256, right: 176, bottom: 10, overflowY: 'auto' }}
    >
      <div style={{ padding: '2px 24px 80px' }}>
        {/* title row */}
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 14, padding: '0 4px 12px', borderBottom: '1px solid #1a1814', marginBottom: 16 }}>
          <span style={{ fontFamily: "'Antonio', sans-serif", fontSize: 28, fontWeight: 600, color: '#ffd9a8' }}>{nb.name}</span>
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
            onRun={() => onRunCell(cell.id)}
            onDelete={() => onDelete(cell.id)}
            onInsert={() => onInsertAfter(cell.id)}
            onUpdateSrc={(src) => onUpdateSrc(cell.id, src)}
            onToggleEdit={() => onToggleEdit(cell.id)}
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
  onRun: () => void
  onDelete: () => void
  onInsert: () => void
  onUpdateSrc: (src: string) => void
  onToggleEdit: () => void
}

function cellStateBg(cell: CellEntry): string {
  if (cell.type === 'markdown') return '#d9a441'
  if (!cell.out) return '#5f6b7a'
  return cell.out.ok ? '#9bb267' : '#cc5a3a'
}

function cellStateWord(cell: CellEntry): string {
  if (cell.type === 'markdown') return 'TEXT'
  if (!cell.out) return 'IDLE'
  return cell.out.ok ? 'RUN' : 'FAIL'
}

function cellInLabel(cell: CellEntry): string {
  if (cell.type === 'markdown') return 'TXT'
  return cell.count != null ? 'IN ' + cell.count : 'IN ··'
}

function CellRow({ cell, onRun, onDelete, onInsert, onUpdateSrc, onToggleEdit }: CellRowProps) {
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

  const stateBg   = cellStateBg(cell)
  const stateWord = cellStateWord(cell)
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
          onClick={onDelete}
          title="delete"
          style={{ width: 34, height: 28, borderRadius: 14, background: '#23211c', color: '#cc5a3a', border: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 12, cursor: 'pointer' }}
        >✕</button>
      </div>
    </div>
  )
}

// ── markdown renderer (ported from prototype) ─────────────────────────────────

function renderMd(src: string, accent: string): string {
  const esc = (x: string) => x.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
  const inl = (x: string) => esc(x)
    .replace(/\*\*([^*]+)\*\*/g, `<b style="color:${accent};font-weight:700">$1</b>`)
    .replace(/`([^`]+)`/g, `<code style="font-family:'JetBrains Mono',monospace;background:#1d1712;color:${accent};padding:1px 6px;border-radius:4px;font-size:.84em">$1</code>`)
    .replace(/\*([^*]+)\*/g, '<i style="color:#e9c9a0">$1</i>')

  const lines = src.split('\n')
  let html = ''
  let inUl = false
  const close = () => { if (inUl) { html += '</ul>'; inUl = false } }

  for (const ln of lines) {
    if (/^### /.test(ln)) {
      close()
      html += `<div style="font-family:Antonio,sans-serif;text-transform:uppercase;letter-spacing:.05em;color:${accent};font-size:17px;font-weight:600;margin:14px 0 5px">${inl(ln.replace(/^### /, ''))}</div>`
    } else if (/^## /.test(ln)) {
      close()
      html += `<div style="font-family:Antonio,sans-serif;text-transform:uppercase;letter-spacing:.04em;color:${accent};font-size:23px;font-weight:600;margin:18px 0 7px">${inl(ln.replace(/^## /, ''))}</div>`
    } else if (/^# /.test(ln)) {
      close()
      html += `<div style="font-family:Antonio,sans-serif;text-transform:uppercase;letter-spacing:.03em;color:${accent};font-size:33px;font-weight:700;line-height:1;margin:4px 0 10px">${inl(ln.replace(/^# /, ''))}</div>`
    } else if (/^[-*] /.test(ln)) {
      if (!inUl) { html += '<ul style="margin:5px 0;padding-left:20px">'; inUl = true }
      html += `<li style="margin:3px 0;line-height:1.45">${inl(ln.replace(/^[-*] /, ''))}</li>`
    } else if (ln.trim() === '') {
      close()
    } else {
      close()
      html += `<p style="margin:7px 0;line-height:1.5">${inl(ln)}</p>`
    }
  }
  close()
  return html
}
