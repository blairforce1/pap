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
  generated-by: Claude Fable 5.1 (2026-09-21); revised by Claude Opus 5.5 (2026-09-23)
  skills: not recorded (2026-09-21); none (2026-09-23 revision)
  prompt: 'not recorded (written 2026-09-21 in the dotfiles skills directory; moved into this plugin the same day); 2026-09-23 revision: "merged, go ahead with the follow-up PR" and "go ahead with A in #10" (fixes from the review of PR #9)'
---

# Full Design Specification Review (Review Board)

You are chairing a design review board. Run the relevant `spec-review-*` perspectives against the specification and produce one consolidated report.

## Procedure

1. **Select perspectives.** Start from the task class. If the spec sits in a PAP change folder (`changes/<id>/spec.md`), read `changes/<id>/intent.md` for its `class` and `invariants-touched`, and `product/invariants.md` for the invariants' text. Run every perspective the repository's task class matrix makes mandatory for that class (look for the matrix in `product/`). "Compliance" in a matrix means each of gdpr, ai-act, soc2 and iso27001 that applies by the content rules below; if compliance is mandatory and none applies, say so. If the class is known but no matrix exists, use the process's starting set: security-sensitive runs every perspective, infra runs at least reliability and operations, and docs and spike need no spec review (say so and stop unless the user asks for one). Never skip a mandatory perspective. Then add perspectives by content, which is the whole rule outside a PAP repository. Default set: security, reliability, operations, cost, performance, qa. The first five map to the Azure Well-Architected Framework pillars (security, reliability, operational excellence, cost optimization, performance efficiency); running them together constitutes a WAF-aligned design review. Add ux if the spec has user-facing behaviour. Add gdpr by default; skip it only when the spec states the system holds no personal data, remembering that staff, telemetry and support access count. Add ai-act if the design contains, integrates or calls an AI system, including an LLM through an API, and EU exposure exists or is unknown; ai-act always runs with gdpr. Add soc2 if the system will be in a SOC 2 scope. Add iso27001 if the organisation holds or is pursuing ISO 27001 certification and the system will sit inside the ISMS scope. State the class, where the mandatory set came from (matrix, starting set, or none), which perspectives you ran, and why any were skipped.
2. **Run each perspective.** For each selected perspective, read `${CLAUDE_PLUGIN_ROOT}/skills/spec-review-<perspective>/SKILL.md`. Where the environment supports subagents, run the perspectives in parallel. Give each subagent the full text of that file, the spec path, and the PAP context from step 1 (class, the invariants touched and their text, the spec's Areas of concern). Use a read-only agent type such as Explore, and state in the prompt that it must not edit files, run commands or use the network: a subagent does not inherit the perspective's tool restrictions. Require its verdict, findings table, gaps and questions back verbatim. Otherwise run the perspectives one after another yourself, following each file. Apply each perspective fully; do not summarise a perspective away because another already raised something similar.
3. **Deduplicate and cross-reference.** Where two perspectives hit the same underlying issue (e.g. missing audit logging appears in security, soc2, and iso27001; missing deletion appears in gdpr, iso27001, and soc2; an automated decision without human review appears in gdpr, ai-act, and ux), keep one primary finding, note the other perspectives as reinforcing, and keep the highest severity any single perspective gave it. Agreement between perspectives adds confidence, not severity. Where perspectives genuinely conflict (cost vs reliability, performance vs cost), do not average them away: surface the conflict as an explicit trade-off decision for the spec author, WAF-style.
4. **Consolidate.** Set the overall verdict by rule: Fail if any finding is a Blocker or any perspective returned Fail; otherwise Pass with conditions if any finding is Major; otherwise Pass. Every Blocker and Major becomes a recommended condition for approval. Then write the report below.

## Output format

1. **Executive verdict**: Pass / Pass with conditions / Fail overall, with the per-perspective verdicts in a one-line-each summary table.
2. **Top findings**: the 5-10 findings that most affect the decision, ordered by severity, each with its perspective(s) of origin.
3. **Full findings register**: all findings from all perspectives, deduplicated, with original IDs preserved (SEC-, REL-, OPS-, COST-, PERF-, QA-, UX-, GDPR-, AIA-, SOC-, ISO-) and every column the perspectives produced, including Relaxed under, Invariant and Disposition. Leave Disposition empty for the human.
4. **Cross-cutting themes**: patterns spanning perspectives (e.g. "observability is underspecified everywhere").
5. **Trade-off register**: explicit conflicts between perspectives requiring an author decision, with the options and their consequences.
6. **Gaps and questions**: merged from all perspectives, deduplicated.
7. **Recommended conditions for approval**: the concrete spec changes required to move to Pass, if not already there.

Keep the executive section readable by a non-specialist stakeholder. Keep the register precise for the spec author.
