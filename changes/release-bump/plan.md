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
2. Refusals, environment-value checks, `with_timeout`; `tests/release-bump.test.sh` joins `test:pap`. Satisfies -9, -10, -11.
3. Trap and run record, then work tree, re-exec, edits, staged-diff assertion, local checks, commit; a failure undoes (exit 2). Satisfies -2, -3 (dating), -4, -12, -13, -20.
4. Push, draft, body, label read-back, URL. Satisfies -1, -3 (body's UTC), -5, -6, -8, -18, -21.
5. Risk wait and box. Satisfies -7.
6. Undo after the push, signals, exit 3. Satisfies -14, -15, -16.
7. The re-answer form. Satisfies -17.
8. The release cycle: `pap:cycle-mechanical`'s wording and `--by`, the 0024 dated note, the release brief in `docs/run-a-project.md`, the CHANGELOG line. Satisfies -19.

## Design

- `scripts/release-bump.sh`, POSIX `sh`, is mise task `release-bump`.
- `--places-at` checks the manifests, the prompt and `### [<v>] - YYYY-MM-DD` under `## pap`.
- The caller's copy runs every refusal, reading places by `git show origin/main:<path>`, arms the trap, then records each thing it makes from `git worktree add -b` on.
- `GIT_CONFIG_COUNT` must be decimal; `awk` reads pairs from `ENVIRON`, lower-cases keys, takes only the spec's credential pairs.
- It then `exec sh "$wt/scripts/release-bump.sh" --in-worktree <wt> <branch> <sha>`, which re-arms the trap and repeats the environment and hooks checks.
- Versions compare field by field; a CR or newline in route or `--by` refuses first.
- The assertion reads `git diff --cached -U0`; the date is `date -u +%F`.
- `with_timeout` runs a command under `set -m` in its own process group; a `sleep` watchdog marks and sends `kill -TERM -- "-<pgid>"`, a form dash and bash both take; `wait` gives 124 when marked. Fetch 10 s; `RELEASE_BUMP_NET_TIMEOUT` (60) on `ls-remote`, push, `gh`.
- `RELEASE_BUMP_NET_TIMEOUT` and `RELEASE_BUMP_RISK_WAIT` (120) are taken only as a decimal integer from 1 to their default, else the default: a test can shorten a wait, nothing lengthens one.
- `scripts/release-bump-body.txt`, a fixed template, filled by `awk` from `ENVIRON` with `index` and `substr`, never `gsub` or `eval`.
- One trap, on EXIT, INT, TERM, HUP, undoes in the spec's order what was recorded, then removes the `mktemp -d` directory. The delete checks `ls-remote` against this run's sha, then a plain `git push origin --delete` from the work tree (decision 0022).
- Each step prints one timed stderr line.

## Fit

- Touched: `release.sh`, `pap-repo.toml`, `cycle-mechanical.md`, `docs/run-a-project.md`, `CHANGELOG.md`; two new `scripts/` files.
- Left alone: `/change`, `/pap:pm launch`, `pap-pm.sh`, the guard, `pr-checks`, `cycle.md`, the agent shell, and `product/**`: the domain terms, event and rules landed with the spec (54e1c5f).
- Coupling: one flag into `release.sh`; the credential pairs copy the agent shell's exports, so a change there refuses loudly.
- `plugin-agents.test.sh` checks the first-act sentence verbatim; the exception follows it, one case added.
- Invariants: INV-004, -005, -006, -009; rules 27.1, 27.2.
- Protected paths: `decisions/0024-cycles-run-as-slim-plugin-agents.md` (dated note), `tests/release.test.sh` and `tests/plugin-agents.test.sh` (added to), `tests/release-bump.test.sh` (new).
- Decision record: the 0024 dated note, recording the first-act exception, the cold-review reading, and that a script opens a cycle's pull request as the agent app (0023) under 0027's Limits.

## Tests

Integration, by id: a bare origin, `gh`, `mise`, `date` stubs on `PATH`, run by `sh`: dash on CI's ubuntu runner, bash locally.

- Increment 1: `release.test.sh` refuses each condition, an undated heading included.
- -1: draft, one `class:chore`, exit 0, URL; caller unchanged.
- -2: exactly the bump's lines. -3: date at 23:30Z; other sections unchanged; UTC in the body.
- -4: `--places-at HEAD` exits 0.
- -5, -6: body lines and Provenance, with and without a route. `pr-checks`' parser lives in the reusable workflow, so no hermetic test runs it: accepted, and observed.
- -7: each label row. -8: a dropped label re-added.
- -9, -10, -11: each row exits 1 naming its reason, nothing made; the agent shell's exact pairs, mixed-case keys, are taken.
- -20: every row exits 0. -21: Provenance carries the value byte for byte.
- `with_timeout`: a hanging fetch exits 1 within 15 s; a hanging `gh pr create` past 2 s exits 2, nothing left, no live process; a non-numeric or oversized timeout falls back.
- -12, -13: a failing `mise test`, or a hook that ran and refused: exit 2.
- -14: `gh pr create` fails after the stub pushes another commit, or a `pre-receive` refuses deletes.
- -15: a refused label edit: exit 3.
- -16: the create stub blocks on a FIFO; TERM, INT, HUP each give exit 2, body directory gone.
- -17: four rows.
- -18, from increment 4: the stub log holds no merge, ready, `owner-reviewed`, tag, `main` push or force of any kind; each push and `gh` call once, the label re-add aside; every network call saw `GIT_TERMINAL_PROMPT=0`; no `GH_TOKEN`.
- Per-step lines: a full run's stderr has one per step, each timed.
- -19: a text check on the exception and its `--by`; live rows unproven.
- Portability: `shellcheck -s sh` in `mise run check`.
- Tokens, hand edits, minutes: acceptance on the next three bumps; refused time also by the hung-fetch test.

## Observation

- Cycle tokens: increment 8's report event, with the model.
- Hand edits: nothing built; the PM runs `gh pr view <n> --json commits,files`.
- Command minutes: increments 2 to 6, stderr quoted in the report.
- Undone runs: increments 3 and 6's exits, `ASK:` from increment 8.
- Release refuses: increment 1, read at the PM's `mise run release`.
- The first bump's `pr-checks` run first checks the body; a failure is an `ASK:`.
- It works once three bumps each stay within 30k tokens and 6 minutes, with no hand edit, exit 3 or `release.sh` refusal.
