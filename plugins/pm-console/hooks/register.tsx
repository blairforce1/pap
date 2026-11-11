// pm-console: the PM's console beside the chat.
// - Waiting on you: what each cycle's report asks of the Project Lead. The PM
//   records items with the inbox_add tool, with the report as detail. Items are
//   grouped by ref; opening a group shows the report and ticks items. The PM
//   can also call inbox_done. Kept in $.store, so it survives restarts.
// - Cycles: this session's background agents, live from $.agent.list().
// - CI: average and slowest run time per workflow, from `gh run list`.
// - Status line: one summary of all three.
// - Class band: while a change command (/intent, /change, /spec, /pap:pm launch)
//   is typed, a band above the prompt lists the classes; a bad class or slug
//   is painted red and refused at submit.
// - Exit: `/pap:pm exit` has the PM pause every cycle and save, then call
//   exit_ready, which puts /exit in the box. `/pap:pm console` calls
//   console_open. The console registers no command of its own.
import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { BranchHit, CiRow, CiStats, InboxItem, LaneRow, PapRow, PapStats } from '../types'

const PANE = 'pm-console'
const PLUGIN = 'pm-console'
const inboxRef = { plugin: 'pm-console', key: 'inbox' } as const
const lanesRef = { plugin: 'pm-console', key: 'lanes' } as const
const ciRef = { plugin: 'pm-console', key: 'ci' } as const
const papRef = { plugin: 'pm-console', key: 'pap' } as const
const tabRef = { plugin: 'pm-console', key: 'tab' } as const
const inbox = atom(inboxRef, [] as InboxItem[], { shape: 'inbox-1' })
const lanes = atom(lanesRef, [] as LaneRow[])
const ci = atom(ciRef, { at: 0, rows: [], error: '', repos: 0 } as CiStats)
const pap = atom(papRef, { at: 0, latest: '', rows: [], repos: 0 } as PapStats)
const tab = atom(tabRef, 'inbox')
// The inbox group whose detail is open ('' = the list). A group is one report: its ref, else its cycle.
const openGroupRef = { plugin: 'pm-console', key: 'openGroup' } as const
const openGroup = atom(openGroupRef, '')
const TABS = [
  ['inbox', 'Inbox', '1'],
  ['cycles', 'Cycles', '2'],
  ['pap', 'PAP', '3'],
  ['ci', 'CI', '4'],
] as const
const groupOf = (i: InboxItem) => i.ref || `cycle ${i.lane}`

// The change classes, each with the ceremony it gets (process section 4; chore from decision 0017).
const CLASSES = [
  ['feature', 'full spec, review per touched invariant'],
  ['infra', 'reliability and ops review; protected paths'],
  ['security-sensitive', 'full reviewer set, acceptance tests'],
  ['bugfix', 'light spec, cites the defect, adds an eval'],
  ['spike', 'intent and findings only; no spec, no deploy'],
  ['chore', 'upkeep; no scenarios'],
  ['docs', 'intent and human review only'],
] as const
const CLASS_NAMES: readonly string[] = CLASSES.map(c => c[0])
// Words people reach for that are not classes, with what to use instead.
const NOT_A_CLASS: Record<string, string> = { process: 'not a class; process records use infra' }
// As the pap skills check it: worktree.sh and the launch script refuse a slug that starts with "." or "-".
const SLUG_OK = /^[A-Za-z0-9][A-Za-z0-9._-]*$/
const draftRef = { plugin: 'pm-console', key: 'draft' } as const
const draft = atom(draftRef, '')
const branchRef = { plugin: 'pm-console', key: 'branch' } as const
const branchHit = atom(branchRef, { slug: '', exists: false } as BranchHit)

type Token = { word: string; start: number; end: number; isDone: boolean }
type ChangeLine = { command: string; slug?: Token; cls?: Token }

// `/change <slug> <class> ...` and its kin; undefined for any other draft.
function parseChangeLine(text: string): ChangeLine | undefined {
  const head = /^\/(?:pap:)?(intent|change|spec) |^\/pap:pm launch /.exec(text)
  if (!head) return undefined
  const words: Token[] = []
  const re = /\S+/g
  re.lastIndex = head[0].length
  for (let m = re.exec(text); m && words.length < 2; m = re.exec(text)) {
    const end = m.index + m[0].length
    words.push({ word: m[0], start: m.index, end, isDone: end < text.length })
  }
  const command = head[1] ?? 'pm launch'
  // `/spec <slug>` takes no class: it reads it from the accepted changes/<slug>/intent.md.
  return { command, slug: words[0], cls: command === 'spec' ? undefined : words[1] }
}

// Why a class token is wrong, or '' when it is fine (or may still become a class as it is typed).
function classProblem(t: Token): string {
  if (CLASS_NAMES.includes(t.word)) return ''
  if (!t.isDone && CLASS_NAMES.some(c => c.startsWith(t.word))) return ''
  return NOT_A_CLASS[t.word] ?? `not a class; the classes are ${CLASS_NAMES.join(', ')}`
}
const slugProblem = (t: Token) => (SLUG_OK.test(t.word) ? '' : 'a slug takes only letters, digits, ".", "_" and "-", and starts with a letter or digit')

