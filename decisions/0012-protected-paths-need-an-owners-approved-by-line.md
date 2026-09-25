# 0012. A protected path needs an owner's Approved-by line, not a reason

- **Status:** accepted
- **Date:** 2026-09-25
- **Deciders:** blairforce1, with Claude Code
- **Supersedes:** none; amends [0004](0004-pull-request-checks-are-answered.md)
- **PIP:** #46 (merged with the protected-path box unticked and "Approval is blairforce1's to record here before merge"; no approval was ever recorded) and #48 (the same reason, its approval written two minutes after the merge); found by 0004's revisit, #49
- **Expected effect:** pull requests touching a protected path merged with no owner's approval recorded in the body before the merge ↓ from 3 of the 4 since #46 (#46 never, #47 a false tick, #48 two minutes after; #49 24 s before) to 0
- **Introduced in:** unreleased
- **Revisit:** after 10 change PRs from #50: whether any pull request the check labelled protected-path merged without an owner's Approved-by line, or the check refused one that had it

## Context

Rule 4.1 says every Checks box is ticked or has a one-line reason under
it. The check reads any reason as an answer, so a reason that defers the
answer passes. 0004's revisit found it: #46 left the protected-path box
unticked with "Approval is blairforce1's to record here before merge",
and no approval was recorded before the merge or since. #48 did the same
and its approval arrived two minutes after the merge. #49 recorded one 24
seconds before its merge, in prose. #47 ticked the box with nothing
recorded; 0004 chose to enforce declarations, not their truth, so the
tick passed.

`pr-checks / checks` has been a required check in pap since #42, so a
refusal blocks the merge; rules.md and 0004 still said it only reports.
The check already works out which changed files the base branch's
`.github/CODEOWNERS` protects, and labels the pull request. It did not
look for an approval anywhere.

One account, `blairforce1`, opens and edits every pull request. The
agent, through `gh`, and the human who owns the paths share it. No
approving review is possible (rule 2.1), and the body's edit history
names the same editor for every edit. Nothing the check can read proves
who approved.

#46 sits outside the check's reach: it created `.github/CODEOWNERS`, and
the check reads the base branch's copy, so #46 was never labelled. Of the
three the check labelled, #47 and #48 would have been refused. The
effect is counted against all four; the check's own share is 2 of 3.

## Decision

On a pull request whose changed files have an owner in the base branch's
`.github/CODEOWNERS`, the reusable `pr-checks` workflow in
`blairforce1/.github` requires a body line

```text
Approved-by: @login
```

naming an owner of every such file, before merge. The key is
case-sensitive, logins are compared without case, several owners may be
listed with commas or on several lines, and the line may be indented
under the box. Nothing else may follow on the line. A line inside an
HTML comment does not count. A file's owners are those on the last
CODEOWNERS line that matches it; a last line with no owners leaves it
unowned and unprotected. A team or email owner is compared as written.

The test is on the files, not the box: a ticked box without the line
fails (#47), and an unticked box whose reason defers the approval fails
(#46, #48). An unticked box with the `Approved-by:` line as its reason
passes both this and rule 4.1. A pull request touching no protected path
is unchanged. Bots are not exempt: a Renovate update under
`.github/workflows/**` waits for the line like any other.

The line is the owner's to write. An agent leaves the box unticked with
the protected paths as its reason, and never writes an `Approved-by:`
line. The pull request template's box now reads "No protected path
touched, or an owner has written `Approved-by: @login` below".

The reason that carried it: "later" was being accepted as an answer to a
question whose only valid answer is a name, and a name is something a
check can match against CODEOWNERS.

## Considered options

- **Match deferral phrases in the reason.** Lost: a list of wordings;
  the next phrasing passes, a reason with no approval in it passes, and
  it cannot see #47's false tick.
- **Require an approving review from a code owner.** Lost: one account
  opens and owns every pull request and cannot approve its own (rule
  2.1).
- **Check who made the edit that added the line.** Lost: the same account
  makes every edit; the edit history has nothing to tell apart.
- **Require the line only under an unticked box, the brief's scope.**
  Lost: it needs the box text as well as the files, and leaves #47's
  false tick open. The rule on files alone is smaller and closes both.
- **A comment or a label as the approval.** Lost: a label is writable by
  the check's own token and by `gh`; a comment is another call and
  another place to read. The body is where 0004 already reads.
- **Read the head branch's CODEOWNERS too.** Lost: reading the base only
  is what stops a pull request unprotecting itself. Kept as a limit.

## Consequences

- Easier: the protected-path box's second half is checked. #46 to #49's
  boxes, as they merged, are all refused in the check's tests.
- Harder: 10 of the last 10 change pull requests (#39, #41 to #49) touch
  a protected path, so nearly every merge now waits on a hand-typed body
  edit and one more check run. Intended. If it costs too much, shorten
  the list in `product/invariants.md`, not the check.
- Harder: a Renovate pull request touching a protected path no longer
  merges on its own.
- Limit: the check enforces a declaration. It cannot tell who typed the
  line, and an agent with `gh` can type it. Follow-up: the `PreToolUse`
  hook refuses an agent's `gh pr create` or `gh pr edit` whose body
  carries `Approved-by:`, the other half of H-003.
- Limit: the base branch's CODEOWNERS only, so the pull request that adds
  a protected path is not protected by its own addition (#46).
- Changed: the protected-path label now means "a changed file has an
  owner", not "a pattern matched". The two differ only for a pattern
  with no owners.
- Measurement: 0001's median verdict will read inconclusive at this
  floor, as 0004's did, since the after side is 0 or 1 per pull request.
  The count is what this record is judged on. After the change the last
  `pr-checks` run before a merge is green only with the line; the before
  side is the edit history 0004's revisit read.

## Where it is taught or enforced

Amends [`rules.md`](../rules.md) 4.1 (checks are answered). Taught in the
pull request template in `blairforce1/.github` and the `/change` skill.
Enforced by `.github/workflows/pr-checks.yml`, which calls
`blairforce1/.github/.github/workflows/pr-checks.yml@main`, from
blairforce1/.github#8.
