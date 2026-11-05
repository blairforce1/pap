// pm-console: the PM's console beside the chat.
// - Waiting on you: what each lane's report asks of the Project Lead. The PM
//   records items with the inbox_add tool, with the report as detail. Items are
//   grouped by ref; opening a group shows the report and ticks items. The PM
//   can also call inbox_done. Kept in $.store, so it survives restarts.
// - Lanes: this session's background agents, live from $.agent.list().
// - CI: average and slowest run time per workflow, from `gh run list`.
// - Status line: one summary of all three.
import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { CiRow, CiStats, InboxItem, LaneRow, PapRow, PapStats } from '../types'

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
// The inbox group whose detail is open ('' = the list). A group is one report: its ref, else its lane.
const openGroupRef = { plugin: 'pm-console', key: 'openGroup' } as const
const openGroup = atom(openGroupRef, '')
const TABS = [
  ['inbox', 'Inbox', '1'],
  ['lanes', 'Lanes', '2'],
  ['pap', 'PAP', '3'],
  ['ci', 'CI', '4'],
] as const
const groupOf = (i: InboxItem) => i.ref || `lane ${i.lane}`

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

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const stored = (await $.store.get(STORE_INBOX)) as InboxItem[] | undefined
    if (stored && (await getInbox($)).length === 0) await update($, inbox, () => (Array.isArray(stored) ? stored : []))

    await $.command.register({
      name: 'pm',
      description: 'Open the PM console (what lanes ask of you, lanes, CI)',
    })
    await $.tool.register({
      name: 'inbox_add',
      description:
        'Add what a lane report asks of the Project Lead to the PM console (one short imperative line per item: review, decide, merge, run). Call when a lane reports.',
      inputSchema: {
        type: 'object',
        properties: {
          lane: { type: 'string', description: 'Lane number or slug, e.g. "105"' },
          ref: { type: 'string', description: 'PR or thing it concerns, e.g. "ap#4"; items are grouped by it' },
          items: { type: 'array', items: { type: 'string' }, minItems: 1 },
          detail: {
            type: 'string',
            description:
              'What the lane reported, shown when the Project Lead opens the group: built, deviations, decisions left, revisits. Short lines, no secrets.',
          },
          url: { type: 'string', description: 'Link to the PR or thing, copied from the detail view' },
        },
        required: ['lane', 'items'],
      },
      isDeferred: false,
    })
    await $.tool.register({
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
    await $.tool.register({
      name: 'inbox_done',
      description: 'Mark PM console items done by id (the Project Lead did them).',
      inputSchema: {
        type: 'object',
        properties: { ids: { type: 'array', items: { type: 'string' }, minItems: 1 } },
        required: ['ids'],
      },
      isDeferred: false,
    })
    await $.tool.register({
      name: 'inbox_list',
      description: 'List the PM console items still waiting on the Project Lead, with ids.',
      inputSchema: { type: 'object', properties: {} },
      isDeferred: false,
    })
    await $.tool.register({
      name: 'ci_repos',
      description: 'Set the GitHub repos (owner/name) whose CI timings the PM console shows.',
      inputSchema: {
        type: 'object',
        properties: { repos: { type: 'array', items: { type: 'string' }, minItems: 1 } },
        required: ['repos'],
      },
    })

    $.clock.every(15_000, () => void refreshLanes($))
    await $.tool.register({
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

    $.clock.every(600_000, () => void refreshCi($))
    $.clock.every(1_800_000, () => void refreshPap($))
    void refreshLanes($)
    void refreshCi($)
    void refreshPap($)
    void $.ui.open({ id: PANE, title: 'PM console' })

    return next(e)
  })

  on('command.run', { command: 'pm' }, async $ => {
    await $.ui.open({ id: PANE, title: 'PM console' })
    void refreshCi($)
    void refreshPap($)
    return { text: 'PM console opened; CI and PAP figures refreshing.' }
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
    const input = e as unknown as { lane: string; ref?: string; items: string[]; detail?: string; url?: string }
    const now = Date.now()
    const added: InboxItem[] = input.items.map((text, i) => ({
      id: `${now.toString(36)}${i}`,
      text,
      lane: String(input.lane),
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
      lanes: `${running}`,
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
          const tail = ` lane ${first.lane} · ${ago(first.at, now)} · ${g.items.length} ▸`
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
          <Text dimColor>{`  lane ${lead.lane} · ${ago(lead.at, now)}`}</Text>
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

    const lanesView = (
      <Box flexDirection="column">
        <Text bold>LANES ({running} running)</Text>
        {laneRows.length === 0 && <Text dimColor>No lanes this session.</Text>}
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
        {papStats.at > 0 && <Text dimColor>{`updated ${ago(papStats.at, now)} ago · /pm to refresh`}</Text>}
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
        {stats.at > 0 && <Text dimColor>{`updated ${ago(stats.at, now)} ago · /pm to refresh`}</Text>}
      </Box>
    )

    const body = current === 'lanes' ? lanesView : current === 'pap' ? papView : current === 'ci' ? ciView : inboxView

    return (
      <Box flexDirection="column">
        {tabs}
        <Text> </Text>
        {body}
      </Box>
    )
  })
}
