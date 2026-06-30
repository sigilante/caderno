import { useState } from 'react'
import './Sidebar.css'

const KNOWN_KERNELS = [
  { id: 'hoon',  label: 'Hoon',  color: 'var(--purple)', builtin: true },
  { id: 'north', label: 'North', color: 'var(--blue)',   builtin: false },
  { id: 'dojo',  label: 'Dojo',  color: 'var(--red)',    builtin: false },
]

interface Props {
  kernel: string
  availableAgents: string[]
  onSetKernel: (k: string) => void
  onRunAll: () => void
  onInsert: () => void
}

export default function Sidebar({ kernel, availableAgents, onSetKernel, onRunAll, onInsert }: Props) {
  const [otherValue, setOtherValue] = useState('')
  const [showOther, setShowOther] = useState(false)

  const isCustomKernel = !KNOWN_KERNELS.some(k => k.id === kernel)

  function submitOther(e: React.FormEvent) {
    e.preventDefault()
    const val = otherValue.trim().replace(/^%/, '')
    if (val) { onSetKernel(val); setShowOther(false) }
  }

  return (
    <aside className="sidebar">
      <header className="sidebar-header">
        <span className="sidebar-logo">caderno</span>
      </header>

      <div className="sidebar-body">
        <p className="sidebar-label">kernel</p>

        {KNOWN_KERNELS.map(k => {
          const available = k.builtin || availableAgents.includes(k.id)
          return (
            <button
              key={k.id}
              className={`kernel-pill ${kernel === k.id ? 'active' : ''} ${!available ? 'unavailable' : ''}`}
              style={{ '--pill-color': k.color } as React.CSSProperties}
              onClick={() => available && onSetKernel(k.id)}
              title={available ? undefined : `${k.label} not running`}
            >
              {k.label}
              {!available && <span className="pill-dot">·</span>}
            </button>
          )
        })}

        {isCustomKernel && (
          <button
            className="kernel-pill active"
            style={{ '--pill-color': 'var(--gold)' } as React.CSSProperties}
          >
            %{kernel}
          </button>
        )}

        {showOther ? (
          <form className="other-form" onSubmit={submitOther}>
            <input
              className="other-input"
              placeholder="agent name"
              value={otherValue}
              onChange={e => setOtherValue(e.target.value)}
              autoFocus
            />
            <button type="submit" className="other-submit">→</button>
          </form>
        ) : (
          <button className="sidebar-action" onClick={() => setShowOther(true)}>other…</button>
        )}

        <hr className="sidebar-divider" />

        <button className="sidebar-action" onClick={onInsert}>+ cell</button>
        <button className="sidebar-action" onClick={onRunAll}>▶ run all</button>
      </div>
    </aside>
  )
}
