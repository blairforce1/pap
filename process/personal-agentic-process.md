# Personal Agentic Process

A lightweight process for building software with AI agents, structured so that every increment is small, testable, and traceable back to a stated direction, and so that the process itself can be measured and improved over time.

This document describes what must happen. It does not prescribe tools.

---

## 1. Principles <!-- id: S-principles -->

1. **Intent is the human artefact.** Humans write intent and judge results. Agents generate specifications, plans, code, and tests from intent. The quality of intent is the main lever on the quality of everything downstream. <!-- id: P-intent -->
2. **Proportional ceremony.** The amount of specification, review, and testing is set by the class of change, not applied uniformly. A typo fix and a security-sensitive feature do not get the same treatment. <!-- id: P-ceremony -->
3. **Small, shippable increments.** Every change must be independently deployable and have a success measure that can be observed after release. If a success measure cannot be written, the change is too large or too vague. <!-- id: P-increments -->
4. **Direction is preserved by invariants, not by re-reading the vision.** Constraints that must not be violated are written down, kept short, and checked at review. <!-- id: P-invariants -->
5. **Acceptance is recorded, and the record is a trigger.** Each phase ends by committing an artefact. Accepting that artefact is what starts the next phase: for intent, spec and plan, the human's yes recorded in the file on the change branch; for the rest, the merge or the closed review. Nothing starts because someone remembered to start it. <!-- id: P-merge-trigger -->
6. **Every generated artefact records what produced it.** Model, skill or policy versions, and the prompt or command that produced a spec, plan, or review are recorded with it. Without this, no change to the process can be attributed to an outcome. <!-- id: P-provenance -->
7. **Going backwards is normal and is recorded.** When work returns to an earlier phase, the return and its reason are noted. Returns are the raw material for improvement. <!-- id: P-returns -->
8. **Every escaped defect is attributed to a phase.** Not "we had a bug" but "the specification omitted a failure mode" or "the test plan did not cover this path". Attribution is what turns defects into process changes. <!-- id: P-attribution -->
9. **Verification is part of done, and cannot be weakened by the thing it verifies.** An agent reports a task complete only after running the checks and showing the output. An agent fixing code may not modify the tests that check that code without human approval. <!-- id: P-verification -->
10. **Process changes are experiments.** Any change to how you work is written down before it starts, with the outcome it is expected to move, and is regression-tested against a suite of known tasks before it goes live. One change at a time per class of work. <!-- id: P-experiments -->
11. **Gates are automated, not remembered.** Approvals that must survive (protected paths, release authorisation, protected tests) are enforced by a check that runs every time and logs its verdict. <!-- id: P-gates -->
12. **Overhead must shrink.** As calibration improves in a class of work, the process should demand less there. A process whose cost never declines is a tax. <!-- id: P-overhead -->

---

## 2. Structure <!-- id: S-structure -->

Three layers, each changing at a different pace.

| Layer | Pace | Contents |
|---|---|---|
| Product | Changes rarely | Vision, invariants, hypothesis backlog, conventions |
| Change | One per increment | Intent, spec, plan, build, verify, operate, findings |
| Improvement | Continuous | Interventions, eval suite, weekly review, monthly retrospective |

Each layer feeds the one above it: findings from changes revise the backlog, invariants, and conventions; observations across changes drive interventions; escapes become evals.

---

## 3. Product layer <!-- id: S-product -->

Lives in a `product/` folder (per product if a repository holds several). Four artefacts.

### 3.1 `vision.md` (one page, outcomes not features) <!-- id: S-vision -->

- The problem and who has it
- What "done enough to matter" looks like
- Non-goals
- How success will be recognised at product level

A feature list does not belong here.

### 3.2 `invariants.md` plus Architecture Decision Records <!-- id: S-invariants -->

The constraints no change may violate:

- Architectural boundaries (module, service, tenant, trust)
- Security posture (authn/authz model, data handling, secrets)
- Compliance obligations
- Load-bearing data model decisions
- Operational constraints (deployment model, observability minimums)
- **Protected paths**: files or directories (migrations, infrastructure, test suites, the conventions file) that no agent may change without an explicit human approval recorded on the change

