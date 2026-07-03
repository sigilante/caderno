import { useState } from 'react'
import type { CatalogEntry, FollowEntry } from '../App'

interface Props {
  lookup: { who: string; items: CatalogEntry[] } | null
  follows: FollowEntry[]
  onLookupShip: (who: string) => void
  onFollow: (who: string, id: string) => void
}

export function LookupView({ lookup, follows, onLookupShip, onFollow }: Props) {
  const [ship, setShip] = useState('')
  const submit = () => onLookupShip(ship)
  const following = new Set(follows.map(f => `${f.who}/${f.id}`))

  return (
    <div
      className="lc-scroll"
      style={{ position: 'absolute', top: 116, left: 256, right: 176, bottom: 10, overflowY: 'auto' }}
    >
      <div style={{ padding: '6px 24px 60px' }}>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 14, margin: '4px 0 22px' }}>
          <span style={{ fontSize: 30, fontWeight: 600, color: '#7fd4ff', letterSpacing: '.02em' }}>LOOKUP</span>
          <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 12, color: '#4a6b7c', letterSpacing: '.18em' }}>BROWSE A SHIP'S PUBLISHED NOTEBOOKS</span>
        </div>

        {/* ship entry */}
        <div style={{ display: 'flex', gap: 10, marginBottom: 26 }}>
          <input
            value={ship}
            onChange={e => setShip(e.target.value)}
            onKeyDown={e => { if (e.key === 'Enter') submit() }}
            placeholder="~sampel-palnet"
            spellCheck={false}
            style={{ flex: 1, background: '#0c0c0e', border: '1px solid #1c3040', borderRadius: 25, color: '#bfe8ff', fontFamily: "'JetBrains Mono', monospace", fontSize: 18, padding: '12px 22px', outline: 'none' }}
          />
          <div className="lc-press" onClick={submit} style={{ background: '#1c3040', color: '#7fd4ff', borderRadius: 25, padding: '0 28px', display: 'flex', alignItems: 'center', fontWeight: 700, fontSize: 16, letterSpacing: '.08em' }}>LOOKUP ▸</div>
        </div>

        {!lookup && (
          <div style={{ fontFamily: "'JetBrains Mono', monospace", color: '#4a6b7c', fontSize: 13, letterSpacing: '.06em' }}>
            Enter a ship to see the notebooks it publishes.
          </div>
        )}

        {lookup && (
          <>
            <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 12, color: '#6b5a3c', letterSpacing: '.14em', marginBottom: 14 }}>
              {lookup.who} · {lookup.items.length} PUBLISHED
            </div>
            {lookup.items.length === 0 && (
              <div style={{ fontFamily: "'JetBrains Mono', monospace", color: '#4a6b7c', fontSize: 13 }}>
                Nothing published (or ship unreachable).
              </div>
            )}
            {lookup.items.map(it => {
              const isFollowing = following.has(`${lookup.who}/${it.id}`)
              return (
                <div key={it.id} style={{ display: 'flex', alignItems: 'stretch', gap: 12, marginBottom: 10 }}>
                  <div style={{ flex: '0 0 150px', borderRadius: '0 0 0 22px', background: '#1c3040', color: '#7fd4ff', padding: '14px 18px', display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
                    <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 11, letterSpacing: '.08em', fontWeight: 700, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{lookup.who}</span>
                    <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 12, letterSpacing: '.04em' }}>{it.id}</span>
                  </div>
                  <div style={{ flex: 1, background: '#0c0c0e', border: '1px solid #14202a', borderRadius: '0 22px 22px 0', padding: '14px 22px', display: 'flex', alignItems: 'center', gap: 12 }}>
                    <div style={{ fontFamily: "'Antonio', sans-serif", fontSize: 25, fontWeight: 600, color: '#bfe8ff' }}>{it.title}</div>
                    <div style={{ marginLeft: 'auto' }}>
                      {isFollowing ? (
                        <span style={{ color: '#99e6a3', fontFamily: "'JetBrains Mono', monospace", fontSize: 12, fontWeight: 700 }}>FOLLOWING ✓</span>
                      ) : (
                        <span className="lc-press" onClick={() => onFollow(lookup.who, it.id)} style={{ background: '#1c3040', color: '#7fd4ff', borderRadius: 16, padding: '7px 16px', fontFamily: "'JetBrains Mono', monospace", fontSize: 12, fontWeight: 700 }}>FOLLOW</span>
                      )}
                    </div>
                  </div>
                </div>
              )
            })}
          </>
        )}
      </div>
    </div>
  )
}
