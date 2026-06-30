import { useEffect, useReducer, useCallback, useRef } from 'react'
import {
  fetchActiveNotebook, fetchKelvins, fetchLogStatus, openChannel, closeChannel, actions,
  type Notebook, type Cell, type Output, type Update, type Kelvins,
} from './api'
import { NotebookIndex } from './components/NotebookIndex'
import { NotebookView } from './components/NotebookView'

// ── state ────────────────────────────────────────────────────────────────────

type AppState = {
  view: 'list' | 'nb'
  active: string | null
  notebooks: NbEntry[]
  channelOpen: boolean
  logMounted: boolean
  error: string | null
  running: Set<number>
  kelvins: Kelvins | null
}

export type NbEntry = {
  id: string
  name: string
  stardate: string
  kernel: string
  status: 'new' | 'edited' | 'saved'
  cells: CellEntry[]
  counter: number
}

export type CellEntry = {
  id: number
  type: 'code' | 'markdown'
  src: string
  out: { ok: boolean; text: string } | null
  count: number | null
  editing: boolean
  fresh?: boolean  // true for cells just inserted this session → textarea autoFocus
}

function notebookToEntry(id: string, nb: Notebook): NbEntry {
  return {
    id,
    name: nb.title,
    stardate: toUrbitDate(Date.now()),
    kernel: nb.kernel,
    status: 'saved',
    counter: 0,
    cells: nb.cells.map(cellToEntry),
  }
}

function cellToEntry(c: Cell): CellEntry {
  const out = c.outputs[0]
    ? c.outputs[0].text != null
      ? { ok: true, text: c.outputs[0].text! }
      : { ok: false, text: (c.outputs[0].ename ?? '') + ': ' + (c.outputs[0].evalue ?? '') }
    : null
  return {
    id: c.id,
    type: c.type,
    src: c.source,
    out,
    count: c.exec_count,
    editing: false,
  }
}

function toUrbitDate(ms: number): string {
  const d = new Date(ms)
  return `~${d.getUTCFullYear()}.${d.getUTCMonth() + 1}.${d.getUTCDate()}`
}

type Action =
  | { type: 'loaded'; id: string; nb: Notebook }
  | { type: 'nb-list'; items: { id: string; title: string }[] }
  | { type: 'cell-output'; id: number; out: Output; count: number }
  | { type: 'cell-status'; id: number; status: string }
  | { type: 'cell-added'; cell: Cell; after: number | null }
  | { type: 'cell-deleted'; id: number }
  | { type: 'channel-open' }
  | { type: 'log-mounted' }
  | { type: 'log-committed' }
  | { type: 'error'; msg: string }
  | { type: 'set-view'; view: 'list' | 'nb'; id?: string }
  | { type: 'set-kernel'; kernel: string }
  | { type: 'set-src'; id: number; src: string }
  | { type: 'toggle-edit'; id: number }
  | { type: 'cell-run-result'; id: number; ok: boolean; text: string; count: number }
  | { type: 'set-cell-type'; id: number; cellType: 'code' | 'markdown' }
  | { type: 'rename-nb'; title: string }
  | { type: 'set-kelvins'; kelvins: Kelvins }
  | { type: 'set-log-mounted'; mounted: boolean }

