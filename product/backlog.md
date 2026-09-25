# Backlog: PAP

Hypotheses, not features. Ordered by value and risk. Rewritten when findings come back.

This file is the backlog (decision 0011). An issue may propose an item; the item exists once it is merged here. Every change names one of these in its `intent.md`, or says it is reactive and why.

Last reviewed: 2026-09-25

## Recommended first slice

**H-001** We believe giving every principle and section of the process document a stable ID, and a `pap coverage` check that maps each ID to a rule, a backlog item or an explicit deferral, will produce a process whose unbuilt parts are visible without a manual review, measured by uncovered IDs and by `rules.md` entries whose enforcement column disagrees with the ruleset and workflows, both reported in every `/change` report and both at 0 before each release.
Tests invariant: none directly. It closes the gap behind the 2026-09-25 review, which found unbuilt and misdescribed controls only because the human asked. Envision would pick H-004 instead, because INV-010 (events carry the process version) is the riskiest invariant: every measure depends on it. Confirm or swap.
Class: infra
Status: built in change process-coverage (`pap coverage`).

## Ranked

Proposed order; confirm or reorder.

**H-002** We believe adopting v0.5.0 in the trial app repository will produce real changes carried by the process, measured by change pull requests merged there under PAP.
Related: vision §Done enough to matter. Class: infra

**H-003** We believe making a missing approval on a protected path fail `pr-checks` will produce protected paths that do not change unapproved, measured by merged pull requests touching a protected path with no recorded approval, at 0.
Related: vision §Done enough to matter; process principles 9 and 11. Class: security-sensitive
Status: built by decisions 0012 and 0013 (`pr-checks` refuses a protected path without an owner's `Approved-by:` line for the head). Dropped: denying agent Edit and Write on protected paths in the `PreToolUse` hook, because it would have blocked 10 of the last 10 change pull requests; the approval gate, not the edit, is the control.

**H-004** We believe deriving CDEvents from the GitHub pull request timeline (phase and return labels, reviews, merges), each carrying the pinned process version, will produce interventions settled without hand counting, measured by records past their revisit trigger that reach a `measured:` status from derived data alone.
Related: vision §How we will know. Class: feature

**H-005** We believe `/intent` and `/findings` skills will produce closed changes whose escapes are attributed to a phase, measured by the share of closed changes with a merged `findings.md`.
Related: vision §How we will know; process 5.11. Class: feature

## Unranked

**H-006** We believe joining Claude Code's telemetry to the change id will produce inner-loop measures per change, measured by the share of changes with token and rework-share data.
Related: vision §Assumptions to test. Class: feature

**H-007** We believe diff coverage and cognitive complexity, reported as signals with a `REVIEW.md` in the base template, will produce more defects caught before merge, measured by review yield (caught before merge against escaped).
Related: process 5.8. Class: feature

**H-008** We believe a scheduled monthly review, with process section 6.4 as its brief, will produce drift caught between releases, measured by drift signals (section 6.5) found by the review before a human asks.
Related: vision §How we will know. Class: infra

**H-009** We believe `pap career export` will produce one evidence fragment per closed change at no marginal cost beyond a fragment review, measured by fragments per closed change (spec: `spec-career-export-1.md`).
Related: vision §Non-goals (export, not render). Class: feature

**H-010** We believe an outcome eval suite of real tasks, run on every change to skills, hooks or model, will produce configuration changes that do not silently regress, measured by eval pass rate per configuration version.
Related: process 6.2. Class: infra

## Dropped

- Uber-style scalar PR risk score: no action a solo reviewer can take on a number. Its useful half returns as the attention plan in H-007.
