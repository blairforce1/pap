# 0001. Treat process changes as versioned, measured interventions

- **Status:** accepted
- **Date:** 2026-09-17
- **Deciders:** blairforce1, with Claude Code
- **Supersedes:** none
- **PIP:** none (founding)
- **Expected effect:** none (founding)
- **Introduced in:** v0.1.0
- **Revisit:** after three process interventions have shipped, if none shows a detectable effect

## Context

PSP failed on the cost of data collection. PAP makes collection nearly free,
but cheap data only helps if a process change can be attributed to an outcome.
Process rules and toolkit change at different speeds: a skill wording fix is
daily; a change to what the process asks of a human is rare. Without a rule
separating them, every tweak is a confound and no change is ever shown to
have worked. App repos consume PAP by version, so the version is the only
boundary both the process and the dashboard can agree on.

## Decision

The repo treats a change under `process/` as an intervention. An intervention
requires a record with a PIP, at least one expected effect, and a revisit
trigger. Interventions ship only in tagged releases; the tag is the boundary,
app repos pin it, and every emitted event carries the pinned version.
Toolkit changes (skills, hooks, CLI, templates) are not interventions and need
no record unless they change what the process asks of a human. The changelog's
Process section is derived from record references in PR footers, never
written by hand. A record moves to `measured:confirmed` or `measured:refuted`
when the dashboard shows a before/after split with enough changes on each
side; refuted is a normal outcome. The reason that carried it: attribution
is the whole point of measuring, and attribution needs a boundary.

## Considered options

- **Record every change as an intervention.** Lost: confounds everything, and
  the record set becomes a commit log.
- **Mark interventions by label, not tag.** Lost: labels don't pin; an app repo
  cannot say which process it was running.
- **Skip expected effect, judge afterwards.** Lost: post-hoc stories always fit.

## Consequences

- Easier: every intervention gets a clean before/after split by tag; record
  headers are the dashboard's annotation schema, so nothing else drifts.
- Harder: no quick process tweaks; a change must be worth a tag. Intended.
- Harder: expected effects will often be wrong, on the record, in public.
- Follow-up: rule 3's "asks of a human" is judged by intent, not mechanism;
  expect a case that forces a sharper line.
- Follow-up: define "enough changes on each side" before the first
  `measured:` transition, not after.
- Recorded 2026-09-23: neither enforcement named below exists yet. The
  register at `rules.md` carries 1.1 and 1.2 as enforced by nothing, so the
  gap is on the record until `pap emit` and the title check are built.
- Recorded 2026-09-24: the title check is built, as part of the reusable
  `pr-checks` workflow of [0004](0004-pull-request-checks-are-answered.md).
  It is not yet a required check; `pap emit` is still unbuilt.

## Where it is taught or enforced

Backs [`rules.md`](../rules.md) 1.1 (interventions are tagged) and 1.2 (records carry
expected effect). Introduced at repo founding. Enforced by the PR title check
(`process:` type requires a `Record:` footer) and by `pap emit`, which
refuses to run against an untagged process version.
