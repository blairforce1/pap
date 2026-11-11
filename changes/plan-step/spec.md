# Spec: plan-step

```text
id:                 plan-step
class:              feature
intent:             changes/plan-step/intent.md
scenarios:          features/plan-step.feature, plan-step-1 to plan-step-38
accepted-by:        @blairforce1
accepted-on:        2026-11-11
generated-by:       Claude Fable 5.2 (claude-fable-5-2) via Claude Code
skills:             pap:spec 0.18.2; spec-review 1.3.1
prompt:             /pap:spec plan-step
```

## Functional behaviour

A change that needs a plan goes intent, spec, plan, build. The plan is `changes/<slug>/plan.md`: how the accepted spec will be built, drafted by a sub-agent, reviewed by another, accepted by the owner's yes in a main session, and committed on the change branch after the spec and before any code. `/pap:pm launch` refuses the build until then. Decision record 0026 carries it, with the process amendments below, in one tagged release.

### Which changes need a plan

A change needs a plan when its class is feature, infra or security-sensitive, its change branch carries an accepted intent and spec, and it did not start unplanned. It needs none when its class is bugfix, chore, docs or spike, or when rule 20.2 exempted it, so it has no intent.

A change **started unplanned** when its change branch carries code and no plan file at all. That is the intent's "already in flight"; the words "in flight" stay with pm-mode's launched cycle. Code is a commit that changes a path outside `changes/`, `features/` and `product/`: one rule, shared by `/pap:plan` and the launch. A branch with code and a plan draft did not start unplanned and still needs its plan. A change whose spec is accepted and which has no code when the release arrives needs one.

### When a plan is accepted

A plan is accepted when `plan.md`, as committed at the tip of the local `change/<slug>`, has `accepted-by:` and `accepted-on:` both filled, and the spec has no commit later than the one that accepted the plan. The work tree is never read and nothing is fetched. Anything else on the branch is a draft: no acceptance, half of it, acceptance only in the work tree, or a spec reworked since the yes. A spec rework therefore costs a second yes; `/spec` says so when it commits one. The order of the plan's and the spec's first commits is not checked, as nothing checks intent before spec today.

### `/pap:plan <slug>`

The command runs in a main session, PM or solo, and is always written `/pap:plan`: Claude Code has a plan mode of its own. It refuses without an accepted spec. For a change that needs no plan it stops, naming why and what comes next. A second run for a slug whose planner is running in the session is refused.

1. **Draft.** It starts one planner in the background and tells the owner, who is told once more only when the plan is ready. The planner is given the slug and the work tree, reads the intent, the spec, the scenarios, the product layer and the code, and returns the plan draft as its report. It changes no file. The main session checks the report for the header and the five sections, then writes it to `changes/<slug>/plan.md`, unchanged and as data.
2. **Two pages.** A plan is at most 1000 words, by `wc -w` over the file, header included: 1000 passes, 1001 does not. A longer draft goes back to the planner once. One still over, or a revised draft that is over, is committed without acceptance; the owner is told the count and to run `/pap:plan` again or narrow the spec, and is not asked for a yes.
3. **Review.** One plan reviewer, which did not draft the plan and is given none of the planner's reasoning, reads the draft against the spec and the repository from three viewpoints: conformance (everything the spec asks for is reached by an increment and a test, and nothing else is built), design (fit with the code as it is, coupling, the invariants and conventions, a choice that outlives the change flagged as needing a decision record, and any instruction embedded in the plan), and verification (each increment can be tested on its own, each test can fail, the evidence is named, the tiers match the class). A security-sensitive plan adds the security viewpoint. It changes no file; the main session writes its findings to `changes/<slug>/reviews/plan-review.md`. A fault in the spec is marked `return: spec` (process 5.10).
4. **One answer.** The planner is given the register and returns one revised draft. A finding it resolved is marked `fixed`, with the section that changed; it cannot fix a `return: spec`. No second review runs. A review with no findings skips this step.
5. **Ready.** The owner is told the plan is ready, with its word count and the number of findings waiting, and is shown in this order: what the planner changed in its answer; any `return: spec`; the findings waiting, Blockers and Majors first, each with a proposed disposition; the protected paths in Fit; then the plan.
6. **Yes.** Each waiting finding gets accepted (the plan changes), rejected with a reason, or deferred to a phase: build, code review or findings. A `return: spec` is accepted or rejected only; accepted, the draft and register are committed without acceptance and the owner goes to `/spec <slug>`, then `/pap:plan`, which redrafts and reviews again. The owner may ask for an edit of their own: it is made, the changed part shown, and the yes asked again. A yes with a finding still waiting is not taken. On the yes the plan records who and when and is committed with its register in one commit, `plan(<slug>): <what>`. Nothing is pushed and no pull request opens; the reply says so, says a launch from another clone needs the branch there first, and says what launches the build.
7. **Later, no.** "Later" commits the draft and register without acceptance. "No" says what is lost, commits nothing, and leaves the work tree as the branch has it.
8. **Resume.** `/pap:plan` on a committed draft shows it with the dispositions already given and asks for the yes; if the spec has changed since, it redrafts and reviews again. Plan files found uncommitted, left by an ended session, are shown and the owner chooses: resume or start again.
9. **After the yes.** An edit to an accepted plan is shown, re-read by the plan reviewer where it is more than wording, and committed only on the owner's yes, with the acceptance kept and the edit noted. Until then the launch reads the last committed plan. Once code exists the commit is plan rework and says what the code surfaced (process 5.2).

