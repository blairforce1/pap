# spec-review

A multi-perspective review board for design specifications. Each skill reviews a
spec from one perspective and returns a findings table. `spec-review-full`
orchestrates the set and consolidates the results.

The skills review designs only, never code. They are read-only: every skill
disallows editing, shell, and network tools. None of the compliance skills is
legal advice or a conformity assessment.

This plugin is phase 3 (spec review) of the Personal Agentic Process, but it
does not depend on the `pap` plugin and works on any design document.

## Skills

| Skill | Perspective |
|-------|-------------|
| `spec-review-full` | Orchestrates every perspective below and consolidates findings |
| `spec-review-security` | Threats, trust boundaries, secrets, authn/authz |
| `spec-review-reliability` | Resilience, availability, failure modes |
| `spec-review-operations` | Operability, observability, day-2 readiness |
| `spec-review-cost` | Cost optimisation (Azure Well-Architected Framework pillar) |
| `spec-review-performance` | Performance efficiency, scalability, capacity |
| `spec-review-qa` | Testability and requirements quality |
| `spec-review-ux` | Usability and user journeys |
| `spec-review-gdpr` | EU and UK GDPR data protection by design |
| `spec-review-ai-act` | EU AI Act (Regulation (EU) 2024/1689) obligations |
| `spec-review-soc2` | SOC 2 Trust Services Criteria audit readiness |
| `spec-review-iso27001` | ISO/IEC 27001:2022 ISMS fit and Annex A controls |
| `spec-review-solvency2` | Solvency II / Solvency UK for insurance systems |

## Usage

Ask for a single perspective, for example "give this spec a security review",
or for the whole board with "run a full review of this design". The full review
selects the perspectives that apply to the spec, runs each one (in parallel
where the environment allows subagents), and returns one consolidated findings
table with duplicates merged and severities reconciled.

The orchestrator locates the perspective skills through `${CLAUDE_PLUGIN_ROOT}`,
so all thirteen must ship together in this plugin.