function reducer(state: AppState, action: Action): AppState {
  const activeNb = () => state.notebooks.find(n => n.id === state.active) ?? null

  switch (action.type) {
    case 'loaded': {
      const entry = notebookToEntry(action.id, action.nb)
      const existing = state.notebooks.findIndex(n => n.id === action.id)
      const isNew = existing === -1
      const notebooks = isNew
        ? [...state.notebooks, entry]
        : state.notebooks.map((n, i) => i === existing ? entry : n)
      const active = isNew ? action.id : (state.active ?? action.id)
      // Navigate to new notebooks automatically (e.g. after %new-notebook poke)
      const view = isNew ? 'nb' : state.view
      return { ...state, notebooks, active, view, error: null }
    }
    case 'nb-list': {
      const existingIds = new Set(state.notebooks.map(n => n.id))
      const incomingIds = new Set(action.items.map(i => i.id))
      let notebooks = state.notebooks
        .filter(n => incomingIds.has(n.id))
        .map(n => {
          const item = action.items.find(i => i.id === n.id)
          return item ? { ...n, name: item.title } : n
        })
      for (const item of action.items) {
        if (!existingIds.has(item.id)) {
          notebooks = [...notebooks, {
            id: item.id, name: item.title,
            stardate: toUrbitDate(Date.now()),
            kernel: 'hoon', status: 'saved' as const,
            cells: [], counter: 0,
          }]
        }
      }
      return { ...state, notebooks }
    }
    case 'cell-output': {
      const out = action.out.text != null
        ? { ok: true, text: action.out.text! }
        : { ok: false, text: (action.out.ename ?? '') + ': ' + (action.out.evalue ?? '') }
      return mutCells(state, action.id, c => ({ ...c, out, count: action.count }))
    }
    case 'cell-status': {
      const running = new Set(state.running)
      if (action.status === 'running') running.add(action.id)
      else running.delete(action.id)
      // Also update cell output on 'done'/'error' to clear stale EXEC state
      // (output update arrives separately via cell-output; just update running set here)
      return { ...state, running }
    }
    case 'cell-added': {
      const nb = activeNb(); if (!nb) return state
      const ce = cellToEntry(action.cell)
      // Markdown → editing mode; code → fresh=true so textarea gets autoFocus
      const ce2 = ce.type === 'markdown' ? { ...ce, editing: true } : { ...ce, fresh: true }
      return mutNb(state, nb.id, n => ({
        ...n,
        cells: action.after == null
          ? [...n.cells, ce2]
          : insertAfterCell(n.cells, action.after, ce2),
      }))
    }
    case 'cell-deleted': {
      const nb = activeNb(); if (!nb) return state
      return mutNb(state, nb.id, n => ({
        ...n, cells: n.cells.length > 1 ? n.cells.filter(c => c.id !== action.id) : n.cells,
      }))
    }
    case 'channel-open':
      return { ...state, channelOpen: true }
    case 'log-mounted':
      return { ...state, logMounted: true }
    case 'log-committed':
      return state
    case 'set-log-mounted':
      return { ...state, logMounted: action.mounted }
    case 'error':
      return { ...state, error: action.msg }
    case 'set-view':
      return { ...state, view: action.view, active: action.id ?? state.active }
    case 'set-kernel': {
      const nb = activeNb(); if (!nb) return state
      return mutNb(state, nb.id, n => ({ ...n, kernel: action.kernel }))
    }
    case 'set-src': {
      return mutCells(state, action.id, c => ({ ...c, src: action.src }))
    }
    case 'toggle-edit': {
      return mutCells(state, action.id, c => ({ ...c, editing: !c.editing }))
    }
    case 'cell-run-result': {
      return mutCells(state, action.id, c => ({ ...c, out: { ok: action.ok, text: action.text }, count: action.count }))
    }
    case 'set-cell-type': {
      return mutCells(state, action.id, c => ({ ...c, type: action.cellType, out: null, count: null }))
    }
    case 'rename-nb': {
      const nb = activeNb(); if (!nb) return state
      return mutNb(state, nb.id, n => ({ ...n, name: action.title }))
    }
    case 'set-kelvins':
      return { ...state, kelvins: action.kelvins }
    default: return state
  }
}

function mutNb(state: AppState, id: string, fn: (n: NbEntry) => NbEntry): AppState {
  return { ...state, notebooks: state.notebooks.map(n => n.id === id ? fn(n) : n) }
}

function mutCells(state: AppState, cellId: number, fn: (c: CellEntry) => CellEntry): AppState {
  const nb = state.notebooks.find(n => n.id === state.active)
  if (!nb) return state
  return mutNb(state, nb.id, n => ({ ...n, cells: n.cells.map(c => c.id === cellId ? fn(c) : c) }))
}

function insertAfterCell(cells: CellEntry[], after: number, newCell: CellEntry): CellEntry[] {
  const idx = cells.findIndex(c => c.id === after)
  if (idx === -1) return [...cells, newCell]
  return [...cells.slice(0, idx + 1), newCell, ...cells.slice(idx + 1)]
}

// ── component ────────────────────────────────────────────────────────────────

