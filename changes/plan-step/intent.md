# Intent: plan-step

```text
id:                 plan-step
class:              feature
product:            PAP
source:             none
hypothesis:         reactive: process phase 4 (Planning, section 5.6) is unbuilt, so the owner first sees how a change was built at its pull request; part of the rework after review
invariants-touched: INV-006, INV-007, INV-008; process/**, decisions/**, rules.md, product/**, tests/**, plugins/pap/hooks/** (risk:high)
accepted-by:        @blairforce1
accepted-on:        2026-11-11
generated-by:       Claude Fable 5.2 via Claude Code
skills:             pap:intent 0.18.2
prompt:             /intent plan-step feature a plan between spec and change: how an accepted spec will be built, reviewed before any code
```

## Problem

A cycle goes from an accepted spec straight to code. The owner first sees
how the change was built at the pull request, when a different approach
means redoing the work. The cycle builds from a brief that says what to
build and little about how. The process names a planning phase, and
nothing carries it.

## Desired outcome

- After a spec is accepted and before any code, `changes/<slug>/plan.md`
  says how the change will be built: the increments; the design (types,
  functions, events, infrastructure); how it fits the existing code and
  keeps coupling low; how it will be observed and known to work.
- A background agent drafts the plan from the spec and the code. Plan
  reviews run. The owner says yes in the main session, recorded in the
  file.
- The cycle that builds the change reads the accepted plan and reports
  where it deviated.
- For feature, infra and security-sensitive changes, `/pap:pm launch`
  refuses a build whose branch has no accepted plan.

## Non-goals

- Not a task tracker or an estimate: no hours, no points.
- Not system architecture: a decision that outlives the change still gets
  a decision record.
- Not a second spec review: plan reviews check how it is built, not what.
- Not the two-member cycle (H-013) or the scenario bindings of H-011.
- Not a line-by-line gate on the code matching the plan.

## Constraints

- The file is `changes/<slug>/plan.md`, as process 5.1 names it, committed
  on the change branch after the spec (INV-006).
- Bugfix, chore, docs and spike changes, changes exempt under rule 20.2,
  and changes already in flight need no plan.
- The plan is at most two pages.
- The owner's yes is a disposition; the owner does not write the plan
  (process section 7 gains no seventh step).
- spec-review stays separately versioned; plan reviews placed there bump
  its own version.
- It ships in a tagged release with a decision record, 0026, carrying the
  measure below (INV-007, INV-008).

## Success measure

Over the first 10 changes with an accepted plan, across pap and the two
arapsys repositories, against earlier changes of the same three classes:

- Pull requests with a commit pushed after they open: half the baseline
  share or fewer (53 of 112, 47%, so at most 2 of 10), with the mean
  number of such commits at half the baseline (1.41) or less. Merge
  commits are not counted. Read from GitHub.
- Cycles that get a message after their first report: under 10% (18% in
  decision 0018). Read from the tracker.
- Cost guard: the time from the spec's yes to the plan's yes, read from
  the two files' commits. If agreeing plans costs more time than the
  rework saved, the step is refuted.

The baseline was counted during the spec, over 112 merged change pull
requests of the three classes in the three repositories, 2026-09-22 to
2026-11-11.

Edited 2026-11-11 after the yes (churn): the baseline median of commits
after open is 0, so the first measure reads as a share and a mean.

## Open questions

- Who drafts the plan: answered, a background agent; the owner says yes
  in the main session.
- Is the plan a hard gate: answered, yes, at `/pap:pm launch` for the
  three classes.
- Is `test-plan.md` its own file or a section of the plan: carried
  forward to the spec, the PM answers.
- Which review viewpoints a plan gets, and where those skills live:
  carried forward to the spec, the PM answers.
- Does the plan replace most of the PM's brief: carried forward to the
  spec, the PM answers.
- The plan's exact sections: carried forward to the spec, the PM answers.
