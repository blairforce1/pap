# 0006. Carry every change with /change, assemble.sh and CLAUDE.md

- **Status:** measured:refuted (2026-09-24); the skill is kept
- **Date:** 2026-09-24
- **Deciders:** blairforce1, with Claude Code
- **Supersedes:** none
- **PIP:** the 2026-09-24 session-speed analysis: of about 230 active minutes over seven sessions, 57% was model time and 43% tool time; every brief re-sent the same per-change preamble and asked for a full read-and-summarise before work and a long verification list after it
- **Expected effect:** brief-to-draft-PR wall time ↓ from the 8.8 min median of #25 to #29; fix-up rounds per pull request not ↑ from a median of 0; findings per pull request not ↓ from a median of 6
- **Introduced in:** v0.5.0
- **Revisit:** after the next five change pull requests; keep or revert on the three numbers

## Context

The analysis read seven sessions. Model time was most of the wait, and
much of it went on ceremony rather than the change: each brief carried a
preamble of about 3,000 characters restating decision 0002's branch,
commit and draft-PR steps and 0004's Checks. It asked the session to read
decisions 0001 to 0004 and report what it found before starting, and to
end by listing every file with a way to verify it. The same instructions,
re-read and re-reported per change, cost model time every time. Throwaway
repositories for template changes were assembled by hand in each session,
and parallel sessions sharing one checkout switched each other's branch.

## Decision

The per-change ceremony moves out of the brief. The `/change` skill
carries it: a worktree on `change/<slug>` (created, or resumed when the
branch exists), a report of only what contradicts the brief in place of a
read-and-summarise, background waits, local check and test, a draft pull
request with every Checks box answered, and a fixed five-line report.
`scripts/assemble.sh` builds throwaway repositories from template layers.
`CLAUDE.md` points every session at the skill, at `rules.md` and
`decisions/` without restating them, and at worktrees. A brief says only
what to build.

Model and effort are unchanged: Opus 5.5 at medium, which already ran
#25 to #29, so the baseline and the next five differ only in the
ceremony. The one comparison with a different setting is #22, run on
Fable 5.1 at xhigh: 22.0 minutes to its draft and two fix-up rounds, with
no "Decisions and tradeoffs" list to count findings from. It is recorded
here and not used as the baseline. The reason that carried it: the
ceremony is the part of every session that repeats, so it is the part
where a fixed saving multiplies.

## Baseline

Measured from the session transcripts and the pull request bodies of the
last five merged pull requests. Wall time is from the brief being sent to
the draft pull request being opened. A fix-up round is a further prompt on
the same branch after the draft was opened and before merge. A finding is
a bullet under "Decisions and tradeoffs to review" in the body.

| PR     | Wall time | Fix-up rounds | Findings |
| ------ | --------- | ------------- | -------- |
| #25    | 8.8 min   | 0             | 6        |
| #26    | 12.2 min  | 0             | 7        |
| #27    | 4.8 min   | 0             | 9        |
| #28    | 0.8 min   | 0             | 0        |
| #29    | 9.0 min   | 1             | 5        |
| Median | 8.8 min   | 0             | 6        |

## Result

Measured the same way as the baseline, over the first five change pull
requests after #30. The scratch previews (#32, #40), Renovate's #34 and
#39, split out of #38 by a fix-up prompt, are not change pull requests.

| PR     | Wall time | Fix-up rounds | Findings |
| ------ | --------- | ------------- | -------- |
| #31    | 9.6 min   | 1             | 8        |
| #33    | 21.5 min  | 2             | 6        |
| #35    | 3.7 min   | 0             | 2        |
| #37    | 12.4 min  | 0             | 6        |
| #38    | 8.2 min   | 1             | 8        |
| Median | 9.6 min   | 1             | 6        |

Against 8.8 min, 0 and 6: wall time rose, fix-up rounds rose, findings
held. Refuted on two of the three numbers.

Confounds, recorded and not used to adjust the result:

- #31's fix-up was an approval the pull request asked for, not a repair.
- #33's second fix-up was a merge conflict from running in parallel with
  #31, which the worktrees of this decision make possible.
- Task mix: #33 (security scanning) and #37 (`pap init`, `sync`,
  `doctor` and two records) are larger than most of the baseline.
- #41 to #43 ran in 3.6, 4.0 and 3.7 min with no fix-up rounds. They fall
  outside the pre-registered window and are not counted.
- The first brief of a session fell from about 3,200 to 4,100 characters
  before #30 to a median of about 1,800 over the five. Not
  pre-registered, so not evidence for the effect.

The skill is kept. The result says the wall time is in the work, not the
ceremony; reverting would restore the per-change preamble for no measured
gain.

## Considered options

- **Keep the preamble in each brief.** Lost: it is the measured cost, and
  prose retyped per change drifts between briefs.
- **Put the ceremony in CLAUDE.md alone.** Lost: CLAUDE.md is loaded
  into every session, including the ones that make no change, and it
  cannot run the worktree step or be tested.
- **Change the model or effort at the same time.** Lost: two changes in
  one intervention cannot be told apart, and the analysis shows the
  current setting is already the faster one.

## Consequences

- Easier: a brief is the task alone; the ceremony is versioned with the
  plugin and tested where it is mechanical (`worktree.sh`,
  `assemble.sh`).
- Easier: the report shape gives the findings count directly.
- Harder: a skill fault now reaches every change at once; the scratch
  run in #30 is the only end-to-end test.
- Harder: #28 (0.8 min) sits in a baseline of five, so the median, not
  the mean, is the number compared.
- Follow-up: record the three numbers for each of the next five change
  pull requests, and decide at the fifth.
- Recorded 2026-09-24: done; see Result. Measured from the session
  transcripts and pull requests, as the baseline was: no dashboard exists
  yet.
- Recorded 2026-09-24: this was the first `measured:` transition, and
  [0001](0001-process-changes-are-measured-interventions.md)'s "enough
  changes on each side" is still undefined. Five a side proved too few to
  separate the effect from the task mix.
- Recorded 2026-09-24: under 0001 this was arguably a toolkit change, not
  an intervention: it moved ceremony out of the brief without changing
  what the process asks of a human.

## Where it is taught or enforced

No rule in [`rules.md`](../rules.md) follows: using the skill is a
habit, and the rules it applies are already in 2.1, 2.2, 4.1 and 4.2.
Taught in `CLAUDE.md` and in the skill
(`plugins/pap/skills/change/SKILL.md`). The status lifecycle follows
[0001](0001-process-changes-are-measured-interventions.md).