Keep it short. Each entry references the ADR that established it. This is the artefact that lets an agent produce a specification for the fortieth feature that is consistent with the third without the whole system being re-explained.

### 3.3 `backlog.md` (hypothesis backlog) <!-- id: S-backlog -->

Candidate changes, each phrased as a hypothesis:

> We believe **[change]** will produce **[outcome]**, measured by **[observable signal]**.

Ordered by value and risk, not scheduled. Rewritten when findings come back.

### 3.4 `conventions.md` (institutional memory for agents) <!-- id: S-conventions -->

What a new engineer would need on day one: commands, conventions, architecture summary, and the mistakes seen most often. Agents read it at the start of every session. It is version controlled and changes to it are reviewed like code.

Rule: when a review catches the same class of mistake for the second time, the correction goes into `conventions.md` as part of that review. Reviews also flag when a change has made `conventions.md` stale.

### 3.5 Starting a large system <!-- id: S-large-system -->

Do not start with a full specification. Start with:

1. The vision.
2. The invariants you already know.
3. The first vertical slice that exercises the riskiest invariant end to end.

Riskiest, not easiest. Write the ADRs after the slice works, so they record what is true rather than what was hoped.

---

## 4. Task classes <!-- id: S-classes -->

Every change declares a class at intent time. The class determines mandatory reviews, test tiers, and the operation window. Define the matrix once and revise it rarely.

Suggested starting set:

| Class | Typical example | Notes |
|---|---|---|
| feature | New user-facing capability | Full spec, review per touched invariants |
| infra | Pipeline, platform, deployment change | Reliability and ops review mandatory; touches protected paths by definition |
| security-sensitive | Anything touching authn, authz, secrets, PII | Full reviewer set, acceptance tests mandatory |
| bugfix | Correcting a defect | Light spec; must cite the escaped defect it closes; must add an eval |
| spike | Time-boxed learning, throwaway | Intent and findings only; no spec, no deploy |
| docs | Documentation only | Intent, a half-page spec and human review; no spec review board |

A matrix should state, per class:

- Mandatory reviewer perspectives for the spec (from: security, reliability, operations, QA, UX, cost, performance, compliance)
- Mandatory code review passes (from: bugs, security, conformance to spec and plan, design principles)
- Mandatory test tiers (from: unit, integration, acceptance, performance)
- Operation window (how long after release a defect still counts against this change; default 30 days)

---

## 5. Change layer <!-- id: S-change -->

Each change gets an identifier at intent time and a folder `changes/<id>/` holding its artefacts. The folder's history is the record of the change. Every artefact generated by an agent carries provenance in its frontmatter:

```
generated-by:      # model and version
skills:            # reviewer skill / policy versions in force
prompt:            # the prompt or command that produced it
```

### 5.1 Phases <!-- id: S-phases -->

| # | Phase | Artefact | Accepted when (this is the trigger for the next phase) | Owner |
|---|---|---|---|---|
| 1 | Intent | `intent.md` | The human's yes to the intent, restated in 5.3's sections, recorded in the file (who, when): class declared, hypothesis linked, success measure written, invariants touched listed. Committed on the change branch before the spec; the change's one pull request carries intent, spec and code in that order | Human |
| 2 | Specification | `spec.md` | The human's yes after spec review, recorded in the file (who, when): covers the sections the class requires, with acceptance scenarios where the class asks for them (5.4); every open question from intent is answered or explicitly carried forward; a feature, infra or security-sensitive change says how it is monitored and undone (5.4, Operations). Committed on the change branch after the intent and before the code | Agent drafts, human edits |
| 3 | Spec review | `reviews/` | Every finding has a disposition (accepted, rejected, deferred), recorded with the spec on the change branch; the human's approval is the spec's recorded yes (phase 2) | Reviewers + human |
| 4 | Planning | `plan.md` | The human's yes after plan review, recorded in the file (who, when): every plan review finding is fixed or has a disposition, and the increments and test tiers match the class matrix (5.6). Committed on the change branch after the spec and before the code. Feature, infra and security-sensitive changes only | Agent drafts, human approves |
| 5 | Generation | Code, tests, design notes | All planned increments implemented with their tests | Agent |
| 6 | Self-check | CI results, agent self-review | Build green, tests pass, agent has run the checks and shown the output, and reviewed its own diff against spec | Automated |
| 7 | Code review | Review record | All review passes run, findings ranked; human has read the attention plan and approved | Reviewers + human |
| 8 | Verification | Test run records | All mandatory tiers pass in a production-like environment | Automated |
| 9 | Operation | Deployment record, control bands | Released; operation window elapses without a breach attributed to this change | Automated |
| 10 | Findings | `findings.md` | Success measure evaluated; every escape attributed; product-layer impacts flagged; escapes converted to evals | Human |

