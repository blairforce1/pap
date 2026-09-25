# 0005. Agent sessions may not bypass git hooks

- **Status:** measured:inconclusive (2026-09-25)
- **Disposition:** kept
- **Date:** 2026-09-24
- **Deciders:** blairforce1, with Claude Code
- **Supersedes:** none
- **PIP:** #26 (the refusal added to `.lefthookrc` for a missing lefthook binary is itself skipped by `LEFTHOOK=0 git commit`)
- **Expected effect:** hook bypasses issued by an agent session in a repository that adopts PAP ↓ to 0; no baseline exists, as nothing recorded them before
- **Introduced in:** v0.5.0
- **Revisit:** after 20 change PRs from #27: if the hook refused more than two commands that bypassed nothing; and at once, by hand, if an agent bypass is found in an adopting repository. The record predates the first tag, so the count starts after its pull request

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

## Result

Evaluated 2026-09-25 by hand. The data is not in GitHub: a refusal
happens inside a Claude Code session and leaves no trace outside it. The
window is #28 to #51, the twenty change pull requests after #27, read as
the time from #27's merge (2026-09-24 13:14 UTC) to #51's (2026-09-25
15:43 UTC).

Method: a script read every session transcript on this machine under
`~/.claude/projects/` whose directory names blairforce1, subagent and
scratchpad sessions included: 27 files and 21 sessions in the window,
953 Bash tool calls. It paired each Bash call with its result and
counted a refusal only where the result begins with Claude Code's
`PreToolUse:Bash hook error:` framing; the hook's own text quoted in a
file read or a diff was not counted. Each of the twenty `change/`
branches is named in at least four of those transcripts. The script was
a throwaway and is not in the repository.

Trigger: no. The hook refused six commands in the window, and one of
them bypassed nothing.

| When (UTC)       | Command                                                 | Refused under | Class                                     |
| ---------------- | ------------------------------------------------------- | ------------- | ----------------------------------------- |
| 2026-09-24 13:17 | `git commit --no-verify -m x` on `main`                 | 0002 and 0005 | Real bypass refused: a deliberate probe   |
| 2026-09-24 15:07 | `git push origin --delete change/scratch-…` from `main` | 0002          | Out of scope: 0002's branch guard         |
| 2026-09-24 15:30 | `git -c core.hooksPath=/dev/null status`, then a commit | 0005          | False refusal: `git status` runs no hooks |
| 2026-09-24 18:51 | commit and push on `scratch/security-cache-preview`     | 0002          | Out of scope: 0002's branch guard         |
| 2026-09-24 18:51 | push `--delete` on the same `scratch/` branch           | 0002          | Out of scope: 0002's branch guard         |
| 2026-09-24 18:51 | `git branch -m` then push `--delete`, from `main`       | 0002          | Out of scope: 0002's branch guard         |

So under this record: one real bypass refused, one false refusal, and
four refusals that belong to 0002. The probe was the #28 session
checking that the hook was live, on the human's question; it is a real
bypass and was meant to be refused. The false refusal's `-c` applied
only to `git status`; the commit after it in the same command carried no
hatch, and ran on the retry. Why the agent wrote the `-c` is not in the
transcript; it called it stray. It is counted as a command that bypassed
nothing. No refusal under
[0012](0012-protected-paths-need-an-owners-approved-by-line.md) falls in
the window, or anywhere in these transcripts: the hook runs from the main
checkout (the plugin's marketplace is that directory), and 0012's check
reached main only when #51 merged, at the window's end.

"jq not found": eleven transcript results contain the phrase. Ten are the
script's source or a decision record quoted by a file read. The one real
run was a test on 2026-09-23, before the window: the script run by hand
with `jq` removed from `PATH`, which printed the message and exited 1
for a guarded session. In a live session that exit is a non-blocking hook
error, so the command would run: the hook errors open without `jq`. It
did not happen here as far as can be seen: `jq` is installed from nix,
and every 0005 refusal in the window needed `jq` to parse the command.

Bypasses that got through: none found. Every Bash command in the window
was searched for `LEFTHOOK`, `LEFTHOOK_EXCLUDE`, `--no-verify`, a
`commit` short-flag cluster containing `n`, `core.hooksPath` and
`GIT_CONFIG_`, in the raw command text, so a hatch inside `bash -c` or
`eval` would have matched too. Besides the two refused above, the hits
are text: `--no-verify` quoted in the #28 commit message and pull request
body (passed, correctly), and `--no-verify` and `LEFTHOOK=0` quoted in a
README edit. No `bash -c` or `eval` in the window wraps a hatch. pap's
`scripts/`, `bin/`, `tests/`, `templates/` and `plugins/` run no git
command with a hatch; `tests/guard-route.test.sh` feeds hatch strings to
the hook, never to git. pap is the only adopting repository checked out
on this machine.

Limits: only this machine's sessions. Cloud sessions, claude.ai sessions
and any other machine are unseen, and a transcript deleted by Claude
Code's cleanup would be missing without a trace. A hook that exits 0 or
errors open leaves nothing in the transcript, since only blocks are
recorded, so an errored-open run cannot be excluded, only made unlikely.
A hatch built from a variable, or inside a script outside the paths
searched, would not be seen.

Status, by [0001](0001-process-changes-are-measured-interventions.md)'s
rule: the expected effect has no baseline, as the record says, so no
before/after split exists and nothing can be confirmed; the trigger did
not fire, so `measured:inconclusive`. The trigger's condition for
reconsidering the hook, more than two false refusals, is not met, and
no bypass got through, so the hook is kept.

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
- Recorded 2026-09-25: the revisit was evaluated; see Result. The hook
  runs from the main checkout, not a pinned plugin copy, so the version in
  force in a session is whatever main held when the checkout was last
  pulled; 0012's refusal was not live until #51 merged.

## Where it is taught or enforced

Backs [`rules.md`](../rules.md) 5.1 (agents do not bypass hooks). Enforced
by `plugins/pap/hooks/hooks.json` routing `PreToolUse` on Bash to
`plugins/pap/hooks/guard-route.sh`, tested in `tests/guard-route.test.sh`.
Serves process principle 9 and the hook layers of
[0002](0002-skills-stop-at-draft-pr.md). The status lifecycle follows
[0001](0001-process-changes-are-measured-interventions.md).
