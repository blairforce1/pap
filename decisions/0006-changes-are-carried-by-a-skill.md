# 0006. Carry every change with /change, assemble.sh and CLAUDE.md

- **Status:** accepted
- **Date:** 2026-09-24
- **Deciders:** blairforce1, with Claude Code
- **Supersedes:** none
- **PIP:** the 2026-09-24 session-speed analysis: of about 230 active minutes over seven sessions, 57% was model time and 43% tool time; every brief re-sent the same per-change preamble and asked for a full read-and-summarise before work and a long verification list after it
- **Expected effect:** brief-to-draft-PR wall time ↓ from the 8.8 min median of #25 to #29; fix-up rounds per pull request not ↑ from a median of 0; findings per pull request not ↓ from a median of 6
- **Introduced in:** unreleased
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

| PR | Wall time | Fix-up rounds | Findings |
|---|---|---|---|
| #25 | 8.8 min | 0 | 6 |
| #26 | 12.2 min | 0 | 7 |
| #27 | 4.8 min | 0 | 9 |
| #28 | 0.8 min | 0 | 0 |
| #29 | 9.0 min | 1 | 5 |
| Median | 8.8 min | 0 | 6 |

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

## Where it is taught or enforced

No rule in [`rules.md`](../rules.md) follows: using the skill is a
habit, and the rules it applies are already in 2.1, 2.2, 4.1 and 4.2.
Taught in `CLAUDE.md` and in the skill
(`plugins/pap/skills/change/SKILL.md`). The status lifecycle follows
[0001](0001-process-changes-are-measured-interventions.md).
