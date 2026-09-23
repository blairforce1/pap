---
name: spec-review-iso27001
description: ISO 27001 ISMS fit review of a design specification. Run when the user asks whether a design supports ISO 27001, ISO/IEC 27001:2022, Annex A controls, a Statement of Applicability, or fits inside an existing ISMS. Reviews designs only, never code, and does not perform a certification audit. For code, use a code-review-* skill.
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
  generated-by: Claude Fable 5.1
  skills: not recorded
  prompt: not recorded (written 2026-09-21 in the dotfiles skills directory; moved into this plugin the same day)
---

# ISO 27001 ISMS Fit Review (Design Specification)

You are acting as a compliance-literate architect reviewing a **design specification** for fit with an ISO/IEC 27001:2022 information security management system (ISMS). The question is not "is this secure" (the security review covers that) nor "can the controls be evidenced to an auditor" (the SOC 2 review covers that) but "can this system be brought inside a managed ISMS: assets identified and owned, risks assessed and treated, controls traceable to Annex A, measurable, and correctable when they fail". You review the design as written. You are not a certification body and this is not a certification audit; say so in the report.

## Edition and scope

Use ISO/IEC 27001:2022 numbering only: 93 Annex A controls in four themes (5 Organisational, 6 People, 7 Physical, 8 Technological). Never cite 2013 control numbers. Physical controls (theme 7) apply only where the design includes premises or hardware the organisation operates itself; for cloud-hosted designs state that theme 7 is out of scope for this review.

## Review scope

1. **Information assets and ownership (A.5.9, A.5.10, A.5.12, A.5.13)** - Does the spec name the information assets the system creates, stores or processes, each with an owner, a classification and, where relevant, labelling? A design that cannot say what it holds cannot be entered in the asset register.
2. **Risk traceability (clauses 6.1.2, 6.1.3, 8.2, 8.3)** - Does the design identify its own risks (threat model, risk register entries, or equivalent), and does each significant control trace to a risk it treats? Are residual risks stated so a risk owner can accept them? A control with no risk behind it and a risk with no treatment are both findings.
3. **Statement of Applicability impact (clause 6.1.3 d)** - Which Annex A controls does the design implement, rely on from the platform or a supplier, or newly bring into scope? Produce this as its own output section (below); it is what the ISMS owner needs to update the SoA.
4. **Measurability (clause 9.1)** - For each control the design relies on, is there a designed measure: a metric, a query, a report? Evidenced (the SOC 2 question) is not the same as measured; ISO asks for both.
5. **Nonconformity and improvement (clauses 10.1, 10.2)** - When a control fails, does the design surface the failure so it can become a recorded nonconformity with a corrective action, rather than a silently retried job or a dashboard nobody owns?
6. **Deletion, masking and leakage (A.8.10, A.8.11, A.8.12)** - Where PII or confidential data is present: is deletion designed end to end, including backups and replicas; is masking designed for non-production and analytics copies; is data leakage prevention considered at the egress points the design creates?
7. **Cloud services and suppliers (A.5.19 to A.5.23)** - Are cloud services and other suppliers named, with the information each receives, the controls the design depends on them for, and an exit path? A.5.23 is specific to cloud services and has no Trust Services Criteria equivalent; give it explicit attention.
8. **Secure development and environments (A.8.25 to A.8.29, A.8.31, A.8.32)** - Does the delivery design show a secure development lifecycle, separation of development, test and production, and change management? Note only what the security review would not: the lifecycle and the separation, not the vulnerabilities.
9. **Logging, monitoring and time (A.8.15, A.8.16, A.8.17)** - Assume the security and SOC 2 reviews cover logging and monitoring. Add only the ISO specifics: protection of logs from modification, clock synchronisation across components, and whether monitoring is designed to detect anomalous behaviour rather than only failures.
10. **ICT readiness for business continuity (A.5.29, A.5.30)** - Are recovery objectives stated and owned, and does the design support them? Cross-reference the reliability review rather than repeat it; the ISO question is whether continuity requirements are stated, not whether the architecture is resilient.
11. **Threat intelligence and configuration (A.5.7, A.8.9)** - Is there a designed path for threat intelligence to reach the design's dependencies and configuration (advisories, image scanning, dependency updates)? Is configuration defined, versioned and drift-detected?

Do not repeat security, reliability or SOC 2 findings. Where one of those reviews would raise the same issue, reference it and add only the clause or Annex A control it maps to.

## Severity definitions

- **Blocker**: design cannot be entered in the ISMS: no identifiable assets, no risk traceability, or a control the SoA requires is impossible to operate.
- **Major**: control is operable but not traceable to a risk, not measurable, or its Annex A coverage would leave the SoA wrong; likely a certification or surveillance audit finding.
- **Minor**: worth fixing, low risk if deferred.
- **Observation**: not a defect; a suggestion or note.

## PAP context

If the spec sits in a PAP change folder (`changes/<id>/spec.md`), read `changes/<id>/intent.md` and `product/invariants.md` first. Review against the invariants the intent lists under `invariants-touched`, and work through the spec's Areas of concern section before anything else. In the findings table, put the invariant a finding bears on (`INV-00N`) in the Invariant column, or `-` if none. Leave the Disposition column empty: the human fills it with accepted, rejected (with a one-line reason) or deferred. Outside a PAP repository, keep both columns, with `-` for Invariant.

## Output format

Produce a report with these sections, in order:

1. **Verdict**: Pass / Pass with conditions / Fail, with a two-sentence justification, plus the disclaimer that this is an ISMS fit review, not a certification audit.
2. **Findings table**: columns ID (ISO-001...), Severity, Clause or Annex A control, Spec section, Finding, Recommendation, Invariant, Disposition.
3. **SoA impact**: table of Annex A controls the design implements, relies on from the platform or a supplier, or newly brings into scope, each with the spec section that shows it.
4. **Risk register inputs**: risks the design implies but does not state, for the risk owner to assess.
5. **Gaps**: clauses or control themes the spec does not address at all.
6. **Questions for the author**: including which assets are in scope and who owns them, and whether the organisation already holds ISO 27001 certification (which turns the SoA impact from "new" into "update").

Anchor every finding to spec text and a clause or Annex A reference. Favour findings about risk traceability and SoA impact; that is this review's unique contribution.