// Warn, never refuse, when change/<slug> is already a branch here or on a remote.
// One run per slug while typing; `fresh` (at submit) asks git again.
let branchRun: { slug: string; done: Promise<boolean> } | undefined
async function checkBranch($: EngineInterface, slug: string, fresh = false) {
  const known = await read($, branchHit)
  if (!fresh && known?.slug === slug) return known.exists
  if (!fresh && branchRun?.slug === slug) return branchRun.done
  const done = gitHasChangeBranch($, slug)
  branchRun = { slug, done }
  const exists = await done
  await update($, branchHit, () => ({ slug, exists }))
  return exists
}

// For /spec: whether change/<slug> (local, else origin) holds changes/<slug>/intent.md; true when git cannot tell.
async function hasIntent($: EngineInterface, slug: string) {
  try {
    const cwd = await $.session.cwd()
    for (const ref of [`change/${slug}`, `origin/change/${slug}`]) {
      const ran = await $.process.run(['git', 'cat-file', '-e', `${ref}:changes/${slug}/intent.md`], { cwd, timeoutMs: 10_000 })
      if (ran.exitCode === 0) return true
    }
    const repo = await $.process.run(['git', 'rev-parse', '--git-dir'], { cwd, timeoutMs: 10_000 })
    return repo.exitCode !== 0
  } catch {
    return true
  }
}

async function gitHasChangeBranch($: EngineInterface, slug: string) {
  let exists = false
  try {
    const ran = await $.process.run(['git', 'branch', '-a', '--format=%(refname)'], {
      cwd: await $.session.cwd(),
      timeoutMs: 10_000,
    })
    if (ran.exitCode === 0) {
      // Compared as plain strings, no pattern built from the slug: refs/heads/change/<slug>
      // or refs/remotes/<one remote>/change/<slug>.
      const want = `change/${slug}`
      exists = ran.stdout.split('\n').some(line => {
        const ref = line.trim()
        if (ref === `refs/heads/${want}`) return true
        if (!ref.startsWith('refs/remotes/')) return false
        const rest = ref.slice('refs/remotes/'.length)
        const cut = rest.indexOf('/')
        return cut > 0 && rest.slice(cut + 1) === want
      })
    }
  } catch {
    // Not a git repository, or no git: say nothing.
  }
  return exists
}

const STORE_INBOX = 'inbox-1'
const STORE_REPOS = 'ci-repos'
const STORE_PAP_REPOS = 'pap-repos'
const STORE_STARTS = 'lane-starts'
// No repos until the PM sets them with ci_repos and pap_repos; the tabs say so.
const DEFAULT_REPOS: string[] = []
type PapRepo = { repo: string; path: string }
const DEFAULT_PAP_REPOS: PapRepo[] = []
const PAP_REPO = 'blairforce1/pap'
const noRepos = (tool: string) => `no repos set; ask the PM to call ${tool}`

// Backlog sections that mean a hypothesis is settled; anything else is open.
const BUILT_SECTION = /confirmed|built|done/i
const DROPPED_SECTION = /dropped|rejected/i

async function papRow($: EngineInterface, { repo, path }: PapRepo): Promise<PapRow> {
  const run = (argv: string[]) => $.process.run(argv, { cwd: path, timeoutMs: 60_000 })
  const row: PapRow = {
    repo,
    version: '',
    drift: '',
    proposed: [],
    revisitsDue: 0,
    revisitsManual: 0,
    experiments: { open: 0, building: 0, built: 0, dropped: 0 },
    nextExperiment: '',
    openPrs: 0,
    awaitingReview: 0,
    leadTimeDays: 0,
    error: '',
  }
  const errors: string[] = []
  // pap's own checkout runs its CLI from source; every other repo pins it through mise.
  const isPap = repo === PAP_REPO
  const papCmd = isPap ? ['bin/pap'] : ['mise', 'exec', '--', 'pap']

  const toml = await run(['cat', '.config/pap.toml'])
  row.version = isPap ? 'self' : (/^version = "([^"]+)"/m.exec(toml.stdout)?.[1] ?? '?')

  const proposed = await run(['grep', '-rlE', '^- \\*\\*Status:\\*\\* proposed|^Status: proposed', 'decisions'])
  row.proposed = proposed.stdout
    .split('\n')
    .filter(Boolean)
    .map(f => /(\d{4})/.exec(f)?.[1] ?? f)
    .sort()

  const revisits = await run([...papCmd, 'revisits'])
  if (revisits.exitCode === 0) {
    for (const line of revisits.stdout.split('\n')) {
      const kind = line.trim().split(/\s+/)[1]
      if (kind === 'due') row.revisitsDue++
      if (kind === 'manual') row.revisitsManual++
    }
  } else errors.push('revisits')

  const backlog = await run(['cat', 'product/backlog.md'])
  let section = ''
  let current = ''
  const state = new Map<string, keyof PapRow['experiments']>()
  const order: string[] = []
  for (const line of backlog.stdout.split('\n')) {
    if (line.startsWith('## ')) section = line
    const id = /^\*\*(H-\d+)\*\*/.exec(line)?.[1]
    if (id) {
      current = id
      order.push(id)
      state.set(id, BUILT_SECTION.test(section) ? 'built' : DROPPED_SECTION.test(section) ? 'dropped' : 'open')
    }
    const status = /^Status:\s*(.*)/i.exec(line)?.[1]
    if (current && status) {
      if (/^built|^confirmed/i.test(status)) state.set(current, 'built')
      else if (/^dropped/i.test(status)) state.set(current, 'dropped')
      else if (/build|progress|running/i.test(status)) state.set(current, 'building')
    }
  }
  for (const id of order) row.experiments[state.get(id) ?? 'open']++
  row.nextExperiment = order.find(id => state.get(id) === 'open') ?? ''

  const prs = await run(['gh', 'pr', 'list', '-R', repo, '--state', 'open', '--json', 'labels'])
  if (prs.exitCode === 0) {
    const list = JSON.parse(prs.stdout) as { labels: { name: string }[] }[]
    row.openPrs = list.length
    row.awaitingReview = list.filter(
      p => p.labels.some(l => l.name === 'risk:high') && !p.labels.some(l => l.name === 'owner-reviewed'),
    ).length
  } else errors.push('open PRs')

  const merged = await run(['gh', 'pr', 'list', '-R', repo, '--state', 'merged', '-L', '10', '--json', 'createdAt,mergedAt'])
  if (merged.exitCode === 0) {
    const days = (JSON.parse(merged.stdout) as { createdAt: string; mergedAt: string }[])
      .map(p => (Date.parse(p.mergedAt) - Date.parse(p.createdAt)) / 86_400_000)
      .sort((a, b) => a - b)
    row.leadTimeDays = days.length ? (days[Math.floor((days.length - 1) / 2)] ?? 0) : 0
  } else errors.push('merged PRs')

  const status = await run([...papCmd, 'repo', 'status'])
  const summary = /(\d+) drift, (\d+) missing/.exec(status.stdout)
  row.drift = summary ? `${summary[1]} drift, ${summary[2]} missing` : 'unknown'

  row.error = errors.length ? `could not read: ${errors.join(', ')}` : ''
  return row
}

