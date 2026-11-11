# Intent: spec-board-keeps-tools

```text
id:                 spec-board-keeps-tools
class:              bugfix
product:            PAP
source:             none
hypothesis:         reactive: /spec could not write the review register in the turn the board returned (pap 0.19.0, spec-review 1.3.1)
invariants-touched: none; protected path tests/** (added to only)
accepted-by:        @blairforce1
accepted-on:        2026-11-11
generated-by:       Claude Fable 5.2 via Claude Code
skills:             pap:intent 0.19.0
prompt:             /intent spec-board-keeps-tools bugfix /spec can write the review register and apply accepted findings in the same turn the board returns, with the board still read-only (composed by the project-manager session from a reported issue, on the owner's go)
```

## Problem

`/spec` step 6 says to write the review register as soon as the review
returns, then apply accepted findings to the spec. Every `spec-review-*`
skill withholds Bash, Edit and Write, and the report is that the session
stays without them for the rest of that turn. So the register lives only
in the conversation until the owner's next message, and a session that
ends or compacts in that window loses it. The full board and the single
`spec-review-qa` a bugfix runs are both affected.

## Desired outcome

When the review `/spec` runs returns, the session writes
`changes/<slug>/reviews/spec-review.md` in that same turn, before it asks
for any disposition, and can apply an accepted finding and commit without
waiting. The review itself still cannot edit, write or run shell. While
perspectives are still reporting, `/spec` waits for all of them before
consolidating and gives the owner a short progress line.

## Non-goals

- No new perspective, and no change to what any perspective checks or how it grades.
- No change to the register's format or columns.
- Not a general fix for skills that withhold tools; only the review `/spec` runs.

## Constraints

- Whatever runs the review can read and cannot edit, write or run shell.
- Invoking any `spec-review-*` skill directly keeps working as it does today.
- The `spec-review` plugin stays usable without the `pap` plugin installed.
- The register's content and columns come back unchanged.
- No rule is added and no decision record is edited; if the spec finds it needs either, it stops and says so.
- No version bump in this change.
- Expected risk level: medium (skills changed, tests added to only).

## Success measure

Over the next five `/spec` runs that hold a review, in any adopting
repository, the register is written in the turn the review returns in
five of five, read from the session transcript.

## Open questions

- Does the restriction outlast the skill for the whole turn: carried forward to spec, reproduced there first; the project manager finds, the owner decides.
- Can a review sub-agent start the per-perspective sub-agents, or must the caller run the fan-out: carried forward to spec, same owners.
- Does the agent definition live in the `spec-review` plugin or in `pap`: carried forward to spec, same owners.
- Does decision 0021 or any rule name the skill invocation in words this change would contradict: carried forward to spec, same owners.
