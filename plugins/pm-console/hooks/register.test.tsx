import type { PromptEditInput, PromptEditResult } from 'claude-code'
import { expect, mock, test } from 'claude-code/testing'

const BAND = {
  plugin: 'pm-console',
  component: 'AbovePrompt',
  props: {
    hasSurvey: false,
    isWorking: false,
    maxRows: 20,
    bodyColumns: 80,
    scroll: { offset: 0, bodyRows: 20 },
    view: {},
  },
} as const

const submit = (name: string, args: string) => ({
  text: `/${name} ${args}`,
  command: { name, args },
  wait: false,
  origin: { kind: 'composer' as const },
})

test('a change command with an unknown class is refused, with the reason', async ($, on) => {
  let reached = false
  on('prompt.submit', (_, e) => {
    reached = true
    return { text: e.text }
  })

  const sent = await $.prompt.submit(submit('pap:change', 'acme-widgets process tidy the backlog'))

  expect(sent.drop).toContain('not a class; process records use infra')
  expect(reached).toBe(false)
})

test('a change command with a valid class goes through', async ($, on) => {
  let reached = false
  on('prompt.submit', (_, e) => {
    reached = true
    return { text: e.text }
  })
  // Not a git repository: the branch check says nothing.
  on('session.cwd', () => ({ value: '/' }))
  on('process.run', () => ({
    value: { exitCode: 128, stdout: '', stderr: 'not a git repository', isStdoutTruncated: false, isStderrTruncated: false },
  }))

  const sent = await $.prompt.submit(submit('pap:change', 'acme-widgets feature add the widget list'))

  expect(sent.drop).toBeUndefined()
  expect(reached).toBe(true)
})

test('a slug is matched to branches literally, and a backslash in it is refused', async ($, on) => {
  const toasts: string[] = []
  on('ui.toast', (_, e) => {
    toasts.push(String(e.text))
    return { value: undefined }
  })
  on('prompt.submit', (_, e) => ({ text: e.text }))
  on('session.cwd', () => ({ value: '/' }))
  // `.` in a slug is a dot, not any character: a.b must not match aXb.
  on('process.run', () => ({
    value: {
      exitCode: 0,
      stdout: 'refs/heads/main\nrefs/remotes/origin/change/aXb\nrefs/heads/wip/change/a.b\n',
      stderr: '',
      isStdoutTruncated: false,
      isStderrTruncated: false,
    },
  }))

  const slash = await $.prompt.submit(submit('pap:change', 'a\\b feature tidy'))
  expect(slash.drop).toContain('a slug takes only')

  const dotted = await $.prompt.submit(submit('pap:change', 'a.b feature tidy'))
  expect(dotted.drop).toBeUndefined()
  expect(toasts.some(t => t.includes('already exists'))).toBe(false)

  const real = await $.prompt.submit(submit('pap:change', 'aXb feature tidy'))
  expect(real.drop).toBeUndefined()
  expect(toasts.some(t => t.includes('change/aXb already exists'))).toBe(true)
})

test('/spec takes a slug alone and is not refused', async ($, on) => {
  let reached = false
  on('prompt.submit', (_, e) => {
    reached = true
    return { text: e.text }
  })
  // The intent is on the branch: git answers yes.
  on('session.cwd', () => ({ value: '/' }))
  on('process.run', () => ({
    value: { exitCode: 0, stdout: '', stderr: '', isStdoutTruncated: false, isStderrTruncated: false },
  }))

  const good = await $.prompt.submit(submit('pap:spec', 'good-slug'))
  expect(good.drop).toBeUndefined()
  expect(reached).toBe(true)

  const bad = await $.prompt.submit(submit('pap:spec', 'bad/slug'))
  expect(bad.drop).toContain('a slug takes only')
})