async function refreshPap($: EngineInterface) {
  const repos = ((await $.store.get(STORE_PAP_REPOS)) as PapRepo[] | undefined) ?? DEFAULT_PAP_REPOS
  if (repos.length === 0) {
    await update($, pap, () => ({ at: Date.now(), latest: '', rows: [], repos: 0 }))
    await refreshStatus($)
    return
  }
  const latest = await $.process.run(['gh', 'release', 'view', '-R', PAP_REPO, '--json', 'tagName', '-q', '.tagName'])
  const rows: PapRow[] = []
  for (const r of repos) rows.push(await papRow($, r))
  await update($, pap, () => ({
    at: Date.now(),
    latest: latest.exitCode === 0 ? latest.stdout.trim().replace(/^v/, '') : '',
    rows,
    repos: repos.length,
  }))
  await refreshStatus($)
}

type Starts = Record<string, { at: number; model: string }>

const ago = (at: number, now: number) => {
  const m = Math.max(0, Math.round((now - at) / 60000))
  return m < 60 ? `${m}m` : m < 2880 ? `${Math.round(m / 60)}h` : `${Math.round(m / 1440)}d`
}
const mmss = (s: number) => `${Math.floor(s / 60)}m${String(Math.round(s % 60)).padStart(2, '0')}`
const cut = (text: string, width: number) =>
  text.length <= width ? text : `${text.slice(0, Math.max(1, width - 1))}…`

async function getInbox($: EngineInterface): Promise<InboxItem[]> {
  const value = await read($, inbox)
  return Array.isArray(value) ? value : []
}

async function changeInbox($: EngineInterface, fn: (list: InboxItem[]) => InboxItem[]) {
  await update($, inbox, list => fn(list ?? []))
  await $.store.set(STORE_INBOX, await getInbox($))
  await refreshStatus($)
}

async function refreshStatus($: EngineInterface) {
  const open = (await getInbox($)).filter(i => !i.isDone).length
  const laneList = await read($, lanes)
  const running = (Array.isArray(laneList) ? laneList : []).filter(l =>
    ['running', 'pending', 'waiting'].includes(l.status),
  ).length
  const stats = await read($, ci)
  const rows = stats?.rows ?? []
  const slowest = rows.reduce<CiRow | undefined>((a, r) => (!a || r.avgSec > a.avgSec ? r : a), undefined)
  const ciText = slowest ? ` · CI slowest ${slowest.workflow} ~${mmss(slowest.avgSec)}` : ''
  const papStats = await read($, pap)
  const proposed = (papStats?.rows ?? []).reduce((n, r) => n + r.proposed.length, 0)
  const due = (papStats?.rows ?? []).reduce((n, r) => n + r.revisitsDue, 0)
  const papText = papStats?.at ? ` · ${proposed} decisions proposed${due ? ` · ${due} revisits due` : ''}` : ''
  $.ui.status(`PM ▸ ${running} running · ${open} waiting on you${papText}${ciText}`)
}

async function refreshLanes($: EngineInterface) {
  const starts = ((await $.store.get(STORE_STARTS)) as Starts | undefined) ?? {}
  const list = await $.agent.list()
  const rows: LaneRow[] = list
    .filter(a => !a.parentId)
    .map(a => ({
      id: a.id,
      description: a.description,
      status: a.status,
      model: starts[a.id]?.model ?? '',
      startedAt: starts[a.id]?.at ?? 0,
    }))
  await update($, lanes, () => rows)
  await refreshStatus($)
}

