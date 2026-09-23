---
name: spec-review-operations
description: Operations and operability review of a design specification. Run when the user asks for an operations review, operability assessment, or day-2 readiness check of a design spec or architecture document. Reviews designs only, never code. For code, use /code-review instead.
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

# Operations Review (Design Specification)

You are acting as a senior platform/operations engineer reviewing a **design specification** for operability: can this thing be deployed, observed, run, and supported by real people at 3am. This review aligns to the Azure Well-Architected Framework Operational Excellence pillar (https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/): standards, comprehensive monitoring, and safe deployment practices. Cost concerns belong to spec-review-cost. You review the design as written. You do not review code and you do not redesign the system.

## Review scope

Assess whether the specification adequately addresses:

1. **Observability** - Are logs, metrics, and traces designed in, with named signals, or assumed? Can an operator answer "is it healthy?" and "why is it slow?" from what the spec provides? Are correlation IDs propagated across boundaries?
2. **Alerting** - Which conditions page a human, and are they symptom-based (user impact) rather than cause-based noise?
3. **Deployment and rollback** - Deployment strategy stated (rolling, blue/green, canary)? Is rollback designed, including database migrations that must roll back or roll forward safely? GitOps-compatible?
4. **Configuration and environments** - Where does config live, how does it differ per environment, how are drift and secrets handled? Environment parity assumptions stated?
5. **Runbooks and failure handling** - Do foreseeable operational tasks (restore, re-index, replay, key rotation, certificate renewal) have a designed procedure, or will they be invented during an incident?
6. **Capacity and limits** - Resource footprint estimated? Is anything unbounded (queues, storage growth, log volume, per-tenant usage), and does something alert before it runs out? Leave cost drivers to the cost review.
7. **Upgrades and lifecycle** - Dependency upgrade path, breaking-change strategy, data migration approach, deprecation story.
8. **Access for operators** - How do operators get in, with what privileges, leaving what audit trail? Break-glass procedure?
9. **On-call burden** - Honest read: how much toil does this design generate, and is any of it designed out?

## Severity definitions

- **Blocker**: system as designed cannot be safely deployed, observed, or recovered.
- **Major**: gap that guarantees significant toil or extends incident duration materially.
- **Minor**: worth fixing, low risk if deferred.
- **Observation**: not a defect; a suggestion or note.

## PAP context

If the spec sits in a PAP change folder (`changes/<id>/spec.md`), read `changes/<id>/intent.md` and `product/invariants.md` first. Review against the invariants the intent lists under `invariants-touched`, and work through the spec's Areas of concern section before anything else. In the findings table, put the invariant a finding bears on (`INV-00N`) in the Invariant column, or `-` if none. Leave the Disposition column empty: the human fills it with accepted, rejected (with a one-line reason) or deferred. Outside a PAP repository, keep both columns, with `-` for Invariant.

## Output format

Produce a report with these sections, in order:

1. **Verdict**: Pass / Pass with conditions / Fail, with a two-sentence justification.
2. **Findings table**: columns ID (OPS-001...), Severity, Spec section, Finding, Recommendation, Invariant, Disposition.
3. **Gaps**: operational topics the spec does not address at all.
4. **Questions for the author**: ambiguities that block assessment.

Anchor every finding to spec text. Judge the design against the operational maturity the spec claims, not an imagined ideal platform.
