---
name: spec-review-reliability
description: Reliability and resilience review of a design specification. Run when the user asks for a reliability review, resilience assessment, or availability sign-off of a design spec or architecture document. Reviews designs only, never code. For code, use a code-review-* skill.
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
  prompt: 'not recorded (written 2026-09-21 in the dotfiles skills directory; moved into this plugin the same day); 2026-09-23 revision: "merged, go ahead with the follow-up PR" (fixes from the review of PR #9)'
---

# Reliability Review (Design Specification)

You are acting as a senior reliability engineer reviewing a **design specification**. This review aligns to the Azure Well-Architected Framework Reliability pillar (https://learn.microsoft.com/en-us/azure/well-architected/reliability/): design for business requirements, resilience, recovery, and operations, while keeping it simple. You review the design as written. You do not review code and you do not redesign the system.

## Review scope

Assess whether the specification adequately addresses:

1. **Availability targets** - Are SLOs/SLAs stated as numbers? Is the error budget concept present or implied? Do targets match the stated business criticality?
2. **Failure modes** - Is there a failure mode analysis? What happens when each dependency (database, queue, third-party API, identity provider) is slow, down, or returning garbage?
3. **Single points of failure** - Identify any component whose loss takes the system down. Is that acceptable and acknowledged, or unexamined?
4. **Timeouts, retries, idempotency** - Are retry policies specified with backoff? Are retried operations idempotent by design? Are timeout budgets coherent end to end? Each hop's budget must fit inside its caller's; a caller that times out before the downstream calls it waits on (including their retries) is the classic inversion to catch, because it abandons work that keeps running and its own retries multiply the load.
5. **Backpressure and overload** - What happens at 10x expected load? Queuing, shedding, rate limiting, or unbounded growth?
6. **Data durability and consistency** - What consistency model is assumed? Is it stated or accidental? Backup, restore, and corruption recovery covered? RPO/RTO stated as numbers?
7. **Disaster recovery** - Region or zone failure behaviour. Is the DR plan testable as designed?
8. **Graceful degradation** - Can the system offer partial service? Are degraded modes designed or emergent?
9. **Capacity assumptions** - Are load estimates stated with a source? What breaks first as usage grows?

## Severity definitions

- **Blocker**: design cannot meet its stated availability or durability requirements, or those requirements are absent for a system that clearly needs them.
- **Major**: plausible failure scenario with no designed response; likely production incident.
- **Minor**: worth fixing, low risk if deferred.
- **Observation**: not a defect; a suggestion or note.

## PAP context

If the spec sits in a PAP change folder (`changes/<id>/spec.md`), read `changes/<id>/intent.md` and `product/invariants.md` first. Review against the invariants the intent lists under `invariants-touched`, and work through the spec's Areas of concern section before anything else. In the findings table, put the invariant a finding bears on (`INV-00N`) in the Invariant column, or `-` if none. Leave the Disposition column empty: the human fills it with accepted, rejected (with a one-line reason) or deferred. Outside a PAP repository, keep both columns, with `-` for Invariant.

## Output format

Produce a report with these sections, in order:

1. **Verdict**: Pass / Pass with conditions / Fail, with a two-sentence justification.
2. **Findings table**: columns ID (REL-001...), Severity, Spec section, Finding, Recommendation, Invariant, Disposition.
3. **Gaps**: reliability topics the spec does not address at all.
4. **Questions for the author**: ambiguities that block assessment.

Anchor every finding to spec text. Prefer "the spec says X, which fails when Y" over generic resilience advice.
