# Plan: release-bump

```text
id:                 release-bump
class:              feature
spec:               changes/release-bump/spec.md
accepted-by:        @blairforce1
accepted-on:        2026-11-13
generated-by:       Claude Opus 5.5 via Claude Code
reviewed-by:        Claude Sonnet (pap:plan-reviewer)
skills:             pap:plan 0.19.1
prompt:             /pap:plan release-bump
```

## Increments

1. The four conditions as `release.sh --places-at <rev> <version>`, which the cut path also calls. Prepares release-bump-4.
2. Refusals and `with_timeout` in `scripts/release-bump.sh`. `tests/release-bump.test.sh` joins `test:pap`. Satisfies release-bump-9, -10, -11.
3. Work tree, re-exec, edits, staged-diff assertion, local checks, commit. Satisfies -2, -3 (the dating), -4, -20.
4. Push, draft, body, label read-back, URL. Satisfies -1, -3 (the body's UTC), -5, -6, -8, -21.
5. Risk wait and box. Satisfies -7.
6. Undo: trap, order, exits 2 and 3. Satisfies -12 to -16.
7. The re-answer form. Satisfies -17.
8. Audit and release cycle: `pap:cycle-mechanical`'s wording and `--by`, the 0024 dated note, the release brief in `docs/run-a-project.md`, the CHANGELOG line. Satisfies -18, -19.

Each drops `@pending` from what it binds.

## Design

- `scripts/release-bump.sh`, POSIX `sh`, is the task `release-bump` in `.config/mise/conf.d/pap-repo.toml`.
- `--places-at` checks the manifests, the prompt and `### [<v>] - YYYY-MM-DD` under `## pap`; the cut path gains the date check.
- The caller's copy runs every refusal, `core.hooksPath` by `git rev-parse --git-path hooks` against the common dir, the places by `git show origin/main:<path>`. It arms the trap, then runs `git worktree add -b`; the caller's index and HEAD are untouched.
- It checks `$wt/scripts/release-bump.sh` exists, else undoes (exit 2), then runs `exec sh "$wt/scripts/release-bump.sh" --in-worktree <wt> <branch> <sha>`. That run re-arms the trap from those first, and repeats the environment and hooks checks.
- The version: x.y.z, no leading zeros, compared field by field in `awk`.
- `--by` is `<agent> on <model>` over `[A-Za-z0-9 .:_-]`, at most 100 bytes; a CR or newline in either input refuses first; `--route` without `--by` refuses.
- Edits use `jq`, `sed`, `awk`, `date -u +%F`; the assertion reads `git diff --cached -U0`.
- `with_timeout` runs a command in the background under `set -m`, its own process group, output to a run-directory file. A `sleep` watchdog sends `kill -TERM -<pgid>` (reaching `ssh` under a push) and writes a marker; `wait` returns the status, 124 when marked. Timeouts: 10 s on the fetch, `RELEASE_BUMP_NET_TIMEOUT` on `ls-remote`, the push, `gh`.
- `scripts/release-bump-body.md`, a fixed template, is filled by `awk` from `ENVIRON` with `index` and `substr`, never `gsub` or `eval`.
- Risk wait 120 s; tests set `RELEASE_BUMP_RISK_WAIT`.
- One trap, on EXIT, INT, TERM and HUP, undoes in the spec's order what the run recorded, then removes the `mktemp -d` directory. The delete checks `ls-remote` against this run's sha, then a plain `git push origin --delete` from the work tree, no lease (decision 0022); the header accepts the window.
- Every step and exit prints its elapsed time.

## Fit

- Touched: `release.sh`, `pap-repo.toml`, `cycle-mechanical.md`, `docs/run-a-project.md`, `CHANGELOG.md`; two new `scripts/` files.
- Left alone: `/change`, `/pap:pm launch` and `pap-pm.sh`, the guard, `pr-checks`, `cycle.md`. The PM writes the release brief.
- The conditions stay in `release.sh`, which `release.test.sh` copies; the coupling is one flag.
- `plugin-agents.test.sh` checks the first-act sentence verbatim, so the exception follows it in its bullet. One case is added, none edited.
- The in-worktree script and template come from `origin/main`; their integrity rests on review of their pull requests, decision 0027's limit.
- Invariants: INV-004, -005, -006, -009; rules 27.1, 27.2.
- Protected paths: `decisions/0024-cycles-run-as-slim-plugin-agents.md` (dated note), `tests/release.test.sh` and `tests/plugin-agents.test.sh` (added to), `tests/release-bump.test.sh` (new).
- Decision record: the 0024 dated note only.

## Tests

Integration tests naming their ids: a bare origin, stubs of `gh`, `mise`, `date` on `PATH`.

- Increment 1: in `release.test.sh`, one refusal per condition, an undated heading included.
- -1: a draft, one `class:chore`, exit 0, URL; caller unchanged.
- -2: exactly the expected lines.
- -3: date stubbed at 23:30Z; other sections unchanged; UTC in the body.
- -4: `--places-at HEAD` exits 0 in the work tree.
- -5, -6: the body's lines and Provenance, with and without a route. The reusable `pr-checks` reads a live pull request through the API, so the first real bump checks it.
- -7: each label row. -8: a dropped label re-added.
- -9 to -11: exit 1, reason named, nothing made. -20: every row exits 0. -21: Provenance carries the value byte for byte.
- `with_timeout`: a `git` wrapper whose fetch hangs gives exit 1 within 15 s; a `gh pr create` that hangs past a 2 s timeout gives exit 2, nothing left, no live process.
- -12, -13: a failing `mise test`, or a refusing hook that ran: exit 2.
- -14: `gh pr create` fails after the stub pushes another commit, or a `pre-receive` refuses deletes.
- -15: a refused label edit, exit 3.
- -16: the create stub signals ready and blocks on a FIFO; TERM, INT and HUP, one row each, give exit 2, the body directory gone.
- -17: four rows.
- -18: the stub log holds no merge, ready, `owner-reviewed`, tag or `main` push; no `GH_TOKEN`.
- -19: a text check on the exception and its `--by`; the first bumps show the passing row; others stay unproven until they occur.
- Portability: `shellcheck -s sh` in `mise run check`.
- Tokens, hand edits, minutes: acceptance on the next three bumps. Refused time: the hung-fetch test bounds it; live, unproven until a bump refuses.

## Observation

- Cycle tokens: increment 8's report; the report event, with the model.
- Hand edits: nothing built; the PM runs `gh pr view <n> --json commits,files`.
- Command minutes: increments 2 to 6, stderr quoted in the report.
- Undone runs: increment 6's exits, `ASK:` from increment 8.
- Release refuses: increment 1, read at the PM's `mise run release`.
- It works once three bumps each come in at or under 30k tokens and 6 minutes, with no hand edit, exit 3 or `release.sh` refusal.
