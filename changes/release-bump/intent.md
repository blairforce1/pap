# Intent: release-bump

```text
id:                 release-bump
class:              feature
product:            PAP
source:             none
hypothesis:         H-026
invariants-touched: INV-004, INV-005, INV-006, INV-009; decision 0027 (rules 27.1, 27.2); tests/** (added to only)
accepted-by:        @blairforce1
accepted-on:        2026-11-13
generated-by:       Claude Opus 5.5 via Claude Code
skills:             pap:intent 0.19.1
prompt:             /intent release-bump feature a script that makes a pap version bump end to end (the four version places and the dated changelog heading, then the worktree, commit, push and draft pull request with its class label), so a mechanical cycle only runs it, watches the checks and verifies the result
```

## Problem

A pap version bump is about five lines in four known places, yet each runs as a full agent cycle that edits them by hand: 49k to 86k tokens and 4 to 8 minutes a release, over the last five.

## Desired outcome

One command makes the bump end to end: the version in the plugin manifest, the marketplace entry and the install prompt; the dated changelog heading; then the worktree, the commit, the push and the draft pull request with its `class:chore` label. A release cycle (the mechanical cycle) runs that command in place of `/change`, watches the checks and verifies the result.

## Non-goals

- Cutting the release: `scripts/release.sh` stays the PM's step after the merge.
- Choosing the version or writing changelog lines: the owner names the version, and `[Unreleased]` must already hold its lines.
- Bumping pm-console or spec-review.
- Taking a version into an adopting repository (`/pap:pm sync`).
- Running from the owner's terminal is not a goal; it may come as a side effect.

## Constraints

- POSIX `sh`, like `release.sh`.
- Refuses before it changes anything: a version not x.y.z or not above the current one; `origin/main` not fetched; the four places disagreeing now; the branch or worktree already there; an empty `[Unreleased]`.
- Leaves nothing half made on failure: no stray branch or worktree.
- Keeps by itself what the guard cannot see inside a script: every git hook runs; a draft pull request only, never a merge or a push to `main`; a linked worktree and exactly one class label (decision 0027); a body that answers its Checks and declares generated content (INV-009).
- Always class `chore`.

## Success measure

Tokens a release-bump cycle, from the report events: at most 30k on each of the next three releases (49k to 86k today), with no release pull request carrying a hand edit.

## Open questions

- Run from the owner's terminal: answered, possible as a side effect, not a goal.
- The class label: answered, always `chore`.
- Whether the release exception to a cycle's first act being `/change` needs a rule or a dated note on decision 0024: carried forward to spec, the PM.
- Where the pull request body's template lives: carried forward to spec, the PM.
- What the same release would cost with the script run inside `/change` (option B), as the comparison: carried forward to spec, the PM.