async function refreshCi($: EngineInterface) {
  const repos = ((await $.store.get(STORE_REPOS)) as string[] | undefined) ?? DEFAULT_REPOS
  const rows: CiRow[] = []
  const errors: string[] = []
  for (const repo of repos) {
    const ran = await $.process.run([
      'gh', 'run', 'list', '-R', repo, '-L', '40',
      '--json', 'workflowName,conclusion,status,createdAt,updatedAt',
    ])
    if (ran.exitCode !== 0) {
      errors.push(`${repo}: ${ran.stderr.trim().split('\n')[0] ?? 'gh failed'}`)
      continue
    }
    type Run = { workflowName: string; conclusion: string; status: string; createdAt: string; updatedAt: string }
    const runs = JSON.parse(ran.stdout) as Run[]
    const byWorkflow = new Map<string, number[]>()
    for (const r of runs) {
      if (r.status !== 'completed' || r.conclusion !== 'success') continue
      const secs = (Date.parse(r.updatedAt) - Date.parse(r.createdAt)) / 1000
      if (!(secs > 0)) continue
      const list = byWorkflow.get(r.workflowName) ?? []
      if (list.length < 20) list.push(secs)
      byWorkflow.set(r.workflowName, list)
    }
    for (const [workflow, secs] of byWorkflow) {
      rows.push({
        repo,
        workflow,
        runs: secs.length,
        avgSec: secs.reduce((a, b) => a + b, 0) / secs.length,
        maxSec: Math.max(...secs),
      })
    }
  }
  rows.sort((a, b) => b.avgSec - a.avgSec)
  await update($, ci, () => ({ at: Date.now(), rows, error: errors.join('; '), repos: repos.length }))
  await refreshStatus($)
}

const toolText = (text: string) => ({ result: text })

