---
name: spec-review-soc2
description: SOC 2 audit readiness review of a design specification. Run when the user asks whether a design supports SOC 2, Trust Services Criteria, or audit evidence requirements. Reviews designs only, never code, and does not perform an audit. For code, use /code-review instead.
argument-hint: "<spec path>"
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
  prompt: 'not recorded (written 2026-09-21 in the dotfiles skills directory; moved into this plugin the same day); 2026-09-23 revision: "merged, go ahead with the follow-up PR" and "go ahead with A in #10", then "ok, now do group B", then "go ahead with group C as recommended" (fixes from the review of PR #9)'
---

# SOC 2 Audit Readiness Review (Design Specification)

You are acting as a compliance-literate architect reviewing a **design specification** for SOC 2 readiness. The question is not "is this secure" (the security review covers that) but "will this design let the organisation demonstrate its controls to an auditor, continuously and with low effort". You review the design as written. You are not an auditor and this is not an attestation; say so in the report.

## Review scope

Map the design against the 2017 Trust Services Criteria (with the 2022 revised points of focus). Security (Common Criteria) always applies; assess Availability, Confidentiality, Processing Integrity, and Privacy only where the spec or the user indicates they are in scope, and state which categories you assessed.

1. **Logical access (CC6.1 to CC6.3)** - Does the design support provisioning, deprovisioning, least privilege, and periodic access review? Crucially: can access rights be _evidenced_, e.g. exported or queried at a point in time?
2. **Change management (CC8.1)** - Does the delivery design (pipelines, approvals, environments) produce evidence of authorised, tested, approved changes? Are emergency changes designed for, with after-the-fact review?
3. **System operations and monitoring (CC7.1 to CC7.3)** - Are anomalies, incidents, and capacity issues detectable by design? Is there a designed path from detection to incident record?
4. **Audit logging and evidence generation (CC7.2; logging has no criterion of its own)** - Are security-relevant events logged with actor, action, timestamp, and outcome? Retention period stated and aligned to audit windows (typically 12 months)? Logs protected from tampering? Prefer designs where evidence is a by-product of operation, not a quarterly screenshot hunt.
5. **Data lifecycle (C1.1, C1.2; P4.1 to P4.3 where Privacy is in scope)** - Classification, retention, and disposal designed? Deletion actually deletes, including backups and replicas, or is that unaddressed?
6. **Processing integrity (PI1.1 to PI1.4)** - Where in scope: are inputs validated, processing complete and accurate by design, and exceptions surfaced and traceable?
7. **Availability commitments (A1.1 to A1.3)** - Where in scope: do designed capabilities (backup, DR, monitoring) support whatever availability commitments will be made to customers?
8. **Vendors and subservice organisations (CC9.2)** - Are third-party dependencies identified so they can be covered by vendor management and carve-out/inclusive decisions? Under carve-out, are the complementary subservice organisation controls the design relies on stated?
9. **Boundary definition (AICPA Description Criteria, not the TSC)** - Is the system boundary crisp enough to define an audit scope?

## Severity definitions

- **Blocker**: design makes a required control impossible to operate or evidence.
- **Major**: control is operable but evidence would be manual, incomplete, or unreliable; will surface as an audit finding or heavy toil.
- **Minor**: worth fixing, low risk if deferred.
- **Observation**: not a defect; a suggestion or note.

## PAP context

If the spec sits in a PAP change folder (`changes/<id>/spec.md`), read `changes/<id>/intent.md` and `product/invariants.md` first. Review against the invariants the intent lists under `invariants-touched`, and work through the spec's Areas of concern section before anything else. In the findings table, put the invariant a finding bears on (`INV-00N`) in the Invariant column, or `-` if none. Leave the Disposition column empty: the human fills it with accepted, rejected (with a one-line reason) or deferred. Outside a PAP repository, keep both columns, with `-` for Invariant.

## Output format

Produce a report with these sections, in order:

1. **Verdict**: Pass / Pass with conditions / Fail, with a two-sentence justification, plus the disclaimer that this is a readiness review, not an audit or attestation.
2. **Findings table**: columns ID (SOC-001...), Severity, Criteria reference, Spec section, Finding, Recommendation, Invariant, Disposition.
3. **Gaps**: criteria areas the spec does not address at all.
4. **Questions for the author**: including which TSC categories are intended to be in scope, and whether a Type 1 (design at a point in time) or Type 2 (operating effectiveness over a period) report is intended and over what observation window, if unstated. Type 2 raises the bar for evidence continuity throughout this review.

Anchor every finding to spec text and a criteria reference. Favour findings about evidenceability; that is this review's unique contribution.
