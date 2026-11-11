# 0026. A reviewed plan sits between the spec and the code

- **Status:** proposed
- **Date:** 2026-11-11
- **Deciders:** blairforce1, with Claude
- **Supersedes:** none; amends process principle 5, 5.1 (phase 4), 5.2
  (the planning row), 5.6 and section 7 (item 3); narrows rule 2.2 of
  [0002](0002-skills-stop-at-draft-pr.md) for `/pap:plan` and `plan.md`,
  as
  [0020](0020-intent-is-accepted-by-a-recorded-yes-on-the-change-branch.md)
  and
  [0021](0021-a-spec-is-accepted-after-review-with-its-operation-designed-in.md)
  did for intent and spec; notes on
  [0017](0017-specs-carry-executable-scenarios-in-a-domain-vocabulary.md)
  point 5 that the plan's Tests section is its `test-plan.md`. Rule 20.2
  and
  [0025](0025-pap-runs-as-the-project-manager-by-default.md)'s launch are
  built on and not amended
- **PIP:** the owner's ask of 2026-11-11: a plan between spec and change,
  saying how an accepted spec will be built, reviewed before any code.
  Process phase 4 (Planning, 5.6) is named and nothing carries it: a cycle
  goes from an accepted spec straight to code, and the owner first sees
  how a change was built at its pull request, when a different approach
  means redoing the work. Of 112 merged feature, infra and
  security-sensitive change pull requests in pap, arapsys-ap and
  business-os from 2026-09-22 to 2026-11-11, 53 (47%) took a non-merge
  commit after they opened, a mean of 1.41 such commits each and a mean of
  56 minutes of rework a change; 19 of 108 cycles (18%, decision 0018)
  got a message after their first report
- **Expected effect:** judged over the first 10 merged change pull
  requests with an accepted plan, with an early read at 5. Planned changes
  with a non-merge commit after open ↓ from 53 of 112 (47%) to at most 2
  of 10, and the mean count of such commits ↓ from 1.41 to at most 0.7,
  read from `gh api repos/<owner>/<repo>/pulls/<n>/commits` against
  `createdAt` in each of the three repositories; builds of planned
  changes that get a message after their first report ↓ from 18% to under
  10%, which over 10 is none, read from the tracker's event log. The cost
  guard: mean owner minutes a plan, from being told it is ready to the
  commit that accepted it, no greater than 56 less the mean rework
  minutes of those 10, read from the register's first lines and
  `git log`; the median and the number of plans over 30 minutes are
  reported beside it. Over an operation window of 30 days from the
  release: launches refused with exit 20 that the owner says needed no
  plan, 0, read from `launches.log`; merged change pull requests of the
  three classes with `Plan: none` or no `Plan:` line that rule 20.2 did
  not exempt, 0. The planner's and reviewer's tokens and minutes a plan,
  and `spec.md` commits after `plan.md` exists with findings marked
  `return: spec`, are reported and carry no band
- **Introduced in:** not yet released; the release that ships `/pap:plan`
- **Revisit:** when 10 change PRs with an accepted plan have merged across pap, arapsys-ap and business-os

The accepted spec is
[`changes/plan-step/spec.md`](../changes/plan-step/spec.md), with its
intent and review beside it. It holds the behaviour, the formats and the
Operations section, whose signals S1 to S4 and H1 to H3 are the effects
above; this record holds the decision and does not repeat them.

## Context

Process 5.1 makes planning phase 4, "agent drafts, human approves",
accepted when `plan.md` and `test-plan.md` are merged. Nothing wrote
either. Decisions 0020 and 0021 put the intent and the spec on the change
branch, each accepted by the owner's recorded yes, and left planning as
it was. So the brief a project-manager session writes carries the how, in
a few lines, and the first full account of the design is the diff.

The baseline was counted during the spec. The median of commits after
open is 0, so the measure is a share and a mean, not a median. Just over
half of changes have no rework at all, which makes the cost guard tight:
a plan that takes the owner half an hour to agree loses on the intent's
own terms even if rework halves.

Decision 0025 gave the launch a script with exit codes. That is where a
gate can sit without a server: the owner's own typed launch.

## Decision