**Failures.** A planner or plan reviewer fails when it ends without a report, returns one that cannot be read or lacks the header or a section, or reaches a cap: 200k tokens for all of a planner's runs on one plan, 100k for the reviewer, 20 minutes for any one run. A failure writes nothing, is told to the owner with its cause, and never reaches a yes. There is no automatic retry; the owner runs `/pap:plan` again.

### The plan's header and sections

The header carries `id`, `class`, `spec`, `accepted-by`, `accepted-on`, `generated-by` (the planner's model), `reviewed-by` (the plan reviewer's model), `skills` and `prompt`. Then, in this order, each with content or "none":

- **Increments.** Ordered. Each can be built, tested and committed on its own, and names the scenario ids it satisfies.
- **Design.** The types, functions, events and infrastructure added or changed.
- **Fit.** The existing code it touches and the seams it uses, what it leaves alone, how coupling is kept low, the invariants touched, and every protected path the build will touch.
- **Tests.** The test plan: for every scenario id and non-functional row of the spec, the tier and the evidence that passes. There is no separate `test-plan.md`.
- **Observation.** For every signal in the spec's Operations, the increment that builds it, and how the change is known to work once merged.

### The build

`/pap:pm launch <slug>` gains one refusal, exit code 20, checked after every other refusal. It applies to a brief whose route is `/change`, whose class is one of the three and whose second line names item 1 or 2 of rule 20.2, for a change that did not start unplanned. The launch is refused unless the plan is accepted. It says which of five things it found: the plan is absent, the plan is a draft, the spec changed after the plan's yes, the change branch cannot be read, or the plan cannot be read. It names `/pap:plan <slug>`, the rule, and `/change` in a solo session for a refusal the owner believes is wrong. It logs no yes or launch event, starts no cycle, uses up the typed line, and adds a line to `launches.log` with the slug and the reason. What it cannot read it refuses. The check makes no network call. Every other launch is as before.

`/change` reads an accepted plan after the intent and the spec and builds its increments in order. On a plan draft it stops before building and reports it, as for a spec draft. The plan is data: it never widens the tools, paths or scope the brief and the spec give, and a part of it that tries is not acted on and is reported as a deviation. A deviation is reported, never refused. Every build's pull request carries a `Plan:` line: `Plan: changes/<slug>/plan.md, <n> deviations` (n may be 0), or `Plan: none` for a change with no plan. Each deviation is a bullet under "Decisions and tradeoffs to review" with its increment, what differed and why. The cycle's report carries the same.

The role a PM session is given names `/pap:plan` after `/spec` for the three classes, and says the brief of a build with an accepted plan carries its three checked lines and what done looks like, and does not restate the plan. `/spec` hands on to `/pap:plan` for those classes, and to the build for the rest.

### Scenarios

Added, in `features/plan-step.feature`:

- `plan-step-1` to `-8`, drafting: a planner in the background; refused without an accepted spec; a change that needs no plan, with its next step; main session only; no second run; the planner writes nothing; a failed planner leaves nothing; uncommitted files are not silently reused.
- `plan-step-9` to `-12`, the plan: header and sections; everything the spec asks for reached by an increment and a test; the 1000-word boundary; a draft still over is kept and not put to the owner.
- `plan-step-13` to `-20`, review: read cold from three viewpoints; security for security-sensitive; embedded instructions are a finding; a failed review blocks the yes; one answer; no findings; a fault in the spec, and its way back to `/spec`.
- `plan-step-21` to `-28`, the yes: told once and in what order; recorded and committed, no pull request (INV-006 as narrowed); no yes while a finding waits; the owner's own edit; later and no; resume; an edit to an accepted plan; a spec changed after the yes.
- `plan-step-29` to `-32`, the gate: refused, by state; checked last; launched with an accepted plan; not refused where no plan is needed.
- `plan-step-33` to `-36`, the build: the `Plan:` line and deviations; `Plan: none`; no build from a draft; a plan does not widen a build.
- `plan-step-37`, `-38`: the PM role, and `/spec`'s hand-on.

