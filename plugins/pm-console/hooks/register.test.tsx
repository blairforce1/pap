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
