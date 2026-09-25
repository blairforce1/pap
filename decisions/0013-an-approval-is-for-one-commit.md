# 0013. An approval is for one commit

- **Status:** accepted
- **Date:** 2026-09-25
- **Deciders:** blairforce1, with Claude Code
- **Supersedes:** none; amends [0012](0012-protected-paths-need-an-owners-approved-by-line.md)
- **PIP:** #50 (its `Approved-by: @blairforce1` line was written at 14:18:53 against head `fc95ee6`; `bb6da9a`, which changed the protected `decisions/0012-…md`, reached the head at about 14:20:54, and the pull request merged at 14:23:28 on the earlier approval)
- **Expected effect:** protected-path pull requests where a commit reached the head after the owner's approval was written ↓ from 1 of the 4 with an approval since #47 (#50; #48, #49 and #51 had none after, #47 had no approval) to 0
- **Introduced in:** v0.6.0
- **Revisit:** after 10 change PRs from #52: whether any protected-path pull request merged with a commit after its approval, and how many approvals the check refused as stale

## Context

0012 made an owner's `Approved-by: @login` line a condition of merging a
pull request that touches a protected path. The line says who approved,
not what. Once written it stays in the body, and `pr-checks` passes on it
whatever is pushed afterwards: a new commit, a force push, a rebase onto
a different base.

It has happened once already. Counted from each body's edit history
against its commits and the `pr-checks` runs they triggered, for the
protected-path pull requests merged since #47:

| PR  | Approval written        | Last commit reached the head | After? |
| --- | ----------------------- | ---------------------------- | ------ |
| #47 | none (a false tick)     | 11:09                        | n/a    |
| #48 | 11:39:24, in prose      | 11:29                        | no     |
| #49 | 11:51:14, in prose      | 11:47                        | no     |
| #50 | 14:18:53, `Approved-by` | about 14:20:54 (`bb6da9a`)   | yes    |
| #51 | 15:43:13, `Approved-by` | about 14:59 (`f2ffdb8`)      | no     |

#50's later commit edited 0012 itself, a protected file. The body was
saved again at 14:20:50 with the line still in it; one account makes
every edit, so nothing says whether that save was a fresh approval or a
rewrite that carried the old line forward. Either way, what the owner
read at 14:18 was not what merged.

`pushedDate` is empty for every commit in these pull requests; the push
time is taken from the first `pull_request` run on the new head, which
agrees with the commit time to within seconds in every case.

## Decision

The line names the commit it approves:

```text
Approved-by: @login <sha>
```

The SHA is 7 to 40 hex characters, in any case, and must be a prefix of
the pull request's head. The reusable `pr-checks` workflow in
`blairforce1/.github` reads each `Approved-by:` line on its own. A line
whose SHA is a prefix of any other commit is stale; a line with no SHA,
or a prefix shorter than 7, is refused. Only lines naming the current
head count toward 0012's "an owner of every protected file". A stale
line beside a current one is ignored. Every refusal prints the whole line
to paste, the owners from CODEOWNERS and the head's first seven
characters included.

So every push, force push or rebase needs the owner to approve again.
`pr-checks` already runs on `synchronize`, so the push itself turns the
check red; the owner's body edit turns it green on the new head.

The `/change` skill answers an unticked protected-path box with
`Head to approve: <short sha>`, updates that reason after every push, and
ends its chat report with the ready-to-paste `Approved-by:` line. It
still never writes the line itself (0012, and the `PreToolUse` hook).

The reason that carried it: an approval of a diff the owner has not seen
is not an approval, and the head SHA is the one thing both the check and
the owner can see that changes whenever the diff does.

## Considered options

- **Timestamp staleness: refuse a line older than the last push.** Lost:
  GitHub gives no server-side push time the agent cannot influence
  (`pushedDate` is empty here, and commit dates are set by whoever
  commits), and the body's edit times come only from GraphQL's edit
  history. Worse, an unchanged re-save may not register as an edit, so
  re-approving would mean deleting the line and adding it back.
- **Dismiss the approval on push, as GitHub's "dismiss stale reviews"
  does.** Lost: there are no reviews to dismiss (0012, rule 2.1), and a
  workflow that rewrites the body on push needs the token to edit bodies,
  racing the owner's own edit.
- **Name the tree, or a diff hash, instead of the commit.** Lost: a
  rebase that changes nothing would keep the approval, which is kinder,
  but the owner cannot read a tree hash off the pull request page, and a
  rebase onto a moved base changes what merges.
- **Keep 0012 as it is.** Lost: #50.

## Consequences

- Easier: the line says what was approved, and the check's refusal is
  the approval prompt: one line to paste.
- Harder: every push to a protected-path pull request, including a
  fix-up after review or a rebase to resolve a conflict, needs another
  body edit by the owner. With 10 of the last 10 change pull requests on
  a protected path, that is most pushes. The Revisit counts it.
- Harder: every open protected-path pull request needs its line
  re-written with a SHA once blairforce1/.github#10 merges, since pap
  calls the check `@main`.
- Limit: the check still cannot tell who typed the line (0012). It adds
  what, not who.
- Limit: a SHA prefix of 7 could name two commits in a very large
  repository; it only needs to be a prefix of the head, so the ambiguity
  can pass a line, never refuse one.
- Measurement: the before side is 1 of 4, read from edit histories; the
  after side is structural, since a merge on a stale line needs a red
  required check. The count of stale refusals is the cost side.

## Where it is taught or enforced

Amends [`rules.md`](../rules.md) 4.1 (checks are answered). Taught in the
pull request template in `blairforce1/.github` and the `/change` skill.
Enforced by `.github/workflows/pr-checks.yml`, which calls
`blairforce1/.github/.github/workflows/pr-checks.yml@main`, from
blairforce1/.github#10.
