---
name: spec
description: "Write the spec for one change and get it accepted (decision 0021): read the accepted intent, draft changes/<slug>/spec.md with the sections its class requires, acceptance scenarios in Given/When/Then in the domain vocabulary, and for feature, infra and security-sensitive changes an Operations section (signals, control band, what wrong looks like, undo) with operational scenarios; run the spec review board by class, record each finding's disposition, and on the human's yes commit on change/<slug> and hand on to /change. Use when the human invokes /spec <slug>, or asks to write, draft, specify or review the spec of a change in a repository that adopts PAP. Runs in the main session only; it needs the human's dispositions and yes."
argument-hint: "<slug>"
---

# Spec

Turn an accepted intent into a spec the human has said yes to: `changes/<slug>/spec.md`, its scenarios, the terms they use and the review that read it. The agent drafts and the human edits (process 5.1); decisions 0017 and 0021 and `rules.md` are the authority, and this skill applies them.

**Main session only.** The dispositions and the yes are the human's (process section 7). A background agent cannot ask; if you are one, stop and report that `/spec` needs the main session.

## Arguments

- `<slug>`: the change's id. The branch is `change/<slug>`, the folder `changes/<slug>/`.

Missing: ask once, then proceed.

## Stance

- **The intent is the brief.** Everything in the spec traces to `intent.md`. A spec that cannot be written without answering a question about purpose is a return to intent (process 5.10): stop, say which question, write nothing.
- **Behaviour, not implementation.** Scenarios say what is observed, in the domain's words. File names, classes and libraries belong in the plan and the code.
- **Operations are part of the design.** For feature, infra and security-sensitive changes, how the change is watched and undone is written now, in the spec, not at the pull request.
- **Challenge once, then record.** A finding is raised once; the human's disposition stands.
- **No yes, no acceptance.** The acceptance lines are written only after the human's yes to the reviewed spec.

## 1. Worktree

The same worktree as `/intent` and `/change`:

```sh
sh "${CLAUDE_PLUGIN_ROOT}/skills/change/worktree.sh" <slug>
```

- `resumed <path>`: the expected case; the intent is on the branch. Refuse to go on unless `changes/<slug>/intent.md` is there with `accepted-by:` and `accepted-on:` filled: remove the worktree (`git worktree remove <path>`) and say `/intent <slug> <class>` comes first. If `spec.md` is there with acceptance lines, run as a review: show it, ask what changed, re-run the perspective the edit bears on (none for wording), and go to step 7 with the edits; a commit after code exists on the branch is spec rework (process 5.2). A `spec.md` without acceptance lines is a paused draft: resume from it.
- `created <path>`: no branch, so no intent. Remove the worktree (`git worktree remove <path>`, `git branch -D change/<slug>`) and say `/intent` comes first.
- `exists <path>` (exit 3) or exit 1: stop and print the message.

Every later command runs in the printed path.

## 2. Read

`changes/<slug>/intent.md` first: its `class` decides the sections, its success measure decides the signals, its `invariants-touched` decides what the review checks against, its open questions are carried into the spec. Then `product/invariants.md`, `product/conventions.md`, `product/domain.md` if present (the words the scenarios use), `product/vision.md` for the product's name, `features/` for the scenarios that already hold, and the files the intent names. Do not summarise any of it to the human.

A `spike` has no spec (process section 4): say so and stop.

## 3. Draft the spec

Use `references/template.md`. Write only the sections the class requires; "none" is an answer, a missing heading is not.

| Class              | Sections                                                                                                                                            |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| feature            | Functional behaviour with scenarios; Non-functional rows; Data, Interfaces and Security where touched; Operations; Areas of concern; Open questions |
| infra              | Functional behaviour (scenarios optional, rule 17.4); Non-functional rows; Operations; Areas of concern; Open questions                             |
| security-sensitive | Everything feature has, plus Security and Compliance                                                                                                |
| bugfix             | Functional behaviour: the escaped defect it cites and one scenario that fails before the fix (rule 17.4); Operations with Undo only; Open questions |
| docs, chore        | Half a page: what changes and where, how a reader checks it afterwards, Open questions. No Operations, no board: the human's read is the review     |

**Functional behaviour.** Prose for the shape, then the scenarios. The intent's desired outcome and non-goals set the boundary; every scenario sits inside it.

**Non-functional.** One row each: what is measured, the threshold, the test tier. Not scenarios (decision 0017).

**Open questions.** Every question the intent carried forward, each marked `answered: <answer>` or `still open: <who>, <phase>`. **Intent churn.** If drafting showed the intent missed something, say what under its own heading; the fix to `intent.md` is a churn commit, `intent(<slug>): churn, <what the spec surfaced>`, with the acceptance lines kept (decision 0020).

**Areas of concern.** Where the intent, an invariant and a convention pull in different directions, say so; the review starts there.

## 4. Scenarios and the vocabulary

