# 0006. Run execution at Opus 5.5 medium; reserve Fable for judgement

- **Status:** accepted
- **Date:** 2026-09-24
- **Deciders:** blairforce1, with Claude Code
- **Supersedes:** none
- **PIP:** the 2026-09-24 session-speed analysis: of about 230 active minutes over seven sessions, 57% was model time and 43% tool time; Fable 5.1 xhigh sessions spent 34 and 40 minutes of model time, against 5 to 10 for Opus 5.5 medium sessions doing similar tasks
- **Expected effect:** wall time per pull request ↓; fix-up rounds per pull request not ↑; findings surfaced per pull request not ↓ (baseline below)
- **Introduced in:** unreleased
- **Revisit:** after the next five change pull requests; keep or revert on the three numbers

## Context

The analysis found model time, not tools, was most of the wait, and the
sessions that ran Fable 5.1 at xhigh for execution were the slowest. The
briefs those sessions ran were already precise: what to build, what to
verify, which files to leave alone. The thinking a high effort level buys
had mostly been done before the session started. The global
`effortLevel` was `xhigh`, so a session that did not choose ran at the
most expensive setting. The risk in lowering it is quality, not speed: a
cheaper run that needs more fix-up rounds, or reports fewer of the
findings a reviewer relies on, is slower end to end.

## Decision

For the next five change pull requests, execution runs at Opus 5.5 with
effort `medium`. Fable 5.1 is used only as a subagent, for a judgement
call the brief does not settle (design, taste, a tradeoff with no clear
answer), and returns its answer to the executing session. The `/change`
skill says so. The three numbers are measured for each of the five and
compared with the baseline. The reason that carried it: effort was the
largest lever the analysis found, and the only one that can make things
worse, so it is the one that gets measured.

## Baseline

Measured from the session transcripts and the pull request bodies of the
last five merged pull requests. Wall time is from the brief being sent to
the draft pull request being opened. A fix-up round is a further prompt on
the same branch after the draft was opened and before merge. A finding is
a bullet under "Decisions and tradeoffs to review" in the body.

| PR | Wall time | Fix-up rounds | Findings |
|---|---|---|---|
| #25 | 8.8 min | 0 | 6 |
| #26 | 12.2 min | 0 | 7 |
| #27 | 4.8 min | 0 | 9 |
| #28 | 0.8 min | 0 | 0 |
| #29 | 9.0 min | 1 | 5 |
| Median | 8.8 min | 0 | 6 |

All five already ran at Opus 5.5 medium: sessions switched to Opus at
10:26 on 2026-09-24, with its effort set to medium. So the next five
measure whether the regime holds, not the switch from Fable. The Fable side of the switch is
one comparable pull request: #22, at Fable 5.1 xhigh, took 22.0 minutes to
its draft and two fix-up rounds. Its body has no "Decisions and tradeoffs"
list, so it has no findings count.

## Considered options

- **Keep Fable xhigh for everything.** Lost: the slowest configuration
  measured, on work whose judgement was in the brief.
- **Opus low, or Sonnet, for execution.** Lost for now: no measurement
  says the quality holds, and one change at a time keeps the effect
  attributable.
- **Change the setting without a record.** Lost: 0001; a change to how
  work is run, with no expected effect written down, cannot be judged
  afterwards.

## Consequences

- Easier: the default session is the faster one; a slow session is a
  choice someone made.
- Easier: the skill's report shape gives the findings count directly.
- Harder: the baseline is small and already treated, so a null result is
  the likely outcome and says the regime is safe, not that it is faster.
- Harder: the effort setting lives in each machine's Claude Code
  settings, not the repository; nothing checks it.
- Follow-up: record the three numbers for each of the next five change
  pull requests, and decide at the fifth.

## Where it is taught or enforced

No rule in [`rules.md`](../rules.md) follows: the effort level is a
local setting no check can see. Taught in the `/change` skill
(`plugins/pap/skills/change/SKILL.md`). The status lifecycle follows
[0001](0001-process-changes-are-measured-interventions.md).
