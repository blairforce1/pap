---
name: envision
description: "Interview the human to produce the product layer for a new or existing software project: vision.md, invariants.md (with ADR stubs and protected paths), backlog.md (hypothesis backlog), and a conventions.md skeleton, then recommend the first vertical slice. Use this whenever someone wants to start a new project, product, system, or repo, says \"kick off\", \"set up the product layer\", \"write the vision\", \"define invariants\", \"what should we build first\", or invokes /envision, even if they have not mentioned the process by name. Also use it when a product/ folder is missing or incomplete before any intent.md is written."
---

# Envision

Produce the product layer that every later change traces back to. The human knows the product; you know what the artefacts need to contain. Your job is to get the first out of their head and into the second without letting them skip the hard parts.

## Stance

You are the interviewer, not the scribe. The human will want to start listing features. Don't let them. A vision written as a feature list is a backlog with ambitions, and it will be wrong by month two. Every question below exists because agents downstream will generate specs from these files; anything vague here becomes a faithfully built wrong thing later.

Rules that hold throughout:

- **One question at a time.** Ask, wait, follow up. Batching questions gets shallow answers to all of them.
- **Push back on vagueness the first time, not the third.** "Users should find it easy" is not an outcome. Ask what they would observe if it were true.
- **Never invent an invariant.** Every constraint in `invariants.md` must be stated or explicitly confirmed by the human. Offer candidates from the categories below, but mark anything unconfirmed as an open question, not a constraint.
- **Separate known from assumed.** When the human hedges ("probably", "I think", "we'll need something like"), record it as an assumption to be tested, not a fact.
- **Short answers are fine.** A one-line vision statement that is precise beats three paragraphs that are not. Do not pad.
- **If they say "just write it", ask the minimum three** (problem, who has it, what done-enough looks like) before drafting anything, then draft and mark every gap as an open question.

## Before starting

Check for an existing `product/` folder. If files exist, read them and run the interview as a review: confirm what's there, probe what's missing, and edit rather than overwrite. Tell the human what you found before asking anything.

If the repository already contains code, skim its structure first (top-level layout, main dependencies, any existing ADRs or architecture docs). Use what you find to propose candidate invariants rather than asking cold.

## Part 1: Vision

Work through the five areas in order. Each has the question to ask, what a good answer looks like, and the follow-up to use when the answer is weak.

### 1.1 The problem and who has it

Ask: what can someone not do today, and who is that someone?

Good: a named role or person, a concrete situation, and a cost they currently pay (time, money, risk, frustration).
Weak: "users", "businesses", "people who need X". Follow up: describe one specific person on a specific day hitting this problem. What do they do instead?

### 1.2 What "done enough to matter" looks like

Ask: if this works, what changes for that person? What would they stop doing, start doing, or do differently?

Good: an observable change in behaviour or outcome, ideally with a rough magnitude.
Weak: a description of the product ("they'll have a dashboard"). Follow up: and then what? What does the dashboard let them do that they couldn't before?

### 1.3 Non-goals

Ask: what will people expect this to do that it deliberately will not?

Good: three to five specific exclusions, each with a one-line reason.
Weak: none, or "we'll see". Follow up: name the nearest existing product or approach. What does it do that you are choosing not to?

Non-goals are the most valuable section for downstream agents, because they prevent scope creep in generated specs. Don't accept an empty list.

### 1.4 How success is recognised at product level

Ask: six months in, what would you look at to decide whether to keep going?

Good: one or two signals that can actually be observed, with a rough threshold.
Weak: revenue or adoption with no number, or "if people like it". Follow up: what number, from where, would make you stop?

### 1.5 Constraints on the whole effort

Ask: what limits the shape of this before any design decision? Budget, timeline, team, regulation, existing systems it must live alongside, technology the human is committed to.

Record these separately from invariants. Constraints are about the effort; invariants are about the system.

Draft `vision.md` from these five answers using the template in `references/templates.md`. Keep it to one page. Show it and ask for corrections before moving on.

## Part 2: Invariants

