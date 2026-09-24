# Rules

The enforceable rules of the process, one line each. The process document
says what must happen; a rule is the part of that which a check can refuse.
Each rule names the decision record that introduced it and what enforces it
today. "Nothing yet" is an honest entry and an open item, not a reason to
leave the rule out.

A rule is numbered by the decision that introduced it, then by sequence
within that decision: 2.1 is the first rule from decision 0002. Numbers are
never reused; a withdrawn rule keeps its line and names the decision that
withdrew it. This file is an index of the decision records, not a process
artefact in its own right: a new rule arrives with its decision record, and
a change to the enforcement column arrives with the check that ships.

| Rule | Statement | Decision | Enforced by |
|---|---|---|---|
| 1.1 | Interventions are tagged. A change under `process/` ships only in a tagged release; app repos pin the tag and every emitted event carries it. | [0001](decisions/0001-process-changes-are-measured-interventions.md) | Nothing yet. Planned: `pap emit` refuses to run against an untagged process version. |
| 1.2 | Records carry expected effect. Every intervention has a decision record with a PIP, at least one expected effect and a revisit trigger. | [0001](decisions/0001-process-changes-are-measured-interventions.md) | Partly: the reusable `pr-checks` workflow ([`.github/workflows/pr-checks.yml`](.github/workflows/pr-checks.yml), decision [0004](decisions/0004-pull-request-checks-are-answered.md)) refuses a `process:` title without a `Record: NNNN` line. It reports and does not block until it is a required check. The expected-effect half is taught in the record template and not checked. |
| 2.1 | Main changes only by pull request. Squash-merged, linear history, review threads resolved, the `tests` check passing; no approving review is required. | [0002](decisions/0002-skills-stop-at-draft-pr.md) | Repository ruleset [`.github/rulesets/main.json`](.github/rulesets/main.json) (`pull_request`, `non_fast_forward`, `required_linear_history`, `required_status_checks`); Claude Code `PreToolUse` hook [`plugins/pap/hooks/hooks.json`](plugins/pap/hooks/hooks.json) routing to [`scripts/guard-branch.sh`](scripts/guard-branch.sh); git `pre-push` via [`lefthook.yml`](lefthook.yml). |
| 2.2 | Skills stop at a draft PR. A skill that writes a phase artefact works on `change/<id>`, commits as it likes, opens a draft PR and stops. It never merges. | [0002](decisions/0002-skills-stop-at-draft-pr.md) | Reaching main without a PR is refused by the rule 2.1 layers. The stop itself is taught in skill text and not checked; nothing refuses `gh pr merge` from a skill. |
| 3.1 | Layers add, never replace. A template layer adds files; it may append a `[*.ext]` section to `.editorconfig`, ships its tool pins and hooks as its own `.config/mise/conf.d/` and `.config/lefthook/` files, and touches nothing else another layer owns. | [0003](decisions/0003-template-layers-compose-additively.md) | Nothing yet. Planned: the sync tool refuses a layer that writes a file another layer owns. |
| 4.1 | Checks are answered. Every box in a pull request's Checks section is ticked, or has a one-line reason on the line below it. | [0004](decisions/0004-pull-request-checks-are-answered.md) | The reusable `pr-checks` workflow via [`.github/workflows/pr-checks.yml`](.github/workflows/pr-checks.yml). Reports, does not block, until `pr-checks / checks` is a required check. |
| 4.2 | Generated content is declared. A pull request that shows generated content ticks the provenance box, and a ticked box has provenance recorded: a `Co-authored-by` trailer on a commit or a `Provenance:` line. | [0004](decisions/0004-pull-request-checks-are-answered.md) | The reusable `pr-checks` workflow, as 4.1. It sees an Anthropic co-author trailer or a "Generated with" line, not undeclared content. |
| 5.1 | Agents do not bypass hooks. An agent session never sets `LEFTHOOK` or `LEFTHOOK_EXCLUDE`, passes `--no-verify` or `commit -n`, or sets `core.hooksPath` in a repository that adopts PAP; the hatches are for humans. | [0005](decisions/0005-agent-sessions-do-not-bypass-hooks.md) | Claude Code `PreToolUse` hook [`plugins/pap/hooks/guard-route.sh`](plugins/pap/hooks/guard-route.sh) via [`hooks.json`](plugins/pap/hooks/hooks.json), from pap plugin 0.3.0. It does not follow `bash -c`, `eval` or scripts. Server-side backstop in repositories built from the base template: its `security` workflow ([`templates/base/.github/workflows/security.yml`](templates/base/.github/workflows/security.yml)) re-runs `mise run check` on every pull request, so a skipped hook's checks still run. It catches what the hooks would have refused, not the bypass itself. |
