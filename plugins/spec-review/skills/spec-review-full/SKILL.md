---
name: spec-review-full
description: Full multi-perspective review board for a design specification. Run when the user asks for a full review, design sign-off, review board, Well-Architected review, or does not specify a single perspective. Orchestrates the spec-review-* skills (security, reliability, operations, cost, performance, qa, ux, gdpr, ai-act, soc2, iso27001) and consolidates findings. Reviews designs only, never code.
disallowed-tools:
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

# Full Design Specification Review (Review Board)

You are chairing a design review board. Run the relevant `spec-review-*` perspectives against the specification and produce one consolidated report.

## Procedure

1. **Select perspectives.** Default set: security, reliability, operations, cost, performance, qa. The first five map to the Azure Well-Architected Framework pillars (security, reliability, operational excellence, cost optimization, performance efficiency); running them together constitutes a WAF-aligned design review. Add ux if the spec has user-facing behaviour. Add gdpr by default; skip it only when the spec states the system holds no personal data, remembering that staff, telemetry and support access count. Add ai-act if the design contains, integrates or calls an AI system, including an LLM through an API, and EU exposure exists or is unknown; ai-act always runs with gdpr. Add soc2 if the system will be in a SOC 2 scope. Add iso27001 if the organisation holds or is pursuing ISO 27001 certification and the system will sit inside the ISMS scope. State which perspectives you ran and why any were skipped.
2. **Run each perspective** by loading and following `${CLAUDE_PLUGIN_ROOT}/skills/spec-review-<perspective>/SKILL.md` for each selected perspective. Where the environment supports it, run perspectives as parallel subagents, each returning its findings table; otherwise run them sequentially. Apply each perspective fully; do not summarise a perspective away because another already raised something similar.
3. **Deduplicate and cross-reference.** Where two perspectives hit the same underlying issue (e.g. missing audit logging appears in security, soc2, and iso27001; missing deletion appears in gdpr, iso27001, and soc2; an automated decision without human review appears in gdpr, ai-act, and ux), keep one primary finding, note the other perspectives as reinforcing, and raise its severity if multiple perspectives independently flagged it. Where perspectives genuinely conflict (cost vs reliability, performance vs cost), do not average them away: surface the conflict as an explicit trade-off decision for the spec author, WAF-style.
4. **Consolidate.**

## Output format

1. **Executive verdict**: Pass / Pass with conditions / Fail overall, with the per-perspective verdicts in a one-line-each summary table.
2. **Top findings**: the 5-10 findings that most affect the decision, ordered by severity, each with its perspective(s) of origin.
3. **Full findings register**: all findings from all perspectives, deduplicated, with original IDs preserved (SEC-, REL-, OPS-, COST-, PERF-, QA-, UX-, GDPR-, AIA-, SOC-, ISO-, SII-).
4. **Cross-cutting themes**: patterns spanning perspectives (e.g. "observability is underspecified everywhere").
5. **Trade-off register**: explicit conflicts between perspectives requiring an author decision, with the options and their consequences.
6. **Gaps and questions**: merged from all perspectives, deduplicated.
7. **Recommended conditions for approval**: the concrete spec changes required to move to Pass, if not already there.

Keep the executive section readable by a non-specialist stakeholder. Keep the register precise for the spec author.
