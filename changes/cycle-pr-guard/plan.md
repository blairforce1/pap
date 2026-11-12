# Plan: cycle-pr-guard

```text
id:                 cycle-pr-guard
class:              infra
spec:               changes/cycle-pr-guard/spec.md
accepted-by:        @blairforce1
accepted-on:        2026-11-12
generated-by:       Claude Fable 5.2 (claude-fable-5-2) via Claude Code
reviewed-by:        Claude Sonnet via pap:plan-reviewer
skills:             pap:plan 0.19.0
prompt:             /pap:plan cycle-pr-guard
```

## Increments

1. Placement and rule 27.2, with the refusal log line.
   Scenarios: cycle-pr-guard-4, -5, -6, -7, -8, -9, -13, -17.
2. Rule 27.1 and the `unread` line.
   Scenarios: cycle-pr-guard-1, -2, -3, -14, -16, and the 27.1 rows of
   -7, -9 and -13.
3. The reading at session start. Scenario: cycle-pr-guard-15.
4. The `pap doctor` item. Scenarios: cycle-pr-guard-10, -11.
5. Decision 0027, `rules.md`, the two cycle definitions' sentence, the
   adoption guides, `docs/troubleshooting.md`, `docs/run-a-project.md`.
   Scenario: cycle-pr-guard-12.

Each increment removes `@pending:cycle-pr-guard` from the scenarios it
binds.

## Design

`plugins/pap/hooks/guard-route.sh`. Both new targets come from the
quote-aware pass (`prbodies`), which splits statements outside quotes
only: a verb inside a quoted word or a heredoc is no target.

- The pass gains an `unplaced` state, kept for the rest of the command:
  set by a `cd` whose word as written holds `$` or a backquote, by
  `cd -`, `pushd`, `popd`, and by `GIT_DIR` or `GIT_WORK_TREE` assigned
  in any statement, `export` included. A git statement with
  `--git-dir`, `--work-tree`, or a `-C` word holding `$` or a backquote
  is unplaced itself. Words are tested before unquoting.
- A statement headed `git` skips global options and applies `-C`. For
  `switch` and `checkout` it emits a target `sw`: directory, verb,
  verdict, placed flag. Verdicts: `ok`, the spec's four forms;
  `path-without-dashes`, a checkout of exactly one word that is not
  `main`, with no `--` and none of the four options, branch or path
  alike; `branch-switch`, every other form.
- `gh pr create|new` emits a target `pr`: directory, count of literal
  class labels, placed flag.
- `unread` is emitted when the unquoted words name one of the four
  verbs and no statement has it at its head, as in
  `if true; then gh pr create; fi`, and from the pass's `catch`.

The shell loop:

- The three targets are skipped unless `PAP_MODE=pm`; verdict `ok`
  costs no git call.
- `place <dir>`: a directory that does not exist is not placed. Else
  one `git rev-parse --path-format=absolute --show-toplevel --git-dir
  --git-common-dir`, cached by directory. Main checkout: the git
  directory equals the common directory. It adopts by an executable
  `scripts/guard-branch.sh` at its root.
- The session's project adopts by today's file test,
  `-x "$CLAUDE_PROJECT_DIR/scripts/guard-branch.sh"`, with no git call.
  It binds a `pr` in no adopting repository and every unplaced target.
- `refuse27 <kind> <form> <dir>`: the spec's two lines, status 2, the
  log line, with the caller's agent type. Only here is `pm_session`
  run, for the repository key.

`plugins/pap/hooks/pm-lib.sh`: `pm_log` sets `pm_logged` false when the
directory cannot be made or the append fails; the guard then prints
the third line. The refusal log line gains an eighth field, the form.

`plugins/pap/hooks/session-start.sh`, PM branch: the main checkout is
`pm_own_common` less `/.git`; one `git symbolic-ref -q --short HEAD`
there. Off `main` the session log line gains a seventh field,
`main-checkout:<branch>` or `main-checkout:detached`, and the role a
part `[pap-pm:main-checkout]`.

`bin/pap`, `cmd_doctor`, git section: one item, "main checkout on
main", read the same way.

`product/domain.md`: the Refusal log's definition gains kind and form.
Decision 0027 records them too.

## Fit

- Left alone: the segment pass, `scripts/guard-branch.sh`, `/change`,
  every existing target kind.
- Coupling: the new targets return before the generic branch, so no
  existing rule reads them.
- Invariants: INV-003, INV-005, INV-008.
- Protected paths: `plugins/pap/hooks/**`, `tests/**`, `decisions/**`,
  `rules.md`, `product/**`.
- Not buildable as written, two points. Processes are to be counted "as
  the guard's tests count them today", and those tests count none: a
  stand-in `git` is added, after `tests/pap-new.test.sh`. And placement
  costs one process a distinct directory, so the verbs in three
  directories take three, over the row's two. The owner decides: a
  limit named in 0027, or the row returns to the spec.

## Tests

In a new `tests/cycle-pr-guard.test.sh`, registered in
`.config/mise/conf.d/pap-repo.toml`; integration tier unless said. The
hook is fed Claude Code's JSON in throwaway repositories, in the shim
world of `tests/guard-route.test.sh`, so rule 23.4 passes. Each result
label opens `cycle-pr-guard-<n>:`.

- -1, -3, -4, -13: exit 2 and both refusal lines, every example row.
- -2, -5, -6, -7, -14: exit 0 and stderr names no rule 27; -14's
  unlabelled row is refused. The scenario 5 row is -5's count.
  `echo "x; git switch y"` passes.
- -8, earlier-suite row: `tests/guard-route.test.sh` and
  `tests/pm-mode.test.sh` pass unchanged; a hook bypass, a force push
  and a merge are refused under `PAP_MODE=pm`.
- -9: one new line a refusal; field 7 the kind, field 8 the form; a
  body given in the command is absent.
- -17: the state path's `pm` is a file: exit 2 and three lines.
- -16: `if true; then gh pr create; fi`: exit 0, one `unread` line.
- -15: the hook's context and session log line in the three states; on
  `main` both are as before the change.
- -10, -11: `pap doctor`'s line and exit code, in `tests/pap.test.sh`.
- -12: unit: `grep -F` of the sentence in both cycle definitions; that
  `pap revisits` reads 0027's revisit; that 0027 has its PIP and
  `rules.md` 18.1 names 27.1.
- Process rows: the stand-in `git` logs each start. Baselines are
  constants in the test, measured at the commit before increment 1.
  Equal for a call with none of the verbs and for any call outside a PM
  session; at most two more with the verbs, in one and in two
  directories.
- Shell row: unit: `mise run check`, shellcheck clean.

## Observation

- Unlabelled agent pull requests: increment 5 writes the query into
  0027; increment 2 moves it.
- Main checkout off main: increment 3, the session log line's seventh
  field.
- Saves and false refusals: increments 1 and 2, kind and form fields.
- Unread: increments 1 and 2.

Known to work once merged: `pap doctor` shows the new item `ok`; a PM
session's `git switch -c x` in the main checkout leaves a
`branch-switch` line.
