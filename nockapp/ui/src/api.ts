// HTTP client for the caderno NockApp.
//
// There is no ship, no Eyre channel and no scry endpoint here: the backend is
// a single binary exposing two POST routes.
//
//   POST /api/state   -> full state snapshot
//   POST /api/action  -> apply one action, respond with the new snapshot
//
// Both answer **201, not 200**, deliberately: the NockApp http driver caches
// responses in one global slot keyed on nothing, writing it whenever an effect
// status is exactly 200 and reading it on any GET. A 200 from POST /api/state
// would therefore become the body of GET /. So treat any 2xx as success and do
// not "fix" the status. Errors are 4xx with a `{"error": "..."}` body.

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

export interface NbListItem {
  id: string
  title: string
}

//  Every action responds with one of these; there are no incremental updates.
export interface Snapshot {
  state: { id: string; nb: Notebook }
  'nb-list': NbListItem[]
}

export class ApiError extends Error {}

async function post(path: string, body?: object): Promise<Snapshot> {
  let res: Response
  try {
    res = await fetch(path, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: body === undefined ? undefined : JSON.stringify(body),
    })
  } catch {
    throw new ApiError('Could not reach the caderno backend')
  }
  //  201 is the success status; `res.ok` covers the whole 2xx range.
  if (!res.ok) {
    let msg = `HTTP ${res.status}`
    try {
      const j = await res.json()
      if (j && typeof j.error === 'string') msg = j.error
    } catch { /* non-JSON error body; keep the status line */ }
    throw new ApiError(msg)
  }
  return res.json() as Promise<Snapshot>
}

export function fetchState(): Promise<Snapshot> {
  return post('/api/state')
}

function act(action: object): Promise<Snapshot> {
  return post('/api/action', action)
}

export const actions = {
  runCell: (id: number) => act({ 'run-cell': { id } }),
  //  The Urbit client could batch update-source + run-cell into one channel
  //  PUT. Here they are two requests, so send them in order and keep only the
  //  second snapshot — the source write is already reflected in it.
  runCellFlushed: async (id: number, src: string) => {
    await act({ 'update-source': { id, src } })
    return act({ 'run-cell': { id } })
  },
  runAll: () => act({ 'run-all': true }),
  insertCell: (after: number | null, type: 'code' | 'markdown') =>
    act({ 'insert-cell': { after, type } }),
  deleteCell: (id: number) => act({ 'delete-cell': { id } }),
  updateSource: (id: number, src: string) => act({ 'update-source': { id, src } }),
  resetSubject: () => act({ 'reset-subject': true }),
  setCellType: (id: number, type: 'code' | 'markdown') =>
    act({ 'set-cell-type': { id, type } }),
  setTitle: (title: string) => act({ 'set-title': { title } }),
  newNotebook: () => act({ 'new-notebook': true }),
  switchNotebook: (id: string) => act({ 'switch-notebook': { id } }),
  deleteNotebook: (id: string) => act({ 'delete-notebook': { id } }),
}
