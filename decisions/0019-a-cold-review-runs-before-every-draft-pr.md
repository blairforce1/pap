# 0019. A cold review runs before every draft pull request

- **Status:** proposed
- **Date:** 2026-11-05
- **Deciders:** blairforce1, with Claude
- **Supersedes:** none; amends the `/change` skill of [0006](0006-changes-are-carried-by-a-skill.md)
- **PIP:** the owner's call of 2026-11-05 to add a fresh-context review before every draft pull request. Anthropic's account of its own practice, "How the Claude Code team does code review" (2026-10-15, <https://claude.dev/blog/solving-code-review-at-anthropic/>), is to verify, then have a second agent read the diff cold before a human sees it. In the project-manager session's first two weeks, 19 of 108 cycles needed a message after their first report, and the reworked cycles used a median of 690k tokens against 157k for the rest (decision [0018](0018-a-project-manager-session-launches-cycles-and-keeps-the-tracker.md)). Today `/change` checks its work in the same context that wrote it
- **Expected effect:** cycles that get a message after their first report ↓ from 19 of 108 (18%); median tokens on the cycles that still get one ↓ from 690k; median tokens per cycle not ↑ by more than the reviewer's tokens, which the Verification row records
- **Introduced in:** not yet released; the release that ships the step in `/change`
- **Revisit:** after 20 change PRs from #85: both effects over those 20 change pull requests, the findings the reviews fixed, and the share of reviews that found nothing

## Context

`/change` builds, runs the local checks and opens the draft pull request.
Its only review before the human's is its own: the context that wrote the
change reads it back, with the same assumptions that wrote it. A check that
passes is not a brief that was met, and a missed instruction or a wrong file
is found by the human, after the report, at the cost of a message and a
second pass through a context that is already large. That second pass is
the likely source of the 690k median.

Claude Code ships `/code-review` (<https://code.claude.com/docs/en/code-review>),
local and on any plan, which reviews a diff or a branch at a chosen level.
It looks for correctness bugs; it does not know the brief.

## Decision

1. **Before `gh pr create`, `/change` has the branch diff reviewed cold.**
   It spawns one read-only subagent and gives it only the brief, the
   worktree's absolute path and the diff command,
   `git -C <worktree> diff origin/main...HEAD`, not its own reasoning.
   The subagent runs `/code-review low` against that worktree where the
   skill is available, reads the diff against the brief itself either
   way, and returns its findings. It edits nothing. A `/code-review` that
   could not see the diff counts as not available, not as a clean review.
2. **Every finding is fixed or answered before the pull request opens.**
   A fix is committed, and the local checks run again if it touched
   anything they cover. A finding not fixed is answered with its reason in
   the pull request.
3. **Verification says the review ran.** One row: that it ran, the level
   (or that the skill was not available), the findings, which were fixed,
   any left with the reason, and the reviewer's tokens.

The reviewer is a subagent rather than `/code-review` run in place, so the
context is fresh by construction whatever the skill does inside, and so
the brief goes with the diff. The level is `low`: a few high-confidence
findings, cheap enough to run on every change. A level is raised by a
later record if the revisit shows the reviews missing what the human then
finds.

The reason that carried it: the cheapest reader who does not share the
author's assumptions is a fresh context, and the cheapest time to use one
is before the human reads the pull request.

## Considered options

- **Review after the pull request opens.** Lost: the human may already be
  reading it, and every fix is a push, which in risk mode removes
  `owner-reviewed` (0016).
- **Self-review in the authoring context.** Lost: it is today's practice,
  and it reads the change with the assumptions that wrote it.
- **A second member, a QA, on every cycle.** Lost as the default: it is
  backlog item H-013 (decision [0018](0018-a-project-manager-session-launches-cycles-and-keeps-the-tracker.md)), unproven and dearer. This record is
  H-013's control arm: a one-member cycle with a cold review is the
  baseline a two-member cycle has to beat.
- **`/code-review` at `medium` or above.** Lost for now: more findings,
  some uncertain, and more tokens on every change; `max` and `ultra` start
  many reviewers. `low` first, raised on evidence.
- **`/code-review` alone, without the brief.** Lost: most rework is a brief
  not met, not a bug, and `/code-review` cannot see the brief.
- **A review that may edit.** Lost: two writers on one branch, and the
  author no longer knows what the diff holds.

## Consequences

- Easier: a missed instruction or a stray file is found before the human
  reads the pull request, by a context that costs tens of thousands of
  tokens rather than a second pass through hundreds of thousands.
- Harder: every change pays for the review, including the ones it finds
  nothing in. The revisit counts that share.
- Harder: a reviewer can be wrong. Answering a finding with a reason is
  allowed for that, and the answer is in front of the human.
- Limit: the reviewer sees only what is in the diff and the brief. A
  missing file or a rule the brief did not name can still pass.
- Measurement: both effects are counted from the project-manager
  tracker's cycle records, as 0018's baseline was; neither is in git
  history. The window is small, so the result is read as a direction, not
  a significance test (0001's ten-a-side rule applies to the token median).

## Where it is taught or enforced

Backs [`rules.md`](../rules.md) 19.1 (a cold review runs before a draft
pull request). Taught by the `/change` skill
([`plugins/pap/skills/change/SKILL.md`](../plugins/pap/skills/change/SKILL.md),
step 5); nothing refuses a pull request opened without one.
