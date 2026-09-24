# 0005. Agent sessions may not bypass git hooks

- **Status:** accepted
- **Date:** 2026-09-24
- **Deciders:** blairforce1, with Claude Code
- **Supersedes:** none
- **PIP:** #26 (the refusal added to `.lefthookrc` for a missing lefthook binary is itself skipped by `LEFTHOOK=0 git commit`)
- **Expected effect:** hook bypasses issued by an agent session in a repository that adopts PAP ↓ to 0; no baseline exists, as nothing recorded them before
- **Introduced in:** unreleased
- **Revisit:** after 20 changes, if the hook refused more than two commands that bypassed nothing, or at once if an agent bypass is found in an adopting repository

## Context

Process principle 9 says verification is part of done and cannot be
weakened by the thing it verifies. Git hooks are verification: the
pre-commit layer runs the secret scan, the formatters and the linters, and
the pre-push layer is one of the three enforcers of
[0002](0002-skills-stop-at-draft-pr.md). Each has an escape hatch:
`LEFTHOOK=0`, `LEFTHOOK_EXCLUDE`, `git commit --no-verify` or `-n`,
`git push --no-verify`, and `git config core.hooksPath`. The hatches exist
for humans, who own the consequences of using them. An agent that meets a
failing hook has the same hatches one command away, and an agent optimising
for a passing commit is exactly the thing the hook verifies. #26 made a
missing lefthook refuse the commit and recorded that `LEFTHOOK=0` still
skips it. Nothing server-side checks pre-commit work: the ruleset guards
main only, and the CI scanning layer does not exist yet.

## Decision

The pap plugin's Claude Code `PreToolUse` hook refuses a Bash command that
sets or contains any of the hatches when the repository it targets adopts
PAP: `LEFTHOOK` or `LEFTHOOK_EXCLUDE` assigned anywhere in the command
(as a prefix, through `env` or `export`, or earlier in a sequence),
`git commit --no-verify` or `-n`, `git push --no-verify`, and
`core.hooksPath` set through `git config`, `-c` or `--config-env`. It
follows `cd`, `git -C`, `env` and `&&`, `||` and `;` sequences the same way
the branch guard does. Humans are unaffected: the hook sees only an agent's
tool calls, so a human at their own terminal keeps every hatch. The reason that
carried it: a check the checked party can switch off is not a check, and
the only party that can be refused without losing an accountable escape is
the agent.

## Considered options

- **Refuse for everyone** (a pre-commit wrapper that rejects the hatches).
  Lost: removes a legitimate hatch, and the human is the accountable party
  who should be able to use it.
- **Teach skills not to bypass.** Lost: 0002 already showed that prose does
  not enforce.
- **Rely on CI.** Lost: CI scanning does not exist yet, and by the time CI
  sees a leaked secret it is already in history.

## Consequences

- Easier: a failing hook in an agent session is fixed or handed to the
  human, not skipped; the refusal names the hatch and this record.
- Easier: the hook shares the branch guard's routing, so a repository that
  does not adopt PAP keeps its hatches, as a repository that does not
  adopt 0002 keeps its main.
- Harder: an agent cannot work around a broken hook, even a broken one;
  the human must fix it or run the command. Intended.
- Harder: the parser is simple. It does not follow `bash -c`, `eval`,
  `GIT_CONFIG_*` variables or a script that runs git, and it refuses a
  `LEFTHOOK=` that appears unquoted inside a commit message split by `;`.
  It raises the cost of a bypass; it does not make one impossible.
- Harder: `git config core.hooksPath` is refused even as a read. Accepted:
  an agent has no need to read it.
- Follow-up: the CI scanning layer is the server-side backstop for
  pre-commit checks; until it exists this hook is the only one.
- Follow-up: the installed plugin enforces this only after
  `claude plugin update` to 0.3.0.
- Recorded 2026-09-24: a command the human runs with `!` inside a Claude
  Code session does not pass through `PreToolUse`. With pap 0.3.0
  installed and reloaded, `! git commit --no-verify -m x` on `main` in
  this repository reached git ("nothing to commit"); the hook would have
  refused it twice, under this record and under 0002. So "humans are
  unaffected" holds inside a session too. It also means `!` skips the 0002
  hook layer; the pre-push hook and the ruleset still apply. `!` is typed
  at the prompt, not issued through the agent's Bash tool, so this record's
  rule is unchanged.

## Where it is taught or enforced

Backs [`rules.md`](../rules.md) 5.1 (agents do not bypass hooks). Enforced
by `plugins/pap/hooks/hooks.json` routing `PreToolUse` on Bash to
`plugins/pap/hooks/guard-route.sh`, tested in `tests/guard-route.test.sh`.
Serves process principle 9 and the hook layers of
[0002](0002-skills-stop-at-draft-pr.md). The status lifecycle follows
[0001](0001-process-changes-are-measured-interventions.md).