### 5.2 Per-phase measures <!-- id: S-phase-measures -->

Each phase has one leading and one lagging measure, all derivable from version control, CI, or the incident record.

| Phase | Leading | Lagging |
|---|---|---|
| Intent | Time from first idea to accepted `intent.md` | Survival rate: share of intents accepted rather than closed; intent edits after `spec.md` exists (intent churn) |
| Specification | Time from `intent.md` acceptance to `spec.md` acceptance | `spec.md` commits after `plan.md` or code exists on the branch (spec rework) |
| Spec review | Findings per review, by severity | Escapes later attributed to spec review miss |
| Planning | Time from the spec's yes to the plan's yes | `plan.md` commits after code exists on the branch (plan rework); increments that were split or merged after build started |
| Generation | Sessions per increment; rework share | Escapes attributed to generation |
| Self-check | First-pass CI success rate for agent-written changes | Defects found in code review that self-check should have caught |
| Code review | Time to first review; share of review comments resolved without a human touching the branch | Defects caught before merge vs escaped to production |
| Verification | Time from approval to verified | Escapes attributed to verification gap |
| Operation | Time from breach to a triaged finding | Repeat incidents of the same class |
| Findings | Time from window close to `findings.md` | Share of findings that changed a backlog item, invariant, or convention |

### 5.3 `intent.md` (keep to half a page) <!-- id: S-intent -->

```
id:
class:
product:
source:            # the issue or request it absorbed, or "none"
hypothesis:        # reference into backlog, or "reactive: <reason>"
invariants-touched:
accepted-by:       # who said yes to the intent as restated
accepted-on:       # when

## Problem
## Desired outcome
## Non-goals
## Constraints
## Success measure   # observable after release, within the operation window
## Open questions
```

An intent is accepted when the human says yes to it restated in these sections, and the yes is recorded in the two acceptance lines; the file is then committed on the change branch, before the spec and the code, and the change's pull request carries it to the merge. An edit after the yes keeps the acceptance lines and notes the edit; a change of class or hypothesis is a new yes. Once a spec exists, an edit is intent churn (5.4).

### 5.4 `spec.md` sections <!-- id: S-spec -->

Include only what the class requires. Candidate sections:

- Functional behaviour: prose for the shape, then acceptance scenarios in Given/When/Then, written in the product's domain vocabulary (`product/domain.md`, which the spec extends in the same diff) and kept in `features/` at the repository root so they keep running after the change closes. Mandatory for feature, security-sensitive and bugfix (where one scenario fails before the fix); optional for infra; none for spike, docs and chore
- Non-functional: performance, reliability, availability, capacity; each a row: what is measured, the threshold, the test tier
- Security
- Compliance
- Operations, mandatory for feature, infra and security-sensitive: deployment and configuration; **Signals**, what is measured for each success measure in the intent and for the health the change could move; **Good**, the control band, thresholds and the window they are judged over (5.9); **Wrong**, what a breach looks like, how fast it is noticed and the first checks; **Undo**, revert the merge, a feature flag off or a config rollback, with the steps for anything outside git, which the pull request repeats as its "How to revert"; and operational scenarios in Given/When/Then ("Given it is live, When <signal> breaches <band> over <window>, Then <undo> and the human is told")
- Data: model changes, migration, retention
- Interfaces and contracts
- Areas of concern (flagged by the generating agent, especially where policies conflict)
- Open questions (carried forward from intent, each marked answered or still open)