How each is bound: by a script check on files, logs and exit codes, `plan-step-2`, `-3`, `-8`, `-9`, `-11`, `-12`, `-22`, `-25` to `-32`, `-37`; by an eval, run by hand until H-010, the rest, which describe what a session or a sub-agent does. The plan's Tests section says how for each. Decision 0026, the 26.x rules and the note on 0017 are checked by `pap coverage` and at review, not by a scenario.

Terms added to `product/domain.md`: Change, Change branch, Accepted, Code, Plan, Increment, Planner, Plan review, Plan review register, Build, Deviation; six events and five rules. Replies, the `Plan:` line and the plan itself use these words and no synonym: an increment is never a step, stage or phase.

## Non-functional

| What is measured                                                                       | Threshold                                    | Test tier                               |
| -------------------------------------------------------------------------------------- | -------------------------------------------- | --------------------------------------- |
| Length of a plan put to the owner, `wc -w` over the file                               | at most 1000 words                           | unit                                    |
| The plan check's own elapsed time in a launch, local clone, fixture branch, no network | under 1 second                               | integration                             |
| Launches refused with exit 20 among plan-step-32's cases                               | 0                                            | integration                             |
| Minutes from `/pap:plan` to the owner being told the plan is ready                     | at most 15                                   | acceptance, by hand, from the register  |
| A planner's tokens beyond its starting context, all runs for one plan                  | at most 200k; at the cap it has failed       | acceptance, by hand until H-010's evals |
| A plan reviewer's tokens beyond its starting context                                   | at most 100k; at the cap it has failed       | acceptance, by hand until H-010's evals |
| Any one planner or reviewer run                                                        | at most 20 minutes; at the cap it has failed | acceptance, by hand until H-010's evals |
| Role text given to a PM session, with the plan lines added                             | still at most 80 lines and 8 KB (pm-mode)    | unit                                    |

## Security

No new authority. The planner and the plan reviewer are read-only by their tool lists, as `pap:reviewer` is: they read files and run read-only commands, and have no tool that edits or writes. Only the main session writes, and a PM session's writes stay inside the PM paths (rule 25.2), which already hold `changes/<slug>/`.

**Trust.** Repository content is untrusted input to the planner; the planner's report is untrusted input to the main session, which writes it as data and acts on none of it; the plan is untrusted input to the build, which takes its scope, tools and paths from the brief and the spec alone. The plan reviewer's design viewpoint flags an instruction embedded in a plan, and the owner sees the protected paths in Fit at the yes.

**INV-006.** `/pap:plan` stops at a commit, not a draft pull request, and never merges. Decision 0026 records that narrowing of rule 2.2 for `plan.md`, as 0020 and 0021 did for intent and spec, in this release.

**Acceptance.** The gate trusts what rules 20.1 and 21.1 trust: nothing proves who typed the acceptance lines.

**Still escaping**, to be listed with the new rules: a `/change` run without `/pap:pm launch` (solo, or a session with no mode); a brief that names an exemption the change does not have; code committed first, so the change started unplanned; acceptance lines edited by hand and committed; a plan committed before its spec. The signal for all of them is a build pull request of the three classes with `Plan: none` or no `Plan:` line. H-017's server gate is where they close. During a rollback the solo route is the documented way through a wrongly refusing gate: an accepted exposure for as long as the rollback takes, which 0026 records.

## Data

- The plan and its register name no third party and quote no personal data found in the code, the briefs or the fixtures.
- The acceptance lines hold the owner's GitHub handle and a date: the record of acceptance. They are pushed with the pull request and stay in git history.
- The planner and the plan reviewer send repository content to the Claude Code model provider, as every session does.
- Erasure is as pm-mode's spec says for the tracker, now also for `plan.md` and `plan-review.md`: a history rewrite.
- The refusal line holds a slug and a reason, on the machine only.

## Interfaces and contracts