export default function App() {
  const [state, dispatch] = useReducer(reducer, {
    view: 'list', active: null, notebooks: [], channelOpen: false, logMounted: false, error: null, running: new Set<number>(), kelvins: null,
  })
  const stateRef = useRef(state)
  stateRef.current = state

  const handleUpdate = useCallback((upd: Update) => {
    if ('state' in upd)           dispatch({ type: 'loaded', id: upd['state'].id, nb: upd['state'].nb })
    else if ('nb-list' in upd)    dispatch({ type: 'nb-list', items: upd['nb-list'] })
    else if ('cell-output' in upd)   dispatch({ type: 'cell-output', id: upd['cell-output'].id, out: upd['cell-output'].out, count: upd['cell-output'].count })
    else if ('cell-status' in upd)   dispatch({ type: 'cell-status', id: upd['cell-status'].id, status: upd['cell-status'].status })
    else if ('cell-added' in upd)    dispatch({ type: 'cell-added', cell: upd['cell-added'].c, after: upd['cell-added'].after })
    else if ('cell-deleted' in upd)  dispatch({ type: 'cell-deleted', id: upd['cell-deleted'].id })
    else if ('log-mounted' in upd)   dispatch({ type: 'log-mounted' })
    else if ('log-committed' in upd) dispatch({ type: 'log-committed' })
  }, [])

  useEffect(() => {
    fetchActiveNotebook()
      .then(({ id, nb }) => dispatch({ type: 'loaded', id, nb }))
      .catch(() => dispatch({ type: 'error', msg: 'Could not reach ship' }))
    fetchKelvins()
      .then(kelvins => dispatch({ type: 'set-kelvins', kelvins }))
      .catch(() => {})
    fetchLogStatus()
      .then(mounted => dispatch({ type: 'set-log-mounted', mounted }))
      .catch(() => {})
    openChannel(handleUpdate, () => dispatch({ type: 'channel-open' }))
    return () => { closeChannel() }
  }, [handleUpdate])

  const activeNb = state.notebooks.find(n => n.id === state.active) ?? null

  // callbacks
  const onSetKernel = (k: string) => { dispatch({ type: 'set-kernel', kernel: k }); actions.setKernel(k) }
  const onRunAll = () => { actions.runAll() }
  const onAddCode = () => { actions.insertCell(null, 'code') }
  const onAddText = () => { actions.insertCell(null, 'markdown') }
  const onBack = () => dispatch({ type: 'set-view', view: 'list' })
  const onResetSubject = () => { actions.resetSubject() }
  const onNewNb = () => { actions.newNotebook() }
  const onOpen = (id: string) => {
    dispatch({ type: 'set-view', view: 'nb', id })
    actions.switchNotebook(id)
  }

  const srcDebounce = useRef(new Map<number, ReturnType<typeof setTimeout>>())

  const onRunCell = useCallback((id: number) => {
    const nb = stateRef.current.notebooks.find(n => n.id === stateRef.current.active)
    const cell = nb?.cells.find(c => c.id === id)
    if (cell?.type === 'markdown') {
      dispatch({ type: 'toggle-edit', id })
      return
    }
    // Cancel any pending debounced source update and send it atomically with run-cell.
    // This guarantees the backend evals the source currently visible in the editor.
    const timeout = srcDebounce.current.get(id)
    if (timeout !== undefined) {
      clearTimeout(timeout)
      srcDebounce.current.delete(id)
      if (cell) { actions.runCellFlushed(id, cell.src); return }
    }
    actions.runCell(id)
  }, [])

  const onDelete = (id: number) => { actions.deleteCell(id) }
  const onInsertAfter = (id: number) => { actions.insertCell(id, 'code') }

  const onUpdateSrc = useCallback((id: number, src: string) => {
    dispatch({ type: 'set-src', id, src })
    const prev = srcDebounce.current.get(id)
    if (prev !== undefined) clearTimeout(prev)
    srcDebounce.current.set(id, setTimeout(() => {
      actions.updateSource(id, src)
      srcDebounce.current.delete(id)
    }, 400))
  }, [])

  const onToggleEdit = (id: number) => dispatch({ type: 'toggle-edit', id })
  const onSetCellType = (id: number, cellType: 'code' | 'markdown') => {
    dispatch({ type: 'set-cell-type', id, cellType })
    actions.setCellType(id, cellType)
  }
  const onRename = (title: string) => {
    dispatch({ type: 'rename-nb', title })
    actions.setTitle(title)
  }

  const stardate = toUrbitDate(Date.now())

  return (
    <div style={{ position: 'relative', width: '100%', height: '100vh', minHeight: 780, background: '#000', fontFamily: "'Antonio', sans-serif" }}>
      <div style={{ position: 'absolute', inset: 0, padding: 10, overflow: 'hidden' }}>

        {/* ELBOW */}
        <div style={{ position: 'absolute', top: 10, left: 10, width: 236, height: 158, background: '#ff9900', borderTopLeftRadius: 96, borderBottomRightRadius: 18 }} />

        {/* TOP HEADER BAR */}
        <div style={{ position: 'absolute', top: 10, left: 255, right: 10, height: 96, background: '#ff9900', borderRadius: '0 18px 18px 18px', display: 'flex', alignItems: 'center', padding: '0 30px' }}>
          <div style={{ display: 'flex', flexDirection: 'column', lineHeight: .92 }}>
            <span style={{ fontSize: 42, fontWeight: 700, color: '#000', letterSpacing: '-.01em' }}>caderno</span>
            <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 11, color: '#3a2400', letterSpacing: '.34em', marginTop: 3 }}>LCARS · NOTEBOOK 47-Δ</span>
          </div>
          <div style={{ marginLeft: 'auto', display: 'flex', alignItems: 'center', gap: 26 }}>
            {state.view === 'nb' && activeNb && (
              <div style={{ textAlign: 'right', lineHeight: 1 }}>
                <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 11, color: '#3a2400', letterSpacing: '.22em' }}>ACTIVE BUFFER</div>
                <div style={{ fontSize: 26, fontWeight: 600, color: '#000', marginTop: 2 }}>{activeNb.name}</div>
              </div>
            )}
            <div style={{ textAlign: 'right', lineHeight: 1 }}>
              <div style={{ fontSize: 40, fontWeight: 700, color: '#000' }}>
                {state.view === 'nb' ? (activeNb?.cells.length ?? 0) : state.notebooks.length}
              </div>
              <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 10, color: '#3a2400', letterSpacing: '.2em' }}>
                {state.view === 'nb' ? 'CELLS' : 'BUFFERS'}
              </div>
            </div>
          </div>
        </div>

        {/* LEFT RAIL */}
        <div style={{ position: 'absolute', top: 178, left: 10, bottom: 10, width: 236, display: 'flex', flexDirection: 'column', gap: 7, fontFamily: "'JetBrains Mono', monospace" }}>
          {state.view === 'nb' ? (
            <>
              <div style={{ color: '#6b5a3c', fontSize: 10, letterSpacing: '.24em', padding: '2px 14px 0', textAlign: 'right' }}>KERNEL</div>
              <div style={{ display: 'flex', gap: 7 }}>
                <div
                  className="lc-press"
                  onClick={() => onSetKernel('north')}
                  style={{ flex: 1, height: 52, borderRadius: '0 0 0 26px', background: activeNb?.kernel === 'north' ? '#ff9900' : '#3a2a10', color: activeNb?.kernel === 'north' ? '#000' : '#7a6334', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, fontSize: 16, letterSpacing: '.1em' }}
                >NORTH</div>
                <div
                  className="lc-press"
                  onClick={() => onSetKernel('hoon')}
                  style={{ flex: 1, height: 52, borderRadius: '0 26px 0 0', background: activeNb?.kernel === 'hoon' ? '#cc88ff' : '#2a1c34', color: activeNb?.kernel === 'hoon' ? '#000' : '#6a548a', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, fontSize: 16, letterSpacing: '.1em' }}
                >HOON</div>
              </div>
              <div className="lc-press" onClick={onRunAll} style={{ height: 54, borderRadius: '0 30px 30px 0', background: '#cc88ff', color: '#000', display: 'flex', alignItems: 'center', justifyContent: 'flex-end', paddingRight: 20, fontWeight: 700, fontSize: 17, letterSpacing: '.06em' }}>RUN ALL ▶</div>
              <div className="lc-press" onClick={onAddCode} style={{ height: 50, borderRadius: '0 30px 30px 0', background: '#6c8cff', color: '#000', display: 'flex', alignItems: 'center', justifyContent: 'flex-end', paddingRight: 20, fontWeight: 700, fontSize: 16, letterSpacing: '.04em' }}>+ CODE</div>
              <div className="lc-press" onClick={onAddText} style={{ height: 50, borderRadius: '0 30px 30px 0', background: '#ff8866', color: '#000', display: 'flex', alignItems: 'center', justifyContent: 'flex-end', paddingRight: 20, fontWeight: 700, fontSize: 16, letterSpacing: '.04em' }}>+ TEXT</div>
              <div className="lc-press" onClick={onBack} style={{ height: 50, borderRadius: '0 30px 30px 0', background: '#d9a441', color: '#000', display: 'flex', alignItems: 'center', justifyContent: 'flex-end', paddingRight: 20, fontWeight: 700, fontSize: 16, letterSpacing: '.04em' }}>◂ INDEX</div>
              <div className="lc-press" onClick={onResetSubject} style={{ height: 50, borderRadius: '0 30px 30px 0', background: '#3a2a10', color: '#9a8147', display: 'flex', alignItems: 'center', justifyContent: 'flex-end', paddingRight: 20, fontWeight: 700, fontSize: 14, letterSpacing: '.04em' }}>RESET ENV</div>
            </>
          ) : (
            <>
              <div style={{ color: '#6b5a3c', fontSize: 10, letterSpacing: '.24em', padding: '2px 14px 0', textAlign: 'right' }}>CLAY · /caderno</div>
              <div className="lc-press" onClick={onNewNb} style={{ height: 62, borderRadius: '0 0 0 26px', background: '#cc88ff', color: '#000', display: 'flex', alignItems: 'center', justifyContent: 'flex-end', paddingRight: 20, fontWeight: 700, fontSize: 18, letterSpacing: '.03em' }}>+ NEW NOTEBOOK</div>
              <div style={{ height: 50, borderRadius: '0 30px 30px 0', background: '#6c8cff', color: '#000', display: 'flex', alignItems: 'center', justifyContent: 'flex-end', paddingRight: 20, fontWeight: 700, fontSize: 15, letterSpacing: '.03em' }}>{state.notebooks.length} BUFFERS</div>
              {state.logMounted ? (
                <div
                  className="lc-press"
                  onClick={() => actions.commitLog()}
                  style={{ height: 50, borderRadius: '0 30px 30px 0', background: '#3a4a3a', color: '#99e6a3', display: 'flex', alignItems: 'center', justifyContent: 'flex-end', paddingRight: 20, fontWeight: 700, fontSize: 15, letterSpacing: '.03em' }}
                >COMMIT ▸</div>
              ) : (
                <div
                  className="lc-press"
                  onClick={() => actions.mountLog()}
                  style={{ height: 50, borderRadius: '0 30px 30px 0', background: '#3a2a10', color: '#9a8147', display: 'flex', alignItems: 'center', justifyContent: 'flex-end', paddingRight: 20, fontWeight: 700, fontSize: 15, letterSpacing: '.03em' }}
                >MOUNT</div>
              )}
            </>
          )}

          {/* STATUS BOX */}
          <div style={{ marginTop: 'auto', background: '#0c0c0e', borderRadius: '0 20px 20px 0', border: '1px solid #1c1a16', padding: '16px 18px', display: 'flex', flexDirection: 'column', gap: 11 }}>
            <div>
              <div style={{ color: '#6b5a3c', fontSize: 10, letterSpacing: '.2em' }}>STARDATE</div>
              <div style={{ color: '#ff9900', fontSize: 18, fontWeight: 500 }}>{stardate}</div>
            </div>
            <div>
              <div style={{ color: '#6b5a3c', fontSize: 10, letterSpacing: '.2em' }}>KERNEL</div>
              <div style={{ color: '#cc88ff', fontSize: 18, fontWeight: 500 }}>{(activeNb?.kernel ?? 'NORTH').toUpperCase()}</div>
            </div>
            <div>
              <div style={{ color: '#6b5a3c', fontSize: 10, letterSpacing: '.2em' }}>CHANNEL</div>
              <div style={{ color: state.channelOpen ? '#99e6a3' : '#9a8147', fontSize: 18, fontWeight: 500 }}>
                {state.channelOpen ? 'SUBSCRIBED' : 'OFFLINE'}
              </div>
            </div>
          </div>
        </div>

        {/* CENTER */}
        {state.view === 'nb' && activeNb ? (
          <NotebookView
            nb={activeNb}
            running={state.running}
            onRunCell={onRunCell}
            onDelete={onDelete}
            onInsertAfter={onInsertAfter}
            onUpdateSrc={onUpdateSrc}
            onToggleEdit={onToggleEdit}
            onAddCode={onAddCode}
            onSetCellType={onSetCellType}
            onRename={onRename}
          />
        ) : (
          <NotebookIndex
            notebooks={state.notebooks}
            error={state.error}
            onOpen={onOpen}
          />
        )}

        {/* RIGHT RAIL */}
        <RightRail channelOpen={state.channelOpen} kelvins={state.kelvins} />

      </div>
    </div>
  )
}

