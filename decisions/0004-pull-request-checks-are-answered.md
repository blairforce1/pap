# 0004. Check every pull request's title and Checks section in CI

- **Status:** measured:inconclusive (2026-09-25)
- **Disposition:** kept
- **Date:** 2026-09-24
- **Deciders:** blairforce1, with Claude Code
- **Supersedes:** none
- **PIP:** #21 (decision 0003 merged with all three Checks boxes unticked, no reasons, and no attribution for generated content)
- **Expected effect:** pull requests merged with an unexplained unticked box, or with generated content shown but not declared, ↓ from 2 of the 15 merged since the template (#7, #21) to 0
- **Introduced in:** v0.5.0
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

## Result

Evaluated 2026-09-25 with `bin/pap measure 0004` (#13 to #22 before,
#24 to #35 after) and `bin/pap measure 0004 --from '#35'` (#37 to #47),
the twenty change pull requests the trigger counts. Every failed
`pr-checks` run was read from its annotations, or from the run page
where it had none, and each refusal checked against the body as it stood when the
run started, from the pull request's edit history.

Trigger: no. Over #24 to #47 the check refused a correct pull request
zero times and a real omission three times.

| PR    | Class | Failed runs | What it refused                                                   | Real omission | False refusal |
| ----- | ----- | ----------- | ----------------------------------------------------------------- | ------------- | ------------- |
| #45   | infra | 3           | No `## Checks` section; the body read "(body to follow)" for 30 s | 3             | 0             |
| Total |       | 3           |                                                                   | 3             | 0             |

The other nineteen had no failed run. The Actions API agrees with
`pap measure`: no run on a commit a force push dropped was missed.

#23, the pull request that built the check, is listed apart and not
counted. Of its seven failed runs, six never started: GitHub refused the
caller's `uses:` ref ("a workflow file issue"), first a branch ref with a
slash, then a commit that existed only on the unmerged
`blairforce1/.github#2`. They are faults in the check's wiring, not
refusals of anything. The seventh refused an unticked Verification box
with no reason, which the body had at that moment: a deliberate probe,
ticked again 19 s later. So #23 is 0 false, 1 real, 6 that refused
nothing.

Omissions the check let through: one. #46 merged with its protected-path
box unticked and the reason "Approval is blairforce1's to record here
before merge"; no approval was recorded before the merge or since. The
check reads any reason as an answer, so "not yet" passes. #48 has the
same gap, with the approval recorded two minutes after the merge; it is
the 21st change pull request, outside the count, and is recorded here
as a confound and not counted.

A second kind the check cannot see by design: a ticked box that is
false. #47 edited `decisions/0002`, a protected path since #46, and
ticked "No protected path touched, or the approval is recorded here"
with no approval recorded. The Considered options above chose to
enforce declarations, not detect the truth of them, so it is noted and
not counted. #24 to #45 cannot be judged the same way: pap had no
protected-path list until #46 wrote one.

Expected effect: inconclusive on both columns, and it could be nothing
else.

| PR  | Window | Class              | Unexplained unticked | Provenance line |
| --- | ------ | ------------------ | -------------------- | --------------- |
| #13 | before | bugfix             | 0                    | 1               |
| #14 | before | infra              | 0                    | 1               |
| #15 | before | chore              | 0                    | 1               |
| #16 | before | spike              | 0                    | 1               |
| #17 | before | infra              | 0                    | 1               |
| #18 | before | docs               | 0                    | 1               |
| #19 | before | feature            | 0                    | 1               |
| #20 | before | chore              | 0                    | 1               |
| #21 | before | docs               | 3                    | 0               |
| #22 | before | feature            | 0                    | 1               |
| #24 | after  | feature            | 0                    | 1               |
| #25 | after  | feature            | 0                    | 1               |
| #26 | after  | feature            | 0                    | 1               |
| #27 | after  | security-sensitive | 0                    | 1               |
| #28 | after  | docs               | 0                    | 1               |
| #29 | after  | feature            | 0                    | 1               |
| #30 | after  | feature            | 0                    | 1               |
| #31 | after  | infra              | 0                    | 1               |
| #33 | after  | security-sensitive | 0                    | 1               |
| #35 | after  | infra              | 0                    | 1               |

#37 to #47 read the same, 0 and 1 on every row. `--verdict` gives
`checks_unticked_unexplained` down: inconclusive (after median 0, before
3rd to 8th 0 to 0), and `provenance_declared` up: inconclusive (after
median 1, before 1 to 1). Only #21 moved either column before, so the
baseline's range is a single value, and a median cannot fall below 0 or
rise above 1. An extension by ten a side would read the same, so it is
not taken. On the counts the registered effect holds: 1 of 10 before, 0
of 20 after. `provenance_declared` is a proxy: it reads a `Provenance:`
line, not whether generated content was shown.

`pr_checks_failures` has no before side: the check first ran on #23.
`--verdict` says it cannot run (0 before, 10 after). No before side is
constructed for it.

Status, by 0001's rule: no metric refuted, none confirmed, so
`measured:inconclusive`. The trigger's revert condition does not fire,
so the check is kept. The two do not contradict each other: the rule
cannot confirm an effect whose baseline sits at the floor, and the
trigger asks a different question, which it answers.

What `pap measure` could not answer, and where it came from instead: it
counts failed runs but not what they refused, and counts #23's six runs
that never started as failures (the annotations and run pages, through
`gh api`); it reads the final body, so not what a run saw (the edit
history); and it cannot tell a deferred approval or a false tick from an
answer (each body read by hand, against `.github/CODEOWNERS`).

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
- Recorded 2026-09-25: the revisit was evaluated; see Result. The check
  accepts any reason under an unticked box, so an approval the reason
  defers ("record here before merge") is never checked for. #46 and #48
  merged that way.
- Recorded 2026-09-25, by [0012](0012-protected-paths-need-an-owners-approved-by-line.md):
  a pull request touching a protected path needs an owner's
  `Approved-by: @login` line, and a reason no longer answers that box.
  The required-check follow-up above was done in #42.
- Recorded 2026-09-25: a squash merge keeps one co-author per email, and
  every Claude model shares `noreply@anthropic.com`, so all but one
  Anthropic co-author are dropped (#50 lost its Fable 5.1 trailer). Rule
  4.2's trailer is a lower bound; the `Provenance:` line is the complete
  record, and `scripts/written-with.sh` counts both for release notes.

## Where it is taught or enforced

Backs [`rules.md`](../rules.md) 4.1 (checks are answered) and 4.2
(generated content is declared), and enforces 1.2 from
[0001](0001-process-changes-are-measured-interventions.md). Taught in the
pull request template in `blairforce1/.github`. Enforced by
`.github/workflows/pr-checks.yml`, which calls
`blairforce1/.github/.github/workflows/pr-checks.yml@main`.