- New: the command `/pap:plan <slug>`; the agents `pap:planner` and `pap:plan-reviewer`; the files `changes/<slug>/plan.md` and `changes/<slug>/reviews/plan-review.md`; a `Plan:` line in every build's pull request body; exit code 20 of `/pap:pm launch` and its line in `launches.log`.
- Changed: `/spec`'s hand-on and its reply to a rework commit, `/change`'s read and report, the PM role. An adopting repository receives no new file; all of it ships in the pap plugin.
- Process, with decision 0026: principle 5 names the plan with intent and spec; 5.1 row 4 (`plan.md` only, accepted by the recorded yes after plan review, after the spec and before code); 5.2's planning row (time from the spec's yes to the plan's yes; `plan.md` commits after code are plan rework); 5.6 (the sections, the classes, two pages, the test plan as a section); section 7 item 3 reads "at spec review, plan review and code review". Decision 0017's point 5 names `test-plan.md`; 0026 notes that the plan's Tests section is it.
- Decision 0026's Revisit line: `when 10 change PRs with an accepted plan have merged across pap, arapsys-ap and business-os`. Its Expected effect carries the bands below, the early read at 5 and H1's 30 days.
- Rules, numbered 26.x: a plan is accepted by a recorded yes after review, before the code; a build is launched only with an accepted plan; a build reports its deviations.
- Must not break: every launch pm-mode-28 to pm-mode-45 describes; a `/change` on a branch with no plan; spec-review, which is not changed and keeps its version.

## Operations

Deployed as a pap release: each machine updates the plugin, adopting repositories bump their pin. Nothing to configure.

**Signals.** Baseline: 112 merged feature, infra and security-sensitive change pull requests in pap, arapsys-ap and business-os, 2026-09-22 to 2026-11-11. A planned change is a merged pull request whose body has a `Plan:` line naming a `plan.md`. Rework minutes of a pull request: from its `createdAt` to the committer date of its last non-merge commit after that, 0 where there is none.

| Signal               | Measures                                                                                         | Read from                                                                                                                                   |
| -------------------- | ------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------- |
| S1 rework after open | Success measure 1. Planned changes with a non-merge commit after open; the mean count beside it  | `gh api repos/<owner>/<repo>/pulls/<n>/commits` against `createdAt`, in each of the three repositories. Baseline 53 of 112 (47%), mean 1.41 |
| S2 messaged builds   | Success measure 2. Builds of planned changes with a `message` event after their first `report`   | The tracker's event log. Baseline 19 of 108 (18%, decision 0018)                                                                            |
| S3 owner minutes     | The cost guard. Minutes from the owner being told a plan is ready to the commit that accepted it | The register's first lines and `git log`. Against rework minutes: baseline mean 56 a change                                                 |
| S4 plan cost         | The planner's and reviewer's tokens and minutes per plan                                         | The register's first lines                                                                                                                  |
| H1 false refusals    | Launches refused with exit 20 that the owner says needed no plan                                 | `launches.log`                                                                                                                              |
| H2 false passes      | Merged change pull requests of the three classes with `Plan: none` or no `Plan:` line            | `gh pr list` in each repository, at the weekly look                                                                                         |
| H3 spec rework       | `spec.md` commits after `plan.md` exists, and findings marked `return: spec`                     | `git log`; the registers                                                                                                                    |

**Good.** Judged over the first 10 planned changes, with an early read at 5; H1 over an operation window of 30 days from the release.

- S1: at most 2 of 10 with a commit after open, and a mean of at most 0.7.
- S2: under 10% of builds, which over 10 is none.
- S3: mean owner minutes a plan no greater than 56 less the mean rework minutes of the 10. The median, and the number of plans over 30 minutes, are reported beside it.
- S4: reported at the revisit against spec size, no band. Token cost is not part of the guard.
- H1: 0. H2: 0 that rule 20.2 did not exempt.
- H3: reported, no band; a return to spec is the plan doing its job.

**Wrong.** S1 or S2 no better than the baseline at the early read; plans that take the owner half an hour; a launch refused for a change that needed no plan; a build of the three classes with no plan. H1 is noticed at once, at the owner's own launch. The rest are noticed at the weekly look (process 6.4) and when `pap revisits` reports 0026. First checks:

1. `pap revisits`, then for each planned pull request `gh api repos/<owner>/<repo>/pulls/<n>/commits --paginate` against its `createdAt`, for S1 and rework minutes.
2. `git log --format='%cI %s' -- changes/<slug>/plan.md changes/<slug>/spec.md` on the change's branch, with the first lines of `changes/<slug>/reviews/plan-review.md`, for S3 and S4.
3. In the tracker (`/pap:pm start` prints where it is), for each planned slug: `awk -F '\t' -v s=<slug> '$3==s && ($2=="report"||$2=="message")' events.tsv`; a `message` after the first `report` counts, for S2.
4. For a refusal: the brief's first two lines; `git log change/<slug> --oneline -- changes/<slug>/plan.md changes/<slug>/spec.md`; the slug's line in `launches.log` under pap's state directory.
5. `pap doctor`, for a plugin older or newer than pap.