A spec is accepted when the human says yes to it after spec review (5.5) and the yes is recorded in the file (who, when). It is committed on the change branch after `intent.md` and before any code, and the change's pull request carries it to the merge. Intent edits made after the spec exists are noted as **intent churn**: the spec surfaced something the intent missed. Spec edits after code exists are **spec rework** (5.2).

### 5.5 Spec review <!-- id: S-spec-review -->

Run the reviewer perspectives the class requires (the `spec-review` plugin in this marketplace provides them; `spec-review-full` runs the whole board). Each finding is recorded with reviewer, severity, and the human's disposition, in `reviews/` on the change branch before the spec's yes. Rejected findings need a one-line reason. Work through flagged areas of concern first. Review specifically against the invariants the intent declared it touches.

### 5.6 `plan.md` <!-- id: S-plan -->

The plan says how an accepted spec will be built. A feature, infra or security-sensitive change has one; a bugfix, chore, docs or spike change, and a change exempt from intent, has none. It is at most two pages (1000 words) and has five sections, in this order:

- **Increments**: ordered; each can be built, tested and committed on its own, and names the scenarios of the spec it satisfies.
- **Design**: the types, functions, events and infrastructure added or changed.
- **Fit**: the existing code it touches and the seams it uses, what it leaves alone, how coupling is kept low, the invariants touched, and every protected path the build will touch.
- **Tests**: the test plan. For every scenario and non-functional row of the spec, per tier the class requires, what will be tested and what evidence passes. There is no separate `test-plan.md`.
- **Observation**: for every signal in the spec's Operations, the increment that builds it, and how the change is known to work once merged.

An agent drafts it and another, which did not draft it, reviews it against the spec and the code as it is: conformance, design and verification, and security for a security-sensitive change. Each finding is recorded with its viewpoint, severity and disposition in `reviews/` on the change branch before the plan's yes. The build reads the accepted plan and reports where it deviated; a deviation is reported, never refused.

### 5.7 Generation and self-check <!-- id: S-generation -->

Agents implement increments in sessions. Each session is noted as either first-pass or rework (following a rejection or a return). Self-check means the agent runs the tests and reviews its own diff against the spec before a human sees it. Two or three self-check rounds are normal; the output should improve with each.

Agents fixing code do not edit the tests that check it. If a test is wrong, that is a separate change with human approval.

### 5.8 Code review <!-- id: S-code-review -->

A written review policy (`REVIEW.md` at the repository root) defines:

- The passes to run, each tagged on its findings: bugs and logic errors; security; conformance to `spec.md`, `plan.md`, and design principles; and any class-specific pass
- What "important" means (would break behaviour, leak data, or breach a policy) as opposed to a nit (style, naming)
- A cap on nits per review, with the remainder summarised as a count
- What to skip: generated paths and anything CI already enforces

Findings do not approve or block on their own. The human reviewer receives an attention plan, not a risk score: which parts of the diff carry logic and touch unfamiliar areas, which parts are tests or generated code to skim. Approval is a human action recorded on the change.

When a review catches the same class of mistake for the second time, the correction goes into `conventions.md` as part of that review.

### 5.9 Verification and operation <!-- id: S-verification-operation -->

Mandatory test tiers run in a production-like environment. The change is released. The operation window starts.

During the window, a deterministic monitor (no model in the detection path) watches a small set of metrics against rolling baselines, with rules that catch slow drift as well as spikes. Response is tiered and version controlled:

- Minor deviation: log only
- Moderate deviation: invoke a read-only diagnosis, written up as a finding
- Severe deviation: propose action, but only through the normal review gate or a pre-approved rollback

Anything observed in production that traces back to this change during the window is an escape. Breaches that do not trace to a specific change become new reactive intents.

### 5.10 Returns <!-- id: S-returns -->

At any phase, work may return to an earlier phase. Record: from, to, and the trigger. Guidance on where to return:

| Trigger | Return to |
|---|---|
| Test fails on behaviour the spec does not describe | Specification |
| Reviewer finds a missing requirement | Specification |
| Spec cannot be written without answering a question about purpose | Intent |
| Same failure recurs after two attempts at the same phase | One phase earlier than last time |
| Build fails on something the spec covers | Generation (same phase) |

Oscillation between two phases is a signal to go back further, usually to intent.

### 5.11 `findings.md` <!-- id: S-findings -->