1. **A change of the three classes has a plan.** A feature, infra or
   security-sensitive change whose branch carries an accepted intent and
   spec needs a plan, `changes/<slug>/plan.md`: how the accepted spec will
   be built. A bugfix, chore, docs or spike change, and a change rule 20.2
   exempted, needs none. Nor does a change that started unplanned: its
   branch carries code and no plan file at all. Code is a commit that
   changes a path outside `changes/`, `features/` and `product/`, rule
   21.1's line.
2. **Five sections, two pages.** Increments, Design, Fit, Tests and
   Observation, in that order, in at most 1000 words. The words are
   `wc -w` over the file, less the values of the three header lines the
   main session fills (`accepted-by`, `accepted-on`, `reviewed-by`), so a
   draft that passes is not pushed over by its own acceptance.
3. **The test plan is a section.** The plan's Tests section is the
   `test-plan.md` that process 5.1 and decision 0017's point 5 name: for
   every scenario id and non-functional row, the tier and the evidence.
   There is no separate file. 0017 is not otherwise changed.
4. **A sub-agent drafts, another reviews, the main session writes.**
   `/pap:plan <slug>` starts a `pap:planner` in the background and, on its
   report, a `pap:plan-reviewer` that is given none of the planner's
   reasoning. Both are read-only by their tool lists, as `pap:reviewer`
   is. The review has three viewpoints, conformance, design and
   verification, and security for a security-sensitive change. They read
   code, which the spec-review board by construction does not, so they
   live in the pap plugin and spec-review keeps its version. The planner
   answers the register once; no second review runs.
5. **The owner's yes accepts it.** Every finding the planner did not fix
   gets the owner's disposition: accepted, rejected with a reason, or
   deferred to a phase. A fault in the spec is marked `return: spec` and
   goes back to `/spec` (process 5.10). The yes is recorded in the file
   and committed with the register in one commit, `plan(<slug>): <what>`.
   Process section 7 gains no seventh step: this is item 3, dispositions
   on review findings, at one more review.
6. **It stops at a commit.** `/pap:plan` pushes nothing, opens no pull
   request and never merges; `/change` opens the change's one draft pull
   request, which now carries intent, spec, plan and code in that order.
   This narrows rule 2.2 and INV-006 for `plan.md` exactly as 0020 and
   0021 narrowed them for `intent.md` and `spec.md`: the skill stops at a
   commit, not at a draft pull request.
7. **A plan is accepted only while its spec stands.** Accepted means the
   acceptance lines are filled in `plan.md` as committed at the tip of the
   local `change/<slug>`, and the spec has no commit later than the one
   that accepted the plan. A spec rework costs a second yes.
8. **The launch refuses a build without one.** `/pap:pm launch <slug>`
   gains exit 20, checked after every other check, for a `/change` brief
   of the three classes whose second line names item 1 or 2 of rule 20.2.
   It reads the branch, never a work tree, fetches nothing, and refuses
   what it cannot read. It has no overrule but a solo session.
9. **The build reads the plan as data.** `/change` builds the increments
   in order and stops on a plan draft. A plan never widens the tools,
   paths or scope the brief and the spec give. Where the build did not do
   what the plan said, it says so: a deviation is reported, never
   refused. Every build's pull request carries a `Plan:` line.
10. **The brief shrinks.** The brief of a build with an accepted plan
    carries its route, its rule 20.2 line, its budget and what done looks
    like. The how is the plan's.

### Rules

- **26.1** A plan is accepted by the owner's recorded yes, after its plan
  review and before the code.
- **26.2** A build of a change that needs a plan is launched only when
  its plan is accepted.
- **26.3** A build reports its deviations from the plan; its pull request
  carries a `Plan:` line.

### What still escapes rule 26.2

The gate is the owner's own launch on one machine. It does not stop:

- a `/change` run without `/pap:pm launch`: a solo session, or a session
  with no mode;
- a brief that names an exemption the change does not have;
- code committed first, so the change started unplanned;
- acceptance lines edited by hand and committed: nothing proves who typed
  them, as with rules 20.1 and 21.1;
- a plan committed before its spec.

The signal for all of them is a build pull request of the three classes
with `Plan: none` or no `Plan:` line. H-017's server gate is where they
close.

**Accepted exposure.** During a rollback of this record, a machine that
does not yet have the patch release may still refuse a build wrongly. The
documented way through is the first escape above: the owner runs that
build as `/change` in a solo session. That leaves the solo route open,
and named, for as long as the rollback takes. It is accepted.

