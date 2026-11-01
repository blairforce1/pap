# 0018. An owner's `/reviewed <sha>` comment approves a high-risk head

- **Status:** proposed
- **Date:** 2026-11-01
- **Deciders:** blairforce1, with Claude
- **Supersedes:** none; amends [0016](0016-risk-labels-and-an-owner-reviewed-label-replace-approved-by.md): the gate on `risk:high` accepts a second form of the owner's review, and rules 16.1 and 16.2 widen to name it
- **PIP:** the owner's call of 2026-11-01: a `risk:high` pull request cannot be approved from a phone. GitHub Mobile adds no label to a pull request (the owner's observation; the app's documented feature list names no label action), the pull request's own Approve review is closed to its author and every pull request is opened under the owner's account, and a reaction is open to anyone and fires no workflow event. So a `risk:high` pull request waits until the owner is at a desk, however short the review
- **Expected effect:** in an opted-in repository, the wait from a `risk:high` pull request's last push to the owner's approval of that head ↓ (median, against its last 20 `risk:high` pull requests before the comment gate ships); approvals the gate accepts from a login that is not a CODEOWNERS owner, or for a SHA that is not the head, at 0
- **Introduced in:** not yet released; the release that ships the comment gate in `blairforce1/.github` and the risk layer's caller
- **Revisit:** when 20 `risk:high` change PRs have merged in a repository with the comment gate: both effects, how many approvals came by comment and how many by label, and how many `pr-reviewed` runs each approval took

## Context

0016 made the owner's `owner-reviewed` label the gate on a `risk:high`
pull request, removed by any push. It turned a hand-typed line into one
click, and the click needs a desktop browser. Three ways to approve from a
phone were tried or considered, and none works:

- **The label.** GitHub Mobile's documented feature list is "Read, review,
  and collaborate on issues and pull requests" and "Edit files in pull
  requests"; it names no label action, and the owner finds none on a pull
  request. Taken as observed, not proved from the docs.
- **The Approve review.** "Pull request authors cannot approve their own
  pull requests." One account opens every pull request (0012, Context), so
  there is no approver.
- **A reaction.** Anyone can react, and the events that trigger workflows
  list no reaction event.

A comment is the one thing a phone does well. The question is what it
takes for a comment to be an approval the gate can trust as far as it
trusts the label, and no further (0016, "What the label proves").

### What GitHub documents, and what pap's own runs show

The design turns on these facts. Each names its source; two are marked
unverified.

1. **`issue_comment` runs on the default branch.** The events reference
   lists it with activity types `created`, `edited`, `deleted`, GITHUB_SHA
   "Last commit on default branch" and GITHUB_REF "Default branch". It
   fires for comments on pull requests too, with `issue.pull_request` set,
   which is how a workflow tells the two apart.
