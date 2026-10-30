# 0017. Specs carry executable scenarios in a domain vocabulary

- **Status:** proposed
- **Date:** 2026-10-30
- **Deciders:** blairforce1, with Claude
- **Supersedes:** none; amends process sections 3, 4, 5.4, 5.6 and 5.10 when its first tooling ships
- **PIP:** the owner's call of 2026-10-27 and 2026-10-30: a spec should carry "executable" tests, Given/When/Then acceptance scenarios and others, that feed Gherkin or a similar runner, with a domain model and vocabulary they map to. Today a spec's functional behaviour is prose, so the code review pass "conformance to `spec.md`" (5.8) is a judgement, and an escape attributed to a "specification gap" (5.11) has nothing concrete to point at
- **Expected effect:** in an adopting repository, `fix:` or `revert:` pull requests merged within 14 days that touch a file a feature, security-sensitive or bugfix change PR changed ↓, against its last 20 such change PRs before the first scenario-carrying change; scenarios edited by a pull request that neither changes a `spec.md` nor carries a `return:spec` label at 0
- **Introduced in:** not yet released; the release that ships `/spec`
- **Revisit:** when 20 change PRs whose spec carries scenarios have merged in an adopting repository: both effects, and the share of scenarios executed rather than only traced

## Context

The spec phase (5.4) lists "Functional behaviour" as a section of prose,
and the test plan (5.6) is a separate file that says what will be tested.
Nothing ties one to the other, or either to the code. Three things follow.

- Conformance to the spec is reviewed by reading, and an agent's
  self-check against the spec (5.7) is the agent's own opinion.
- A test can be rewritten to fit the code, and the spec would not notice.
  Principle 9 and 5.7 forbid it; nothing in the spec makes it visible.
- Each spec invents its own words for the domain. Two specs can describe
  one state under two names, and nothing catches it until the code does.

There is no tooling for intent, spec or findings yet (H-005, H-011); `/change`
goes from a brief to code. This record settles what a spec carries before
`/spec` is written, so the skill is built to it rather than the other way
round.

## Decision

Backlog item H-011 carries the work, built in slices: `product/domain.md`
and `/envision` seeding it; `/spec` with scenarios and the process
amendments below; the binding check (17.1); `pr-checks` for 17.3 and
17.4; the vocabulary pass in `spec-review-qa`; executed runners per
layer. `/spec` reads the `intent.md` that H-005's `/intent` writes, and
17.2 waits for H-005's `/findings`. `/change` stays as it is and reads
the spec.

1. **Scenarios live in a living tree.** Acceptance scenarios are Gherkin
   in `features/` at the repository root, not in the change folder. The
   spec pull request edits that tree, and `spec.md` links the scenarios it
   added or changed and says why. A change's scenarios keep running after
   the change closes; the change folder records what was asked, the tree
   what still holds.
2. **Every scenario is bound or pending.** A scenario carries
   `@id:<slug>-<n>`, the slug of the change that wrote it. It is bound
   when a passing test names that ID. A scenario the spec added before the
   code exists carries `@pending:<slug>` until it is bound. CI fails a
   scenario that is neither bound nor pending, and a change does not close
   (its `findings.md` does not merge) while a scenario carries its
   `@pending`.
3. **Traced everywhere, executed where a layer offers it.** Tracing by ID
   is the floor and works in any language, pap's POSIX shell included.
   Executing the steps is an opt-in per template layer: Reqnroll in the
   dotnet layer, godog in the go layer, each binding steps to code. An
   executed scenario is bound when it passes.
4. **One vocabulary, in the product layer.** `product/domain.md` holds the
   domain's terms, the states an entity can be in, the events, and the
   rules between them. `/envision` seeds it; a spec pull request that uses
   a new term defines it in the same diff. A vocabulary pass in
   `spec-review-qa` checks that each scenario's words are defined there;
   it is a review, not a linter. Splitting the file per bounded context
   waits for a system large enough to need it (3.5).
5. **Scenarios for behaviour, rows for the rest.** Given/When/Then is for
   functional and acceptance behaviour. A non-functional requirement is a
   row in `spec.md`: what is measured, the threshold, and the test tier.
   `test-plan.md` maps each row to a test.
6. **Scenarios change only in the spec phase.** A pull request that edits
   `features/` either changes a `changes/<slug>/spec.md` in the same diff
   or carries a `return:spec` label, recording the return (5.10). An agent
   making a failing test pass by rewriting the scenario is the failure
   this stops.
7. **The class sets whether a spec has scenarios.** Mandatory for feature
   and security-sensitive. Mandatory for bugfix, where a scenario that
   fails before the fix is the eval the class already has to add. Optional
   for infra. None for spike, docs and chore.

The process document changes with the first tooling, not with this record,
so the tag that changes what the process asks of a human also ships the
skill that does it (0001). The vocabulary, `/spec` and the binding check
ship in that one release, so the intervention has a single boundary; the
other slices enforce or extend it and can follow.

The reason that carried it: a spec that can fail is one that conformance,
and attribution, can be measured against.

## Considered options

- **Scenarios in the change folder.** Lost: they stop running when the
  change closes, so the next change can break them unnoticed.
- **Executed Gherkin as the floor.** Lost for now: pap is POSIX shell and
  has no Gherkin runner worth adopting, so pap could not run its own
  process. Tracing first; a shell runner can raise the floor later.
- **Tracing only, no runners.** Lost: a test body can drift from the
  scenario that names it. Executed steps tie the words to the code, and
  the step definitions become the vocabulary in executable form.
- **A vocabulary per change.** Lost: terms drift between changes, which
  is the problem the vocabulary is there to stop.
- **A linter for the vocabulary.** Lost: matching domain words in prose
  is a rabbit hole. Review first; a check if review keeps missing.
- **Given/When/Then for non-functional requirements too.** Lost: a
  latency threshold reads worse as a scenario and tests no better.
- **Scenarios as a separate phase after the spec.** Lost: a seventh
  manual step (section 7), and the scenarios are the most reviewable part
  of the spec, not an appendix to it.

## Consequences

- Easier: conformance to the spec becomes a check, and a "specification
  gap" escape names the scenario that was missing.
- Easier: the bugfix class's eval rule becomes checkable: a scenario that
  fails before the fix and passes after.
- Harder: the human reads Gherkin at spec review. It pays only if the
  scenarios come before the code and are read; written after, they are
  ceremony. The Revisit's first effect is there to show which.
- Harder: `product/domain.md` is a fifth product-layer file to keep, and
  `/envision` grows a section.
- Harder: traced scenarios can still drift from their test bodies. The
  Revisit counts the executed share to see whether the floor should rise.
- Limit: pap itself has no runner, so its own scenarios are traced, not
  executed, until one exists.
- Measurement: there is no before side for "specification gap" escapes,
  because no `findings.md` exists anywhere yet. The first effect uses
  follow-up fix pull requests instead, readable from git history, as
  0016's does. The second is counted from the pull requests that touch
  `features/`.
- Follow-up: process sections 3, 4, 5.4, 5.6 and 5.10 are amended in the
  pull request that ships `/spec`; `coverage.md` then maps S-spec and
  S-plan to these rules.

## Where it is taught or enforced

Backs [`rules.md`](../rules.md) 17.1 (every scenario is bound or pending),
17.2 (a change closes with no pending scenarios), 17.3 (scenarios change
only in the spec phase) and 17.4 (the class sets whether a spec has
scenarios). Nothing enforces them yet; backlog item H-011 builds the
skills and checks, and H-005 the `/findings` that 17.2 needs.