Scenarios are Gherkin in `features/<slug>.feature` at the repository root, not in the change folder (decision 0017). Each carries `@id:<slug>-<n>` and `@pending:<slug>`; the test that binds it names the id later. One behaviour a scenario: a Given that is a state, a When that is one event, a Then that is observable, in the domain's words. `spec.md` lists each scenario it adds or changes and why.

Every noun of state and every event in a scenario is defined in `product/domain.md`: the term, its states, its events and the rules between them. A term the file lacks is added in the same diff, as decision 0017 asks; a missing file is started from the template's skeleton. Say which terms you added: `product/` is in the product layer, usually protected, and the pull request's reviewer will look there. Prefer the existing word to a new one; two names for one state is the fault the file exists to stop.

## 5. Operations

For feature, infra and security-sensitive changes, the Operations section is mandatory (rule 21.2). It connects the intent's success measure to process 5.9 (the operation window, control bands, tiered response) in four parts and a set of scenarios:

- **Signals.** For each success measure in the intent, what is measured, from where, and the two or three health signals this change could move (errors, latency, a queue, a cost). A measure with no signal is a measure that cannot be read; say so and send it back to the intent if it cannot be fixed here.
- **Good.** The control band for each signal: the thresholds and the window they are judged over, inside the class's operation window (default 30 days).
- **Wrong.** What a breach looks like, how long it takes to be noticed from where the signal lands, and the first checks: three to five lines an operator runs before anything else.
- **Undo.** How the intent is withdrawn: revert the merge, a feature flag off, or a config rollback; for anything outside git (settings, a ruleset, an external system, a machine), the steps in order. The same text answers the pull request's "How to revert".
- **Operational scenarios**, in Given/When/Then, in the spec itself, not in `features/`: nothing binds them until an operations role exists (backlog H-015). One per band at least: `Given <the change> is live, When <signal> breaches <band> over <window>, Then <undo or diagnosis per 5.9's tier> and the human is told`.

A bugfix writes Undo only. Docs and chore write none.

## 6. Review

Run the board the class requires (process 5.5): invoke `spec-review-full` with the spec's path. It reads the intent, selects the perspectives by class (every one for security-sensitive; at least reliability and operations for infra; the default set for feature, plus ux, gdpr and ai-act where its content rules say), reviews against the invariants the intent touches, and returns a consolidated register with the Disposition column empty. Docs and chore run no board. A bugfix invokes `spec-review-qa` directly, or the board when its intent touches an invariant.

Write the register as it came back to `changes/<slug>/reviews/spec-review.md` (process 5.1, phase 3). Then take the human through the findings, Blockers and Majors first and the Areas of concern before the rest, a few at a turn: each gets `accepted` (and the spec changes before the yes), `rejected: <one-line reason>` or `deferred: <phase>`. Record each disposition in the register. Where the spec changed, say which section.

## 7. Restate for the yes

Show the human what they are accepting: the section list, the scenarios (ids and titles), the terms added to `domain.md`, the Operations section in full, the review's verdict and the dispositions by count. Ask for a yes.

A yes goes to step 8. An edit is made, the changed part shown, and the question asked again. A "later" commits the draft as `spec(<slug>): draft, <state>` with no acceptance lines and removes the worktree; the next `/spec <slug>` resumes it. A no ends here with nothing committed: say so and discard the draft with the worktree (`git worktree remove --force <path>`), keeping the branch and its intent.

## 8. Write and commit

Fill the acceptance lines (`accepted-by: @<login>` from `gh api user -q .login` or the name the human gives, `accepted-on:` today) and the provenance (`generated-by:`, `skills:` with this plugin's version, `prompt:` as the `/spec` line typed). One commit, never bypassing a hook (rule 5.1):

```sh
git add changes/<slug>   # and features/<slug>.feature, product/domain.md: only the files this run wrote
git commit -m "spec(<slug>): <what the change does, in a few words>"
```

A review edit (step 1) commits as `spec(<slug>): <what changed>`, or `spec(<slug>): rework, <what the code surfaced>` after code exists.

Then `git worktree remove <path>`, keeping the branch. No push and no pull request: `/change` opens the one draft pull request that carries intent, spec and code in order (decision 0020, rule 2.2).

## 9. Hand on, then stop

Say what is next: `/change <slug> <class>` in a fresh context, with a brief that can be one line, because `/change` reads `intent.md` and `spec.md` from the branch: the scenarios are its acceptance criteria and the Undo is its "How to revert".

Stop. One spec per invocation; do not start the plan, the brief or the change.

## What not to do

- Do not write a spec from a brief, a chat or your own reading of the code; the accepted `intent.md` is the only source of what the change is for.
- Do not put implementation into scenarios, or scenarios into `changes/<slug>/`.
- Do not fill a disposition or the acceptance lines yourself.
- Do not skip a perspective the class makes mandatory, or run the board on docs, chore or a spike.
- Do not push, open a pull request, or edit anything outside `changes/<slug>/`, `features/<slug>.feature` and `product/domain.md`.