test('the class band shows while /intent is typed, and not otherwise', async ($, on) => {
  on('prompt.edit', (_, e) => {
    const text = e.text.slice(0, e.start) + e.inputText + e.text.slice(e.end)
    return { text, cursor: e.start + e.inputText.length }
  })
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>engine</Text>
  })

  // The kit raises prompt.edit, but its typings list no call for it.
  const raise = ($.prompt as unknown as { edit: (e: PromptEditInput) => Promise<PromptEditResult> }).edit
  const edit = (text: string, inputText: string) =>
    raise({ origin: { kind: 'composer' }, text, cursor: text.length, start: text.length, end: text.length, inputText })

  for (const surface of ['terminal', 'desktop'] as const) {
    await edit('', 'hello')
    let ui = await $.ui.mount({ ...BAND, surface })
    expect(await ui.find({ type: 'Text', text: /security-sensitive/ })).toBeUndefined()
    await ui.unmount()

    await edit('', '/intent ')
    ui = await $.ui.mount({ ...BAND, surface })
    expect((await ui.find({ type: 'Text', text: /security-sensitive/ }))?.text).toContain('security-sensitive')
    expect((await ui.find({ type: 'Text', text: /no spec, no deploy/ }))?.text).toContain('no spec, no deploy')
    await ui.unmount()
  }
})

test('exit_ready true puts /exit in the prompt box', async ($, on) => {
  let filled = ''
  mock.store(on)
  on('prompt.fill', (_, e) => {
    filled = e.text
    return { isFilled: true }
  })

  await $.tool.call({ tool: 'mcp__pm-console__exit_ready', ok: true })

  expect(filled).toBe('/exit')
})

// What reached the engine: undefined when the console dropped the prompt.
const launch = async ($: Parameters<Parameters<typeof test>[1]>[0], on: Parameters<Parameters<typeof test>[1]>[1], args: string) => {
  let reached = false
  on('prompt.submit', (_, e) => {
    reached = true
    return { text: e.text }
  })
  on('session.cwd', () => ({ value: '/' }))
  on('process.run', () => ({
    value: { exitCode: 128, stdout: '', stderr: 'not a git repository', isStdoutTruncated: false, isStderrTruncated: false },
  }))
  const sent = await $.prompt.submit(submit('pap:pm', args))
  return { drop: sent.drop, reached }
}

test('/pap:pm launch <slug> is submitted: the class is on the brief', async ($, on) => {
  const sent = await launch($, on, 'launch trial')

  expect(sent.drop).toBeUndefined()
  expect(sent.reached).toBe(true)
})

test('/pap:pm launch <slug> <class> is submitted', async ($, on) => {
  const sent = await launch($, on, 'launch trial bugfix')

  expect(sent.drop).toBeUndefined()
  expect(sent.reached).toBe(true)
})

test('/pap:pm launch with a bad slug is refused', async ($, on) => {
  const sent = await launch($, on, 'launch -bad')

  expect(sent.drop).toContain('a slug takes only')
  expect(sent.reached).toBe(false)
})

test('/pap:pm launch with a word that is not a class after the slug is refused', async ($, on) => {
  const sent = await launch($, on, 'launch trial notaclass')

  expect(sent.drop).toContain('"notaclass": not a class')
  expect(sent.reached).toBe(false)
})

