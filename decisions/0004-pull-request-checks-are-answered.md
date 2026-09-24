# 0004. Check every pull request's title and Checks section in CI

- **Status:** accepted
- **Date:** 2026-09-24
- **Deciders:** blairforce1, with Claude Code
- **Supersedes:** none
- **PIP:** #21 (decision 0003 merged with all three Checks boxes unticked, no reasons, and no attribution for generated content)
- **Expected effect:** pull requests merged with an unexplained unticked box, or with generated content shown but not declared, ↓ from 2 of the 15 merged since the template (#7, #21) to 0
- **Introduced in:** unreleased
- **Revisit:** after 20 change PRs from #23: if the check failed more often on a correct pull request than on a real omission. The record predates the first tag, so the count starts after its pull request

## Context

The pull request template asks three questions in a Checks section and
says an unticked box needs a one-line reason. Nothing checked the answers.
#21 merged with all three boxes unticked and no reasons; its record said
"with Claude" while its commit carried no co-author trailer and its body no
provenance. #7 left the provenance box unticked the same way. Process
principle 6 says every generated artefact records what produced it, and a
reviewer reading their own pull request is the person least likely to
notice what is missing. Rule 1.2's `process:` title check was planned in
0001 and never built.

## Decision

Every repository that adopts PAP calls a reusable workflow,
`pr-checks.yml` in `blairforce1/.github`, on every pull request event that
can change the title or body. It refuses a title that is not a
conventional commit, a `process:` title without a `Record: NNNN` line, a
Checks box left unticked with no reason on the next line, a ticked
provenance box with nothing recorded (no `Co-authored-by` trailer on any
commit, no `Provenance:` line), and an unticked provenance box on a pull
request that shows generated content (an Anthropic co-author trailer or a
"Generated with" line). Bot pull requests pass unchecked. The reason that
carried it: an answer nobody checks is not an answer, and the one pull
request that skipped all three was a process record.

## Considered options

- **A check in each repository.** Lost: every adopting repository would
  carry a copy, and the copies drift.
- **A Claude Code hook on `gh pr create`.** Lost: it misses pull requests
  opened or edited anywhere else, including the web, where #21's body was
  written.
- **Detect generated content from the diff.** Lost: there is no reliable
  signal; the check enforces what the pull request declares, and makes an
  omission visible, not a false declaration.

## Consequences

- Easier: the Checks section means something; a merged pull request has
  answered every question.
- Easier: rule 1.2's title check exists.
- Harder: a pull request not started from the template fails until its body
  has a Checks section. Calibration on the history: pap #1 to #6 and
  `.github` #1 predate the template and would fail; #8 to #20 and #22 pass;
  #7 and #21 fail, as intended.
- Harder: `blairforce1/.github` main is now code every adopting repository
  runs; its ruleset is the only guard on it.
- Follow-up: make `pr-checks / checks` a required status check in each
  repository's ruleset. Until then the check reports and does not block.
- Follow-up: the dependency-updates layer's bot pull requests pass
  unchecked; revisit if a bot ever opens a pull request that needs a
  human's answers.

## Where it is taught or enforced

Backs [`rules.md`](../rules.md) 4.1 (checks are answered) and 4.2
(generated content is declared), and enforces 1.2 from
[0001](0001-process-changes-are-measured-interventions.md). Taught in the
pull request template in `blairforce1/.github`. Enforced by
`.github/workflows/pr-checks.yml`, which calls
`blairforce1/.github/.github/workflows/pr-checks.yml@main`.
