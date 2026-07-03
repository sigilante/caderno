// Urbit Eyre channel API client for caderno

// Our ship, i.e. the ship serving this app (without the leading '~').
// Eyre sets a non-HttpOnly `urbauth-~ship` cookie on the served page, so the
// ship name is readable client-side. Fall back to an injected window.ship, then
// to 'nec' for local dev.
export function getShip(): string {
  const m = document.cookie.match(/urbauth-~([a-z-]+)=/)
  if (m) return m[1]
  const w = (window as any).ship
  if (typeof w === 'string' && w) return w
  return 'nec'
}

export const ship: string = getShip()

export interface Output {
  text?: string
  ename?: string
  evalue?: string
}

export interface Cell {
  id: number
  type: 'code' | 'markdown'
  source: string
  exec_count: number | null
  outputs: Output[]
}

export interface Notebook {
  title: string
  kernel: string
  cells: Cell[]
}

export type CellStatus = 'running' | 'done' | 'error'

export type Update =
  | { 'state': { id: string; nb: Notebook } }
  | { 'nb-list': { id: string; title: string }[] }
  | { 'cell-output': { id: number; out: Output; count: number } }
  | { 'cell-status': { id: number; status: CellStatus } }
  | { 'cell-added': { after: number | null; c: Cell } }
  | { 'cell-deleted': { id: number } }
  | { 'log-mounted': boolean }
  | { 'log-committed': boolean }
  | { 'published': string[] }
  | { 'follows': { who: string; id: string; title: string }[] }
  | { 'lookup': { who: string; items: { id: string; title: string }[] } }

let channelId = `caderno-${Date.now()}`
let eventSource: EventSource | null = null
let messageId = 1

async function channelPut(actions: object[]) {
  await fetch(`/~/channel/${channelId}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(actions),
    credentials: 'include',
  })
}

export async function openChannel(onUpdate: (upd: Update) => void, onOpen?: () => void) {
  // subscribe to /notebook
  await channelPut([{
    id: messageId++,
    action: 'subscribe',
    ship,
    app: 'caderno',
    path: '/notebook',
  }])

  eventSource = new EventSource(`/~/channel/${channelId}`, { withCredentials: true })
  if (onOpen) eventSource.onopen = onOpen
  eventSource.onmessage = (e) => {
    try {
      const msg = JSON.parse(e.data)
      if (msg.response === 'diff' && msg.json) {
        onUpdate(msg.json as Update)
      }
    } catch {}
  }
}

export async function closeChannel() {
  eventSource?.close()
  await channelPut([{ id: messageId++, action: 'delete' }])
}

function mkPoke(data: object) {
  return {
    id: messageId++,
    action: 'poke' as const,
    ship,
    app: 'caderno',
    mark: 'cnb-action',
    json: data,
  }
}

async function poke(data: object) {
  await channelPut([mkPoke(data)])
}

export async function fetchActiveNotebook(): Promise<{ id: string; nb: Notebook }> {
  const res = await fetch('/~/scry/caderno/notebook/json', { credentials: 'include' })
  return res.json()
}

export async function fetchLogStatus(): Promise<boolean> {
  try {
    const res = await fetch('/~/scry/caderno/log-status/json', { credentials: 'include' })
    if (!res.ok) return false
    return res.json()
  } catch {
    return false
  }
}

export interface Kelvins { hoon: number; arvo: number; zuse: number; nock: number; port: number }

export interface SoleSession {
  ship: string
  session: string
}

export async function fetchSoleSessions(agent: string): Promise<SoleSession[] | null> {
  try {
    const res = await fetch(`/~/scry/${agent}/sole/sessions.json`, { credentials: 'include' })
    if (!res.ok) return null
    return res.json()
  } catch {
    return null
  }
}

// All running gall agents on the ship (across desks). %ge enumeration isn't
// reachable over the %gx /~/scry endpoint, so caderno surfaces it for us.
export async function fetchAgents(): Promise<string[]> {
  try {
    const res = await fetch('/~/scry/caderno/agents.json', { credentials: 'include' })
    if (!res.ok) return []
    return res.json()
  } catch {
    return []
  }
}

// Shoe agents that answer the probe but aren't real notebook kernels — e.g.
// %shoe, the shoe library's own example/skeleton agent.
const KERNEL_BLACKLIST = new Set(['shoe'])

// Discover shoe REPL kernels: probe each running agent with the shoe
// /x/sole/sessions scry (a non-shoe agent 404s → null), keeping those that
// answer. The in-process 'hoon' kernel is prepended and is not an agent.
export async function discoverKernels(): Promise<string[]> {
  const agents = (await fetchAgents()).filter(a => !KERNEL_BLACKLIST.has(a))
  const flags = await Promise.all(agents.map(a => fetchSoleSessions(a).then(r => r !== null)))
  const shoe = agents.filter((_, i) => flags[i]).sort()
  return ['hoon', ...shoe]
}

export async function fetchKelvins(): Promise<Kelvins> {
  const res = await fetch('/~/scry/caderno/kelvins/json', { credentials: 'include' })
  return res.json()
}

export const actions = {
  runCell: (id: number) => poke({ 'run-cell': { id } }),
  // Send update-source + run-cell in one PUT so the backend always evals fresh source.
  runCellFlushed: (id: number, src: string) =>
    channelPut([mkPoke({ 'update-source': { id, src } }), mkPoke({ 'run-cell': { id } })]),
  runAll: () => poke({ 'run-all': null }),
  insertCell: (after: number | null, type: 'code' | 'markdown') =>
    poke({ 'insert-cell': { after, type } }),
  deleteCell: (id: number) => poke({ 'delete-cell': { id } }),
  updateSource: (id: number, src: string) =>
    poke({ 'update-source': { id, src } }),
  setKernel: (kernel: string) => poke({ 'set-kernel': { kernel } }),
  resetSubject: () => poke({ 'reset-subject': null }),
  setCellType: (id: number, type: 'code' | 'markdown') => poke({ 'set-cell-type': { id, type } }),
  setTitle: (title: string) => poke({ 'set-title': { title } }),
  newNotebook: () => poke({ 'new-notebook': null }),
  switchNotebook: (id: string) => poke({ 'switch-notebook': { id } }),
  deleteNotebook: (id: string) => poke({ 'delete-notebook': { id } }),
  mountLog: () => poke({ 'mount-log': null }),
  commitLog: () => poke({ 'commit-log': null }),
  importLog: () => poke({ 'import-log': null }),
  publish: (id: string) => poke({ 'publish': { id } }),
  unpublish: (id: string) => poke({ 'unpublish': { id } }),
  // `who` is a patp with the leading ~ (e.g. "~nec"); backend parses via slav %p.
  follow: (who: string, id: string) => poke({ 'follow': { who, id } }),
  unfollow: (who: string, id: string) => poke({ 'unfollow': { who, id } }),
  fork: (who: string, id: string) => poke({ 'fork': { who, id } }),
  lookup: (who: string) => poke({ 'lookup': { who } }),
  unlookup: (who: string) => poke({ 'unlookup': { who } }),
}
