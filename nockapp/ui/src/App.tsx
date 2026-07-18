import { useEffect, useReducer, useCallback, useRef } from 'react'
import {
  fetchState, actions,
  type Notebook, type Cell, type Snapshot,
} from './api'
import { NotebookIndex } from './components/NotebookIndex'
import { NotebookView } from './components/NotebookView'

// ── state ────────────────────────────────────────────────────────────────────

type AppState = {
  view: 'list' | 'nb'
  active: string | null
  notebooks: NbEntry[]
  online: boolean
  error: string | null
  //  Cells with an in-flight run request. Evaluation on the backend is
  //  synchronous — there is no %running status to subscribe to — so this
  //  tracks the HTTP round trip and nothing else. It always clears when the
  //  request settles.
  pending: Set<number>
}

export type NbEntry = {
  id: string
  name: string
  stardate: string
  kernel: string
  status: 'new' | 'edited' | 'saved'
  cells: CellEntry[]
  //  A snapshot carries cells only for the notebook that is active, so an
  //  entry we have only ever seen in `nb-list` has none. False means "cells
  //  unknown", not "no cells".
  loaded: boolean
}

export type CellEntry = {
  id: number
  type: 'code' | 'markdown'
  src: string
  out: { ok: boolean; text: string } | null
  count: number | null
  editing: boolean
  fresh?: boolean  // true for cells that appeared in the last snapshot → autoFocus
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
  | { type: 'snapshot'; snap: Snapshot; dirty: Set<number> }
  | { type: 'error'; msg: string }
  | { type: 'set-view'; view: 'list' | 'nb'; id?: string }
  | { type: 'set-src'; id: number; src: string }
  | { type: 'toggle-edit'; id: number }
  | { type: 'set-cell-type'; id: number; cellType: 'code' | 'markdown' }
  | { type: 'rename-nb'; title: string }
  | { type: 'run-begin'; ids: number[] }
  | { type: 'run-end'; ids: number[] }

//  Fold a snapshot's notebook into the entry we already hold, so purely local
//  editor state survives. `dirty` is the set of cells whose source the user has
//  typed into since the last write we sent; the backend's copy of those is
//  known-stale, so the local text wins until the write lands.
function mergeNotebook(old: NbEntry | undefined, id: string, nb: Notebook, dirty: Set<number>): NbEntry {
  const oldCells = new Map((old?.cells ?? []).map(c => [c.id, c]))
  //  Only autofocus/open cells that appeared *after* we had already seen this
  //  notebook's cells — otherwise the first load would focus everything.
  const seen = old?.loaded ?? false
  const cells = nb.cells.map(c => {
    const entry = cellToEntry(c)
    const prev = oldCells.get(c.id)
    if (prev) {
      return { ...entry, editing: prev.editing, src: dirty.has(c.id) ? prev.src : entry.src }
    }
    if (!seen) return entry
    //  A new markdown cell opens straight into its editor; a new code cell
    //  gets autoFocus on its textarea.
    return c.type === 'markdown' ? { ...entry, editing: true } : { ...entry, fresh: true }
  })
  return {
    id,
    name: nb.title,
    stardate: old?.stardate ?? toUrbitDate(Date.now()),
    kernel: nb.kernel,
    status: 'saved',
    cells,
    loaded: true,
  }
}

function reducer(state: AppState, action: Action): AppState {
  switch (action.type) {
    //  Every backend response is a full snapshot: the active notebook in
    //  full, plus id/title for every notebook. Non-active notebooks carry no
    //  cells, so we keep whatever we last loaded for them.
    case 'snapshot': {
      const activeId = action.snap.state.id
      const prev = new Map(state.notebooks.map(n => [n.id, n]))
      const notebooks = action.snap['nb-list'].map(item => {
        const old = prev.get(item.id)
        if (item.id === activeId) {
          return mergeNotebook(old, item.id, action.snap.state.nb, action.dirty)
        }
        return old
          ? { ...old, name: item.title }
          : {
            id: item.id, name: item.title, stardate: toUrbitDate(Date.now()),
            kernel: 'hoon', status: 'saved' as const, cells: [], loaded: false,
          }
      })
      return { ...state, notebooks, active: activeId, online: true, error: null }
    }
    case 'error':
      return { ...state, error: action.msg, online: false }
    case 'set-view':
      return { ...state, view: action.view, active: action.id ?? state.active }
    case 'set-src':
      return mutCells(state, action.id, c => ({ ...c, src: action.src }))
    case 'toggle-edit':
      return mutCells(state, action.id, c => ({ ...c, editing: !c.editing }))
    //  Optimistic, so the row does not flicker while the request is in flight;
    //  the snapshot that follows confirms it.
    case 'set-cell-type':
      return mutCells(state, action.id, c => ({ ...c, type: action.cellType, out: null, count: null }))
    case 'rename-nb': {
      if (!state.active) return state
      return mutNb(state, state.active, n => ({ ...n, name: action.title }))
    }
    case 'run-begin': {
      const pending = new Set(state.pending)
      for (const id of action.ids) pending.add(id)
      return { ...state, pending }
    }
    case 'run-end': {
      const pending = new Set(state.pending)
      for (const id of action.ids) pending.delete(id)
      return { ...state, pending }
    }
    default: return state
  }
}

function mutNb(state: AppState, id: string, fn: (n: NbEntry) => NbEntry): AppState {
  return { ...state, notebooks: state.notebooks.map(n => n.id === id ? fn(n) : n) }
}

function mutCells(state: AppState, cellId: number, fn: (c: CellEntry) => CellEntry): AppState {
  if (!state.active) return state
  return mutNb(state, state.active, n => ({ ...n, cells: n.cells.map(c => c.id === cellId ? fn(c) : c) }))
}

// ── component ────────────────────────────────────────────────────────────────

export default function App() {
  const [state, dispatch] = useReducer(reducer, {
    view: 'list', active: null, notebooks: [], online: false, error: null,
    pending: new Set<number>(),
  })
  const stateRef = useRef(state)
  stateRef.current = state

  //  Cells the user has typed into since the last source write we sent, and a
  //  per-cell sequence number so a stale write's completion cannot clear a
  //  keystroke that arrived after it.
  const dirty = useRef(new Set<number>())
  const srcSeq = useRef(new Map<number, number>())
  const bumpSrc = (id: number) => {
    const n = (srcSeq.current.get(id) ?? 0) + 1
    srcSeq.current.set(id, n)
    dirty.current.add(id)
    return n
  }
  const settleSrc = (id: number, n: number) => {
    if (srcSeq.current.get(id) === n) dirty.current.delete(id)
  }

  const apply = useCallback((snap: Snapshot) => {
    dispatch({ type: 'snapshot', snap, dirty: new Set(dirty.current) })
  }, [])

  //  Every backend call funnels through here: apply the snapshot, or surface
  //  the error. Returns the snapshot so callers can chain on it.
  const send = useCallback(async (p: Promise<Snapshot>): Promise<Snapshot | null> => {
    try {
      const snap = await p
      apply(snap)
      return snap
    } catch (e) {
      dispatch({ type: 'error', msg: e instanceof Error ? e.message : String(e) })
      return null
    }
  }, [apply])

  useEffect(() => { send(fetchState()) }, [send])

  const activeNb = state.notebooks.find(n => n.id === state.active) ?? null

  // callbacks
  const onRunAll = () => {
    const ids = (stateRef.current.notebooks.find(n => n.id === stateRef.current.active)?.cells ?? [])
      .filter(c => c.type === 'code').map(c => c.id)
    dispatch({ type: 'run-begin', ids })
    send(actions.runAll()).finally(() => dispatch({ type: 'run-end', ids }))
  }
  const onAddCode = () => { send(actions.insertCell(null, 'code')) }
  const onAddText = () => { send(actions.insertCell(null, 'markdown')) }
  const onBack = () => dispatch({ type: 'set-view', view: 'list' })
  const onResetSubject = () => { send(actions.resetSubject()) }
  const onNewNb = async () => {
    const snap = await send(actions.newNotebook())
    //  %new-notebook switches the backend's active notebook; follow it.
    if (snap) dispatch({ type: 'set-view', view: 'nb', id: snap.state.id })
  }
  const onOpen = (id: string) => {
    dispatch({ type: 'set-view', view: 'nb', id })
    send(actions.switchNotebook(id))
  }
  const onDeleteNb = (id: string) => { send(actions.deleteNotebook(id)) }

  const srcDebounce = useRef(new Map<number, ReturnType<typeof setTimeout>>())

  const onRunCell = useCallback((id: number) => {
    const nb = stateRef.current.notebooks.find(n => n.id === stateRef.current.active)
    const cell = nb?.cells.find(c => c.id === id)
    if (cell?.type === 'markdown') {
      dispatch({ type: 'toggle-edit', id })
      return
    }
    //  Cancel any pending debounced source update and send it immediately
    //  before the run, so the backend evaluates what is on screen.
    const timeout = srcDebounce.current.get(id)
    const flush = timeout !== undefined && cell !== undefined
    if (timeout !== undefined) {
      clearTimeout(timeout)
      srcDebounce.current.delete(id)
    }
    const seq = srcSeq.current.get(id) ?? 0
    dispatch({ type: 'run-begin', ids: [id] })
    const p = flush ? actions.runCellFlushed(id, cell!.src) : actions.runCell(id)
    //  The run's snapshot is authoritative for this cell's source, so drop the
    //  dirty flag first — unless the user typed again while it was in flight.
    p.then(() => settleSrc(id, seq), () => {})
    send(p).finally(() => dispatch({ type: 'run-end', ids: [id] }))
  }, [send])

  const onDelete = (id: number) => { send(actions.deleteCell(id)) }
  const onInsertAfter = (id: number) => { send(actions.insertCell(id, 'code')) }

  const onUpdateSrc = useCallback((id: number, src: string) => {
    dispatch({ type: 'set-src', id, src })
    const seq = bumpSrc(id)
    const prev = srcDebounce.current.get(id)
    if (prev !== undefined) clearTimeout(prev)
    srcDebounce.current.set(id, setTimeout(() => {
      srcDebounce.current.delete(id)
      const p = actions.updateSource(id, src)
      p.then(() => settleSrc(id, seq), () => {})
      send(p)
    }, 400))
  }, [send])

  const onToggleEdit = (id: number) => dispatch({ type: 'toggle-edit', id })
  const onSetCellType = (id: number, cellType: 'code' | 'markdown') => {
    dispatch({ type: 'set-cell-type', id, cellType })
    send(actions.setCellType(id, cellType))
  }
  const onRename = (title: string) => {
    dispatch({ type: 'rename-nb', title })
    send(actions.setTitle(title))
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
            <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 11, color: '#3a2400', letterSpacing: '.34em', marginTop: 3 }}>LCARS · NOTEBOOK · NOCKAPP</span>
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
              <div style={{ color: '#6b5a3c', fontSize: 10, letterSpacing: '.24em', padding: '2px 14px 0', textAlign: 'right' }}>HOON KERNEL</div>
              <div className="lc-press" onClick={onRunAll} style={{ height: 54, borderRadius: '0 30px 30px 0', background: '#cc88ff', color: '#000', display: 'flex', alignItems: 'center', justifyContent: 'flex-end', paddingRight: 20, fontWeight: 700, fontSize: 17, letterSpacing: '.06em' }}>RUN ALL ▶</div>
              <div className="lc-press" onClick={onAddCode} style={{ height: 50, borderRadius: '0 30px 30px 0', background: '#6c8cff', color: '#000', display: 'flex', alignItems: 'center', justifyContent: 'flex-end', paddingRight: 20, fontWeight: 700, fontSize: 16, letterSpacing: '.04em' }}>+ CODE</div>
              <div className="lc-press" onClick={onAddText} style={{ height: 50, borderRadius: '0 30px 30px 0', background: '#ff8866', color: '#000', display: 'flex', alignItems: 'center', justifyContent: 'flex-end', paddingRight: 20, fontWeight: 700, fontSize: 16, letterSpacing: '.04em' }}>+ TEXT</div>
              <div className="lc-press" onClick={onBack} style={{ height: 50, borderRadius: '0 30px 30px 0', background: '#d9a441', color: '#000', display: 'flex', alignItems: 'center', justifyContent: 'flex-end', paddingRight: 20, fontWeight: 700, fontSize: 16, letterSpacing: '.04em' }}>◂ INDEX</div>
              <div className="lc-press" onClick={onResetSubject} title="Drop the accumulated Hoon subject" style={{ height: 50, borderRadius: '0 30px 30px 0', background: '#3a2a10', color: '#9a8147', display: 'flex', alignItems: 'center', justifyContent: 'flex-end', paddingRight: 20, fontWeight: 700, fontSize: 14, letterSpacing: '.04em' }}>RESET ENV</div>
            </>
          ) : (
            <>
              <div style={{ color: '#6b5a3c', fontSize: 10, letterSpacing: '.24em', padding: '2px 14px 0', textAlign: 'right' }}>STORE · CHECKPOINT</div>
              <div className="lc-press" onClick={onNewNb} style={{ height: 62, borderRadius: '0 0 0 26px', background: '#cc88ff', color: '#000', display: 'flex', alignItems: 'center', justifyContent: 'flex-end', paddingRight: 20, fontWeight: 700, fontSize: 18, letterSpacing: '.03em' }}>+ NEW NOTEBOOK</div>
              <div style={{ height: 50, borderRadius: '0 30px 30px 0', background: '#6c8cff', color: '#000', display: 'flex', alignItems: 'center', justifyContent: 'flex-end', paddingRight: 20, fontWeight: 700, fontSize: 15, letterSpacing: '.03em' }}>{state.notebooks.length} BUFFERS</div>
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
              <div style={{ color: '#cc88ff', fontSize: 18, fontWeight: 500 }}>{(activeNb?.kernel ?? 'hoon').toUpperCase()}</div>
            </div>
            <div>
              <div style={{ color: '#6b5a3c', fontSize: 10, letterSpacing: '.2em' }}>API</div>
              <div style={{ color: state.online ? '#99e6a3' : '#9a8147', fontSize: 18, fontWeight: 500 }}>
                {state.online ? 'ONLINE' : 'OFFLINE'}
              </div>
            </div>
          </div>
        </div>

        {/* CENTER */}
        {state.view === 'nb' && activeNb ? (
          <NotebookView
            nb={activeNb}
            running={state.pending}
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
            onDelete={onDeleteNb}
          />
        )}

        {/* RIGHT RAIL */}
        <RightRail online={state.online} />

      </div>
    </div>
  )
}

