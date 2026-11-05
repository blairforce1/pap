# Make a change

One change is one branch, `change/<slug>`, one folder, `changes/<slug>/`,
and one draft pull request that carries the intent, the spec and the code
in that order. The skills carry the branch, the worktree, the commits and
the pull request; you supply the intent and the judgement. The reference
is the process document's [change layer](../process/personal-agentic-process.md#5-change-layer),
[`rules.md`](../rules.md) and decisions
[0002](../decisions/0002-skills-stop-at-draft-pr.md),
[0016](../decisions/0016-risk-labels-and-an-owner-reviewed-label-replace-approved-by.md),
[0019](../decisions/0019-a-cold-review-runs-before-every-draft-pr.md),
[0020](../decisions/0020-intent-is-accepted-by-a-recorded-yes-on-the-change-branch.md)
and [0021](../decisions/0021-a-spec-is-accepted-after-review-with-its-operation-designed-in.md).

## The flow

```text
/intent <slug> <class> <what you want>     main session; your yes is recorded
/spec <slug>                               main session; review board; your yes is recorded
/change <slug> <class> [Record: NNNN]      any context; builds, checks, cold review, draft PR
review by risk label                       you read; /pap:reviewed on risk:high
merge                                      you, squash; then mise run tidy
findings                                   by hand today; /findings is planned (H-005)
```

Run each skill in a fresh context: `/clear` between them in a session, or
a new session. One pull request per context; after `/change` opens its
draft the context stops (decision 0002).

## Classes

The class sets the ceremony (process section 4). Pick the smallest that
fits; `/intent` will challenge it.

| Class                | Spec                                                                      | Review                                                                             |
| -------------------- | ------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| `feature`            | Full: scenarios, non-functional rows, Operations section                  | The board's default set, plus UX, GDPR and AI Act where the content calls for them |
| `infra`              | Scenarios optional, non-functional rows, Operations section               | Reliability and operations at least                                                |
| `security-sensitive` | Everything `feature` has, plus Security and Compliance                    | Every perspective                                                                  |
| `bugfix`             | The escaped defect it cites, one scenario that fails before the fix, Undo | QA perspective                                                                     |
| `spike`              | None; intent and findings only, no deploy                                 | None                                                                               |
| `chore`              | Half a page: what changes, how a reader checks it                         | Your read                                                                          |
| `docs`               | Half a page: what changes, how a reader checks it                         | Your read                                                                          |

There is no `process` class. A change that ships a decision record is
class `infra`, its pull request title starts with `process:`, and the body
carries `Record: NNNN`; `pr-checks` refuses a `process:` title without
one. `/change` takes it as `/change <slug> infra Record: NNNN`.

## 1. `/intent`

```text
/intent widget-export feature Let a partner download their usage as CSV
```

Main session only: it interviews you. It reads the product layer first,
then asks in two to four small batches: the ask restated in one line;
which backlog hypothesis it serves (`H-NNN`) or what it reacts to; the
success measure, observable after release; the non-goals; the invariants
and protected paths touched, and the risk level that follows; the class
and what it costs; open questions. It challenges each weak answer once,
then records yours. `docs` and `chore` get one batch; a `spike` one.

Then it restates the intent as half a page in the process's sections and
asks for your yes. No yes, no file. On yes it writes
`changes/<slug>/intent.md` with `accepted-by:` and `accepted-on:`, commits
`intent(<slug>): ...` on `change/<slug>`, removes its worktree and stops.
Nothing is pushed yet.

## 2. `/spec`

```text
/spec widget-export
```

Main session only. It reads the accepted `intent.md` and refuses to go on
without one. It drafts `changes/<slug>/spec.md` with the sections the
class requires:

- **Functional behaviour**: prose for the shape, then acceptance
  scenarios in Given/When/Then, as Gherkin in `features/<slug>.feature`
  at the repository root, each tagged `@id:<slug>-<n>` and
  `@pending:<slug>` until a test binds it. Every noun of state and every
  event is defined in `product/domain.md`; a new term is added in the same
  diff.
- **Non-functional**: one row each, what is measured, the threshold, the
  test tier.
- **Operations** (feature, infra, security-sensitive): **Signals** for
  each success measure, **Good** (the control band and its window),
  **Wrong** (what a breach looks like, how fast it is noticed, the first
  checks), **Undo** (revert the merge, a flag off or a config rollback,
  with steps for anything outside git), and operational scenarios in
  Given/When/Then, kept in the spec. A bugfix writes Undo only.
