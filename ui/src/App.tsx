import { useEffect, useReducer, useCallback, useRef } from 'react'
import {
  fetchNotebook, openChannel, closeChannel, actions,
  type Notebook, type Cell, type Output, type Update,
} from './api'
import { NotebookIndex } from './components/NotebookIndex'
import { NotebookView } from './components/NotebookView'

// ── state ────────────────────────────────────────────────────────────────────

type AppState = {
  view: 'list' | 'nb'
  active: string | null
  notebooks: NbEntry[]
  channelOpen: boolean
  error: string | null
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
}

function notebookToEntry(nb: Notebook): NbEntry {
  return {
    id: nb.title,
    name: nb.title,
    stardate: toStardate(Date.now()),
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

function toStardate(ms: number): string {
  // approximate stardate from real time
  const base = 2318
  const year = new Date(ms).getFullYear()
  const frac = (ms - new Date(year, 0, 1).getTime()) /
    (new Date(year + 1, 0, 1).getTime() - new Date(year, 0, 1).getTime())
  return ((year - 1987) * 1000 + frac * 1000 + base).toFixed(1)
}

type Action =
  | { type: 'loaded'; nb: Notebook }
  | { type: 'cell-output'; id: number; out: Output }
  | { type: 'cell-status'; id: number; status: string }
  | { type: 'cell-added'; cell: Cell }
  | { type: 'cell-deleted'; id: number }
  | { type: 'channel-open' }
  | { type: 'error'; msg: string }
  | { type: 'set-view'; view: 'list' | 'nb'; id?: string }
  | { type: 'set-kernel'; kernel: string }
  | { type: 'set-src'; id: number; src: string }
  | { type: 'toggle-edit'; id: number }
  | { type: 'new-nb' }
  | { type: 'cell-run-result'; id: number; ok: boolean; text: string; count: number }

let _uid = 9000

function reducer(state: AppState, action: Action): AppState {
  const activeNb = () => state.notebooks.find(n => n.id === state.active) ?? null

  switch (action.type) {
    case 'loaded': {
      const entry = notebookToEntry(action.nb)
      const existing = state.notebooks.findIndex(n => n.id === entry.id)
      const notebooks = existing >= 0
        ? state.notebooks.map((n, i) => i === existing ? entry : n)
        : [...state.notebooks, entry]
      const active = state.active ?? entry.id
      return { ...state, notebooks, active, view: state.view, error: null }
    }
    case 'cell-output': {
      const out = action.out.text != null
        ? { ok: true, text: action.out.text! }
        : { ok: false, text: (action.out.ename ?? '') + ': ' + (action.out.evalue ?? '') }
      return mutCells(state, action.id, c => ({ ...c, out }))
    }
    case 'cell-status':
      return state
    case 'cell-added': {
      const nb = activeNb(); if (!nb) return state
      const ce = cellToEntry(action.cell)
      return mutNb(state, nb.id, n => ({ ...n, cells: [...n.cells, ce] }))
    }
    case 'cell-deleted': {
      const nb = activeNb(); if (!nb) return state
      return mutNb(state, nb.id, n => ({
        ...n, cells: n.cells.length > 1 ? n.cells.filter(c => c.id !== action.id) : n.cells,
      }))
    }
    case 'channel-open':
      return { ...state, channelOpen: true }
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
    case 'new-nb': {
      const id = 'nb' + (_uid++)
      const c1: CellEntry = { id: _uid++, type: 'markdown', src: '# untitled-buffer', out: null, count: null, editing: false }
      const c2: CellEntry = { id: _uid++, type: 'code', src: '', out: null, count: null, editing: false }
      const nb: NbEntry = { id, name: 'untitled-buffer', stardate: toStardate(Date.now()), kernel: 'north', status: 'new', cells: [c1, c2], counter: 0 }
      return { ...state, view: 'nb', active: id, notebooks: [...state.notebooks, nb] }
    }
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

// ── component ────────────────────────────────────────────────────────────────

export default function App() {
  const [state, dispatch] = useReducer(reducer, {
    view: 'list', active: null, notebooks: [], channelOpen: false, error: null,
  })
  const stateRef = useRef(state)
  stateRef.current = state

  const handleUpdate = useCallback((upd: Update) => {
    if ('state' in upd)           dispatch({ type: 'loaded', nb: upd['state'].nb })
    else if ('cell-output' in upd)   dispatch({ type: 'cell-output', id: upd['cell-output'].id, out: upd['cell-output'].out })
    else if ('cell-status' in upd)   dispatch({ type: 'cell-status', id: upd['cell-status'].id, status: upd['cell-status'].status })
    else if ('cell-added' in upd)    dispatch({ type: 'cell-added', cell: upd['cell-added'].c })
    else if ('cell-deleted' in upd)  dispatch({ type: 'cell-deleted', id: upd['cell-deleted'].id })
  }, [])

  useEffect(() => {
    fetchNotebook()
      .then(nb => dispatch({ type: 'loaded', nb }))
      .catch(() => dispatch({ type: 'error', msg: 'Could not reach ship' }))
    openChannel(upd => {
      dispatch({ type: 'channel-open' })
      handleUpdate(upd)
    })
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
  const onNewNb = () => dispatch({ type: 'new-nb' })
  const onOpen = (id: string) => dispatch({ type: 'set-view', view: 'nb', id })

  const onRunCell = (id: number) => { actions.runCell(id) }
  const onDelete = (id: number) => { actions.deleteCell(id) }
  const onInsertAfter = (id: number) => { actions.insertCell(id, 'code') }
  const onUpdateSrc = (id: number, src: string) => {
    dispatch({ type: 'set-src', id, src })
    actions.updateSource(id, src)
  }
  const onToggleEdit = (id: number) => dispatch({ type: 'toggle-edit', id })

  const stardate = toStardate(Date.now())

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
              <div style={{ height: 50, borderRadius: '0 30px 30px 0', background: '#3a2a10', color: state.channelOpen ? '#99e6a3' : '#9a8147', display: 'flex', alignItems: 'center', justifyContent: 'flex-end', paddingRight: 20, fontWeight: 700, fontSize: 15, letterSpacing: '.03em' }}>
                {state.channelOpen ? 'SYNCED' : 'CONNECTING'}
              </div>
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
            onRunCell={onRunCell}
            onDelete={onDelete}
            onInsertAfter={onInsertAfter}
            onUpdateSrc={onUpdateSrc}
            onToggleEdit={onToggleEdit}
            onAddCode={onAddCode}
          />
        ) : (
          <NotebookIndex
            notebooks={state.notebooks}
            error={state.error}
            onOpen={onOpen}
          />
        )}

        {/* RIGHT RAIL */}
        <RightRail channelOpen={state.channelOpen} />

      </div>
    </div>
  )
}

function RightRail({ channelOpen }: { channelOpen: boolean }) {
  return (
    <div style={{ position: 'absolute', top: 116, right: 10, bottom: 10, width: 156, display: 'flex', flexDirection: 'column', gap: 7, fontFamily: "'JetBrains Mono', monospace" }}>
      {/* KELVIN */}
      <div style={{ background: '#0c0c0e', borderRadius: '18px 0 0 0', border: '1px solid #1a1814', padding: '13px 15px' }}>
        <div style={{ color: '#6b5a3c', fontSize: 9, letterSpacing: '.22em', marginBottom: 9 }}>KELVIN</div>
        {([['NOCK', '4', '#ff9900'], ['HOON', '140', '#cc88ff'], ['ARVO', '240', '#6c8cff'], ['ZUSE', '420', '#ff8866']] as const).map(([label, val, color]) => (
          <div key={label} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', margin: '5px 0' }}>
            <span style={{ color: '#9a8458', fontSize: 12 }}>{label}</span>
            <span style={{ color, fontSize: 17, fontWeight: 700 }}>{val}</span>
          </div>
        ))}
      </div>

      {/* EYRE CHANNEL */}
      <div style={{ background: '#cc88ff', color: '#000', padding: '11px 15px', display: 'flex', flexDirection: 'column', gap: 2 }}>
        <span style={{ fontSize: 9, letterSpacing: '.18em', opacity: .7 }}>EYRE CHANNEL</span>
        <span style={{ fontSize: 15, fontWeight: 700, display: 'flex', alignItems: 'center', gap: 6 }}>
          <span style={{ width: 8, height: 8, borderRadius: '50%', background: channelOpen ? '#143a18' : '#3a1414', animation: channelOpen ? 'lcpulse 1.6s infinite' : 'none', display: 'inline-block' }} />
          :7777 {channelOpen ? 'OPEN' : 'CLOSED'}
        </span>
      </div>

      {/* MARK */}
      <div style={{ background: '#0c0c0e', border: '1px solid #1a1814', padding: '11px 15px', color: '#5a4a2c', fontSize: 10, lineHeight: 1.5, letterSpacing: '.02em' }}>
        <div style={{ color: '#6b5a3c', fontSize: 9, letterSpacing: '.2em', marginBottom: 6 }}>MARK</div>
        <div style={{ color: '#9a8458' }}>%caderno-action</div>
        <div style={{ color: '#9a8458' }}>%caderno-update</div>
        <div style={{ marginTop: 4, color: '#5a8a5f' }}>fact · %json SSE</div>
      </div>

      <div style={{ flex: 1 }} />

      {/* DESK HASH */}
      <div style={{ background: '#0c0c0e', border: '1px solid #1a1814', borderRadius: '0 0 0 24px', padding: '13px 15px' }}>
        <div style={{ color: '#6b5a3c', fontSize: 9, letterSpacing: '.2em', marginBottom: 9 }}>DESK HASH</div>
        <div style={{ margin: '6px 0' }}>
          <div style={{ color: '#cc88ff', fontSize: 13, fontWeight: 700 }}>%caderno</div>
          <div style={{ color: '#6b5a3c', fontSize: 11, wordBreak: 'break-all' }}>0v6.j8k2a.9df1c</div>
        </div>
        <div style={{ margin: '6px 0' }}>
          <div style={{ color: '#d9a441', fontSize: 13, fontWeight: 700 }}>%base</div>
          <div style={{ color: '#6b5a3c', fontSize: 11, wordBreak: 'break-all' }}>0vu.fptbs.6f05p</div>
        </div>
      </div>
    </div>
  )
}