Written at the end of the operation window or on the first escape, whichever is sooner.

```
## Success measure: result
## Defects caught before release   (phase found, phase attributed)
## Defects escaped                  (where surfaced, phase attributed, fix reference, eval added)
## Returns                          (from, to, trigger)
## Product-layer impact             (hypothesis confirmed / refuted / revised; invariant challenged; ADR needed; convention added)
## One thing to change next time
```

Attribution vocabulary for defects: intent gap, specification gap, review miss, plan gap, test-plan gap, generation error, verification gap, operational.

Every escape becomes a permanent eval (see 6.2) before the change is closed.

---

## 6. Improvement layer <!-- id: S-improvement -->

### 6.1 Interventions <!-- id: S-interventions -->

Any change to how you work is an intervention: a new skill, a prompt rule, a review pass, a template change, a conventions edit, a hook, a model upgrade. Before it starts, record:

- Name and start date
- What changed (with the versions it introduces)
- Which task classes it applies to
- The measure expected to move, the direction, and a rough size
- The eval suite result before and after the change
- End date, when it ends

One intervention live at a time per task class. Model upgrades count as interventions whether chosen or not.

### 6.2 Eval suite <!-- id: S-evals -->

A set of real tasks from recent work, each with its expected or accepted outcome and the checks that define acceptable (tests pass, lint clean, behaviour unchanged, policy followed). The suite runs:

- On any change to agent configuration: conventions, skills, review policy, hooks, model
- On a schedule, so drift in the model shows up without a configuration change

A configuration change that drops the pass rate is reviewed before it goes live. Every escaped defect adds a case. Cases that no longer discriminate (every model passes them) are retired.

For a solo practitioner, start the suite from escapes only. Twenty curated tasks is the target, not the starting point.

### 6.3 Measures across changes <!-- id: S-cross-measures -->

Per class and over time, in addition to the per-phase measures in 5.2:

- **Rework share**: effort spent in rework sessions as a fraction of total
- **Returns per change**, and how far back they land
- **Review yield**: defects caught before release vs escaped
- **Escape rate**, with phase attribution
- **Reactive share**: changes with no backlog hypothesis
- **Success measure hit rate**: changes whose stated measure was met
- **Eval pass rate** over time, per configuration version
- **Gate wait time**: time spent waiting on each human approval gate
- **Cost per change** (tokens, wall time), always shown next to escape rate, never alone

### 6.4 Cadence <!-- id: S-cadence -->

- **Weekly**: look at the measures. No decisions unless something is clearly broken.
- **Monthly**: retrospective. Answer three questions: what changed since the last intervention started, did it move what it was expected to move, what is the one intervention for next month. One only. Rate a sample of review findings to tune the review policy and the nit cap.
- **Quarterly**: revisit the task class matrix and reduce ceremony where calibration is good. Retire evals that no longer discriminate.

### 6.5 Drift signals <!-- id: S-drift -->

Three things that suggest the product layer is stale:

- Changes touching invariants without an ADR update
- Escapes repeatedly attributed to the same component or phase
- Backlog order diverging from the order changes are actually started

Any of these prompts a product-layer review.

---

## 7. What a human writes by hand <!-- id: S-manual -->

Everything not listed here should be generated, derived, or automated.

1. Vision, invariants, backlog, and conventions (product layer)
2. `intent.md`, including class and success measure
3. Dispositions on review findings, at spec review, plan review and code review
4. Return records (from, to, trigger)
5. Phase attribution on escapes
6. Intervention pre-registration

If a seventh manual step appears, treat it as a defect in the process.

---

## 8. Minimum viable version <!-- id: S-mvp -->

To test this on a real project, the minimum is:

- `vision.md`, `invariants.md` (including protected paths), `backlog.md`, `conventions.md`
- The task class matrix, even if it is three classes
- Per change: `intent.md`, `spec.md`, one spec review pass, a `REVIEW.md` with two passes (bugs, conformance to spec), `findings.md`
- One intervention, pre-registered, with a measure
- An empty eval suite that grows from the first escape

Plan and test plan can be folded into the spec for the first few changes. The operation monitor can be a single metric with a single band. Add the rest once the change loop is running.
