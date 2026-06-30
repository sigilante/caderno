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
  | { 'state': { nb: Notebook } }
  | { 'cell-output': { id: number; out: Output } }
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

async function poke(data: object) {
  await channelPut([{
    id: messageId++,
    action: 'poke',
    ship: (window as any).ship ?? 'nec',
    app: 'caderno',
    mark: 'caderno-action',
    json: data,
  }])
}

export async function fetchNotebook(): Promise<Notebook> {
  const res = await fetch('/~/scry/caderno/notebook/json', { credentials: 'include' })
  return res.json()
}

export async function fetchSoleSessions(agent: string): Promise<string[] | null> {
  try {
    const res = await fetch(`/~/scry/${agent}/sole/sessions/json`, { credentials: 'include' })
    if (!res.ok) return null
    return res.json()
  } catch {
    return null
  }
}

export const actions = {
  runCell: (id: number) => poke({ 'run-cell': { id } }),
  runAll: () => poke({ 'run-all': null }),
  insertCell: (after: number | null, type: 'code' | 'markdown') =>
    poke({ 'insert-cell': { after, type } }),
  deleteCell: (id: number) => poke({ 'delete-cell': { id } }),
  updateSource: (id: number, src: string) =>
    poke({ 'update-source': { id, src } }),
  setKernel: (kernel: string) => poke({ 'set-kernel': { kernel } }),
  resetSubject: () => poke({ 'reset-subject': null }),
}
