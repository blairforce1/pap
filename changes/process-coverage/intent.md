# Intent: process-coverage

```text
id:                 process-coverage
class:              infra
product:            pap
source:             none
hypothesis:         H-001
invariants-touched: none
generated-by:       Claude Opus 5.5 via Claude Code
skills:             pap:change
prompt:             the human's /change brief for H-001, in pull request process-coverage
```

## Problem

The process document says what must happen; `rules.md` says which parts a
check refuses. Nothing says which parts of the document have no rule, no
backlog item and no deferral, and nothing notices when a rule's enforcement
entry names a file that is gone or claims a check is required when the
ruleset says otherwise. The 2026-09-25 review found both only because the
human asked.

## Desired outcome

Every principle and section of the process document has a stable ID.
`pap coverage` maps each ID to a rule, a backlog item or an explicit
deferral, lists the IDs with none, and lists `rules.md` enforcement entries
that disagree with the repository.

## Non-goals

- Fixing what it finds. The first run's findings are listed, not fixed.
- Blocking a merge. It reports, like `pap revisits`.
- Judging whether a rule is enforced well; only whether its entry is true.

## Constraints

- POSIX shell in `bin/pap`; tests in `tests/`.
- The process document keeps its hand formatting and its content.

## Success measure

Uncovered IDs and disagreeing enforcement entries are both counted by
`pap coverage` on main, and both reach 0 before the next release.

## Open questions

- Which uncovered IDs become backlog items and which are deferred: the
  human's call, from the first run's list.
