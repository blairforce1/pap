# 0001. Treat process changes as versioned, measured interventions

- **Status:** accepted
- **Date:** 2026-09-17
- **Deciders:** blairforce1, with Claude Code
- **Supersedes:** none
- **PIP:** none (founding)
- **Expected effect:** none (founding)
- **Introduced in:** v0.5.0
- **Revisit:** when three process interventions have shipped: if none shows a detectable effect

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
- Recorded 2026-09-24: from 0.5.0 the pap plugin and the toolkit (CLI,
  templates, skills) share one version and one tag series, `v<x.y.z>`, so
  the tag an app repository pins names the plugin it runs too.
  `mise run release` refuses a version that
  `plugins/pap/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`
  do not both carry. spec-review keeps its own version.
- Recorded 2026-09-24, by [0010](0010-revisits-are-typed-and-counted.md):
  a Revisit line starts with a typed trigger, `after <n> change PRs`
  (from the Introduced-in tag, or `from #<pr>`), `on <YYYY-MM-DD>` or
  `when <condition>`, and its prose reason follows after a colon. A change
  PR is a pull request merged to main from a `change/` branch. Every record
  was converted without changing its meaning; 0002, 0004 and 0005 predate
  the first tag and count from a pull request, and 0006 counts from #30,
  where its window was registered. `pap revisits` reports which are due.
- Recorded 2026-09-24, by 0010: the status lifecycle is `accepted`, `due`,
  then one of `measured:confirmed`, `measured:refuted` or
  `measured:inconclusive`, with `superseded` open at any point. `due` is set
  by a human when they take up the revisit, never by a tool; `pap revisits`
  only reports. Status carries the outcome and its date and nothing else,
  `measured:refuted (2026-09-24)`; what was done about it goes in a
  `Disposition:` header added at the transition: `kept`,
  `reverted in v<x.y.z>` or `superseded by NNNN`, with the reason in the
  record's Result.
- Recorded 2026-09-24, by 0010, settling the follow-up above: enough is ten
  change PRs a side, the last ten merged before the pull request that
  introduced the intervention and the first ten after it, with the
  metrics and each one's direction pre-registered in the record; every
  row of the baseline and result tables carries its class. The verdict is
  per metric, on medians: a directional effect is confirmed when the
  result median lies beyond the baseline's interquartile range (the 3rd
  and 8th of the ten sorted values) in the predicted direction, refuted
  when beyond it the other way, inconclusive inside it; a bound (not ↑,
  not ↓) holds unless the result median lies beyond the range in the
  forbidden direction. Any refuted metric makes the record
  `measured:refuted`; every effect confirmed and every bound held makes it
  `measured:confirmed`; anything else is `measured:inconclusive`. A record
  may extend its window once, by ten more a side, when the verdict is
  inconclusive or one side lacks a class the other has, and never across
  another intervention's tag. Not retroactive: 0006, at five a side,
  stands as recorded.
- Recorded 2026-09-24, by 0010: "toolkit changes are not interventions"
  is amended. 0006 changed no process text yet claimed a measured effect,
  and was recorded and measured as an intervention. Read the rule as:
  toolkit changes (skills, hooks, CLI, templates) need no record unless
  they change what the process asks of a human or are shipped to move a
  measured number; either makes the change an intervention, whatever it
  touches, and it then carries a record and ships under a tag. Since 0.5.0
  the toolkit shares the tag series, so the boundary exists for them.

## Where it is taught or enforced

Backs [`rules.md`](../rules.md) 1.1 (interventions are tagged) and 1.2 (records carry
expected effect). Introduced at repo founding. Enforced by the PR title check
(`process:` type requires a `Record:` footer) and by `pap emit`, which
refuses to run against an untagged process version.