Invariants are the constraints no change may violate. They are what let an agent generate a spec for the fortieth feature that is consistent with the third without the whole system being re-explained. They are also the checklist spec review runs against.

Walk the categories below. For each, ask whether there is a constraint the human already knows. Propose candidates based on what you learned in Part 1 and from the codebase, but label them as proposals. Confirmed constraints go in `invariants.md`; unconfirmed ones go under "Open questions".

| Category                 | Ask about                                                   | Typical invariants                                                                                                                        |
| ------------------------ | ----------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| Architectural boundaries | Modules, services, tenants, trust zones                     | "Tenant data never crosses a tenant boundary in process memory"; "The core domain has no dependency on infrastructure packages"           |
| Security posture         | Authentication, authorisation, secrets, data classification | "All external access goes through the authorisation server; no service issues its own tokens"; "Secrets are never in configuration files" |
| Compliance               | Regulations, audit, retention, evidence                     | "Every valuation run is reproducible from committed inputs"; "Audit records are append-only"                                              |
| Data model               | Load-bearing decisions that would be expensive to reverse   | "Money is stored as integer minor units"; "Every entity carries a tenant id"                                                              |
| Operational              | Deployment model, observability minimums, rollback          | "Every service exposes health and readiness"; "No deploy without a rollback path"                                                         |
| Protected paths          | Files no agent may change without a recorded human approval | Migrations, infrastructure definitions, test suites, `product/`, the conventions file                                                     |

For each confirmed invariant capture three things: the constraint in one sentence, the reason in one sentence, and whether an ADR exists or needs writing. Create ADR stubs for the ones that need writing; do not write full ADRs now.

Aim for five to twelve invariants. Fewer than five and the human probably hasn't thought about the system yet; more than fifteen and they are writing a design document. If they are, ask which ones would actually be expensive to violate, and demote the rest to conventions.

Protected paths are mandatory. If the human has no view, propose the default set (migrations, infra, tests, `product/`) and ask them to confirm or trim.

## Part 3: Hypothesis backlog

Now the features. Each one is rewritten as a hypothesis:

> We believe **[change]** will produce **[outcome]**, measured by **[observable signal]**.

Take whatever list the human offers and convert it. For each, the outcome must connect to 1.2 or 1.4, and the signal must be something observable after release. If a feature has no outcome the human can name, ask why it's on the list. Some will drop out. That's the point.

Order by value and risk, not by ease. Ask the human to rank the top five; leave the rest unranked.

Aim for three to ten hypotheses. This is a seed, not a roadmap.

## Part 4: The first slice

Identify the riskiest invariant: the one that, if it turns out to be wrong or unachievable, invalidates the most downstream work. Ask the human to confirm or override.

Recommend a first change that is a thin vertical slice exercising that invariant end to end, deployed, with a test that proves the invariant holds. Not the easiest change and not the most valuable feature; the one that retires the most risk.

Write this as the first entry in the backlog, marked as the recommended starting point, with a note explaining which invariant it tests.

## Part 5: Conventions skeleton

Create `conventions.md` with headings only, plus anything the codebase already makes obvious (build and test commands, language and framework versions). Do not fill in conventions the human hasn't stated. This file grows from reviews; its job now is to exist.

## Output

Write to `product/`:

- `vision.md`
- `invariants.md` (with an "Open questions" section for unconfirmed candidates)
- `decisions/ADR-NNNN-<slug>.md` stubs for invariants that need one
- `backlog.md` (with the first slice marked)
- `conventions.md` (skeleton)

Templates for all five are in `references/templates.md`. Read that file before writing.

After writing, summarise in a few lines: how many invariants were confirmed vs open, how many hypotheses survived conversion, and what the first slice is. Then stop. Do not start writing an `intent.md`; that is a separate step the human initiates.

## What not to do

- Do not produce a feature list dressed as a vision.
- Do not write invariants the human did not confirm.
- Do not write full ADRs; stubs only.
- Do not fill in conventions from your own preferences.
- Do not propose architecture. If the human starts designing, note the decision as a candidate invariant and move on.
- Do not exceed one page for `vision.md`.