2. **The required check is read on the pull request head, and the gate's
   runs already land there.** In pap, PR #76's head is `3a7b521`; its
   `pr-checks / checks` check runs sit on that commit under the
   `github-actions` app (id 15368, the ruleset's `integration_id`), and the
   `pull_request_target` runs behind them report `head_sha` `3a7b521` and
   `head_branch` `change/pap-risk-mode`, with `pull_requests` empty. Five
   runs reached that head (three failed, two passed); the merge went
   through on the latest. Listing runs with `head_sha=<head>` returns
   exactly those runs ("Only returns workflow runs that are associated
   with the specified head_sha", Actions read). No `issue_comment` run
   exists in pap or blairforce1/.github to inspect, so fact 1 rests on the
   docs alone.
3. **A run can be re-run from the API.** `POST
   /repos/{owner}/{repo}/actions/runs/{run_id}/rerun`, "Actions repository
   permissions (write)". "Re-runs use the privileges of the actor who
   initially triggered the workflow, not the privileges of the actor who
   initiated the re-run. The workflow will also use the same GITHUB_SHA
   (commit SHA) and GITHUB_REF (git ref) of the original event." Up to 30
   days after the run, at most 50 re-runs of one run. `github.run_attempt`
   "begins at 1 for the workflow run's first attempt, and increments with
   each re-run". **Unverified:** that the job's own GITHUB_TOKEN may call
   the endpoint is not stated in the pages read; workflows in the wild do
   it with `actions: write` and report "Resource not accessible by
   integration" without that scope and a refusal while the run is still in
   progress. The build's first run proves it; the fallback the docs name
   for triggering from a workflow is a GitHub App or fine-grained token.
4. **Events the token makes trigger nothing.** "Events triggered by the
   GITHUB_TOKEN will not create a new workflow run, with the following
   exceptions: workflow_dispatch and repository_dispatch events always
   create workflow runs." A label a workflow adds re-runs no gate.
5. **Comments can be edited by anyone with write access.** "Anyone with
   write access to a repository can edit comments on issues, discussions,
   pull requests, and commits", and delete them; "The edited dropdown at
   the top of the comment contains a history of edits showing the user and
   timestamp for each edit." The REST comment carries `user.login`,
   `user.type`, `created_at`, `updated_at` and `author_association`;
   listing needs "Issues (read)" or "Pull requests (read)". Not only the
   author or an admin, then: in these repositories write access is the
   owner's account, which the agent shares.
6. **`author_association` says what the account is to the repository, not
   who the owner is.** OWNER "Author is the owner of the repository",
   MEMBER "a member of the organization that owns the repository",
   COLLABORATOR "has been invited to collaborate on the repository" (any
   role, read included), CONTRIBUTOR, NONE. In an organisation's repository
   every member is MEMBER, and 0014 names the owner in the invariants, not
   in the organisation's roster.
7. **A comment body is untrusted input.** The secure-use reference lists
   `github.event.comment.body` among the values an attacker controls; the
   mitigation is an intermediate environment variable, never interpolation
   into `run:`. `pull_request_target` and `workflow_run` workflows "must
   not explicitly check out untrusted code".
8. **Scopes.** "If you specify the access for any of these permissions,
   all of those that are not specified are set to none." `actions: write`
   is the scope for re-running (fact 3); `pull-requests: read` reads the
   pull request and its comments (fact 5).

### Spike

No scratch repository was created (the PM did not confirm one), so the
spike is what could be proved from pap and locally.

- The lookup the trigger needs: `gh api
  "repos/blairforce1/pap/actions/runs?head_sha=3a7b521…"` returns PR #76's
  `pr-checks` runs (fact 2). Since a `pull_request_target` run's
  `pull_requests` is empty, the trigger must go from the pull request to
  its head to the runs, never from a run to its pull request.
- The acceptance rule below, as a bash and jq function in the gate's own
  style, run against sixteen fixture comments: a valid one, the key
  capitalised by a phone with an upper-case SHA, the login in another
  case, free text after the first line, a full 40-character SHA, a stale
  SHA, a 6-character one, no SHA, an edited comment, a collaborator who is
  not an owner, a bot, a team, trailing text on the command line, the
  command on a later line, a stale comment beside a current one, and no
  comments. 16 of 16 behave as written. Script and output:
  `~/dev/arapsys/scratch/pap-reviewed-comment/gate-comment.sh` and
  `spike-output.txt`, outside the repository.

## Decision

Three parts: the gate accepts a comment, a trigger re-runs the gate, and
the rules name the comment.

1. **The gate accepts a comment.** In risk mode a `risk:high` pull request
   passes with the `owner-reviewed` label, as 0016 says, or with a
   `/reviewed` comment on the pull request:

   - The comment's first line, trimmed, is `/reviewed <sha>`: the key in
     any case (a phone capitalises the first letter), one or more spaces,
     7 to 40 hex characters in any case, nothing else on the line. Later
     lines are free text.
   - The SHA is a prefix of the pull request's head (0013). Any other
     commit makes it stale.
   - The author's login, compared without case, is a `@login` owner on any
     line of the base branch's `.github/CODEOWNERS`, and `user.type` is
     `User`. `author_association` is not consulted (fact 6). A team or an
     email owner cannot be matched by a login and does not count.
   - The comment has never been edited: `created_at` equals `updated_at`.
     An edited comment is ignored, whoever edited it (fact 5), and the
     refusal says to post a new one.

   Any one valid comment suffices; a stale or ignored one beside it does
   no harm. The refusal names each comment that fell short and why, and
   prints the line to post, `/reviewed <head7>`, as 0013's refusal prints
   the line to paste. The gate reads the comments live on every run, as it
   reads the labels. One more change: it removes `owner-reviewed` on
   `synchronize` only on the run's first attempt (`github.run_attempt` is
   1), so a re-run of a push's run never strips a label the owner added
   after the push.

2. **A trigger re-runs the gate.** A comment fires none of the gate's
   events (fact 1 against the caller's `pull_request_target` types), and
   its own check would land on the default branch, not the head (facts 1
   and 2). So a second reusable workflow in `blairforce1/.github`,
   `pr-reviewed.yml`, re-runs the head's latest gate run (fact 3), and the
   risk layer carries its caller:

   ```yaml
   # .github/workflows/pr-reviewed.yml: decision 0018. On a /reviewed
   # comment, re-run the head's latest pr-checks run so the gate reads the
   # comment. The job reads no comment body and checks nothing out.
   name: pr-reviewed
   on:
     issue_comment:
       types: [created, edited, deleted]
   permissions:
     actions: write
     pull-requests: read
   jobs:
     rerun:
       if: >-
         github.event.issue.pull_request
         && (startsWith(github.event.comment.body, '/reviewed')
             || startsWith(github.event.changes.body.from, '/reviewed'))
         && contains(fromJSON('["OWNER", "MEMBER", "COLLABORATOR"]'),
                     github.event.comment.author_association)
       uses: blairforce1/.github/.github/workflows/pr-reviewed.yml@main
   ```

   The reusable job takes the pull request number from the event, refuses
   one that is not digits, reads the head SHA from `pulls/<n>`, lists
   `actions/runs?event=pull_request_target&head_sha=<head>`, takes the
   latest run whose path is `.github/workflows/pr-checks.yml`, polls for
   up to five minutes while it is in progress, then posts to its `rerun`.
   The re-run replays the gate on the original event and SHA, the gate
   reads the comments live, and `pr-checks / checks` on the head updates.
   `edited` and `deleted` are in the types so that editing an approval
   away, or deleting it, re-judges the head as removing the label does.
   The `if:` is a filter, not the test: `startsWith` ignores case, so a
   capitalised key passes; `author_association` keeps a stranger's
   comment on a public repository from starting a runner or spending one
   of the run's 50 re-runs (fact 3). Whether a comment approves anything
   is decided in the gate alone.

   Permissions, the minimum (facts 3, 5, 8): `actions: write` to list and
   re-run; `pull-requests: read` for the head SHA. No `contents`, no
   checkout, no secret, and the comment body appears only in the `if:`
   expression, which GitHub evaluates, never in a `run:` (fact 7). A
   re-run runs as the actor who triggered the original run and reads only
   data (0016), so the trigger lends it nothing.

3. **The rules.** 16.1 reads "merges only with the `owner-reviewed` label,
   which any push removes, or with an owner's unedited `/reviewed <sha>`
   comment naming its head". 16.2 adds that an agent posts no `/reviewed`
   comment, and `guard-route.sh` refuses an agent's `gh pr comment`, `gh
   issue comment` or `gh api` post to `issues/<n>/comments` whose body
   starts with `/reviewed`, as it refuses the label.

Answers to the brief's six questions, in short. Who counts: a CODEOWNERS
login, matched on the comment's author, never on `author_association`;
an edit by anyone voids the comment and re-runs the gate; a deletion
re-runs it too. Staleness: the SHA alone, as 0013; a push makes the
comment stale with nothing to remove, and no timestamp is compared (0013
found none the agent cannot influence). The check-run gotcha: the gate
reads the comments, and an `issue_comment` workflow re-runs the head's
latest gate run; the other two options lose below. Security: two scopes,
no body in a shell, no checkout. The label stays. Reach: a reusable
workflow and a caller in the risk layer, which `pap sync` adds; `pap repo
apply` changes nothing, since no label, ruleset entry or setting is
needed and the required check is still `pr-checks / checks`.

The label stays as an equal alternative: on a desktop it is one click, the
hook already guards it, and it binds to the head as the comment does. The
comment adds the path a phone has; it replaces nothing. The cost is a
second guard surface, taken.

The reason that carried it: the approval is the same fact as the label, an
owner looked at this head, in the one medium a phone has, and the gate
stays the single judge; the trigger only asks it to look again.

## Considered options

- **The comment workflow adds `owner-reviewed` itself.** Lost: a label the
  token adds re-runs nothing (fact 4), so the re-run is needed anyway; and
  the re-run of a push's `synchronize` run would strip the label again
  without the attempt guard above. Worse, judging the comment (owner,
  SHA) in the trigger moves the judgement out of the gate and into a
  workflow with a write token, and the label it adds says nothing about
  which head was approved.
- **The gate reads comments on its own events only.** Lost on its own: a
  comment fires none of them. The owner would have to also edit the
  title or mark the pull request ready from the phone to fire `edited`
  or `ready_for_review`, a ritual. Kept as half of the answer: the
  reading lives in the gate, and the trigger supplies the event.
- **The trigger creates a check run named `pr-checks / checks` on the
  head through the Checks API.** Lost: two writers of one check name,
  and the judgement duplicated outside the gate. It would also lean on
  the check being attributed to the GitHub Actions app so the ruleset's
  `integration_id` accepts it, which was not verified.
- **`workflow_dispatch` on the pull request's head branch, so GITHUB_SHA
  is the head.** Lost: the workflow file is then read from the head
  branch, which is what the move to `pull_request_target` stopped (a
  pull request editing its own gate).
- **A fine-grained token or GitHub App for the trigger.** Not now: a
  secret to hold and rotate, and a token that outlives the job. The
  endpoint is documented for the token's own scope; kept as the fallback
  if fact 3's unverified step fails in the build.
- **Match on `author_association`.** Lost as the test (fact 6:
  COLLABORATOR includes read access, MEMBER is any member). Kept as the
  caller's pre-filter, where a false positive costs one re-run and a
  false negative is impossible for an owner.
- **Compare timestamps for staleness.** Lost, as 0013 found: no push time
  the agent cannot influence, and an unchanged re-save may not register.
  The SHA is the binding.
- **Accept an edited comment when its last editor is the author.** Lost:
  the REST comment does not say who edited it; the history is GraphQL
  `userContentEdits`, one more call and one more thing to get wrong. A
  new comment is one line.
- **`/reviewed` for repositories on 0012 too, in place of the body
  line.** Not now; the Revisit may extend it once the gate's reading is
  proven.
- **A second account that approves.** Lost: 0012's context chose one
  account and behavioural guards; a second login for the same person
  proves no more than the comment does.

## Consequences

- Easier: a `risk:high` review from a phone is to read the Review focus
  comment and post one line.
- Easier: the approval names the head it is for, as 0013's line did and
  the label never did.
- Harder: a second workflow in every opted-in repository, and a runner job
  per `/reviewed` comment plus a re-run of `pr-checks`, about a minute of
  runner time, only for comments that start with `/reviewed` from an
  owner, member or collaborator.
- Harder: the risk layer's `pap sync` adds a workflow file, which is a
  fixed-high path, so the sync's pull request is `risk:high` in each
  adopting repository. Intended: the owner reads the workflow they are
  about to run with a write token.
- Limit: identity is the label's (0016). The same account posts the
  comment, an agent with `gh` can post it, and rule 16.2 with the hook is
  the guard. The gate sees a login, not who held the phone.
- Limit: a re-run shares its run's cap of 50 attempts. A collaborator
  posting `/reviewed` fifty times exhausts the head's latest run; a push
  makes a fresh one. The pre-filter keeps strangers out of the count.
- Limit: a gate run still in progress cannot be re-run. The trigger polls
  for up to five minutes, then stops with a notice; the owner posts
  again. A comment that lands before the running gate's fetch step is
  read by that run anyway.
- Limit: a repository with no `.github/CODEOWNERS` on its base branch has
  no login to match, so the label is the only way there; the refusal says
  so. A team owner is not matched: the token has no organisation scope to
  read membership.
- Limit: the filter is loose (any case, anything after the key) and the
  gate strict (one line, a real SHA), on purpose. A comment that passes
  the filter and fails the gate costs one re-run and gets a refusal that
  names why.
- Follow-up, the build, in two pull requests: in `blairforce1/.github`,
  the gate's comment reading, the attempt guard and `pr-reviewed.yml`,
  each with cases in `tests/risk.test.sh` and a new test file; in pap, the
  risk layer's caller and README, `guard-route.sh` with cases in
  `tests/guard-route.test.sh`, the pull request template's box wording
  and the `/change` skill's report line. The build's first live run
  proves fact 3's unverified step; if the token cannot re-run, the
  fallback token is a decision, not a quiet swap.
- Measurement: the before side is the opted-in repository's last 20
  `risk:high` pull requests under 0016: the time from the first
  `pr-checks` run on the final head (the push, 0013's proxy) to the
  `labeled` event for `owner-reviewed`, from the issue events. The after
  side is the same, or the accepting comment's `created_at`. The zero
  count is read from the gate's annotations, which name the accepting
  comment's author and SHA.

## Where it is taught or enforced

Amends [`rules.md`](../rules.md) 16.1 (high risk waits for the owner's
review) and 16.2 (agents never give it). Taught, once built, in the risk
layer's README, the pull request template in `blairforce1/.github` and
the `/change` skill. Enforced, once built, by the reusable `pr-checks`
workflow (the gate), `pr-reviewed` (the trigger) and `guard-route.sh`
(rule 16.2). Nothing yet: this record ships no workflow.