for (const form of ['start', 'exit', 'console']) {
  test(`/pap:pm ${form} passes the prompt hook untouched`, async ($, on) => {
    let seen = ''
    let ran = false
    on('prompt.submit', (_, e) => {
      seen = e.text
      return { text: e.text }
    })
    // A form with no slug asks git nothing.
    on('process.run', () => {
      ran = true
      return { value: { exitCode: 0, stdout: '', stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }
    })

    const sent = await $.prompt.submit(submit('pap:pm', form))

    expect(sent.drop).toBeUndefined()
    expect(seen).toBe(`/pap:pm ${form}`)
    expect(ran).toBe(false)
  })
}

const TOOLS = ['console_open', 'exit_ready', 'inbox_add', 'inbox_note', 'inbox_done', 'inbox_list', 'ci_repos', 'pap_repos']

// Start the session with the engine refusing the tools named; what it was asked to register and what was said.
const startUp = async (
  $: Parameters<Parameters<typeof test>[1]>[0],
  on: Parameters<Parameters<typeof test>[1]>[1],
  refused: string[] = [],
) => {
  const seen = { tools: [] as string[], commands: [] as string[], toasts: [] as string[], logs: [] as string[] }
  mock.store(on)
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('session.cwd', () => ({ value: '/' }))
  on('process.run', () => ({
    value: { exitCode: 1, stdout: '', stderr: '', isStdoutTruncated: false, isStderrTruncated: false },
  }))
  on('agent.list', () => ({ value: [] }))
  on('clock.every', () => ({ value: undefined }))
  on('ui.open', () => ({ value: { isPlaced: true } }))
  on('ui.status', () => ({ value: undefined }))
  on('command.register', (_, e) => {
    seen.commands.push(e.name)
    return { value: { command: e.name } }
  })
  on('tool.register', (_, e) => {
    // A deny rejects the caller, as the engine's own refusal does.
    if (refused.includes(e.name)) return { deny: `"${e.name}" refused` }
    seen.tools.push(e.name)
    return { value: { tool: e.name } }
  })
  on('ui.toast', (_, e) => {
    seen.toasts.push(String(e.text))
    return { value: undefined }
  })
  on('ui.log', (_, e) => {
    seen.logs.push(String(e.text))
    return { value: undefined }
  })
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  // The first refreshes run on after start-up answers: let them end inside the test.
  await new Promise(r => setTimeout(r, 50))
  return seen
}

test('start-up registers no command, and registers console_open with the other tools', async ($, on) => {
  const seen = await startUp($, on)

  expect(seen.commands).toEqual([])
  expect(seen.tools).toEqual(TOOLS)
  expect(seen.toasts).toEqual([])
})

test('a registration that throws does not stop the rest: it is logged by name and toasted once', async ($, on) => {
  const seen = await startUp($, on, ['console_open', 'inbox_note'])

  expect(seen.tools).toEqual(TOOLS.filter(t => t !== 'console_open' && t !== 'inbox_note'))
  expect(seen.logs.filter(l => l.includes('console_open') && l.includes('refused')).length).toBe(1)
  expect(seen.logs.filter(l => l.includes('inbox_note') && l.includes('refused')).length).toBe(1)
  expect(seen.toasts.length).toBe(1)
  expect(seen.toasts[0]).toContain('console_open, inbox_note')
})

test('console_open opens the pane and refreshes the PAP and CI figures', async ($, on) => {
  const opened: string[] = []
  const ran: string[] = []
  mock.store(on, { 'ci-repos': ['acme/widgets'], 'pap-repos': [{ repo: 'acme/widgets', path: '/w' }] })
  on('session.cwd', () => ({ value: '/' }))
  on('agent.list', () => ({ value: [] }))
  on('ui.open', (_, e) => {
    opened.push(e.id)
    return { value: { isPlaced: true } }
  })
  on('process.run', (_, e) => {
    ran.push(JSON.stringify(e))
    return { value: { exitCode: 1, stdout: '', stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }
  })

  const out = (await $.tool.call({ tool: 'mcp__pm-console__console_open' })) as { result?: string }

  expect(opened).toEqual(['pm-console'])
  expect(out.result).toContain('opened')
  // The refreshes run on after the call answers.
  await new Promise(r => setTimeout(r, 50))
  expect(ran.some(r => r.includes('run') && r.includes('acme/widgets'))).toBe(true)
  expect(ran.some(r => r.includes('/w'))).toBe(true)
})

test('the band for /pap:pm launch says the class comes from the brief, and asks for none', async ($, on) => {
  on('prompt.edit', (_, e) => {
    const text = e.text.slice(0, e.start) + e.inputText + e.text.slice(e.end)
    return { text, cursor: e.start + e.inputText.length }
  })
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>engine</Text>
  })
  const raise = ($.prompt as unknown as { edit: (e: PromptEditInput) => Promise<PromptEditResult> }).edit
  await raise({ origin: { kind: 'composer' }, text: '', cursor: 0, start: 0, end: 0, inputText: '/pap:pm launch ' })

  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect((await ui.find({ type: 'Text', text: /class comes from the brief/ }))?.text).toContain('/pap:pm launch <slug>:')
  expect(await ui.find({ type: 'Text', text: /<slug> <class>/ })).toBeUndefined()
  await ui.unmount()
})
