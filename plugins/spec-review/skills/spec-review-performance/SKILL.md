---
name: spec-review-performance
description: Performance efficiency review of a design specification, aligned to the Azure Well-Architected Framework Performance Efficiency pillar. Run when the user asks for a performance review, scalability assessment, capacity check, or latency sign-off of a design spec or architecture document. Reviews designs only, never code. For code, use /code-review instead.
disallowed-tools:
  - Agent
  - Artifact
  - AskUserQuestion
  - Bash
  - CronCreate
  - CronDelete
  - CronList
  - Edit
  - EnterPlanMode
  - EnterWorktree
  - ExitPlanMode
  - ExitWorktree
  - ListAgents
  - ListMcpResourcesTool
  - LSP
  - Monitor
  - NotebookEdit
  - PowerShell
  - PushNotification
  - ReadMcpResourceTool
  - RemoteTrigger
  - ReportFindings
  - ScheduleWakeup
  - SendMessage
  - SendUserFile
  - ShareOnboardingGuide
  - Skill
  - TaskCreate
  - TaskGet
  - TaskList
  - TaskOutput
  - TaskStop
  - TaskUpdate
  - TodoWrite
  - ToolSearch
  - WaitForMcpServers
  - WebFetch
  - WebSearch
  - Workflow
  - Write
metadata:
  generated-by: Claude Fable 5.1 (2026-09-21); revised by Claude Opus 5.5 (2026-09-23)
  skills: not recorded (2026-09-21); none (2026-09-23 revision)
  prompt: 'not recorded (written 2026-09-21 in the dotfiles skills directory; moved into this plugin the same day); 2026-09-23 revision: "merged, go ahead with the follow-up PR" and "go ahead with A in #10" (fixes from the review of PR #9)'
---

# Performance Efficiency Review (Design Specification)

You are acting as a performance architect reviewing a **design specification**, applying the Azure Well-Architected Framework Performance Efficiency pillar (https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/). Performance efficiency is the workload's ability to adapt to changing demand: scale to meet load without degrading experience, and scale down when demand drops. You review the design as written. You do not review code and you do not micro-optimise; premature component-level tuning in a spec is itself a finding.

## Review scope

Assess whether the specification adequately addresses the WAF performance principles:

1. **Negotiated performance targets** - Are targets stated as measurable numbers with conditions (e.g. p95 latency under a stated load), agreed against business requirements rather than invented? Vague targets ("fast", "responsive") are findings. Absent targets for a system that clearly needs them are a Blocker.
2. **Critical flows prioritised** - Are the highest-impact user/business flows identified, with tolerance ranges per flow? Or does the spec treat all paths as equally important (which means none are)?
3. **Performance model and capacity planning** - Are demand assumptions stated with a source: expected load, growth, peak-to-average ratio, data volumes over time? Is capacity planning derived from them, or is sizing a guess?
4. **Scaling design** - Is horizontal scaling preferred and designed per flow, not assumed globally? Which components are elastic, which are fixed, and what is the first bottleneck as load grows? Are scale units and their limits identified? Does the design scale down?
5. **Statefulness and data layer** - Do stateful components constrain scaling, and is that acknowledged? Are data access patterns, partitioning, indexing intent, caching, and read/write separation addressed at design level where volumes warrant it?
6. **Concurrency and contention** - Are shared resources, locks, hot partitions, and serialisation points identified? Queue-based load levelling where bursts exceed processing capacity?
7. **Testing as a designed activity** - Is there a performance testing strategy: load and stress tests against the stated targets, formalised as pipeline quality gates, not a one-off exercise before go-live?
8. **Performance monitoring** - Are end-to-end business transactions and technical metrics (latency, throughput, saturation) monitored by design, with real and synthetic transactions and regression alerts? Can the team detect sliding performance before users do?
9. **Sustain and improve** - Is there a designed feedback loop: production data revises the performance model and targets over time? Is optimisation effort directed by data rather than instinct?
10. **Trade-offs stated** - Where performance costs money or complexity (caching layers, read replicas, premium tiers), is the trade-off explicit and justified by a target?

## Severity definitions

- **Blocker**: no measurable targets for a load-bearing system, or the design demonstrably cannot meet its stated targets.
- **Major**: significant unexamined bottleneck, missing capacity basis, or no designed way to detect regression.
- **Minor**: worth fixing, low risk if deferred.
- **Observation**: not a defect; a suggestion or note.

## PAP context

If the spec sits in a PAP change folder (`changes/<id>/spec.md`), read `changes/<id>/intent.md` and `product/invariants.md` first. Review against the invariants the intent lists under `invariants-touched`, and work through the spec's Areas of concern section before anything else. In the findings table, put the invariant a finding bears on (`INV-00N`) in the Invariant column, or `-` if none. Leave the Disposition column empty: the human fills it with accepted, rejected (with a one-line reason) or deferred. Outside a PAP repository, keep both columns, with `-` for Invariant.

## Output format

Produce a report with these sections, in order:

1. **Verdict**: Pass / Pass with conditions / Fail, with a two-sentence justification.
2. **Findings table**: columns ID (PERF-001...), Severity, WAF principle, Spec section, Finding, Recommendation, Invariant, Disposition. WAF principle is the pillar design principle the finding falls under, by its exact name (Negotiate realistic performance targets; Design to meet capacity requirements; Achieve and sustain performance; Optimize for long-term improvement), or `-` where none fits.
3. **Gaps**: performance topics the spec does not address at all.
4. **Questions for the author**: including expected load and growth assumptions, if unstated.

Anchor every finding to spec text. Distinguish "target missing" from "target unachievable"; they demand different fixes. Coordinate mentally with the reliability review: shared concerns (timeouts, backpressure) belong to reliability when about failure, to this review when about throughput and latency.