// `/pap:pm exit`: the PM pauses everything and calls exit_ready, then the console puts /exit in the prompt box.
const STORE_UNSAFE_EXIT = 'unsafe-exit'
const STORE_EXIT_READY = 'exit-ready'
const isRunning = (status: string) => ['running', 'pending', 'waiting'].includes(status)

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const stored = (await $.store.get(STORE_INBOX)) as InboxItem[] | undefined
    if (stored && (await getInbox($)).length === 0) await update($, inbox, () => (Array.isArray(stored) ? stored : []))

    // An exit that skipped the pause left cycles mid-step: put it in front of the PM and the Project Lead.
    const unsafe = (await $.store.get(STORE_UNSAFE_EXIT)) as { at: number; running: string[] } | undefined
    if (unsafe && unsafe.running?.length) {
      const now = Date.now()
      await changeInbox($, list => [
        ...list,
        {
          id: `${now.toString(36)}x`,
          text: `Last exit skipped the pause: relaunch ${unsafe.running.length} cycle(s) from their save points`,
          lane: 'pm',
          ref: 'exit',
          at: now,
          isDone: false,
          detail: `The session ended at ${new Date(unsafe.at).toISOString()} with these cycles still running:\n${unsafe.running.map(r => `- ${r}`).join('\n')}\n\nThe PM checks each branch and save point, then relaunches. Next time use /pap:pm exit.`,
        },
      ])
      await $.store.delete(STORE_UNSAFE_EXIT)
    }
    await $.store.delete(STORE_EXIT_READY)

    // Each tool registers on its own: one the engine refuses is logged and the rest still load.
    const refused: string[] = []
    const tool = async (spec: Parameters<typeof $.tool.register>[0]) => {
      try {
        await $.tool.register(spec)
      } catch (err) {
        refused.push(spec.name)
        $.ui.log(`pm-console: tool ${spec.name} not registered: ${err instanceof Error ? err.message : String(err)}`)
      }
    }
    await tool({
      name: 'console_open',
      description:
        'Open the PM console pane and refresh its PAP and CI figures. Call when the Project Lead types `/pap:pm console`.',
      inputSchema: { type: 'object', properties: {} },
      isDeferred: false,
    })
    await tool({
      name: 'exit_ready',
      description:
        'Call at the end of a `/pap:pm exit` pause: ok true once every cycle has PAUSED and the tracker and memory are committed and pushed; ok false with what is not done. The console then puts /exit in the prompt box for the Project Lead.',
      inputSchema: {
        type: 'object',
        properties: {
          ok: { type: 'boolean' },
          note: { type: 'string', description: 'What is not done, when ok is false; a one-line summary otherwise' },
        },
        required: ['ok'],
      },
      isDeferred: false,
    })
    await tool({
      name: 'inbox_add',
      description:
        'Add what a cycle report asks of the Project Lead to the PM console (one short imperative line per item: review, decide, merge, run). Call when a cycle reports.',
      inputSchema: {
        type: 'object',
        properties: {
          cycle: { type: 'string', description: 'Cycle number or slug, e.g. "105"' },
          lane: { type: 'string', description: 'Alias of cycle, kept so existing callers keep working' },
          ref: { type: 'string', description: 'PR or thing it concerns, e.g. "ap#4"; items are grouped by it' },
          items: { type: 'array', items: { type: 'string' }, minItems: 1 },
          detail: {
            type: 'string',
            description:
              'What the cycle reported, shown when the Project Lead opens the group: built, deviations, decisions left, revisits. Short lines, no secrets.',
          },
          url: { type: 'string', description: 'Link to the PR or thing, copied from the detail view' },
        },
        required: ['items'],
      },
      isDeferred: false,
    })
    await tool({
      name: 'inbox_note',
      description:
        'Set or replace the detail text and link on every PM console item with this ref (to fill in or correct what the detail view shows).',
      inputSchema: {
        type: 'object',
        properties: {
          ref: { type: 'string' },
          detail: { type: 'string' },
          url: { type: 'string' },
        },
        required: ['ref'],
      },
      isDeferred: false,
    })
    await tool({
      name: 'inbox_done',
      description: 'Mark PM console items done by id (the Project Lead did them).',
      inputSchema: {
        type: 'object',
        properties: { ids: { type: 'array', items: { type: 'string' }, minItems: 1 } },
        required: ['ids'],
      },
      isDeferred: false,
    })
    await tool({
      name: 'inbox_list',
      description: 'List the PM console items still waiting on the Project Lead, with ids.',
      inputSchema: { type: 'object', properties: {} },
      isDeferred: false,
    })
    await tool({
      name: 'ci_repos',
      description: 'Set the GitHub repos (owner/name) whose CI timings the PM console shows.',
      inputSchema: {
        type: 'object',
        properties: { repos: { type: 'array', items: { type: 'string' }, minItems: 1 } },
        required: ['repos'],
      },
    })

    $.clock.every(15_000, () => void refreshLanes($))
    await tool({
      name: 'pap_repos',
      description: 'Set the repos the PM console PAP tab reads: GitHub owner/name plus the local checkout path of each.',
      inputSchema: {
        type: 'object',
        properties: {
          repos: {
            type: 'array',
            minItems: 1,
            items: {
              type: 'object',
              properties: { repo: { type: 'string' }, path: { type: 'string' } },
              required: ['repo', 'path'],
            },
          },
        },
        required: ['repos'],
      },
    })

    if (refused.length) $.ui.toast(`PM console: ${refused.join(', ')} not registered; the debug log says why`)

    $.clock.every(600_000, () => void refreshCi($))
    $.clock.every(1_800_000, () => void refreshPap($))
    void refreshLanes($)
    void refreshCi($)
    void refreshPap($)
    void $.ui.open({ id: PANE, title: 'PM console' })

    return next(e)
  })

  on('tool.call', { tool: 'mcp__pm-console__console_open' }, async $ => {
    await $.ui.open({ id: PANE, title: 'PM console' })
    void refreshCi($)
    void refreshPap($)
    return toolText('PM console opened; CI and PAP figures refreshing.') as never
  })

  on('tool.call', { tool: 'mcp__pm-console__exit_ready' }, async ($, e) => {
    const input = e as unknown as { ok: boolean; note?: string }
    if (!input.ok) {
      $.ui.toast(`Not safe to exit yet: ${input.note ?? 'see the PM'}`)
      void refreshStatus($)
      return toolText('Told the Project Lead it is not safe yet; /exit not offered.') as never
    }
    // The pause ran: paused cycles may still list as waiting, so the safety net stands down.
    await $.store.set(STORE_EXIT_READY, Date.now())
    await $.prompt.fill({ text: '/exit' })
    $.ui.toast('Safe to exit: press Enter')
    $.ui.status('PM ▸ paused and saved · press Enter to exit')
    return toolText('/exit is in the prompt box; the Project Lead presses Enter.') as never
  })

  // Safety net: an exit without `/pap:pm exit` while cycles run is noted for the next session.
  on('session.end', async ($, e, next) => {
    try {
      if (e.reason !== 'clear' && !(await $.store.get(STORE_EXIT_READY))) {
        const running = (await $.agent.list()).filter(a => !a.parentId && isRunning(a.status)).map(a => a.description)
        if (running.length) await $.store.set(STORE_UNSAFE_EXIT, { at: Date.now(), running })
      }
    } catch {
      // Never hold up an exit.
    }
    return next(e)
  })

  // Class band: paint a bad slug or class red as it is typed, and keep the draft for the band.
  on('prompt.edit', async ($, e, next) => {
    const r = await next(e)
    await update($, draft, () => r.text)
    const line = parseChangeLine(r.text)
    if (!line) return r
    const bad = [line.slug && slugProblem(line.slug) ? line.slug : undefined, line.cls && classProblem(line.cls) ? line.cls : undefined]
      .filter((t): t is Token => !!t)
      .map(t => ({ start: t.start, end: t.end, color: 'error' as const }))
    if (line.slug?.isDone && !slugProblem(line.slug)) void checkBranch($, line.slug.word)
    return bad.length ? { ...r, decorations: [...(r.decorations ?? []), ...bad] } : r
  })

  on('prompt.change', async ($, e, next) => {
    await update($, draft, () => e.text)
    return next(e)
  })

  // A skill's slash command reaches prompt.submit with `command` set, before the skill
  // is rendered, so a drop here stops it. The skill's own argument check stays the backstop.
  on('prompt.submit', async ($, e, next) => {
    const name = e.command?.name.replace(/^pap:/, '')
    const args = e.command?.args ?? ''
    const isChange = name === 'intent' || name === 'change' || name === 'spec'
    const isLaunch = e.command?.name === 'pap:pm' && /^launch\s/.test(args)
    if (!isChange && !isLaunch) return next(e)
    const line = parseChangeLine(`/${isLaunch ? 'pap:pm' : name} ${args.trimStart()}\n`)
    const slug = line?.slug
    if (name === 'spec') {
      if (!slug) return { drop: `/${e.command?.name} needs <slug>` }
      if (slugProblem(slug)) return { drop: `"${slug.word}": ${slugProblem(slug)}` }
      if (!(await hasIntent($, slug.word))) {
        $.ui.toast(`No changes/${slug.word}/intent.md on change/${slug.word}: run /intent first`)
      }
      return next(e)
    }
    const cls = line?.cls
    // A launch takes its class from the brief, which the pap skill's script checks: one typed here is optional.
    if (isLaunch && !slug) return { drop: '/pap:pm launch needs <slug>' }
    if (!slug || (!cls && !isLaunch)) {
      return { drop: `/${e.command?.name} needs <slug> <class>; the classes are ${CLASS_NAMES.join(', ')}` }
    }
    if (slugProblem(slug)) return { drop: `"${slug.word}": ${slugProblem(slug)}` }
    if (cls && classProblem(cls)) return { drop: `"${cls.word}": ${classProblem(cls)}` }
    if (await checkBranch($, slug.word, true)) $.ui.toast(`change/${slug.word} already exists; the skill will resume it`)
    return next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const line = parseChangeLine((await read($, draft)) ?? '')
    if (!line || e.props.hasSurvey) return next(e)
    const { Box, Text } = $.ui.resolve(e)
    const width = Math.max(30, (e.props as { bodyColumns?: number }).bodyColumns ?? 80)
    const typed = line.cls?.word ?? ''
    const hit = await read($, branchHit)
    const problems = [line.slug && slugProblem(line.slug), line.cls && classProblem(line.cls)].filter(Boolean)
    if (line.command === 'spec') {
      return (
        <Box flexDirection="column">
          <Text dimColor>{cut('/spec <slug>: no class; it is read from changes/<slug>/intent.md', width)}</Text>
          {problems.map((p, n) => <Text key={`problem-${n}`} color="error">{cut(String(p), width)}</Text>)}
        </Box>
      )
    }
    const isLaunch = line.command === 'pm launch'
    return (
      <Box flexDirection="column">
        <Text dimColor>
          {isLaunch
            ? cut('/pap:pm launch <slug>: the class comes from the brief; typing one here is optional', width)
            : `/${line.command} <slug> <class>: the class sets the ceremony`}
        </Text>
        {CLASSES.map(([c, note]) => (
          <Text key={`class-${c}`}>
            <Text bold={c === typed} color={c === typed ? 'success' : undefined}>{`${c.padEnd(19)}`}</Text>
            <Text dimColor>{cut(note, Math.max(10, width - 20))}</Text>
          </Text>
        ))}
        {problems.map((p, n) => <Text key={`problem-${n}`} color="error">{cut(String(p), width)}</Text>)}
        {hit && hit.exists && hit.slug === line.slug?.word && (
          <Text color="warning">{cut(`change/${hit.slug} already exists: the skill resumes it`, width)}</Text>
        )}
      </Box>
    )
  })

  on('agent.spawn', async ($, e, next) => {
    const ran = (await next(e)) as { agentId?: string; model?: string }
    try {
      if (ran?.agentId) {
        const starts = ((await $.store.get(STORE_STARTS)) as Starts | undefined) ?? {}
        starts[ran.agentId] = { at: Date.now(), model: ran.model ?? '' }
        await $.store.set(STORE_STARTS, starts)
        void refreshLanes($)
      }
    } catch {
      // Recording the start time is a nicety; never let it fail a spawn.
    }
    return ran as never
  })

  on('tool.call', { tool: 'mcp__pm-console__inbox_add' }, async ($, e) => {
    const input = e as unknown as { cycle?: string; lane?: string; ref?: string; items: string[]; detail?: string; url?: string }
    const cycle = String(input.cycle ?? input.lane ?? '').trim()
    if (!cycle) throw new Error('inbox_add needs `cycle` (or its alias `lane`): the cycle number or slug, e.g. "105"')
    const now = Date.now()
    const added: InboxItem[] = input.items.map((text, i) => ({
      id: `${now.toString(36)}${i}`,
      text,
      lane: cycle, // stored field stays `lane` so saved inboxes load
      ref: input.ref ?? '',
      at: now,
      isDone: false,
      ...(input.detail ? { detail: input.detail } : {}),
      ...(input.url ? { url: input.url } : {}),
    }))
    await changeInbox($, list => [...list, ...added])
    return toolText(`Added ${added.length}: ${added.map(a => a.id).join(', ')}`) as never
  })

  on('tool.call', { tool: 'mcp__pm-console__inbox_note' }, async ($, e) => {
    const input = e as unknown as { ref: string; detail?: string; url?: string }
    let n = 0
    await changeInbox($, list =>
      list.map(i => {
        if (i.ref !== input.ref) return i
        n++
        return {
          ...i,
          ...(input.detail !== undefined ? { detail: input.detail } : {}),
          ...(input.url !== undefined ? { url: input.url } : {}),
        }
      }),
    )
    return toolText(n ? `Updated ${n} items for ${input.ref}` : `No items with ref ${input.ref}`) as never
  })

  on('tool.call', { tool: 'mcp__pm-console__inbox_done' }, async ($, e) => {
    const ids = (e as unknown as { ids: string[] }).ids
    await changeInbox($, list => list.map(i => (ids.includes(i.id) ? { ...i, isDone: true } : i)))
    return toolText(`Marked done: ${ids.join(', ')}`) as never
  })

  on('tool.call', { tool: 'mcp__pm-console__inbox_list' }, async $ => {
    const open = (await getInbox($)).filter(i => !i.isDone)
    return toolText(
      open.length === 0
        ? 'Nothing waiting on the Project Lead.'
        : open.map(i => `${i.id}  [${i.lane}${i.ref ? ` ${i.ref}` : ''}] ${i.text}`).join('\n'),
    ) as never
  })

  on('tool.call', { tool: 'mcp__pm-console__pap_repos' }, async ($, e) => {
    const repos = (e as unknown as { repos: PapRepo[] }).repos
    await $.store.set(STORE_PAP_REPOS, repos)
    void refreshPap($)
    return toolText(`PAP repos: ${repos.map(r => r.repo).join(', ')}`) as never
  })

  on('tool.call', { tool: 'mcp__pm-console__ci_repos' }, async ($, e) => {
    const repos = (e as unknown as { repos: string[] }).repos
    await $.store.set(STORE_REPOS, repos)
    void refreshCi($)
    return toolText(`CI repos: ${repos.join(', ')}`) as never
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text, Button } = $.ui.resolve(e)
    const width = Math.max(30, (e.props as { bodyColumns?: number }).bodyColumns ?? 70)
    const now = Date.now()
    const current = (await read($, tab)) ?? 'inbox'
    const inboxValue = await read($, inbox)
    const laneValue = await read($, lanes)
    const ciValue = await read($, ci)
    const papValue = await read($, pap)
    const items = Array.isArray(inboxValue) ? inboxValue : []
    const open = items.filter(i => !i.isDone)
    const done = items.length - open.length
    const laneRows = Array.isArray(laneValue) ? laneValue : []
    const running = laneRows.filter(l => ['running', 'pending', 'waiting'].includes(l.status)).length
    const stats: CiStats = ciValue ?? { at: 0, rows: [], error: '', repos: 0 }
    const papStats: PapStats = papValue ?? { at: 0, latest: '', rows: [], repos: 0 }
    const proposed = papStats.rows.reduce((n, r) => n + r.proposed.length, 0)

    const clearDone = () => void changeInbox($, list => list.filter(i => !i.isDone))
    const counts: Record<string, string> = {
      inbox: `${open.length}`,
      cycles: `${running}`,
      pap: `${proposed}`,
      ci: '',
    }

    const toggle = (id: string) => () =>
      void changeInbox($, list => list.map(i => (i.id === id ? { ...i, isDone: !i.isDone } : i)))
    const showGroup = (g: string) => () => void update($, openGroup, () => g)

    const tabs = (
      <Box flexDirection="row" gap={1}>
        {TABS.map(([id, label, key]) => (
          <Button
            key={`tab-${id}`}
            hotkey={key}
            variant={current === id ? 'primary' : 'secondary'}
            onPress={() => {
              void update($, openGroup, () => '')
              void update($, tab, () => id)
            }}
          >
            {`${key} ${counts[id] ? `${label} ${counts[id]}` : label}`}
          </Button>
        ))}
      </Box>
    )

    // Groups in order of their oldest open item; a group with nothing open drops out of the list.
    const groups: { name: string; items: InboxItem[] }[] = []
    for (const i of open) {
      const g = groups.find(x => x.name === groupOf(i))
      if (g) g.items.push(i)
      else groups.push({ name: groupOf(i), items: [i] })
    }

    const listView = (
      <Box flexDirection="column">
        <Text bold>WAITING ON YOU ({open.length})</Text>
        {open.length === 0 && <Text dimColor>Nothing waiting.</Text>}
        {groups.map(g => {
          const first = g.items[0] as InboxItem
          const tail = ` cycle ${first.lane} · ${ago(first.at, now)} · ${g.items.length} ▸`
          return (
            <Box key={`g-${g.name}`} flexDirection="column" marginBottom={1}>
              <Button key={`open-${g.name}`} plain onPress={showGroup(g.name)}>
                <Text bold>{cut(g.name, Math.max(10, width - tail.length - 1))}</Text>
                <Text dimColor>{tail}</Text>
              </Button>
              {g.items.map(i => (
                <Text key={`t-${i.id}`}>{`  ☐ ${cut(i.text, Math.max(10, width - 4))}`}</Text>
              ))}
            </Box>
          )
        })}
        {done > 0 && (
          <Button key="clear-done" plain onPress={clearDone}>
            <Text dimColor>{`✓ ${done} done · clear`}</Text>
          </Button>
        )}
        {open.length > 0 && <Text dimColor>Open a group to see the report and tick items.</Text>}
      </Box>
    )

    const shown = (await read($, openGroup)) ?? ''
    const groupItems = items.filter(i => groupOf(i) === shown)
    const lead = groupItems.find(i => i.detail || i.url) ?? groupItems[0]
    const detailView = lead && (
      <Box flexDirection="column">
        <Text bold>
          {shown}
          <Text dimColor>{`  cycle ${lead.lane} · ${ago(lead.at, now)}`}</Text>
        </Text>
        <Text> </Text>
        {lead.detail
          ? lead.detail.split('\n').map((line, n) => <Text key={`d-${n}`}>{line || ' '}</Text>)
          : <Text dimColor>No report attached. Ask the PM, or open the link.</Text>}
        <Text> </Text>
        <Text bold>TO DO</Text>
        {groupItems.map(i => (
          <Button key={`i-${i.id}`} plain onPress={toggle(i.id)}>
            {i.isDone ? <Text dimColor>{`☑ ${cut(i.text, width - 3)}`}</Text> : `☐ ${cut(i.text, width - 3)}`}
          </Button>
        ))}
        <Text> </Text>
        <Box flexDirection="row" gap={1}>
          <Button key="back" hotkey="b" role="dismiss" onPress={showGroup('')}>
            b back
          </Button>
          {lead.url && (
            <Button
              key="copy"
              hotkey="c"
              onPress={press => void $.ui.copy({ text: lead.url as string, surface: press.surface })}
            >
              c copy link
            </Button>
          )}
          <Button
            key="all"
            hotkey="a"
            onPress={() => {
              const ids = groupItems.map(i => i.id)
              void changeInbox($, list => list.map(i => (ids.includes(i.id) ? { ...i, isDone: true } : i)))
              void update($, openGroup, () => '')
            }}
          >
            a all done
          </Button>
        </Box>
        {lead.url && <Text dimColor>{cut(lead.url, width)}</Text>}
      </Box>
    )

    const inboxView = shown && detailView ? detailView : listView

    const cyclesView = (
      <Box flexDirection="column">
        <Text bold>CYCLES ({running} running)</Text>
        {laneRows.length === 0 && <Text dimColor>No cycles this session.</Text>}
        {laneRows.slice(-15).map(l => {
          const mark = ['running', 'pending', 'waiting'].includes(l.status) ? '●' : l.status === 'completed' ? '✓' : '✗'
          const tail = ` ${l.model ? `${l.model} · ` : ''}${l.status}${l.startedAt ? ` · ${ago(l.startedAt, now)}` : ''}`
          return (
            <Text>
              {`${mark} ${cut(l.description, Math.max(10, width - tail.length - 3))}`}
              <Text dimColor>{tail}</Text>
            </Text>
          )
        })}
      </Box>
    )

    const papView = (
      <Box flexDirection="column">
        {papStats.at === 0 && <Text dimColor>Reading the repos…</Text>}
        {papStats.at > 0 && papStats.repos === 0 && <Text dimColor>{noRepos('pap_repos')}</Text>}
        {papStats.rows.map(r => {
          const behind = r.version !== 'self' && papStats.latest && r.version !== papStats.latest
          const ex = r.experiments
          return (
            <Box flexDirection="column" marginBottom={1}>
              <Text bold>
                {r.repo.split('/')[1]}
                <Text dimColor>{`  pap ${r.version}${behind ? ` (latest ${papStats.latest})` : r.version === 'self' ? '' : ' ✓'} · ${r.drift}`}</Text>
              </Text>
              <Text>
                {`Decisions   ${r.proposed.length} proposed${r.proposed.length ? ` (${r.proposed.join(', ')})` : ''} · ${r.revisitsDue} revisits due`}
                <Text dimColor>{` (${r.revisitsManual} manual)`}</Text>
              </Text>
              <Text>
                {`Experiments ${ex.open} open · ${ex.building} building · ${ex.built} built · ${ex.dropped} dropped`}
                <Text dimColor>{r.nextExperiment ? `  next ${r.nextExperiment}` : ''}</Text>
              </Text>
              <Text>
                {`Changes     ${r.openPrs} open PRs · ${r.awaitingReview} risk:high awaiting review`}
              </Text>
              <Text>{`Flow        lead time ${r.leadTimeDays.toFixed(1)}d (median, last 10 merged)`}</Text>
              {r.error !== '' && <Text color="warning">{cut(r.error, width)}</Text>}
            </Box>
          )
        })}
        {papStats.at > 0 && <Text dimColor>{`updated ${ago(papStats.at, now)} ago · /pap:pm console to refresh`}</Text>}
      </Box>
    )

    const ciView = (
      <Box flexDirection="column">
        <Text bold>CI (successful runs, avg / max)</Text>
        {stats.at === 0 && <Text dimColor>Loading…</Text>}
        {stats.at > 0 && stats.repos === 0 && <Text dimColor>{noRepos('ci_repos')}</Text>}
        {stats.rows.slice(0, 15).map(r => (
          <Text>
            {cut(`${r.repo.split('/')[1]} ${r.workflow}`, Math.max(10, width - 16))}
            <Text dimColor>{`  ${mmss(r.avgSec)} / ${mmss(r.maxSec)}`}</Text>
          </Text>
        ))}
        {stats.error !== '' && <Text color="warning">{cut(stats.error, width)}</Text>}
        {stats.at > 0 && <Text dimColor>{`updated ${ago(stats.at, now)} ago · /pap:pm console to refresh`}</Text>}
      </Box>
    )

    const body = current === 'cycles' ? cyclesView : current === 'pap' ? papView : current === 'ci' ? ciView : inboxView

    return (
      <Box flexDirection="column">
        {tabs}
        <Text> </Text>
        {body}
      </Box>
    )
  })
}
