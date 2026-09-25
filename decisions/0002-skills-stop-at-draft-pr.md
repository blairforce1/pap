# 0002. Stop skills at a draft PR; nothing reaches main except by PR

- **Status:** accepted
- **Date:** 2026-09-17
- **Deciders:** blairforce1, with Claude Code
- **Supersedes:** none
- **PIP:** #1 (intent.md committed directly to main, 2026-09-16)
- **Expected effect:** humanReview coverage ↑ to 100%; unreviewed changes on main ↓ to 0
- **Introduced in:** v0.5.0
- **Revisit:** after 10 change PRs from #47: the one extension 0001 allows; measure the draft-PR step as active time from draft open to merge, from session transcripts as 0006 did, not timestamps, and close to a `measured:` status whatever it shows

## Context

On 2026-09-16 the intent skill wrote `intent.md` and committed it to main
before anyone had read it. The skill had no instruction to do so and no
instruction not to; skills are prose, and prose does not enforce. A change
that lands on main directly produces no `humanReview` event, so the process
cannot see its own inputs and the dashboard cannot count the change. The
intent document is itself a change with a `change.id`, and its PR is the only
natural place to review it. With one developer, a required approver would
block every merge, so the gate must come from the PR mechanics, not a second
human.

## Decision

A skill that writes a phase artefact works on `change/<id>`, commits as often
as it likes, opens a draft PR, and stops. Main changes only by squash-merged
PR; the merge finalises the phase event. Zero approving reviews are required;
the gate is the PR plus required status checks plus resolved review threads.
The rule is enforced in three places, none of them a skill: the repository
ruleset, a Claude Code `PreToolUse` hook, and a `pre-push` git hook. Each is
allowed to fail independently; the ruleset is the backstop. The reason that
carried it: without a PR there is no review record, and a process that cannot
see its own inputs cannot be measured.

## Result

Evaluated 2026-09-25 over #2 to #21, the first twenty change pull
requests after #1, from `gh`. The follow-up to record time from skill
completion to merge was never done, so the cost is read from a proxy:
`createdAt` to `mergedAt`. Every one of the twenty was opened as a draft;
the draft column is `createdAt` to the timeline's `ready_for_review`, and
it sits inside the total rather than adding to it. #2 to #7 predate the
class labels; their title type is shown instead.

| PR     | Class        | Draft      | Open to merge |
| ------ | ------------ | ---------- | ------------- |
| #2     | none (feat)  | 8.2 min    | 8.4 min       |
| #3     | none (chore) | 0.3 min    | 0.4 min       |
| #4     | none (feat)  | 1329.2 min | 1330.0 min    |
| #5     | none (chore) | 19.4 min   | 123.3 min     |
| #6     | none (feat)  | 96.0 min   | 96.1 min      |
| #7     | none (docs)  | 2.4 min    | 3.1 min       |
| #8     | docs         | 2.1 min    | 2.2 min       |
| #9     | feature      | 16.4 min   | 20.6 min      |
| #10    | bugfix       | 3.9 min    | 33.3 min      |
| #11    | feature      | 3.3 min    | 3.4 min       |
| #12    | feature      | 3.5 min    | 3.6 min       |
| #13    | bugfix       | 25.7 min   | 26.9 min      |
| #14    | infra        | 2.4 min    | 2.7 min       |
| #15    | chore        | 1.4 min    | 2.5 min       |
| #16    | spike        | 3.6 min    | 4.0 min       |
| #17    | infra        | 1.4 min    | 1.5 min       |
| #18    | docs         | 1.3 min    | 1.4 min       |
| #19    | feature      | 221.5 min  | 221.7 min     |
| #20    | chore        | 1.9 min    | 2.0 min       |
| #21    | docs         | 2.5 min    | 3.1 min       |
| Median |              | 3.4 min    | 3.5 min       |

Cost: the median is 3.5 min, under the five-minute line. Eight of the
twenty are over it; the largest are idle gaps, overnight for #4 and an
evening for #19, which timestamps cannot separate from review.

Rejections: none. No `change/` pull request was closed unmerged between
#2 opening and #21 merging, and no review of any kind (approval, comment
or request for changes) exists on any of the twenty: the ruleset
requires none and one developer cannot review their own. So "no
rejections" holds, but vacuously; closing unmerged is the only channel a
rejection could show through. #32 and #40 are not counted: they fall
outside the window, and they were scratch previews opened to be closed,
not changes that were turned down.

The revert condition needs both arms and the cost arm fails, so the rule
is kept. The pre-registered effect cannot be read: `pap emit` is unbuilt,
so no `humanReview` event exists, and on the proxy the effect is true by
construction. Twenty of twenty reached main by pull request because the
ruleset allows nothing else, while none carries a review action, so the
metric as named measures the gate, not a review. It stays as registered;
changing it now would be the post-hoc story 0001 forbids.

The status stays `accepted`, with no Disposition. 0001's ten-a-side split
cannot run, now or later: this record was in force from the founding
commit and has no before side. A `measured:` status would also close the
record to `pap revisits`, so a new trigger would never be counted, which
is the failure 0010 was written for. The Revisit line above spends the
one extension 0001 allows, measured from session transcripts rather than
timestamps, and the next look ends in a `measured:` status whatever it
shows.

