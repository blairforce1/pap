# Intent: cycle-pr-guard

```text
id:                 cycle-pr-guard
class:              infra
product:            PAP
source:             none
hypothesis:         reactive: a cycle in an adopting repository opened its pull request without /change, in the main checkout, with no class label; related to H-017, not part of it
invariants-touched: INV-003, INV-005, INV-008; plugins/pap/hooks/**, scripts/guard-branch.sh, rules.md, decisions/**, tests/** (risk:high)
accepted-by:        @blairforce1
accepted-on:        2026-11-11
generated-by:       Claude Fable 5.2 via Claude Code
skills:             pap:intent 0.19.0
prompt:             /intent cycle-pr-guard infra refuse a cycle that opens its pull request outside /change: an agent's gh pr create with no class label or from the main checkout, a cycle working in the main checkout, and the permission a cycle needs to label its own pull request
```

## Problem

A cycle that skips `/change` is stopped by nothing until `pr-checks`
fails. One did: it switched the main checkout, which parallel sessions
share, onto a change branch and left it there, and it opened its pull
request with no `class:*` label. When sent back to add the label, its
command was denied by Claude Code's permission classifier, and the owner
added it by hand.

## Desired outcome

- An agent's `gh pr create` on a `change/*` branch with no `class:*`
  label is refused, with the way through named.
- An agent's `gh pr create` from the main checkout, and an agent
  switching the main checkout's branch, are refused, with the worktree
  and `/change` named.
- Both refusals bind every agent of a PM session: its sub-agents and its
  main session.
- Each refusal is logged, and `pap doctor` reports a main checkout that
  is not on `main` as drift.
- A cycle can label its own pull request, or the adopter is told what is
  missing.

## Non-goals

- Not the server gate: a session with no hooks, or a `gh` reached through
  `bash -c`, still gets past (H-017).
- Not proof that `/change` ran: it refuses two symptoms of skipping the
  skill, not a pull request's Checks answers or its cold review.
- Not for solo sessions or the owner at a shell.
- No change to an adopter's Claude Code permission settings: at most the
  rule is documented and `pap doctor` reports its absence.

## Constraints

- Hooks stay POSIX shell (INV-003).
- `/change` itself, `worktree.sh`, `mise run tidy`, `mise run release`
  and read-only git in the main checkout keep working.
- A new rule arrives with decision record 0027, carrying the measure
  below and a typed revisit (INV-008).
- The change `cycle-runs-change` lands first or alongside; this one does
  not repeat its wording fixes.

## Success measure

Across pap, arapsys-ap and business-os, after release:

- Over the first 20 pull requests the agent app opens on `change/*`
  branches, none has a `pr-checks` run that fails for a missing class
  label. Read from GitHub's labeled events and check runs.
- Over 30 days, `pap doctor` reports no main checkout off `main`, with
  the logged refusals counted beside it as saves.

The baseline for the first is counted from history during the spec.

## Open questions

- How the hook tells the main checkout from a worktree, and which
  commands there stay allowed: carried forward to the spec, the PM
  answers.
- Whether a fresh cycle's label step inside `/change` is denied in auto
  mode at all: carried forward to the spec, the PM answers by a test run
  before any permission rule or doctor check is specified.
- Which of these local refusals stay once H-017's server gate exists:
  carried forward to H-017's intent.