- **Open questions** carried from the intent, each answered or still open
  with an owner.

It runs the spec review board the class requires, through
`spec-review-full`, writes the register to
`changes/<slug>/reviews/spec-review.md`, and takes you through the
findings a few at a time: each gets `accepted` (the spec changes),
`rejected: <reason>` or `deferred: <phase>`. Then it shows what you are
accepting and asks for your yes. On yes it fills `accepted-by:` and
`accepted-on:`, commits `spec(<slug>): ...`, and stops. "Later" commits a
draft without acceptance lines; the next `/spec <slug>` resumes it.

## 3. `/change`

```text
/change widget-export feature
The brief: one line is enough once intent.md and spec.md are on the branch.
```

Any context, a background agent included. It resumes the branch in a
worktree at `../<repo>-<slug>`, reads the intent and the spec (their class
and hypothesis stand; a different `<class>` argument is reported as a
contradiction), reads the rules and records that bear on the files it
touches, and reports only contradictions. Then it builds: a commit per
logical step, a conventional commit subject, a co-author trailer on
generated content, never bypassing a hook. The scenarios are its
acceptance criteria; a test made to pass by rewriting a scenario is a
return to spec, not a fix.

Before the pull request it runs `mise run check` and `mise run test`, and
has the branch reviewed cold (decision 0019): a read-only subagent given
only the brief and the diff, running `/code-review low` where that skill
exists. Each finding is fixed or answered in the pull request.

Then it pushes and opens the draft pull request with the `class:<class>`
label and a body in the template's order: `Change:` and `Record:` lines,
Summary with the deviations to review, a Verification table (every check
run, and the cold review's row), "How to revert" copied from the spec's
Undo, and the Checks section with every box answered. It reads the
`risk:*` label `pr-checks` set and answers the protected-path box from it.
Its report names the revisits `pap revisits` says are due, the
`mise run tidy` to run once the pull request has merged, and the risk
level.

It stops there. It never marks the pull request ready, never merges.

## 4. Review by risk label

In a repository with `.github/risk.yml` on its base branch (the `risk`
layer), `pr-checks` sets one of `risk:high`, `risk:medium` or `risk:low`
from the diff and keeps one "Review focus" comment listing each file above
low with the reason and the question to ask of it. Fixed high:
`.github/workflows/**`, `.github/CODEOWNERS`, `.github/risk.yml`,
`decisions/**`, `product/invariants.md`, and any weakened test.

- **`risk:low` or `risk:medium`**: your merge is the review. Read the
  Summary's deviations and the Verification table.
- **`risk:high`**: read the review-focus comment and the files it names,
  then:

  ```text
  /pap:reviewed <PR#> [sha7+]
  ```

  adds the `owner-reviewed` label to that head. Only you can invoke it.
  Any push, a merge from main included, removes the label; review the new
  head and run it again. The check fails until the label is back.

Without `.github/risk.yml` the older rule applies (decisions 0012 and
0013): a pull request touching a `CODEOWNERS` path needs an
`Approved-by: @login <sha>` line you type by hand into the body, naming
the head you approve; every push needs a new one.

An agent never adds `owner-reviewed`, never writes `Approved-by:` and
never merges (rule 16.2). The `pap` plugin's hook refuses the attempt.

## 5. Merge

Mark the pull request ready and squash-merge it; the ruleset allows
nothing else. The merge is the acceptance of every phase the branch
carries. Then, in the repository:

```sh
mise run tidy
```

removes the worktree and the branch of every merged change.

### How to revert

Revert the squash commit (`git revert <sha>` on a new `change/` branch,
through a pull request), unless the change reached outside git:
then the pull request's "How to revert" section, copied from the spec's
Undo, lists the steps in order. Write that section before you need it;
`/spec` makes you.

## 6. Findings

At the end of the operation window (30 days by default) or on the first
escape, write `changes/<slug>/findings.md` (process
[5.11](../process/personal-agentic-process.md#511-findingsmd)): the
success measure's result, defects caught and escaped with the phase each is
attributed to, returns, product-layer impact, one thing to change next
time. Every escape becomes an eval. Today this is by hand; `/findings` is
not yet a command (backlog H-005).
