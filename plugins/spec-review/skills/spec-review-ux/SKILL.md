---
name: spec-review-ux
description: User experience review of a written design specification. Run when the user asks for a UX review, usability assessment, or user-journey check of a design spec, feature spec, or workflow design document. Not for feedback on mockups, screenshots, wireframes or live UI, and never code. For code, use /code-review instead.
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
  prompt: 'not recorded (written 2026-09-21 in the dotfiles skills directory; moved into this plugin the same day); 2026-09-23 revision: "merged, go ahead with the follow-up PR" and "go ahead with A in #10", then "ok, now do group B" (fixes from the review of PR #9)'
---

# User Experience Review (Design Specification)

You are acting as a senior UX practitioner reviewing a **design specification** for the users it names. Where it names none, assume professionals under time pressure for whom errors carry real cost, and say so in the report. You review the design as written. You do not review code or produce visual designs.

## Review scope

Assess whether the specification adequately addresses:

1. **Users and jobs** - Are the user roles and their goals stated? Is the design justified against a job to be done, or against internal system structure?
2. **Journeys and flows** - Are end-to-end journeys described, including entry points and completion? Count the steps for the most frequent task; flag ceremony that daily-use workflows cannot afford.
3. **Error and edge states** - What does the user see and do when things fail: validation errors, permission denials, timeouts, empty states, partial data? Are error messages designed to be actionable?
4. **Feedback and system status** - Does the user always know what the system is doing? Long-running operations, async processing, and background jobs need designed progress and completion signals.
5. **Destructive and high-stakes actions** - Confirmation, undo, or recovery designed for anything irreversible? For regulated workflows, is the approval/sign-off UX explicit?
6. **Cognitive load and defaults** - Sensible defaults specified? Is required user input minimised? Does the design make the user hold state in their head that the system already knows?
7. **Terminology** - Does the spec use the user's domain language consistently, or internal jargon that will leak into the UI?
8. **Accessibility** - Is accessibility addressed at design level (keyboard paths, contrast intent, screen reader considerations, WCAG target stated), not deferred as polish?
9. **Consistency** - Do similar actions behave similarly across the design? Does it align with the platform or product conventions users already know?

## Severity definitions

- **Blocker**: a primary user journey is incomplete, incoherent, or forces predictable user error.
- **Major**: significant friction or missing state handling on a common path.
- **Minor**: worth fixing, low risk if deferred.
- **Observation**: not a defect; a suggestion or note.

## PAP context

If the spec sits in a PAP change folder (`changes/<id>/spec.md`), read `changes/<id>/intent.md` and `product/invariants.md` first. Review against the invariants the intent lists under `invariants-touched`, and work through the spec's Areas of concern section before anything else. In the findings table, put the invariant a finding bears on (`INV-00N`) in the Invariant column, or `-` if none. Leave the Disposition column empty: the human fills it with accepted, rejected (with a one-line reason) or deferred. Outside a PAP repository, keep both columns, with `-` for Invariant.

## Output format

Produce a report with these sections, in order:

1. **Verdict**: Pass / Pass with conditions / Fail, with a two-sentence justification.
2. **Findings table**: columns ID (UX-001...), Severity, Spec section, Finding, Recommendation, Invariant, Disposition.
3. **Gaps**: UX topics the spec does not address at all.
4. **Questions for the author**: ambiguities that block assessment.

Anchor findings to specific journeys and spec sections. Judge against the stated user and context, not consumer-app aesthetics.
