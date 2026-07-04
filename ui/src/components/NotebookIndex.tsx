import type { NbEntry, FollowEntry } from '../App'

const SWATCHES = ['#cc88ff', '#6c8cff', '#ff8866', '#d9a441', '#66ccff', '#cc5a3a']

interface Props {
  notebooks: NbEntry[]
  follows: FollowEntry[]
  error: string | null
  onOpen: (id: string) => void
  onDelete: (id: string) => void
  onFork: (who: string, id: string) => void
  onUnfollow: (who: string, id: string) => void
}

export function NotebookIndex({ notebooks, follows, error, onOpen, onDelete, onFork, onUnfollow }: Props) {
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
              <div style={{ marginLeft: 'auto', display: 'flex', alignItems: 'center', gap: 16 }}>
                {notebooks.length > 1 && (
                  <span
                    className="lc-press"
                    title="Delete this notebook"
                    onClick={e => {
                      e.stopPropagation()
                      if (window.confirm(`Delete "${nb.name}"? This cannot be undone.`)) onDelete(nb.id)
                    }}
                    style={{ color: '#7a3a3a', fontSize: 18, fontWeight: 700, lineHeight: 1 }}
                  >✕</span>
                )}
                <span style={{ color: '#cc88ff', fontSize: 26 }}>▶</span>
              </div>
            </div>
          </div>
        ))}

        {follows.length > 0 && (
          <>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 14, margin: '30px 0 16px' }}>
              <span style={{ fontSize: 22, fontWeight: 600, color: '#7fd4ff', letterSpacing: '.02em' }}>FOLLOWING</span>
              <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 12, color: '#4a6b7c', letterSpacing: '.18em' }}>READ-ONLY · REMOTE</span>
            </div>
            {follows.map(f => (
              <div key={`${f.who}/${f.id}`} style={{ display: 'flex', alignItems: 'stretch', gap: 12, marginBottom: 10 }}>
                <div style={{ flex: '0 0 150px', borderRadius: '0 0 0 22px', background: '#1c3040', color: '#7fd4ff', padding: '14px 18px', display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
                  <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 11, letterSpacing: '.08em', fontWeight: 700, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{f.who}</span>
                  <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 12, letterSpacing: '.04em' }}>{f.id}</span>
                </div>
                <div style={{ flex: 1, background: '#0c0c0e', border: '1px solid #14202a', borderRadius: '0 22px 22px 0', padding: '14px 22px', display: 'flex', alignItems: 'center', gap: 12 }}>
                  <div style={{ fontFamily: "'Antonio', sans-serif", fontSize: 25, fontWeight: 600, color: '#bfe8ff' }}>{f.title}</div>
                  <div style={{ marginLeft: 'auto', display: 'flex', gap: 8 }}>
                    <span className="lc-press" onClick={() => onFork(f.who, f.id)} title="Copy into an editable local notebook" style={{ background: '#2a2438', color: '#b79ae0', borderRadius: 16, padding: '7px 14px', fontFamily: "'JetBrains Mono', monospace", fontSize: 12, fontWeight: 700 }}>FORK</span>
                    <span className="lc-press" onClick={() => onUnfollow(f.who, f.id)} title="Stop following" style={{ background: '#2a1414', color: '#e0a0a0', borderRadius: 16, padding: '7px 14px', fontFamily: "'JetBrains Mono', monospace", fontSize: 12, fontWeight: 700 }}>✕</span>
                  </div>
                </div>
              </div>
            ))}
          </>
        )}
      </div>
    </div>
  )
}
