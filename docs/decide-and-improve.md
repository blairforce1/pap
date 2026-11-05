# Decide and improve

How the process changes: a decision record per change to how you work,
written before it starts and checked on a date or a count, and the
backlog that says what comes next. The reference is decision
[0001](../decisions/0001-process-changes-are-measured-interventions.md)
(interventions), [0010](../decisions/0010-revisits-are-typed-and-counted.md)
(revisits) and the process document's
[improvement layer](../process/personal-agentic-process.md#6-improvement-layer).

## Decision records as experiments

A change to how you work (a skill, a prompt rule, a review pass, a
template change, a hook, a model upgrade) is an intervention. Before it
starts, write `decisions/NNNN-<slug>.md` with the header every record in
[`decisions/`](../decisions/) carries: **Status**, **PIP** (the problem it
answers, with a number where there is one), **Expected effect** (the
measure, the direction, a size), **Introduced in** (the release), and
**Revisit**, typed as decision 0010 requires:

```text
after <n> change PRs [from #<pr>]: <what to look at>
on <YYYY-MM-DD>: <what to look at>
when <condition>: <what to look at>
```

Then Context, Decision (with "the reason that carried it"), Considered
options, Consequences, and "Where it is taught or enforced". A new rule
arrives with its record as a line in `rules.md`, numbered by the record
(22.1 is the first rule of record 0022), with what enforces it today;
"Nothing yet" is an honest entry.

Writing the record is by hand; no skill drafts it. It ships through
`/change <slug> infra Record: NNNN`: the pull request title starts with
`process:`, the body carries `Record: NNNN`, and `pr-checks` refuses one
without the other. The record's Status is `proposed` until you accept it.

## `/pap:accept`

```text
/pap:accept [--repo <path>] <NNNN> [NNNN ...]
```

Only you can invoke it. Its script checks that each record is on main and
`proposed`, shows what is accepted, sets each Status line to
`accepted (<login>, <date>)` and nothing else, commits on a new
`change/accept-<ids>` branch, pushes and opens a draft `class:docs` pull
request. Merging it is the acceptance. The first line of its output,
`Repository: owner/name (path)`, names the repository it acted on: it is
the current one unless `--repo` says otherwise, so from a PM session in
another project pass `--repo` to the checkout whose records you mean.

## Revisits

```sh
pap revisits
```

prints one line per record: `due`, `not due (n of m)`, `manual` (a
`when` trigger), `closed` (a `measured:`, superseded or withdrawn record)
or `unknown` when it cannot count (an untyped line, or `gh` offline). It
reports and never blocks, and `/change` ends every report with the due
ones. Taking a revisit up is your act; nothing schedules it. A `/revisit`
skill is a follow-up decision 0010 names and not yet a command.

To take one up on a counted trigger:

```sh
pap measure <record> [--from #<pr>] [--verdict <column> <direction>]
```

prints, as TSV, one row per change pull request in two windows: the last
ten merged before the start the Revisit line names and the first ten
after, with open-to-merge minutes, draft minutes, reviews, changes
requested, unexplained unticked boxes, provenance and failed `pr-checks`
runs, plus the `change/` pull requests closed unmerged in the span.
`--verdict` applies decision 0001's rule to one column (the median of
`after` against the 3rd and 8th of the ten sorted `before` values) for a
direction `up`, `down`, `not-up` or `not-down`, and prints `confirmed`,
`refuted`, `inconclusive`, `held`, `broken` or `cannot run`. A window
with fewer than ten is named short and never padded.

Write the result into the record's Result section with the date, set its
Status to `measured:confirmed`, `measured:refuted` or
`measured:inconclusive` and its Disposition to kept or withdrawn, and ship
it as a `docs` change. Decisions 0002, 0004 and 0010 show the form.

## Audits

Two kinds, both by hand today.

- **The process audit of the repository.** `pap coverage` prints one line
  per principle and section of the process document (covered by a rule or
  backlog item, deferred, or uncovered, from `coverage.md`) and one line
  per `rules.md` enforcement entry that disagrees with the repository (a
  path that does not exist, a check claimed required that the ruleset does
  not require). Both counts should be 0 before a release.
- **The efficiency audit of a project** run under a PM session: every five
  merged change pull requests and at every relaunch, per
  [Run a project](run-a-project.md#efficiency-audits). Its findings become
  briefing rules, and the general ones come back to PAP as a change.

## Evals

Any change to agent configuration (a skill, a hook, a prompt, the model)
should run the eval suite before it goes live (process 6.2). PAP is a
plugin, so the harness is Claude Code's `claude plugin eval`:

```sh
claude plugin eval plugins/spec-review
```

runs the cases under `plugins/spec-review/evals/` (one `case.yaml` each:
a prompt, the tools allowed, graders that check which skill fired) and
reports scored results, with a no-plugin baseline arm by default. That is
the one suite today; it checks that the review perspectives trigger on the
right prompts. An outcome eval suite of real tasks across PAP, gated in CI,
is backlog item H-010, planned, with a decision record to follow when the
first suite lands. Until then, every escape you attribute in a
`findings.md` is a candidate case.

## The backlog

[`product/backlog.md`](../product/backlog.md) holds the hypotheses:
"We believe **[change]** will produce **[outcome]**, measured by
**[observable signal]**", each with its class and the decisions and process
sections it relates to, ranked by value and risk. An item exists once it
is merged there; an issue may propose one but is never canonical (decision
0011). Every `/intent` names one, or says `reactive:` and why. A
`Status:` line on an item records what has shipped; `Dropped` items keep
their line and their reason.

When findings come back, rewrite the backlog: confirm, refute or revise the
hypothesis the change served. The console's PAP tab counts items by state.
