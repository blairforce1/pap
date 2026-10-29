# 0016. A risk label and an owner-reviewed label replace the Approved-by line

- **Status:** proposed
- **Date:** 2026-10-29
- **Deciders:** blairforce1, with Claude
- **Supersedes:** [0012](0012-protected-paths-need-an-owners-approved-by-line.md) and [0013](0013-an-approval-is-for-one-commit.md), in a repository that opts in; amends [0004](0004-pull-request-checks-are-answered.md)
- **PIP:** the owner's call of 2026-10-29: the `Approved-by:` line "is a pain and I am not sure it actually adds anything". In arapsys/business-os 39 of the last 45 merged pull requests touched a protected path, mostly `**/tests/**`, and every merge from main voided the approval (0013), so the owner re-typed a head SHA on nearly every push
- **Expected effect:** owner approval actions per merged change PR in an opted-in repository ↓ from about one per head pushed to about 0.2 (the `risk:high` share); post-merge reverts or fix pull requests of files a merged pull request labelled `risk:high` touched not ↑
- **Introduced in:** v0.9.0
- **Revisit:** when 20 change PRs have merged in a repository that opted in: both effects, counted from its last 20 change PRs before the opt-in, and how often `owner-reviewed` was removed by a push

## Context

0012 made a hand-typed `Approved-by: @login` line a condition of merging a
pull request that touches a CODEOWNERS path; 0013 tied the line to the
head commit. Both did what they said. What they cost, in business-os:

- 39 of the last 45 merged pull requests touched a protected path, most
  of them only by adding tests under `**/tests/**`. A line that every
  pull request needs tells the owner nothing about which ones to read.
- Every push needs a new line, and a merge from main is a push. With
  several lanes open at once, main moves all day, and so did the SHAs.
- One account, `blairforce1`, opens, edits and approves every pull
  request (0012, Context). The line never proved who approved. The guard
  that does the work is behavioural: agents never write the line and
  never merge, and a `PreToolUse` hook refuses an agent's body that
  carries one.

The review itself got no help from the line. It said that the owner had
looked, not where to look.

## Decision

A repository opts in by having `.github/risk.yml` on its base branch.
Without that file nothing changes: 0012 and 0013 apply as written. With
it, the reusable `pr-checks` workflow in `blairforce1/.github` does three
things instead of asking for the line.

1. **A risk level, as exactly one label**: `risk:high`, `risk:medium` or
   `risk:low`, set by the check from the diff on every run, any other
   `risk:*` label removed. Each changed file gets a level; the pull
   request's is the highest of its files. A file's level is the first of:
   - **high, fixed**: `.github/workflows/**`, `.github/CODEOWNERS`,
     `.github/risk.yml`, `decisions/**` and `product/invariants.md`. The
     config cannot lower these.
   - **high, a weakened test**: in a file the config's `tests` globs
     match, the file is deleted; or more assertion lines are removed than
     added; or a line is added that skips or ignores a test (`Skip =`,
     `[Ignore`, `[Explicit`, `t.Skip(`, `.skip(`, `xit(`, `@pytest.mark.skip`
     and the like, listed with the assertion patterns in the check's
     README). In a file the config's `coverage` globs match, a line is
     replaced by one that differs only in a smaller number.
   - **the last rule in the config whose paths match**, with its level and
     review question.
   - **low**: a file the `tests` globs match, which is not weakened. Tests
     only added or extended are low, whatever CODEOWNERS says.
   - **high**: a file with an owner in the base branch's
     `.github/CODEOWNERS`.
   - **the config's `default`**, `low` if it has none.

   Globs are matched as CODEOWNERS patterns are. The check reads the
   config and CODEOWNERS from the base branch, so a pull request cannot
   lower its own level.
2. **A review focus**: one comment on the pull request, found by the
   marker `<!-- pap:review-focus -->` and edited in place on every run,
   never the body, which agents also edit. It gives the level and, for
   each file above low, the reason and its question: "touches the
   bank-detail filter: confirm nothing is stored or logged"; "removes 3
   assertions in `tests/X.cs`: confirm intentional"; "prompt changed:
   confirm an eval ran on this head and its result is in Verification".
3. **A gate on high only.** A `risk:high` pull request passes only with
   the `owner-reviewed` label. On `synchronize` (any push, a merge from
   main included) the check removes `owner-reviewed` before it judges, so
   the push turns it red until the owner adds the label again. The check
   runs on `labeled` and `unlabeled`, so adding the label turns it green.
   `risk:medium` and `risk:low` have no gate; the owner's merge is the
   review. The `Approved-by:` line is neither asked for nor read.

