# Spec template

Use it in this order. Keep the headings the class requires (SKILL.md, step 3) and drop the rest; inside a kept section, write "none" rather than removing a line. A feature spec runs to two pages; docs and chore to half of one.

## `changes/<slug>/spec.md`

````markdown
# Spec: <slug>

```text
id:                 <slug>
class:              <from intent.md>
intent:             changes/<slug>/intent.md
scenarios:          features/<slug>.feature, <slug>-1 to <slug>-<n> | none
accepted-by:        @<login>
accepted-on:        <YYYY-MM-DD>
generated-by:       <model and version> via Claude Code
skills:             pap:spec <plugin version>; spec-review <plugin version>
prompt:             /spec <slug>
```

## Functional behaviour

<The shape of the behaviour in a paragraph: what a user or operator does and sees, inside the intent's desired outcome and outside its non-goals.>

Scenarios added or changed, in `features/<slug>.feature`:

- `<slug>-1` <scenario title>: <why this one, in a line>.
- `<slug>-2` ...

Terms added to `product/domain.md`: <term, term | none>.

## Non-functional

| What is measured                     | Threshold         | Test tier                                    |
| ------------------------------------ | ----------------- | -------------------------------------------- |
| <latency, capacity, availability...> | <number and unit> | <unit, integration, acceptance, performance> |

## Security

<Authn, authz, secrets, data handling this change touches, and the invariant each follows. Only where the class or the intent asks.>

## Compliance

<The obligation and how the design meets it. security-sensitive only, or where the intent names one.>

## Data

<Model changes, migration and its reverse, retention. Only where touched.>

## Interfaces and contracts

<What this change exposes or consumes, and what it must not break. Only where touched.>

## Operations

**Signals.** For each success measure in the intent, and each health signal this change could move:

| Signal | Measures                                                | Read from                    |
| ------ | ------------------------------------------------------- | ---------------------------- |
| <name> | <the intent's success measure, or the health it guards> | <log, metric, query, report> |

**Good.** The control band per signal: `<signal> within <band> over <window>`, inside an operation window of <n> days.

**Wrong.** <What a breach looks like.> Noticed within <time>, from <where the signal lands>. First checks:

1. <command or query>
2. <...>
3. <...>

**Undo.** <Revert the merge | feature flag `<name>` off | config rollback to <version>.> Outside git: <steps in order, or none>. This text is the pull request's "How to revert".

**Operational scenarios.**

```gherkin
Scenario: <signal> breaches its band
  Given <slug> is live
  When <signal> is <outside band> over <window>
  Then <undo, or the 5.9 tier's response>
  And the human is told <where>
```

## Areas of concern

- <Where the intent, an invariant and a convention pull apart, one line each; the review starts here. | none>

## Open questions

- <Question from intent>: answered, <answer>. | still open: <who>, <phase>.

## Intent churn

<What drafting the spec showed the intent had missed, and the churn commit that fixed it. | none>
````

## `features/<slug>.feature`

Gherkin, one `Feature` per change, every scenario tagged with its id and `@pending:<slug>` until a test binds it (decision 0017, rule 17.1). Words from `product/domain.md`.

```gherkin
Feature: <what the change lets someone do, in the domain's words>

  @id:<slug>-1 @pending:<slug>
  Scenario: <one behaviour, as its title>
    Given <a state, named as domain.md names it>
    When <one event>
    Then <what is observed>
```

## `product/domain.md`

The shared vocabulary of the product layer (decision 0017). Start it with this skeleton when the repository has none; otherwise add under the existing headings, naming the spec that added each line.

```markdown
# Domain: <product>

The words every spec and scenario uses. A term is defined once; a state and an event belong to a term. Added by the spec that first needed it, in the same diff (decision 0017).

## Terms

- **<Term>**: <definition in one line>. States: <state>, <state>. (spec: <slug>)

## Events

- **<Event>**: <what happens, to which term, moving it from <state> to <state>>. (spec: <slug>)

## Rules

- <A rule between terms, in a line.> (spec: <slug>)
```

## `changes/<slug>/reviews/spec-review.md`

The register as `spec-review-full` returned it, with its perspectives and verdicts stated, then the human's dispositions filled in: `accepted`, `rejected: <reason>` or `deferred: <phase>`. Add one line at the top: `Reviewed <YYYY-MM-DD> against spec.md at <short sha or "draft">; dispositions by @<login>.`
