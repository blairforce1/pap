# Product layer templates

Use these exactly. Keep the section order. Remove nothing; write "None yet" rather than deleting a heading.

---

## vision.md

```markdown
# Vision: <product name>

Status: draft | agreed
Last reviewed: <date>

## Problem

<Who cannot do what today, and what it costs them. One or two paragraphs. Name the role or person.>

## Done enough to matter

<What changes for that person when this works. Observable behaviour or outcome, with rough magnitude where known.>

## Non-goals

- <Exclusion>: <one-line reason>
- <Exclusion>: <one-line reason>
- <Exclusion>: <one-line reason>

## How we will know

<One or two product-level signals, each with where it is observed and a rough threshold that would change a decision.>

## Constraints on the effort

- <Budget, timeline, team, regulation, existing systems, committed technology. One line each.>

## Assumptions to test

- <Anything the human hedged on. Each should map to a backlog hypothesis or an open question in invariants.md.>
```

---

## invariants.md

```markdown
# Invariants: <product name>

Constraints no change may violate. Spec review checks every change against the invariants its intent declares it touches. Each entry: the constraint, the reason, and the ADR that established it.

Last reviewed: <date>

## Architectural boundaries

- **INV-001** <Constraint in one sentence.>
  Reason: <one sentence>. ADR: decisions/ADR-0001-<slug>.md

## Security posture

- **INV-00N** ...

## Compliance

- **INV-00N** ...

## Data model

- **INV-00N** ...

## Operational

- **INV-00N** ...

## Protected paths

No agent may change these without a human approval recorded on the change.

- `migrations/**`
- `infra/**`
- `**/*.test.*` and `tests/**`
- `product/**`
- `CLAUDE.md`, `REVIEW.md`, `.claude/**`

## Open questions

Candidate invariants not yet confirmed. Each becomes an invariant, a convention, or is dropped.

- <Candidate>: <why it was raised, what would settle it>
```

Number invariants sequentially across all categories. Never reuse a number after removing an invariant; mark it retired instead.

---

## decisions/ADR-NNNN-<slug>.md (stub)

```markdown
# ADR-NNNN: <title>

Status: proposed
Date: <date>
Establishes: INV-00N

## Context

<To be written. One or two lines on why this decision is needed.>

## Decision

<To be written.>

## Consequences

<To be written.>
```

Stubs stay at `proposed` until the human writes them, usually after the first slice proves or disproves the invariant.

---

## backlog.md

```markdown
# Backlog: <product name>

Hypotheses, not features. Ordered by value and risk. Rewritten when findings come back.

Last reviewed: <date>

## Recommended first slice

**H-001** We believe <change> will produce <outcome>, measured by <signal>.
Tests invariant: INV-00N (<why this is the riskiest>).
Class: <task class>

## Ranked

**H-002** We believe <change> will produce <outcome>, measured by <signal>.
Related: vision §<section>. Class: <task class>

**H-003** ...

## Unranked

**H-00N** ...

## Dropped

- <Original feature idea>: <why it had no outcome the human could name>
```

Keep dropped items. They stop the same idea returning under a new name.

---

## conventions.md (skeleton)

```markdown
# Conventions: <product name>

What a new engineer needs on day one. Agents read this at the start of every session. Changes are reviewed like code. When a review catches the same class of mistake for the second time, the correction goes here as part of that review.

## Commands

- Build:
- Test:
- Lint:

## Stack

<Language, framework, versions. Only what is confirmed.>

## Architecture in one paragraph

None yet.

## Conventions that differ from tool defaults

None yet.

## Mistakes we have seen more than once

None yet.
```

Do not fill "None yet" sections with guesses. They fill from reviews.
