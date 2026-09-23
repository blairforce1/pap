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
| 1.2 | Records carry expected effect. Every intervention has a decision record with a PIP, at least one expected effect and a revisit trigger. | [0001](decisions/0001-process-changes-are-measured-interventions.md) | Nothing yet. Planned: a PR title check where the `process:` type requires a `Record:` footer. |
| 2.1 | Main changes only by pull request. Squash-merged, linear history, review threads resolved, the `tests` check passing; no approving review is required. | [0002](decisions/0002-skills-stop-at-draft-pr.md) | Repository ruleset [`.github/rulesets/main.json`](.github/rulesets/main.json) (`pull_request`, `non_fast_forward`, `required_linear_history`, `required_status_checks`); Claude Code `PreToolUse` hook [`plugins/pap/hooks/hooks.json`](plugins/pap/hooks/hooks.json) routing to [`scripts/guard-branch.sh`](scripts/guard-branch.sh); git `pre-push` via [`lefthook.yml`](lefthook.yml). |
| 2.2 | Skills stop at a draft PR. A skill that writes a phase artefact works on `change/<id>`, commits as it likes, opens a draft PR and stops. It never merges. | [0002](decisions/0002-skills-stop-at-draft-pr.md) | Reaching main without a PR is refused by the rule 2.1 layers. The stop itself is taught in skill text and not checked; nothing refuses `gh pr merge` from a skill. |
| 3.1 | Layers add, never replace. A template layer adds files; it may append a `[*.ext]` section to `.editorconfig` and tool pins to `mise.toml`, and touches nothing else another layer owns. | [0003](decisions/0003-template-layers-compose-additively.md) | Nothing yet. Planned: the sync tool refuses a layer that writes a file another layer owns. |
