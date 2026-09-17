# 0002. Stop skills at a draft PR; nothing reaches main except by PR

- **Status:** accepted
- **Date:** 2026-09-17
- **Deciders:** blairforce1, with Claude Code
- **Supersedes:** none
- **PIP:** #1 (intent.md committed directly to main, 2026-09-16)
- **Expected effect:** humanReview coverage ↑ to 100%; unreviewed changes on main ↓ to 0
- **Introduced in:** v0.1.0
- **Revisit:** if the draft-PR step adds more than five minutes per change with no rejections in 20 changes

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

## Where it is taught or enforced

Backs `rules.md` 2.1 (main changes only via PR) and 2.2 (skills stop at a
draft PR). Introduced at the intent stage; applies to every stage that
produces an artefact. Enforced by `.github/rulesets/main.json` (`pull_request`,
`non_fast_forward`, `required_linear_history`), by
`plugins/pap/hooks/hooks.json` routing `PreToolUse` on Bash to
`scripts/guard-branch.sh`, and by `lefthook.yml` `pre-push`. The intervention
boundary and status lifecycle follow
[0001](0001-treat-process-changes-as-measured-interventions.md).