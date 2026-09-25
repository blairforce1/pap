# Coverage

Which part of the process each principle and section of
[`process/personal-agentic-process.md`](process/personal-agentic-process.md)
has behind it: a rule in [`rules.md`](rules.md), a hypothesis in
[`product/backlog.md`](product/backlog.md), or an explicit deferral. `pap coverage`
reads this file and reports every ID in the process document that has none,
and every target here that names a rule or hypothesis that does not exist.

One line per ID: `- <id>: <target>, <target>`, where a target is
`rule <n>` or `H-<nnn>`. `deferred: <reason>` is the last target and takes
the rest of the line. An ID with no line is uncovered.

- P-intent: rule 11.2, H-005
- P-merge-trigger: rule 2.1, rule 2.2
- P-provenance: rule 4.2
- P-returns: H-004
- P-attribution: H-005
- P-verification: rule 4.1
- P-experiments: rule 1.1, rule 1.2, rule 10.1, H-010
- P-gates: rule 4.1, rule 5.1
- S-invariants: rule 4.1
- S-backlog: rule 11.1
- S-change: rule 11.2
- S-phases: rule 2.1, rule 2.2
- S-phase-measures: H-004
- S-intent: rule 11.2
- S-code-review: H-007
- S-returns: H-004
- S-findings: H-005
- S-interventions: rule 1.1, rule 1.2, rule 10.1
- S-evals: H-010
- S-cross-measures: H-004, H-006
- S-cadence: H-008
- S-drift: H-008