## Considered options

- **Instruct skills not to commit to main.** Lost: that is what failed on the 16th.
- **Commit to main, review afterwards.** Lost: no review event; review becomes optional.
- **Require one approving review.** Lost: an author cannot approve their own PR; a solo developer cannot merge.
- **Skills never commit; the human does.** Lost: discards the commit stream as telemetry and reintroduces the manual step PSP died of.

## Consequences

- Easier: every phase artefact has a review record and an event; the
  dashboard sees all changes, not most.
- Easier: the branch guard is identical across repos, so `pap init` can
  apply it without per-repo judgement.
- Harder: one more step per change, and draft PRs for solo work feel like
  ceremony. Measured by the revisit trigger rather than argued.
- Harder: three enforcement layers to keep aligned; a change to one must
  change all three or the layers disagree about what is allowed.
- Harder: skills must be branch-aware. A skill started on main has to create
  the branch first; a skill started on someone else's change branch must
  refuse.
- Follow-up: define behaviour when a `change/<id>` branch already exists
  (resume or refuse).
- Follow-up: record time from skill completion to PR merge per change so the
  revisit trigger can be evaluated.
- Recorded 2026-09-22: of the three enforcement layers only the repository
  ruleset existed; the `PreToolUse` hook and the `lefthook` `pre-push` layer
  were found missing and were built in change `branch-guard`
  (`scripts/guard-branch.sh`, `lefthook.yml`, `plugins/pap/hooks/hooks.json`).
  The hook layer is a no-op in a repo that has no `scripts/guard-branch.sh`
  and the `pre-push` layer needs `lefthook install`; the ruleset remains the
  backstop.
- Recorded 2026-09-23: the hook layer checked the branch of the session's
  repository, not the one a command targets. It blocked commits to
  unguarded repositories from a session here, let `cd <guarded> && git
  commit` through from sessions elsewhere, and never matched `git -C <dir>
  commit`. From pap plugin 0.2.0 the hook runs
  `plugins/pap/hooks/guard-route.sh` in every session; it follows `cd` and
  `git -C` and runs `scripts/guard-branch.sh branch` in the target
  repository. The rule is unchanged, so the three layers still agree.
- Recorded 2026-09-23: `rules.md`, cited by this record and by 0001 since
  the founding commit, did not exist. Written in change `rules-register` as
  an index from each rule to its record and its enforcement.
- Recorded 2026-09-24: #26 found that lefthook's generated hook prints
  "Can't find lefthook in PATH" and exits 0 when the lefthook binary is
  absent, so a commit passes unchecked on any clone where setup has not
  run. `templates/base/.lefthookrc` now refuses the commit and names the
  setup command (`mise trust && mise install`). This is a fourth failure
  mode of the client-side layers, after the missing layers, the unrouted
  hook and the missing register. The ruleset remains the backstop for main
  only; pre-commit checks have no server-side backstop until the CI
  scanning layer exists.
- Recorded 2026-09-24: the follow-up on an existing `change/<id>` branch
  is settled by the `/change` skill (#30): resume, never refuse or reset.
  An existing branch, local or on origin, is checked out in a new
  worktree as it stands; if a worktree for it is already open, the skill
  stops and prints that path instead of working in it. Implemented and
  tested in `plugins/pap/skills/change/worktree.sh`
  (`tests/change-worktree.test.sh`).
- Recorded 2026-09-25: the revisit was evaluated by hand; see Result.
  A tool would have had to supply three things. The data source: `gh`
  pull requests merged to main from `change/` branches (`createdAt`,
  `mergedAt`, `headRefName`, the `class:` label), each one's issue
  timeline for `ready_for_review` and `convert_to_draft`, and its
  reviews; plus `change/` pull requests closed unmerged in the same
  window. The proxy: open to merge stands in for skill completion to
  merge, and is an upper bound that includes idle time; session
  transcripts, as 0006 used, give active time and are what the next look
  uses. The definition of a rejection: a `change/` pull request closed
  unmerged, or a review requesting changes, excluding scratch pull
  requests opened to be closed (a `scratch` title scope or "do not
  merge"). This is the input for `pap measure`.
- Recorded 2026-09-25: 0001's lifecycle has no named step for a revisit
  taken up without a verdict. This record went back to `accepted` with a
  new trigger rather than to a `measured:` status; whether 0001 names
  that step is open. 0004 and 0005 also predate the first tag and have
  no before side, so they can be judged only on their triggers.

## Where it is taught or enforced

Backs [`rules.md`](../rules.md) 2.1 (main changes only via PR) and 2.2 (skills stop at a
draft PR). Introduced at the intent stage; applies to every stage that
produces an artefact. Enforced by `.github/rulesets/main.json` (`pull_request`,
`non_fast_forward`, `required_linear_history`), by
`plugins/pap/hooks/hooks.json` routing `PreToolUse` on Bash to
`scripts/guard-branch.sh`, and by `lefthook.yml` `pre-push`. The intervention
boundary and status lifecycle follow
[0001](0001-process-changes-are-measured-interventions.md).
