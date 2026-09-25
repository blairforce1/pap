# Vision: PAP

Status: draft
Last reviewed: 2026-09-25

## Problem

A developer whose code is mostly written by agents cannot tell whether a change to how they work made things better or worse. The first such developer is blairforce1, running PAP on its own repository and on one trial app repository. Today process changes are judged by feel or counted by hand: decision 0006 was measured only because the human remembered to count, and 0002's revisit trigger passed 19 change pull requests unchecked (0010).

Humphrey's PSP answered this question for hand-written code and died on the cost of manual data collection. Agentic work changes both sides. Collection can be nearly free, because every artefact passes through git, CI and an agent session. The failure mode is new: agents build the wrong thing faithfully and fast, and model baselines shift every quarter, so output volume says nothing durable.

## Done enough to matter

For any process change, the developer sees a before and after on the measures the change named, built from data nobody logged by hand, and keeps or reverts it on those numbers. Every change in an adopting repository is carried through gates an agent cannot skip. The work the human does by hand stays at the six items of process section 7.

## Non-goals

- Team or organisation productivity dashboards: PAP measures one developer's process, not a delivery organisation.
- Scalar PR risk scores: a solo reviewer cannot act on a number; review output is an attention plan.
- Output volume as productivity (lines, velocity): size is an input cost driver, never a result.
- A tool-prescriptive process document: the document says what must happen; the toolkit is one way to do it.
- Career or audience rendering inside PAP: PAP exports evidence; portfolio-pack renders it.
- Brownfield-first instrumentation: instrument greenfield changes; read brownfield history only to set thresholds.

## How we will know

- Interventions are settled on data. Observed in `decisions/` status lines and `pap revisits`. Threshold: every record past its revisit trigger reaches `measured:confirmed` or `measured:refuted` within 10 change pull requests, with no hand counting. If three interventions ship and none shows a detectable effect, revisit the approach (decision 0001).
- Manual steps do not grow. Observed against process section 7. A seventh hand-written step is a defect.

## Constraints on the effort

- One developer. No second approver exists, so no gate can depend on one.
- GitHub Pro personal account; app repositories are private, so CodeQL and GitHub secret scanning are unavailable. Free and open-source tooling only.
- Claude Code is the agent host; the process is delivered as its plugins, skills and hooks.
- Hooks and anything run before `mise install` are POSIX shell (decision 0009).
- Languages supported from the start: .NET and Go.
- The pap repository is public and Apache-2.0.

## Assumptions to test

- Outer-loop events (phase changes, returns, merges, gate waits) can be derived from the GitHub pull request timeline without a live emitter.
- Claude Code's own telemetry is enough for inner-loop measures (tokens, rework share) once joined to a change id.
- One trial app repository produces enough changes for a before and after split in a reasonable time.
- Per-phase skills carry the process better than a long `CLAUDE.md`.
- The controls built so far reduce escapes. There is no escape data yet to show it.
