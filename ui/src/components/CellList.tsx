import type { Cell } from '../api'
import CellView from './CellView'
import './CellList.css'

interface Props {
  cells: Cell[]
  running: Set<number>
  onRun: (id: number) => void
  onDelete: (id: number) => void
  onUpdateSource: (id: number, src: string) => void
  onInsertAfter: (id: number) => void
}

export default function CellList({ cells, running, onRun, onDelete, onUpdateSource, onInsertAfter }: Props) {
  if (cells.length === 0) {
    return (
      <div className="empty-state">
        <p>no cells — use <kbd>+ cell</kbd> to add one</p>
      </div>
    )
  }

  return (
    <div className="cell-list">
      {cells.map(cell => (
        <CellView
          key={cell.id}
          cell={cell}
          isRunning={running.has(cell.id)}
          onRun={() => onRun(cell.id)}
          onDelete={() => onDelete(cell.id)}
          onUpdateSource={(src) => onUpdateSource(cell.id, src)}
          onInsertAfter={() => onInsertAfter(cell.id)}
        />
      ))}
    </div>
  )
}