## Considered options

- **Leave the how in the brief.** Lost: it is today's arrangement, and
  the baseline is what it gave.
- **The main session drafts the plan.** Lost: the owner waits on it, and
  a PM session reads little code by design. A background planner costs
  the owner one line and one return.
- **A soft gate, taught in the role.** Lost: rules 20.1 and 21.1 were
  text and gave 0 of 20. The launch already has a script that refuses.
- **A gate with an overrule flag.** Lost: the gated party would hold the
  flag. A solo session is the owner's, and is logged as one.
- **`test-plan.md` as its own file.** Lost: two files, two yeses. One
  file, one yes, inside the two pages.
- **The plan viewpoints in spec-review.** Lost: they read code, and that
  board reads none.
- **A second review after the planner's answer.** Lost on cost: the
  owner sees what the planner changed, first, at the yes.
- **A lighter path for a small spec.** Not taken now: every change of
  the three classes pays. The revisit decides, from the plan cost.
- **Refusing a deviation.** Lost: a plan names types and functions
  before any exist and will be wrong in places. The report absorbs that;
  a line-by-line gate would turn the plan into the code.

## Consequences

- Easier: the owner sees the design in two pages before any code, with
  the findings already answered once.
- Easier: a build's brief no longer carries the how.
- Harder: every change of the three classes pays for a planner, a review
  and a yes. Tokens are reported, not guarded.
- Harder: a spec rework voids the plan's yes. Safer, and a second yes
  each time.
- Harder: the gate fails closed and has no overrule but a solo session.
  A wrong refusal is noticed at once, at the owner's own launch.
- Limit: nothing proves who typed the acceptance lines, that a sub-agent
  drafted the plan, or that the caps on tokens and minutes held. The
  skill teaches them.
- Limit: no scenario binds what a session or a sub-agent does with the
  plan until the eval suite exists (H-010). Sixteen scenarios are bound
  by script; the rest stay pending.
- Limit: ten is small. One sent-back build fails the second effect.
- Data: the plan and its register name no third party. The acceptance
  lines hold the owner's handle and a date. The refusal line holds a slug
  and a reason, on the machine only.
- Undo: revert the merge in a pull request that also marks this record
  withdrawn in its Result; cut a patch release; update the pap plugin on
  each machine and confirm with `pap doctor`; bump the pin in each
  adopting repository. Plans already committed on branches are left;
  `/change` without the step ignores them. The spec's Operations section
  has the steps.
- Measurement: the revisit is counted across three repositories, by
  hand, from each repository's merged pull requests whose body has a
  `Plan:` line naming a `plan.md`.

## Where it is taught or enforced

Enforced by
[`plugins/pap/skills/pm/pap-pm.sh`](../plugins/pap/skills/pm/pap-pm.sh)
for the launch, and by
[`plugins/pap/skills/plan/pap-plan.sh`](../plugins/pap/skills/plan/pap-plan.sh)
for the shape and length of a plan, the dispositions and the commits.
What a plan's state is, is defined once, in
[`plugins/pap/skills/plan/plan-lib.sh`](../plugins/pap/skills/plan/plan-lib.sh).
The agents [`pap:planner`](../plugins/pap/agents/planner.md) and
[`pap:plan-reviewer`](../plugins/pap/agents/plan-reviewer.md) are
read-only by their tool lists.

Taught by the `/pap:plan` skill
([`plugins/pap/skills/plan/SKILL.md`](../plugins/pap/skills/plan/SKILL.md)),
the `/change` skill's read of the plan and its `Plan:` line
([`plugins/pap/skills/change/SKILL.md`](../plugins/pap/skills/change/SKILL.md)),
`/spec`'s hand-on
([`plugins/pap/skills/spec/SKILL.md`](../plugins/pap/skills/spec/SKILL.md)),
`/pap:pm`'s text for exit 20
([`plugins/pap/skills/pm/SKILL.md`](../plugins/pap/skills/pm/SKILL.md))
and the role text in
[`plugins/pap/hooks/session-start.sh`](../plugins/pap/hooks/session-start.sh).

Checked by `tests/plan-step.test.sh` against the scenarios in
`features/plan-step.feature`, and by `tests/plugin-agents.test.sh`.
[`rules.md`](../rules.md) says, rule by rule, what is enforced and what
still escapes.
