import type { NbEntry } from '../App'

const SWATCHES = ['#cc88ff', '#6c8cff', '#ff8866', '#d9a441', '#66ccff', '#cc5a3a']

interface Props {
  notebooks: NbEntry[]
  error: string | null
  onOpen: (id: string) => void
}

export function NotebookIndex({ notebooks, error, onOpen }: Props) {
  // The backend lists notebooks in map-hash order; present them alphabetically
  // by title so the index is stable and scannable.
  const sorted = [...notebooks].sort((a, b) =>
    a.name.localeCompare(b.name, undefined, { sensitivity: 'base' }))
  return (
    <div
      className="lc-scroll"
      style={{ position: 'absolute', top: 116, left: 256, right: 176, bottom: 10, overflowY: 'auto' }}
    >
      <div style={{ padding: '6px 24px 60px' }}>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 14, margin: '4px 0 22px' }}>
          <span style={{ fontSize: 30, fontWeight: 600, color: '#cc88ff', letterSpacing: '.02em' }}>NOTEBOOK INDEX</span>
          <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 12, color: '#6b5a3c', letterSpacing: '.18em' }}>CLAY · /caderno</span>
        </div>

        {error && (
          <div style={{ fontFamily: "'JetBrains Mono', monospace", color: '#ff9d80', fontSize: 13, marginBottom: 16 }}>
            {error}
          </div>
        )}

        {notebooks.length === 0 && !error && (
          <div style={{ fontFamily: "'JetBrains Mono', monospace", color: '#6b5a3c', fontSize: 12, letterSpacing: '.1em' }}>
            CONNECTING…
          </div>
        )}

        {sorted.map((nb, idx) => (
          <div
            key={nb.id}
            className="lc-press"
            onClick={() => onOpen(nb.id)}
            style={{ display: 'flex', alignItems: 'stretch', gap: 12, marginBottom: 10 }}
          >
            {/* swatch */}
            <div style={{
              flex: '0 0 150px',
              borderRadius: '0 0 0 22px',
              background: SWATCHES[idx % SWATCHES.length],
              color: '#000',
              padding: '14px 18px',
              display: 'flex',
              flexDirection: 'column',
              justifyContent: 'space-between',
            }}>
              <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 11, letterSpacing: '.12em', fontWeight: 700 }}>
                {nb.kernel.toUpperCase()}
              </span>
              <span style={{ fontFamily: "'Antonio', sans-serif", fontSize: 30, fontWeight: 700, lineHeight: .9 }}>
                {nb.cells.length}
                <span style={{ fontSize: 12, fontFamily: "'JetBrains Mono', monospace", letterSpacing: '.1em' }}> CELLS</span>
              </span>
            </div>
            {/* body */}
            <div style={{
              flex: 1,
              background: '#0c0c0e',
              border: '1px solid #1a1814',
              borderRadius: '0 22px 22px 0',
              padding: '14px 22px',
              display: 'flex',
              alignItems: 'center',
            }}>
              <div>
                <div style={{ fontFamily: "'Antonio', sans-serif", fontSize: 25, fontWeight: 600, color: '#ffd9a8' }}>{nb.name}</div>
                <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 12, color: '#6b5a3c', letterSpacing: '.06em', marginTop: 3 }}>
                  SD {nb.stardate} &nbsp;·&nbsp; {(nb.status || 'saved').toUpperCase()}
                </div>
              </div>
              <span style={{ marginLeft: 'auto', color: '#cc88ff', fontSize: 26 }}>▶</span>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
