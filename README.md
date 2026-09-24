# Personal Agentic Process (PAP)

> [!IMPORTANT]
> **Work in progress.** PAP is still being built. The process document is usable; the tooling is incomplete, and anything here may change without notice.

A personal software process for building software with AI agents, and the tooling that enforces and measures it.

Watts Humphrey's Personal Software Process gave an individual engineer a way to measure their own work and improve it deliberately. PAP asks the same question for a developer whose code is mostly generated: what do you measure, what do you gate, and how do you know a change to your process made things better rather than worse?

This repository is the process definition and the toolkit. It is being built in the open and used on real projects as it is built. Expect gaps; the decision records say what exists and what does not.

## What is here

| Path                                  | What it is                                                                                                                                                                                                                   |
| ------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `process/personal-agentic-process.md` | The process itself. Tool-agnostic. Says what must happen, not how.                                                                                                                                                           |
| `rules.md`                            | The rule register: every enforceable rule, the decision that introduced it, and what enforces it today. Gaps are written down, not hidden.                                                                                   |
| `decisions/`                          | Decision records. Process changes are treated as measured interventions (decision 0001), so each record states the expected effect and when it will be revisited.                                                            |
| `plugins/pap/`                        | A Claude Code plugin: one skill per process phase (`/envision` so far), plus hooks that enforce the rules an agent must not be able to talk its way around.                                                                  |
| `plugins/spec-review/`                | A Claude Code plugin for phase 3, spec review: eleven reviewer perspectives, from security to the EU AI Act, plus `spec-review-full` to run the whole board. Works on any design document, with or without the `pap` plugin. |
| `bin/pap`                             | The `pap` CLI: `init` and `sync` apply the template layers, `repo` and `codeowners` configure GitHub, `doctor` checks the local machine.                                                                                     |
| `scripts/`                            | Guards shared by the git hooks and the Claude Code hooks, the template assembler and the release script.                                                                                                                     |
| `.github/rulesets/`                   | The branch ruleset applied to every repo that adopts the process.                                                                                                                                                            |
| `lefthook.yml`, `mise.toml`           | Pinned local tooling. `mise install && lefthook install` is the whole setup.                                                                                                                                                 |

## Core ideas

- **Intent is the human artefact.** Humans write intent and judge results; agents generate specs, plans, code and tests from it.
- **Ceremony is proportional.** A task class sets how much specification, review and testing a change gets.
- **Every artefact records what produced it.** Model, skill version, prompt. Without provenance nothing can be attributed.
- **Escapes are attributed to a phase.** Not "a bug" but "the spec omitted a failure mode".
- **Process changes are experiments.** Written down before they start, with the outcome they are expected to move.
- **Gates are automated, not remembered.** Anything that must survive is enforced by a check that runs every time.

The full list, and the phase model, is in the process document.

## Influences

- **Personal Software Process** (Watts Humphrey). The idea that an individual can measure and improve their own process. PAP keeps the measurement discipline and drops the manual logging.
- **Anthropic's AI-Native SDLC Playbook.** Several mechanics come from it directly: a conventions file agents read, review passes defined in `REVIEW.md`, an eval suite tied to process changes, provenance on generated artefacts, and merge as the trigger for the next phase.
- **DORA and CDEvents.** The outer-loop measures and the event vocabulary used to capture them.

What PAP adds is the product layer above per-change intent, task classes that set ceremony, recorded returns between phases, and escape attribution to a phase.

## Using it

1. Install the plugin in Claude Code from this repository's marketplace:
   `claude plugin marketplace add blairforce1/pap` then `claude plugin install pap@blairforce1-pap`.
2. In a new or existing repo, run `/envision` to produce the product layer (vision, invariants, hypothesis backlog).
3. Apply the template, the ruleset and the hooks with `pap init base [dotnet] [go]`, and take later template versions with `pap sync`. See "Adopting and syncing the template" in `templates/base/README.md`.

Repository templates (editorconfig, .NET analyzers, formatting, devcontainer) and the metrics pipeline are on the roadmap; see the decision records and open pull requests for current state.

## Status

Early. The process document is stable enough to use. The tooling is being built one change at a time, each through the process it enforces. Decision 0002 records the first time the written record and the repository disagreed, and how it was fixed.

## Licence

Apache License 2.0. See [LICENSE](LICENSE).
