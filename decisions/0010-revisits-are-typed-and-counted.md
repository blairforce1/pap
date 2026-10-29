# 0010. Type every Revisit trigger and report the ones that are due

- **Status:** accepted
- **Date:** 2026-09-24
- **Deciders:** blairforce1, with Claude Code
- **Supersedes:** none; amends [0001](0001-process-changes-are-measured-interventions.md)
- **PIP:** #44 (0006 was measured only because the human remembered; 0002's "20 changes" trigger had passed 19 change pull requests earlier, unchecked)
- **Expected effect:** counted revisits sitting more than 10 change pull requests past their trigger ↓ from 1 (0002, 19 past) to 0
- **Introduced in:** v0.6.0
- **Revisit:** after 20 change PRs from #45: whether any counted revisit sat more than 10 change pull requests past its trigger

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

## Result

### Revisit of 2026-10-29, proposed

Proposed, not accepted: the owner accepts it by setting the two header
lines below and deleting this sentence. Until then the Status above
stands.

```text
- **Status:** measured:confirmed (2026-10-29)
- **Disposition:** kept
```

The trigger fired at #65, the 20th change pull request from #45, and is
judged there, as 0004's was at its own trigger. Counted from `gh` and
checked against `pap revisits`.

| Record          | Trigger     | Fired at | Taken up     | Past at #65 | Past at #69 |
| --------------- | ----------- | -------- | ------------ | ----------- | ----------- |
| 0002, rewritten | 10 from #47 | #57      | this revisit | 8           | 12          |
| 0004            | 20 from #23 | #47      | #49          | 1           | 1           |
| 0005            | 20 from #27 | #51      | #53          | 1           | 1           |
| 0010            | 20 from #45 | #65      | this revisit | 0           | 4           |
| 0012            | 10 from #50 | #60      | this revisit | 5           | 9           |
| 0013            | 10 from #52 | #62      | this revisit | 3           | 7           |

Trigger: at #65 no counted revisit sat more than 10 change pull requests
past its trigger; the most was 0002 at 8. Expected effect: 1 (0002, 19
past) to 0, met. The metric is a count over the record set, not a value
per change, so 0001's ten-a-side median rule does not apply, and is not
pretended to.

The uncomfortable part, recorded and not used to change the verdict: four
change pull requests later, at #69, 0002 sat 12 past, the failure this
record was written to prevent, with `pap revisits` printing it at the end
of every change. Reporting worked; the count was right every time.
Scheduling did not: nothing takes a due revisit up but a human choosing
to. That is not a case against the typed trigger, so no amendment. It is
the case for the follow-up above, a `/revisit` skill that acts on a due
revisit rather than printing it, and this is its PIP.

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
