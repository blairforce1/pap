# 0010. Type every Revisit trigger and report the ones that are due

- **Status:** accepted
- **Date:** 2026-09-24
- **Deciders:** blairforce1, with Claude Code
- **Supersedes:** none; amends [0001](0001-process-changes-are-measured-interventions.md)
- **PIP:** #44 (0006 was measured only because the human remembered; 0002's "20 changes" trigger had passed 19 change pull requests earlier, unchecked)
- **Expected effect:** counted revisits sitting more than 10 change pull requests past their trigger ↓ from 1 (0002, 19 past) to 0
- **Introduced in:** unreleased
- **Revisit:** after 20 change PRs from #PR: whether any counted revisit sat more than 10 change pull requests past its trigger

## Context

Every record carries a Revisit line, and every one was free prose. Nothing
counted them. 0006 reached its revisit because the human remembered it;
0002's trigger, "20 changes", passed with nobody looking, and 0004 and 0005
are close behind. A trigger nobody evaluates is not a trigger: the record
set only works as an experiment log if the revisits happen. 0001 also left
three things open that the first measured transition (0006) ran into:
what "enough changes on each side" means, how a refuted but kept record is
written, and whether a toolkit change can be an intervention.

## Decision

A Revisit line starts with one of three typed triggers, and its prose
reason follows after a colon:

- `after <n> change PRs`, counted from the record's Introduced-in tag, or
  `after <n> change PRs from #<pr>` when the record has no tag or its
  window started elsewhere. A change PR is a pull request merged to main
  from a `change/` branch.
- `on <YYYY-MM-DD>`.
- `when <condition>`: an outside condition, checked by hand.

`pap revisits` reads every record in `decisions/` and prints one line per
record: due, not due (n of m), manual, closed (a `measured:` or superseded
record), or unknown when it cannot count. It exits 0 always: it reports
and never blocks. The `/change` skill ends its report with a
"Revisits due:" line from it, so a due revisit is in front of the human at
the end of every change.

The amendments to 0001 (status lifecycle, "enough changes", the toolkit
line) are recorded as dated notes there. The reason that carried it: the
cheapest place to see a due revisit is the report the human already reads
after every change.

## Considered options

- **Extend `pap doctor`.** Lost: doctor checks the machine and exits 1 on
  a problem; a due revisit is not a machine fault and must not fail it.
- **Block merges while a revisit is due.** Lost: a revisit is a judgement
  a human schedules; blocking unrelated changes on it punishes the wrong
  pull request.
- **Count days, not change PRs.** Lost for the counted triggers: effects
  are measured per change, and a quiet week would fire a day count with
  nothing to measure. `on <date>` covers the cases that are about time.

## Consequences

- Easier: 0002 is flagged at once, and 0004 and 0005 as they come due.
- Easier: the Revisit line is machine-readable, so the dashboard can read
  it later without another format change.
- Harder: counting needs `gh` and the network; without it counted records
  print unknown. Manual triggers are still manual.
- Harder: the change-PR definition leans on branch names. A change merged
  from another branch is not counted. Accepted: `/change` names every
  branch `change/<slug>`.
- Follow-up: `pap measure` and a `/revisit` skill, which act on a due
  revisit, are later changes.
- Follow-up: 0002 is due now. Its revisit is a human's to schedule.

## Where it is taught or enforced

Backs [`rules.md`](../rules.md) 10.1 (Revisit triggers are typed). Taught in
[0001](0001-process-changes-are-measured-interventions.md)'s notes and
here. Reported by `pap revisits` in [`bin/pap`](../bin/pap), tested in
`tests/revisits.test.sh`, and surfaced by the `/change` skill's report.
The status lifecycle follows
[0001](0001-process-changes-are-measured-interventions.md).
