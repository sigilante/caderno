import { useState, useRef, useEffect } from 'react'
import type { Cell } from '../api'
import './CellView.css'

interface Props {
  cell: Cell
  isRunning: boolean
  onRun: () => void
  onDelete: () => void
  onUpdateSource: (src: string) => void
  onInsertAfter: () => void
}

export default function CellView({ cell, isRunning, onRun, onDelete, onUpdateSource, onInsertAfter }: Props) {
  const [source, setSource] = useState(cell.source)
  const textareaRef = useRef<HTMLTextAreaElement>(null)

  useEffect(() => { setSource(cell.source) }, [cell.source])

  useEffect(() => {
    const el = textareaRef.current
    if (!el) return
    el.style.height = 'auto'
    el.style.height = `${el.scrollHeight}px`
  }, [source])

  function handleBlur() {
    if (source !== cell.source) onUpdateSource(source)
  }

  function handleKeyDown(e: React.KeyboardEvent) {
    if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
      e.preventDefault()
      if (source !== cell.source) onUpdateSource(source)
      onRun()
    }
  }

  const output = cell.outputs[0]
  const hasError = output && 'ename' in output
  const isEmpty = source.trim() === '' && !output

  return (
    <div className={`cell ${isEmpty ? 'empty' : ''} ${isRunning ? 'running' : ''} ${hasError ? 'has-error' : ''}`}>
      <div className="cell-source-row">
        <div className="cell-gutter">
          <span className="exec-count">
            {isRunning ? '●' : cell.exec_count != null ? `[${cell.exec_count}]` : '[ ]'}
          </span>
          <button className="run-btn" onClick={onRun} title="Run (⌘↵)" disabled={isRunning}>
            ▶
          </button>
        </div>

        <div className="cell-body">
          <textarea
            ref={textareaRef}
            className="cell-source"
            value={source}
            onChange={e => setSource(e.target.value)}
            onBlur={handleBlur}
            onKeyDown={handleKeyDown}
            placeholder="hoon expression…"
            spellCheck={false}
            rows={1}
          />
        </div>

        <div className="cell-actions">
          <button className="cell-btn" onClick={onInsertAfter} title="Insert below">+</button>
          <button className="cell-btn cell-btn-delete" onClick={onDelete} title="Delete">×</button>
        </div>
      </div>

      {output && (
        <div className={`cell-output-row ${hasError ? 'output-error' : ''}`}>
          {hasError
            ? <><span className="error-name">{output.ename}</span>: {output.evalue}</>
            : output.text
          }
        </div>
      )}
    </div>
  )
}