function RightRail({ channelOpen, kelvins }: { channelOpen: boolean; kelvins: Kelvins | null }) {
  const kv = kelvins ?? { zuse: 420, arvo: 240, hoon: 140, nock: 4, port: parseInt(window.location.port) || 80 }
  return (
    <div style={{ position: 'absolute', top: 116, right: 10, bottom: 10, width: 156, display: 'flex', flexDirection: 'column', gap: 7, fontFamily: "'JetBrains Mono', monospace" }}>
      {/* KELVIN */}
      <div style={{ background: '#0c0c0e', borderRadius: '18px 0 0 0', border: '1px solid #1a1814', padding: '13px 15px' }}>
        <div style={{ color: '#6b5a3c', fontSize: 9, letterSpacing: '.22em', marginBottom: 9 }}>KELVIN</div>
        {([['ZUSE', String(kv.zuse), '#ff8866'], ['ARVO', String(kv.arvo), '#6c8cff'], ['HOON', String(kv.hoon), '#cc88ff'], ['NOCK', String(kv.nock), '#ff9900']] as const).map(([label, val, color]) => (
          <div key={label} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', margin: '5px 0' }}>
            <span style={{ color: '#9a8458', fontSize: 12 }}>{label}</span>
            <span style={{ color, fontSize: 17, fontWeight: 700 }}>{val}</span>
          </div>
        ))}
      </div>

      {/* SHIP PORT */}
      <div style={{ background: '#6c8cff', color: '#000', padding: '11px 15px', display: 'flex', flexDirection: 'column', gap: 2 }}>
        <span style={{ fontSize: 9, letterSpacing: '.18em', opacity: .7 }}>SHIP PORT</span>
        <span style={{ fontSize: 15, fontWeight: 700 }}>:{kv.port}</span>
      </div>

      {/* EYRE CHANNEL */}
      <div style={{ background: '#cc88ff', color: '#000', padding: '11px 15px', display: 'flex', flexDirection: 'column', gap: 2 }}>
        <span style={{ fontSize: 9, letterSpacing: '.18em', opacity: .7 }}>EYRE CHANNEL</span>
        <span style={{ fontSize: 15, fontWeight: 700, display: 'flex', alignItems: 'center', gap: 6 }}>
          <span style={{ width: 8, height: 8, borderRadius: '50%', background: channelOpen ? '#143a18' : '#3a1414', animation: channelOpen ? 'lcpulse 1.6s infinite' : 'none', display: 'inline-block' }} />
          :{kv.port} {channelOpen ? 'OPEN' : 'CLOSED'}
        </span>
      </div>

      {/* MARK */}
      <div style={{ background: '#0c0c0e', border: '1px solid #1a1814', padding: '11px 15px', color: '#5a4a2c', fontSize: 10, lineHeight: 1.5, letterSpacing: '.02em' }}>
        <div style={{ color: '#6b5a3c', fontSize: 9, letterSpacing: '.2em', marginBottom: 6 }}>MARK</div>
        <div style={{ color: '#9a8458' }}>%cnb-action</div>
        <div style={{ color: '#9a8458' }}>%cnb-update</div>
        <div style={{ marginTop: 4, color: '#5a8a5f' }}>fact · %json SSE</div>
      </div>

      <div style={{ flex: 1 }} />

      {/* DESK HASH */}
      <div style={{ background: '#0c0c0e', border: '1px solid #1a1814', borderRadius: '0 0 0 24px', padding: '13px 15px' }}>
        <div style={{ color: '#6b5a3c', fontSize: 9, letterSpacing: '.2em', marginBottom: 9 }}>DESK HASH</div>
        <div style={{ margin: '6px 0' }}>
          <div style={{ color: '#cc88ff', fontSize: 13, fontWeight: 700 }}>%caderno</div>
          <div style={{ color: '#6b5a3c', fontSize: 11 }}>9df1c</div>
        </div>
        <div style={{ margin: '6px 0' }}>
          <div style={{ color: '#d9a441', fontSize: 13, fontWeight: 700 }}>%base</div>
          <div style={{ color: '#6b5a3c', fontSize: 11 }}>6f05p</div>
        </div>
      </div>
    </div>
  )
}
