# 0018. A `/reviewed` comment adds the `owner-reviewed` label

- **Status:** proposed
- **Date:** 2026-11-01
- **Deciders:** blairforce1, with Claude
- **Supersedes:** none; amends [0016](0016-risk-labels-and-an-owner-reviewed-label-replace-approved-by.md) with a second way to add its label
- **PIP:** the Project Lead's call of 2026-11-01: a `risk:high` pull request cannot be approved from a phone. GitHub Mobile adds no label to a pull request (observed; the app's documented feature list names no label action), the Approve review is closed to the pull request's author and every pull request is opened under the Project Lead's account, and a reaction is open to anyone and fires no workflow event
- **Expected effect:** in an opted-in repository, the wait from a `risk:high` pull request's last push to its `owner-reviewed` label ↓ (median, against its last 20 `risk:high` pull requests before the workflow ships); labels the workflow adds for a login not in CODEOWNERS, or for a SHA that is not the head, at 0
- **Introduced in:** not yet released; the release that ships the workflow in `blairforce1/.github` and its caller in the risk layer
- **Revisit:** when 20 `risk:high` change PRs have merged in a repository with the workflow: both effects, and how many labels came by comment and how many by hand

## Context

0016 made the `owner-reviewed` label the gate on a `risk:high` pull
request, removed by any push. The label needs a desktop browser. A
comment is the one thing a phone does well, and GitHub Actions can turn
one into the label. Three facts from GitHub's documentation shape how:

- An `issue_comment` workflow runs on the default branch (GITHUB_SHA is
  its last commit), so a check it reports lands there, not on the pull
  request's head, and cannot satisfy the required `pr-checks / checks`.
- Events made with the job's GITHUB_TOKEN "will not create a new workflow
  run", so a label the workflow adds does not re-run the gate.
- A re-run "will also use the same GITHUB_SHA and GITHUB_REF of the
  original event", and the gate's `pull_request_target` runs already sit
  on the head (pap PR #76: five `pr-checks / checks` check runs on its
  head, under the GitHub Actions app the ruleset names).

## Decision

A new comment on a `risk:high` pull request whose first line is
`/reviewed`, or `/reviewed <sha>` with 7 to 40 hex characters, posted by a
login the base branch's `.github/CODEOWNERS` names as a `@login` owner,
adds the `owner-reviewed` label. The SHA is optional: a plain `/reviewed`
approves the head as it stands; with a SHA, the SHA must prefix the head,
or the workflow does nothing but reply why. The `pr-checks` gate still
reads only the label, and a push still removes it, with one change: it
strips the label on `synchronize` only on a run's first attempt
(`github.run_attempt` is 1). A re-run replays the original event, so
without that rule the re-run below would strip the label it was given;
a label present at a later attempt was added after the push, which is
what the rule wants.

A reusable workflow `pr-reviewed.yml` in `blairforce1/.github` does it,
on `issue_comment` with type `created` only; edits and deletions of
comments are ignored, since the label, not the comment, is the record.
The risk layer carries the caller:

```yaml
name: pr-reviewed
on:
  issue_comment:
    types: [created]
permissions:
  contents: read
  pull-requests: write
  actions: write
jobs:
  reviewed:
    if: github.event.issue.pull_request && startsWith(github.event.comment.body, '/reviewed')
    uses: blairforce1/.github/.github/workflows/pr-reviewed.yml@main
```

The job, in order: reads the pull request (`pulls/<n>`) for its head SHA
and base branch; reads `.github/CODEOWNERS` at the base and compares the
comment author's login, without case, to the `@login` owners on any line
(`author_association` is not consulted: it says what the account is to
the repository, not who the invariants name, decision 0014); if a SHA was
given, requires it to be a prefix of the head; on any failure it does
nothing but reply with one comment saying why, and the line to post. On
success it adds `owner-reviewed`, then re-runs the head's latest
`pr-checks` run (`actions/runs?event=pull_request_target&head_sha=<head>`,
the newest whose path is `.github/workflows/pr-checks.yml`, one `POST
…/rerun`), so the check on the head is judged again with the label on.

Permissions are the minimum: `pull-requests: write` for the label and the
reply, `actions: write` for the re-run, `contents: read` for CODEOWNERS.
The comment body appears only in the `if:` expression, which GitHub
evaluates, and in an environment variable the script reads; it is never
interpolated into a shell. Nothing is checked out; no secret is used.

The reason that carried it: the label already proves what it proves
(0016), and a comment from the one login the invariants name is the same
act from a phone.

## Considered options

- **The gate reads the comments itself, instead of a label.** Lost: a
  second form of approval to read, remove and guard; the label is enough.
- **A GitHub App or fine-grained token adds the label.** Not chosen: its
  `labeled` event would start a fresh gate run, but it is a secret to hold
  and rotate; the re-run and the first-attempt rule are two lines.
- **`author_association` as the test.** Lost: COLLABORATOR includes read
  access, MEMBER is any member of the organisation.

## Consequences

- Easier: a `risk:high` review from a phone is to read the Review focus
  comment and post `/reviewed`.
- Harder: one more workflow in each opted-in repository, added by `pap
  sync` as a fixed-high path, so the sync's pull request is `risk:high`.
  `pap repo apply` changes nothing: no new label, check or setting.
- Limit: identity is the label's (0016). The same account posts the
  comment and an agent with `gh` can post it; rule 16.2 covers the act,
  and `guard-route.sh` should refuse an agent's `gh pr comment` or `gh
  api` post whose body starts with `/reviewed`.
- Changed: a re-run of a push's `pr-checks` run keeps `owner-reviewed`.
  Before, every attempt of a `synchronize` run stripped it; a person
  re-running such a run from the Actions page after adding the label
  would have lost the label too. `tests/risk.test.sh` gains the case.
- Limit: a team owner (`@org/team`) is not matched by login; a repository
  with no CODEOWNERS on its base has no login to match, and the reply
  says so.
- Unverified: that the job's GITHUB_TOKEN may call the re-run endpoint is
  not stated in the pages read; workflows in the wild do it with
  `actions: write`. The build's first run proves it.

## Where it is taught or enforced

Adds one sentence to [`rules.md`](../rules.md) 16.1. Taught, once built,
in the risk layer's README and the `/change` skill's report line.
Enforced, once built, by `pr-reviewed.yml` and the first-attempt rule in
the reusable `pr-checks` workflow, both in `blairforce1/.github`. Nothing
yet: this record ships no workflow.