function RightRail({ online }: { online: boolean }) {
  const host = window.location.host || '127.0.0.1:8080'
  return (
    <div style={{ position: 'absolute', top: 116, right: 10, bottom: 10, width: 156, display: 'flex', flexDirection: 'column', gap: 7, fontFamily: "'JetBrains Mono', monospace" }}>
      {/* HOST */}
      <div style={{ background: '#6c8cff', color: '#000', borderRadius: '18px 0 0 0', padding: '11px 15px', display: 'flex', flexDirection: 'column', gap: 2 }}>
        <span style={{ fontSize: 9, letterSpacing: '.18em', opacity: .7 }}>HOST</span>
        <span style={{ fontSize: 14, fontWeight: 700, wordBreak: 'break-all' }}>{host}</span>
      </div>

      {/* API */}
      <div style={{ background: '#cc88ff', color: '#000', padding: '11px 15px', display: 'flex', flexDirection: 'column', gap: 2 }}>
        <span style={{ fontSize: 9, letterSpacing: '.18em', opacity: .7 }}>API</span>
        <span style={{ fontSize: 15, fontWeight: 700, display: 'flex', alignItems: 'center', gap: 6 }}>
          <span style={{ width: 8, height: 8, borderRadius: '50%', background: online ? '#143a18' : '#3a1414', animation: online ? 'lcpulse 1.6s infinite' : 'none', display: 'inline-block' }} />
          {online ? 'ONLINE' : 'OFFLINE'}
        </span>
      </div>

      {/* ROUTES */}
      <div style={{ background: '#0c0c0e', border: '1px solid #1a1814', padding: '11px 15px', color: '#5a4a2c', fontSize: 10, lineHeight: 1.5, letterSpacing: '.02em' }}>
        <div style={{ color: '#6b5a3c', fontSize: 9, letterSpacing: '.2em', marginBottom: 6 }}>ROUTES</div>
        <div style={{ color: '#9a8458' }}>POST /api/state</div>
        <div style={{ color: '#9a8458' }}>POST /api/action</div>
        <div style={{ marginTop: 4, color: '#5a8a5f' }}>201 · SNAPSHOT</div>
      </div>

      <div style={{ flex: 1 }} />

      {/* RUNTIME */}
      <div style={{ background: '#0c0c0e', border: '1px solid #1a1814', borderRadius: '0 0 0 24px', padding: '13px 15px' }}>
        <div style={{ color: '#6b5a3c', fontSize: 9, letterSpacing: '.2em', marginBottom: 9 }}>RUNTIME</div>
        <div style={{ margin: '6px 0' }}>
          <div style={{ color: '#cc88ff', fontSize: 13, fontWeight: 700 }}>nockvm</div>
          <div style={{ color: '#6b5a3c', fontSize: 11 }}>out.jam</div>
        </div>
        <div style={{ margin: '6px 0' }}>
          <div style={{ color: '#d9a441', fontSize: 13, fontWeight: 700 }}>hoon</div>
          <div style={{ color: '#6b5a3c', fontSize: 11 }}>in-process</div>
        </div>
      </div>
    </div>
  )
}
