# Plan: release-bump

```text
id:                 release-bump
class:              feature
spec:               changes/release-bump/spec.md
accepted-by:
accepted-on:
generated-by:       Claude Opus 5.5 via Claude Code
reviewed-by:        Claude Sonnet (pap:plan-reviewer)
skills:             pap:plan 0.19.1
prompt:             /pap:plan release-bump
```

## Increments

1. One definition of the four conditions: `release.sh --places-at <rev> <version>`, which the cut path also uses, with cases added to `tests/release.test.sh`. Prepares release-bump-4.
2. Refusals in `scripts/release-bump.sh`. `tests/release-bump.test.sh` joins `test:pap`. Satisfies release-bump-9, -10 and -11.
3. Work tree and edits: the re-exec, the edits, the staged-diff assertion, the local checks and the commit, with no push. Satisfies -2, -3 and -20.
4. Push and open: the push, the draft, the body, the label read-back and the URL. Satisfies -1, -4, -5, -6 and -8.
5. Risk wait and box. Satisfies -7.
6. Undo: traps, the order, exits 2 and 3. Satisfies -12 to -16.
7. The re-answer form. Satisfies -17.
8. Audit and release cycle: the wording in `pap:cycle-mechanical`, the dated note on 0024 and the CHANGELOG line. Satisfies -18 and -19.

Each increment drops `@pending` from what it binds.

## Design

- `scripts/release-bump.sh`, POSIX `sh`, runs as the task `release-bump` in `pap-repo.toml`. `base.toml` already puts the shim on every task's path.
- `--places-at` checks the manifests, the prompt and `### [<v>] - YYYY-MM-DD` under `## pap`. The cut path keeps its "Unreleased" message and gains the date check.
- The caller's copy checks the route, the environment, `core.hooksPath` (`git rev-parse --git-path hooks` must be the common dir's) and the fetch. Then it reads `git show origin/main:<path>`, checks the branch, work tree and path, and runs `git worktree add -b`. It never touches the caller's index or HEAD.
- It then runs `exec sh "$wt/scripts/release-bump.sh" --in-worktree`, an internal flag. The new run repeats the environment and hooks checks, and checks `$wt`, the branch and the fetched sha.
- The version is `^(0|[1-9][0-9]*)(\.(0|[1-9][0-9]*)){2}$`, compared field by field in `awk`.
- Edits use `jq`, `sed`, `awk` and `date -u +%F`. The assertion is `git diff --cached -U0` against the expected lines.
- `with_timeout` uses `set -m`, so each command gets its own process group. A `sleep` watchdog runs `kill -TERM -<pgid>`, which reaches `ssh` under a push, and is reaped when the command ends. The trap kills live groups before undoing. Timeouts: 10 s for the fetch, and one each for `ls-remote`, the push and `gh`.
- `scripts/release-bump-body.md` is a fixed template. `awk` fills it from `ENVIRON` literally, with `index` and `substr`, never `gsub` or `eval`.
- Provenance cannot be built as written. The spec reads the agent and model "from what the cycle passes", but its interface has no input for them. Release-bump-5's model clause waits on the spec. With no route, Provenance names the owner.
- The risk wait is 120 s; tests set `RELEASE_BUMP_RISK_WAIT`.
- One trap, on EXIT, INT, TERM and HUP, undoes in the spec's order what the run recorded, then removes the `mktemp -d` directory. The delete checks `ls-remote` against this run's sha, then runs a plain `git push origin --delete`, with no lease (decision 0022). The script header accepts the window between the two.
- Every exit, a refusal included, prints its elapsed time.

## Fit

- Touched: `scripts/release.sh`, `pap-repo.toml`, `cycle-mechanical.md`, `CHANGELOG.md` and two new scripts.
- Left alone: `/change`, `/pap:pm launch`, the guard, `pr-checks` and `cycle.md`.
- `tests/plugin-agents.test.sh` checks the first-act sentence word for word, so the exception follows it in the same bullet. No existing case is edited.
- The checks stay inside `release.sh`, because `release.test.sh` copies only it and `written-with.sh`.
- The body meets `pr-checks` as text, and the first real bump proves it.
- Invariants: INV-004, INV-005, INV-006, INV-009; rules 27.1 and 27.2.
- Protected paths: `decisions/0024-cycles-run-as-slim-plugin-agents.md`, `tests/release.test.sh` (added to), `tests/release-bump.test.sh` (new).
- Decision record: the dated note on 0024.

## Tests

All are integration tests, each naming its id. Each runs against a bare origin with stubs of `gh`, `mise` and `date`.

- Increment 1: one refusal per condition, an undated heading among them; the existing suite passes.
- -1: a draft, one `class:chore`, exit 0, the URL; the caller's branch, HEAD and index are unchanged.
- -2: exactly the expected lines.
- -3: with the date stubbed at 23:30Z, the other sections are unchanged and the body says UTC.
- -4: `--places-at HEAD` exits 0, and fails when undated.
- -5, -6: the body and its Provenance; `pr-checks` passes on the first real bump.
- -7, -8: each stubbed label; a dropped label added back.
- -9, -10, -11: exit 1 with the reason, and nothing made. -20: every row exits 0.
- -12, -13: a failing `mise test`, or a refusing hook that ran; exit 2.
- -14: `gh pr create` fails. Either the stub first pushes another commit, or origin's `pre-receive` refuses deletes.
- -15: a refused label edit; exit 3.
- -16: the create stub writes a ready file and blocks on a FIFO; on it the test sends TERM, and gets exit 2.
- -17: the four rows.
- -18: the stub's log shows no merge, ready, `owner-reviewed`, tag or push to `main`; `GH_TOKEN` is unset.
- -19: a text check that the exception is present. The first bumps should show the passing row, and likely "not read" or `risk:high`. The other rows stay unproven until they occur.
- Portability: `shellcheck -s sh`.
- Tokens, hand edits, minutes and refused time: acceptance on the next three bumps.

## Observation

- Cycle tokens: increment 8's report, with the model; read from the report event.
- Hand edits: nothing is built; the PM runs `gh pr view <n> --json commits,files`.
- Minutes and refused time: increments 2 to 6, in the report.
- Undone runs: increment 6's exits, as `ASK:` from increment 8.
- Release refuses: increment 1, read at `mise run release`.
- Once merged, it works when three bumps each come in at or under 30k tokens and under 6 minutes, with no hand edits, no exit 3 and no `release.sh` refusal.