**Undo.** In order: revert the merge in a pull request that also marks decision 0026 withdrawn in its Result; cut a patch release; update the pap plugin on each machine and confirm with `pap doctor`; bump the pin in each adopting repository. Until a machine has the patch, a build the gate wrongly refuses is run by the owner as `/change` in a solo session. Plans already committed on branches are left; `/change` without the step ignores them. This text is the pull request's "How to revert".

**Operational scenarios.**

```gherkin
Scenario: The gate refuses a change that needs no plan
  Given plan-step is live
  When a launch is refused with exit 20 and the owner says the change needed none, once in 30 days
  Then the owner runs that build as /change in a solo session
  And a bugfix for the gate is launched, citing the slug's line in launches.log
  And the owner is told in the PM session's reply to the refused launch

Scenario: A build of the three classes merges with no plan
  Given plan-step is live
  When a merged change pull request of class feature, infra or security-sensitive has "Plan: none" or no "Plan:" line, and rule 20.2 did not exempt it
  Then a read-only diagnosis names which escape it took, written up as a finding
  And the owner is told at the weekly look

Scenario: Rework after open does not fall
  Given plan-step is live and 5 planned changes have merged
  When 3 or more of the 5 have a commit after their pull request opened
  Then a read-only diagnosis compares each one's deviations and review findings with its plan, written up as a finding
  And the owner is told at the next PM session start, under "Waiting on the owner"

Scenario: Agreeing plans costs more than the rework it saves
  Given plan-step is live and 5 or 10 planned changes have merged
  When the mean owner minutes a plan exceed 56 less the mean rework minutes of those changes
  Then at 5 a read-only diagnosis says where the minutes went, and at 10 decision 0026 is reported refuted at its revisit and the Undo is proposed
  And the owner is told by pap revisits at the end of the next change

Scenario: Builds are still sent back
  Given plan-step is live and 10 builds of planned changes have reported
  When any of them got a message after its first report
  Then each such message is classified in 0026's Result: a plan gap, a spec gap or a generation error
  And the owner is told by pap revisits at the end of the next change
```

## Areas of concern

- **The measure and its baseline.** The baseline median of commits after open is 0, so "half the baseline or fewer" has no reading as a median. Settled by the owner as a share and a mean (Intent churn).
- **The cost guard is tight.** Mean rework time is 56 minutes a change, and 53% of changes have none. A plan that takes the owner half an hour to agree loses on the intent's own terms even if rework halves. Tokens are reported, not guarded: a plan can cost more tokens than a sent-back build saves.
- **Ten is small.** "Under 10%" of 10 builds passes only at none; one sent-back build fails S2.
- **Every change of the three classes pays.** No lighter path for a small spec: the revisit decides, from S4.
- **Section 7 against a third register.** The owner gives dispositions at plan review too. It is read as item 3 widened, not a seventh step; the planner's one answer and the proposed dispositions are there to keep it short.
- **A hard gate that fails closed.** Rule 20.2 lets the owner overrule a route; the gate has no overrule but a solo session, and it refuses what it cannot read. That is the intent's answer, and it makes H1 the signal to watch.
- **A spec rework voids the plan's yes.** Safer, and a second yes each time; H3 counts how often.
- **Design on paper.** A plan names types and functions before any exist. It will be wrong in places; the deviation report, not the gate, is what absorbs that.

## Open questions

- Who drafts the plan: answered, a planner sub-agent in the background, which writes nothing; the main session writes the file and the owner says yes.
- Is the plan a hard gate: answered, yes, at `/pap:pm launch`, for the three classes.
- Is `test-plan.md` its own file or a section: answered, a section, Tests. One file, one yes, inside the two pages.
- Which review viewpoints, and where they live: answered, conformance, design and verification, plus security for security-sensitive; one `pap:plan-reviewer` agent in the pap plugin. They read code, which the spec-review board by construction does not, so nothing is placed in spec-review and its version does not move.
- Does the plan replace most of the PM's brief: answered, yes for a build. The brief keeps its route, its rule 20.2 line, its budget and what done looks like; the how is the plan's.
- The plan's exact sections: answered, Increments, Design, Fit, Tests, Observation.

## Intent churn

Counting the baseline showed the first success measure could not be read as written: the median of commits after open is already 0. On the owner's word it now reads as a share and a mean, with the baseline figures: `intent(plan-step): churn, the baseline median is 0`.