Agents never add `owner-reviewed` and never merge (rule 16.2), beside the
rule that they never write an `Approved-by:` line, which stays for
repositories on 0012. The pull request template's protected-path box
covers both modes in one line:

```text
- [ ] No protected path touched, or the owner has approved the head: `Approved-by: @login <sha>` below, or (risk mode) the `owner-reviewed` label
```

The `/change` skill, in an opted-in repository, reads the `risk:*` label
once the check has run, ticks the box for low and medium with
`Risk: <level>` below it, and for high leaves it unticked with
`Risk: high; the owner adds owner-reviewed after review`.

The opt-in ships as a template layer, `templates/risk/`, holding a sample
`.github/risk.yml`; `pap init base risk` adds it, and `pap sync` keeps it
in step with the schema. It is not in base, because a sync would then opt
every repository in, pap included, with no one deciding to.

What the label proves, stated plainly: no more about identity than the
line did. The same account that opens the pull request can add the label,
by hand or through `gh`. Its value is elsewhere. A review is tied to the
head, since a push removes it, it costs one click instead of a pasted
SHA, and it is asked for only where the diff says a review is worth the
owner's time.

The reason that carried it: an approval asked for on every pull request
is a ritual, and one asked for on the fifth that matters, with a list of
what to look at, is a review.

## Considered options

- **Keep 0012 and 0013, and shorten the protected-path list.** Lost: the
  tests are protected because a weakened test is how a regression gets
  in. The list cannot tell an added test from a deleted one; the diff
  can.
- **An approving review instead of a label.** Lost, as in 0012: one
  account cannot approve its own pull request (rule 2.1).
- **Keep the line, but only for high risk.** Lost: still a SHA to paste on
  every push, and a label the check removes on push gives the same
  binding to the head without the typing.
- **Edit the pull request body with the review focus.** Lost: agents
  rewrite the body (the `/change` skill does on every push), and a
  rewrite would race the check's edit or drop it. A comment is the
  check's alone.
- **Keep `owner-reviewed` across a merge from main that leaves the pull
  request's own diff unchanged.** Not now: it needs the diff against the
  merge base compared before and after the push, and a merge from a moved
  base can change what merges. The Revisit counts how often the label was
  removed; if merges from main dominate, this is the next step.
- **Opt in by default, the config in base.** Lost: see the layer above.

## Consequences

- Easier: about four in five pull requests need nothing from the owner but
  the merge, and the fifth comes with a list of what to look at.
- Easier: a weakened test is high wherever it sits, so lowering
  `**/tests/**` loses nothing that the protected path was there to catch.
- Harder: the check grows from reading a body to reading a diff. Its
  heuristics are patterns; an assertion written in a form the patterns do
  not know, or a skip by configuration, passes as low. The focus comment
  says what was matched, never that nothing else changed.
- Harder: a high-risk pull request still loses its review on every push,
  merges from main included. Intended for now; see the considered option.
- Limit: the label is writable by the check's own token, by `gh` and by
  anyone with triage access. The check cannot tell who added it, as it
  could not tell who typed the line.
- Limit: the check removes the label on `synchronize` in the run the push
  starts. A label added in the seconds between the push and that run is
  removed with the rest, and the owner adds it again.
- Unchanged: pap itself stays on 0012 and 0013 until it takes the `risk`
  layer, so this record's own pull request needs the owner's
  `Approved-by:` line.
- Follow-up: the `PreToolUse` hook refuses an agent's `gh pr edit
  --add-label owner-reviewed`, the same through `gh api`, and `gh pr
  merge`, as it refuses an `Approved-by:` body (rule 16.2's planned
  enforcement).
- Measurement: the before side is the opted-in repository's last 20
  change PRs under 0013, each approval action an `Approved-by:` line
  written, read from the body's edit history; the after side counts each
  `owner-reviewed` label added, from the issue events. A fix of a high-risk
  path is a pull request merged within 14 days that touches a file a
  `risk:high` pull request changed and whose title is `fix:` or `revert:`.

## Where it is taught or enforced

Backs [`rules.md`](../rules.md) 16.1 (high risk waits for
`owner-reviewed`) and 16.2 (agents never add `owner-reviewed` or merge),
and narrows 4.1's `Approved-by:` sentence to repositories without the
config. Taught in the `/change` skill, the pull request template in
`blairforce1/.github`, and the `risk` layer's README and sample config.
Enforced by the reusable `pr-checks` workflow in `blairforce1/.github`,
once its risk mode ships.
