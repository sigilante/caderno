// Urbit Eyre channel API client for caderno

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
    ship: (window as any).ship ?? 'nec',
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
    ship: ((window as any).ship ?? 'nec') as string,
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

export interface Kelvins { hoon: number; arvo: number; zuse: number; nock: number; port: number }

export async function fetchSoleSessions(agent: string): Promise<string[] | null> {
  try {
    const res = await fetch(`/~/scry/${agent}/sole/sessions/json`, { credentials: 'include' })
    if (!res.ok) return null
    return res.json()
  } catch {
    return null
  }
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
}
