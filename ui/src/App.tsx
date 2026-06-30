import { useEffect, useReducer, useCallback, useState } from 'react'
import { fetchNotebook, fetchSoleSessions, openChannel, closeChannel, actions, type Notebook, type Cell, type Output, type Update } from './api'
import Sidebar from './components/Sidebar'
import CellList from './components/CellList'
import './App.css'

type State = {
  notebook: Notebook | null
  running: Set<number>
  error: string | null
}

type Action =
  | { type: 'loaded'; nb: Notebook }
  | { type: 'cell-output'; id: number; out: Output }
  | { type: 'cell-status'; id: number; status: string }
  | { type: 'cell-added'; cell: Cell }
  | { type: 'cell-deleted'; id: number }
  | { type: 'error'; msg: string }

function reducer(state: State, action: Action): State {
  switch (action.type) {
    case 'loaded':
      return { ...state, notebook: action.nb, error: null }
    case 'cell-status': {
      const running = new Set(state.running)
      if (action.status === 'running') running.add(action.id)
      else running.delete(action.id)
      return { ...state, running }
    }
    case 'cell-output': {
      if (!state.notebook) return state
      const cells = state.notebook.cells.map(c =>
        c.id === action.id ? { ...c, outputs: [action.out] } : c
      )
      return { ...state, notebook: { ...state.notebook, cells } }
    }
    case 'cell-added': {
      if (!state.notebook) return state
      return { ...state, notebook: { ...state.notebook, cells: [...state.notebook.cells, action.cell] } }
    }
    case 'cell-deleted': {
      if (!state.notebook) return state
      return { ...state, notebook: { ...state.notebook, cells: state.notebook.cells.filter(c => c.id !== action.id) } }
    }
    case 'error':
      return { ...state, error: action.msg }
  }
}

const KNOWN_SHOE_AGENTS = ['north', 'dojo']

export default function App() {
  const [state, dispatch] = useReducer(reducer, { notebook: null, running: new Set<number>(), error: null })
  const [availableAgents, setAvailableAgents] = useState<string[]>([])

  useEffect(() => {
    Promise.all(KNOWN_SHOE_AGENTS.map(a => fetchSoleSessions(a).then(s => s !== null ? a : null)))
      .then(results => setAvailableAgents(results.filter((a): a is string => a !== null)))
  }, [])

  const handleUpdate = useCallback((upd: Update) => {
    if ('state' in upd)          dispatch({ type: 'loaded', nb: upd['state'].nb })
    else if ('cell-output' in upd)  dispatch({ type: 'cell-output', id: upd['cell-output'].id, out: upd['cell-output'].out })
    else if ('cell-status' in upd)  dispatch({ type: 'cell-status', id: upd['cell-status'].id, status: upd['cell-status'].status })
    else if ('cell-added' in upd)   dispatch({ type: 'cell-added', cell: upd['cell-added'].c })
    else if ('cell-deleted' in upd) dispatch({ type: 'cell-deleted', id: upd['cell-deleted'].id })
  }, [])

  useEffect(() => {
    fetchNotebook()
      .then(nb => dispatch({ type: 'loaded', nb }))
      .catch(() => dispatch({ type: 'error', msg: 'Could not reach ship' }))
    openChannel(handleUpdate)
    return () => { closeChannel() }
  }, [handleUpdate])

  const nb = state.notebook

  return (
    <div className="app">
      <Sidebar
        kernel={nb?.kernel ?? 'hoon'}
        availableAgents={availableAgents}
        onSetKernel={actions.setKernel}
        onRunAll={actions.runAll}
        onInsert={() => actions.insertCell(null, 'code')}
      />
      <div className="main-col">
        <div className="title-bar">
          <input
            value={nb?.title ?? ''}
            placeholder="untitled"
            readOnly
          />
        </div>
        <main className="main">
          {state.error && <div className="error-banner">{state.error}</div>}
          {nb && (
            <CellList
              cells={nb.cells}
              running={state.running}
              onRun={actions.runCell}
              onDelete={actions.deleteCell}
              onUpdateSource={actions.updateSource}
              onInsertAfter={(id) => actions.insertCell(id, 'code')}
            />
          )}
          {!nb && !state.error && <div className="loading">connecting…</div>}
        </main>
      </div>
    </div>
  )
}
