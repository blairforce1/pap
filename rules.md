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

### 1.1 Interventions are tagged

A change under `process/` ships only in a tagged release; app repos pin the tag and every emitted event carries it.

- Decision: [0001](decisions/0001-process-changes-are-measured-interventions.md)
- Enforced by: Nothing yet. Planned: `pap emit` refuses to run against an untagged process version.

### 1.2 Records carry expected effect

Every intervention has a decision record with a PIP, at least one expected effect and a revisit trigger.

- Decision: [0001](decisions/0001-process-changes-are-measured-interventions.md)
- Enforced by: Partly: the reusable `pr-checks` workflow ([`.github/workflows/pr-checks.yml`](.github/workflows/pr-checks.yml), decision [0004](decisions/0004-pull-request-checks-are-answered.md)) refuses a `process:` title without a `Record: NNNN` line. It is a required check since #42. The expected-effect half is taught in the record template and not checked.

### 2.1 Main changes only by pull request

Squash-merged, linear history, review threads resolved, the `tests` check passing; no approving review is required.

- Decision: [0002](decisions/0002-skills-stop-at-draft-pr.md)
- Enforced by: Repository ruleset [`.github/rulesets/main.json`](.github/rulesets/main.json) (`pull_request`, `non_fast_forward`, `required_linear_history`, `required_status_checks`); Claude Code `PreToolUse` hook [`plugins/pap/hooks/hooks.json`](plugins/pap/hooks/hooks.json) routing to [`scripts/guard-branch.sh`](scripts/guard-branch.sh); git `pre-push` via [`lefthook.yml`](lefthook.yml).

### 2.2 Skills stop at a draft PR

A skill that writes a phase artefact works on `change/<id>`, commits as it likes and stops at or before the change's one draft PR, which `/change` opens (0020). It never merges.

- Decision: [0002](decisions/0002-skills-stop-at-draft-pr.md); narrowed by [0020](decisions/0020-intent-is-accepted-by-a-recorded-yes-on-the-change-branch.md): the skills that write `intent.md` and `spec.md` commit and hand on, and `/change` opens the one draft PR
- Enforced by: Reaching main without a PR is refused by the rule 2.1 layers. The stop itself is taught in skill text and not checked; nothing refuses `gh pr merge` from a skill.

### 3.1 Layers add, never replace

A template layer adds files; it may append a `[*.ext]` section to `.editorconfig`, ships its tool pins and hooks as its own `.config/mise/conf.d/` and `.config/lefthook/` files, and touches nothing else another layer owns.

- Decision: [0003](decisions/0003-template-layers-compose-additively.md)
- Enforced by: [`scripts/assemble.sh`](scripts/assemble.sh), run by `pap init` and `pap sync` ([`bin/pap`](bin/pap), decision [0008](decisions/0008-template-sync-by-assemble-and-merge-file.md)), refuses a layer that writes a file another layer owns and writes nothing.

### 4.1 Checks are answered

Every box in a pull request's Checks section is ticked, or has a one-line reason on the line below it. In a repository without `.github/risk.yml`, a pull request touching a protected path carries an `Approved-by: @login <sha>` line naming a CODEOWNERS owner of every protected file and the head it approves; a reason does not stand in for it, and a line naming any other head is stale.

- Decision: [0004](decisions/0004-pull-request-checks-are-answered.md), [0012](decisions/0012-protected-paths-need-an-owners-approved-by-line.md), [0013](decisions/0013-an-approval-is-for-one-commit.md); narrowed by [0016](decisions/0016-risk-labels-and-an-owner-reviewed-label-replace-approved-by.md)
- Enforced by: The reusable `pr-checks` workflow via [`.github/workflows/pr-checks.yml`](.github/workflows/pr-checks.yml), a required check since #42. It cannot tell who typed an `Approved-by:` line; [`plugins/pap/hooks/guard-route.sh`](plugins/pap/hooks/guard-route.sh) refuses an agent's `gh` write of a pull request body that carries one.

### 4.2 Generated content is declared

A pull request that shows generated content ticks the provenance box, and a ticked box has provenance recorded: a `Co-authored-by` trailer on a commit or a `Provenance:` line.

- Decision: [0004](decisions/0004-pull-request-checks-are-answered.md)
- Enforced by: The reusable `pr-checks` workflow, as 4.1. It sees an Anthropic co-author trailer or a "Generated with" line, not undeclared content.

### 5.1 Agents do not bypass hooks

An agent session never sets `LEFTHOOK` or `LEFTHOOK_EXCLUDE`, passes `--no-verify` or `commit -n`, or sets `core.hooksPath` in a repository that adopts PAP; the hatches are for humans.

- Decision: [0005](decisions/0005-agent-sessions-do-not-bypass-hooks.md)
- Enforced by: Claude Code `PreToolUse` hook [`plugins/pap/hooks/guard-route.sh`](plugins/pap/hooks/guard-route.sh) via [`hooks.json`](plugins/pap/hooks/hooks.json), from pap plugin 0.3.0. It does not follow `bash -c`, `eval` or scripts. Server-side backstop in repositories built from the base template: its `security` workflow ([`templates/base/.github/workflows/security.yml`](templates/base/.github/workflows/security.yml)) re-runs `mise run check` on every pull request, so a skipped hook's checks still run. It catches what the hooks would have refused, not the bypass itself.

### 7.1 Every pin is kept current or named as manual

A version a template layer pins is read by the base `.github/renovate.jsonc`, through a Renovate manager or a custom manager in that layer's section, or the base README's "Dependency updates" lists it as updated by hand.

- Decision: [0007](decisions/0007-dependency-updates-by-renovate.md)
- Enforced by: Nothing yet. Planned: the sync tool runs a Renovate extract on an assembled repository and refuses a pin that is neither extracted nor listed.

### 10.1 Revisit triggers are typed

A record's Revisit line starts with `after <n> change PRs` (optionally `from #<pr>`), `on <YYYY-MM-DD>` or `when <condition>`, and a due revisit is reported at the end of every change.

- Decision: [0010](decisions/0010-revisits-are-typed-and-counted.md)
- Enforced by: Partly: `pap revisits` ([`bin/pap`](bin/pap)) reports an untyped line as unknown and a due one as due, and the `/change` skill prints the due ones in its report. It reports and never blocks; nothing refuses an untyped line at merge.

### 11.1 Git is the source of truth

Everything actionable is merged in git; issues, Projects and chats are sources that link to it and are never read as canonical.

- Decision: [0011](decisions/0011-git-is-the-source-of-truth.md)
- Enforced by: Nothing yet.

### 11.2 A change's id is its slug: branch `change/<slug>`, folder `changes/<slug>/`

Its `intent.md` names a source (an issue URL, or `none`) and a hypothesis (`H-NNN`, or `reactive: <reason>`).

- Decision: [0011](decisions/0011-git-is-the-source-of-truth.md)
- Enforced by: Partly: the `/change` skill names the branch and the `Change:` line by slug. Planned: `pr-checks` checks the source and hypothesis lines.

### 15.1 Heavy builds are capped and serialised per machine

An Android, iOS or Mac Catalyst target, a Release configuration or an AOT build holds the machine's one heavy-build lock, `${XDG_RUNTIME_DIR:-/tmp}/pap-heavy-build.lock`, while it runs, and on battery runs with at most two MSBuild nodes (`-m:2`).

- Decision: [0015](decisions/0015-agent-sessions-share-one-machines-power-and-cores.md)
- Enforced by: Nothing yet. The .NET layer's [`templates/dotnet/scripts/heavy-build.sh`](templates/dotnet/scripts/heavy-build.sh) does both for a build run through it and logs each one to `${XDG_STATE_HOME:-$HOME/.local/state}/pap/heavy-builds.log`, and the `/change` skill sends heavy builds through it; nothing refuses a bare `dotnet build` of a heavy target. Planned: the `PreToolUse` hook refuses an agent's bare `dotnet build` or `dotnet publish` of a heavy target in an adopting repository and names the script.

### 16.1 High risk waits for the owner's `owner-reviewed` label

In a repository with `.github/risk.yml` on its base branch, every pull request carries exactly one of `risk:high`, `risk:medium` or `risk:low`, computed from its diff, and a `risk:high` pull request merges only with the `owner-reviewed` label, added by a CODEOWNERS owner (rule 23.2), which any push removes. The owner may add the label with `/pap:reviewed <PR#> [sha7+]`; agents never invoke it.

- Decision: [0016](decisions/0016-risk-labels-and-an-owner-reviewed-label-replace-approved-by.md)
- Enforced by: the reusable `pr-checks` workflow in blairforce1/.github (blairforce1/.github#13), which sets the label, keeps the review-focus comment, removes `owner-reviewed` on a push and fails a `risk:high` pull request without it, from a caller on `pull_request_target` so a pull request cannot edit its own check. The skill: `disable-model-invocation: true` in its frontmatter, so only a person can invoke it; the hook below refuses an agent's own `gh pr edit --add-label owner-reviewed` as before.

### 16.2 Agents never add `owner-reviewed`, never write `Approved-by:`, and never merge

The owner's review is the owner's act: an agent session adds no `owner-reviewed` label, writes no `Approved-by:` line (rule 4.1, for repositories still on 0012), and merges no pull request.

- Decision: [0016](decisions/0016-risk-labels-and-an-owner-reviewed-label-replace-approved-by.md), [0012](decisions/0012-protected-paths-need-an-owners-approved-by-line.md)
- Enforced by: [`plugins/pap/hooks/guard-route.sh`](plugins/pap/hooks/guard-route.sh) refuses an agent's pull request body carrying an `Approved-by:` line, an agent's `gh` call adding `owner-reviewed` (`gh pr` or `gh issue` `edit --add-label` or `create --label`, `gh api` on an issue's labels), and `gh pr merge` or `gh api -X PUT` on `pulls/<n>/merge`. GraphQL, `bash -c` and `eval` are not followed; the hook's header lists its limits.

### 17.1 Every scenario is bound or pending

A scenario in `features/` carries `@id:<slug>-<n>`, and is named by a passing test (traced) or passes as an executed scenario, or carries `@pending:<slug>`.

- Decision: [0017](decisions/0017-specs-carry-executable-scenarios-in-a-domain-vocabulary.md)
- Enforced by: Nothing yet. Planned: a binding check in the base layer's `tests` workflow fails a scenario that is neither bound nor pending.

### 17.2 A change closes with no pending scenarios

A change's `findings.md` merges only when no scenario carries `@pending:<slug>` for that change.

- Decision: [0017](decisions/0017-specs-carry-executable-scenarios-in-a-domain-vocabulary.md)
- Enforced by: Nothing yet. Planned: the binding check refuses a pull request that adds `changes/<slug>/findings.md` while that slug's scenarios are pending.

### 17.3 Scenarios change only in the spec phase

A pull request that edits `features/` changes a `changes/<slug>/spec.md` in the same diff or carries the `return:spec` label.

- Decision: [0017](decisions/0017-specs-carry-executable-scenarios-in-a-domain-vocabulary.md)
- Enforced by: Nothing yet. Planned: the reusable `pr-checks` workflow refuses it.

### 17.4 The class sets whether a spec has scenarios

The spec of a feature, security-sensitive or bugfix change adds or changes at least one scenario; a bugfix's scenario fails before the fix.

- Decision: [0017](decisions/0017-specs-carry-executable-scenarios-in-a-domain-vocabulary.md)
- Enforced by: Nothing yet. Taught by the `/spec` skill ([`plugins/pap/skills/spec/SKILL.md`](plugins/pap/skills/spec/SKILL.md)), which writes them (0021). Planned: `pr-checks` refuses a spec pull request of those classes that touches no scenario.

### 18.1 The project-manager session opens, approves and merges nothing

A session that launches cycles opens no change pull request (process housekeeping the human asks for excepted), adds no `owner-reviewed`, writes no `Approved-by:`, merges nothing, writes no GitHub or repository settings, and does no act a hook refused a cycle.

- Decision: [0018](decisions/0018-a-project-manager-session-launches-cycles-and-keeps-the-tracker.md), with [0002](decisions/0002-skills-stop-at-draft-pr.md) and [0016](decisions/0016-risk-labels-and-an-owner-reviewed-label-replace-approved-by.md)
- Enforced by: Partly: [`plugins/pap/hooks/guard-route.sh`](plugins/pap/hooks/guard-route.sh) refuses the label, the `Approved-by:` body and the merge from any agent session (rule 16.2), the project-manager session included. `/pap:pm` ([`plugins/pap/skills/pm/SKILL.md`](plugins/pap/skills/pm/SKILL.md), decision [0025](decisions/0025-pap-runs-as-the-project-manager-by-default.md)) has no step that opens a pull request, labels or merges; its `launch` names `pap:cycle` or `pap:cycle-mechanical` (decision 0024) as the agent of the cycle it starts; and the session's own writes are bound by rule 25.2. Still escaping: nothing refuses its `gh pr create` or a settings write, or a `/change` run by an agent of another type. Whether a server gate should is open for the server-gate intent (backlog H-017).

### 18.2 A cycle is launched after a restated yes

Before a cycle is launched, the event log carries the ask restated in one line and the human's yes to it.

- Decision: [0018](decisions/0018-a-project-manager-session-launches-cycles-and-keeps-the-tracker.md)
- Enforced by: `/pap:pm launch` ([`plugins/pap/skills/pm/pap-pm.sh`](plugins/pap/skills/pm/pap-pm.sh), decision [0025](decisions/0025-pap-runs-as-the-project-manager-by-default.md)) refuses, and no cycle starts, when the event log has no `restate` event for the slug (exit 11) or when the owner did not type `/pap:pm launch <slug>` in that session since the slug's last launch, or the typed line was used up by a refused attempt (exit 10). The typed command is the yes: [`plugins/pap/hooks/pm-log.sh`](plugins/pap/hooks/pm-log.sh) records it from Claude Code's `UserPromptSubmit` hook in `launches.log`, under pap's state directory, where the PM session's Edit and Write are refused (rule 25.2), and one typed line serves one launch. On a pass the script writes the `yes` and `launch` events and commits the tracker before the cycle starts. Still escaping: the `restate` line is appended by the PM itself, so nothing checks its text against the ask; a shell command can write `launches.log`; nothing refuses a cycle spawned with the Agent tool and no `/pap:pm launch`.

### 18.3 The tracker is committed on every event

The state file and the event log are committed on every launch, postmortem, message to a cycle, pause, relaunch, merge, decision and audit, and only the project-manager session writes them.

- Decision: [0018](decisions/0018-a-project-manager-session-launches-cycles-and-keeps-the-tracker.md)
- Enforced by: Partly: [`plugins/pap/skills/pm/pap-pm.sh`](plugins/pap/skills/pm/pap-pm.sh) (decision [0025](decisions/0025-pap-runs-as-the-project-manager-by-default.md)). `/pap:pm start` stops on an uncommitted tracker (exit 4) until the owner commits or discards it, and `/pap:pm launch` commits the tracker before a cycle starts. `pap-pm.sh commit` commits the tracker and pushes it when it has a remote. One session holds the tracker at a time, by a lock every command takes. Still by hand: `launch` writes the `yes` and `launch` events and `start` the `start` event; the PM appends every other event line itself and then runs `commit`, so nothing makes it commit on each one. Still escaping: nothing refuses a sub-agent's shell write to the tracker. Planned: `/pap:pm event` and `relaunch` (backlog H-012).

### 18.4 An audit every five merged change PRs and at every relaunch

The event log carries an audit within five merged change PRs of the last one and one at every relaunch, and every finding names a fix.

- Decision: [0018](decisions/0018-a-project-manager-session-launches-cycles-and-keeps-the-tracker.md)
- Enforced by: Nothing yet. Planned: `/pap:pm` reports an overdue audit on every `event`, as `pap revisits` reports a due revisit (rule 10.1); it reports and never blocks.

### 18.5 A general lesson reaches PAP only as a change

Every rule an audit writes is classified as project or general. A general one goes on the tracker's PAP candidates list (the rule, the miss as numbers, the date), due at three candidates or when the oldest is 30 days old, and reaches PAP only through a cycle's `/change` there after the human's yes, rewritten without its project. The project-manager session writes nothing in PAP.

- Decision: [0018](decisions/0018-a-project-manager-session-launches-cycles-and-keeps-the-tracker.md), with [0002](decisions/0002-skills-stop-at-draft-pr.md)
- Enforced by: Nothing yet. Planned: `/pap:pm audit` records no finding whose rule is unclassified and files a general one on the list; `/pap:pm` reports a due list on every `event`, as rule 18.4's overdue audit, and never blocks. The upstream diff gets what every PAP pull request gets (gitleaks, pr-checks) and nothing more.

### 18.6 Three send-backs end a cycle

After the third message asking for changes since its first report, a cycle stops and starts its reply with `ASK:`, and the event log carries the return to the human. A fix round re-checks the diff since the last report only and repeats no earlier finding.

- Decision: [0018](decisions/0018-a-project-manager-session-launches-cycles-and-keeps-the-tracker.md)
- Enforced by: Nothing yet. Planned: `/pap:pm event` counts the messages to a cycle after its first report and refuses to log a fourth without a decision event beside it; the `pap:cycle` agent definition carries the `ASK:` line and the diff-since-last-report rule.

### 18.7 Every brief carries a budget

A cycle's brief names its budget in tokens or wall time, set from the last audit's medians; at the cap the cycle stops at its nearest safe point and ends with `PAUSED:` and what is left.

- Decision: [0018](decisions/0018-a-project-manager-session-launches-cycles-and-keeps-the-tracker.md)
- Enforced by: Partly: `/pap:pm launch` ([`plugins/pap/skills/pm/pap-pm.sh`](plugins/pap/skills/pm/pap-pm.sh)) refuses a brief with no `Budget:` line that carries a number and tokens or wall time (exit 14), and the `pap:cycle` agent definition carries the stop at the cap (decision 0024). Nothing checks that the number came from an audit's medians. Planned: `/pap:pm audit` reports the medians the next budgets are set from.

### 18.8 Every brief names its route and why

A cycle's brief starts with its route, `/intent <slug> <class>` or `/change <slug> <class> [Record: NNNN]`, and says in one line which item of rule 20.2 decided it; the human can overrule the route.

- Decision: [0018](decisions/0018-a-project-manager-session-launches-cycles-and-keeps-the-tracker.md), with [0020](decisions/0020-intent-is-accepted-by-a-recorded-yes-on-the-change-branch.md)
- Enforced by: `/pap:pm launch` ([`plugins/pap/skills/pm/pap-pm.sh`](plugins/pap/skills/pm/pap-pm.sh)) refuses a missing brief, or one whose first line is not `/intent <slug> <class>` or `/change <slug> <class>` for the slug launched and one of the seven classes (exit 12), and one whose second line is not `Rule 20.2: item 1`, `item 2` or `exempt: <which>` (exit 13). It checks the shape, not whether the route is the right one; the human's overrule is not checked.

### 19.1 A cold review runs before a draft pull request

Before `/change` opens its draft pull request, unless the change is mechanical as decision 0024 defines it, a read-only subagent given only the brief and the branch diff reviews it, with `/code-review low` against the worktree where that skill exists; each finding is fixed or answered, and Verification states the review ran, its level, its findings, the fixes and any left with the reason.

- Decision: [0019](decisions/0019-a-cold-review-runs-before-every-draft-pr.md), amended by [0024](decisions/0024-cycles-run-as-slim-plugin-agents.md)
- Enforced by: Nothing yet. Taught by the `/change` skill ([`plugins/pap/skills/change/SKILL.md`](plugins/pap/skills/change/SKILL.md), step 5); nothing refuses a pull request whose Verification lacks the row.

### 20.1 Intent is accepted by a recorded yes, before the spec and the code

A change that needs one (rule 20.2) has a `changes/<slug>/intent.md` that records the human's yes to the intent restated in process 5.3's sections (`accepted-by:`, `accepted-on:`) and is committed on `change/<slug>` before `spec.md` and before any code; the one pull request carries them in that order, and an edit to `intent.md` after `spec.md` exists is intent churn, with its reason in the commit message.

- Decision: [0020](decisions/0020-intent-is-accepted-by-a-recorded-yes-on-the-change-branch.md)
- Enforced by: Nothing yet. Taught by the `/intent` skill ([`plugins/pap/skills/intent/SKILL.md`](plugins/pap/skills/intent/SKILL.md)), which writes no file without the yes, and by the `/change` skill's step 2, which reads the file as the brief's intent. Planned: the reusable `pr-checks` workflow checks that a pull request with a `Change:` line carries `changes/<slug>/intent.md` with the acceptance lines and a hypothesis, and that its first commit precedes `spec.md`'s.

### 20.2 A change starts with `/intent` when it needs one, and not otherwise

A change that needs an intent starts with `/intent`, then `/spec` as its class asks (a spike has none); one that does not starts with `/change`. It needs it when either holds:

1. it adds or changes something a user, operator or adopter sees, beyond what a decision record, rule, accepted spec or doc already states: a command, a flag, an output, a file an adopting repository receives, a rule, or a check that can refuse;
2. the brief has to choose between two or more designs, or leaves a question open, that no decision record, rule, accepted spec or message from the human settles.

It does not when every part of it is one of: the tracker; a rename that leaves every command, flag, output and shipped file as it was; docs that describe what already exists and change no text in `rules.md` or `decisions/`; a version bump or a template sync; a change to tests only; a fix that restores behaviour a record, rule, spec or doc already states; a change to `rules.md` or `decisions/` that records a decision the human has already made in a message (a revisit Result they answered, a dated note, or an amendment they approved), where the brief quotes or cites that approval. A change with any part outside that list is tested against items 1 and 2.

The project-manager session makes the call and carries it in the brief's first line (rule 18.8); the human can overrule it before launch or at review.

- Decision: [0020](decisions/0020-intent-is-accepted-by-a-recorded-yes-on-the-change-branch.md), with [0021](decisions/0021-a-spec-is-accepted-after-review-with-its-operation-designed-in.md)
- Enforced by: Partly: `/pap:pm launch` ([`plugins/pap/skills/pm/pap-pm.sh`](plugins/pap/skills/pm/pap-pm.sh)) refuses a brief whose first line names no route (exit 12) or whose second line names no item of this rule (exit 13), and the cycle's pull request carries both as its `Route:` line (rule 25.5). Nothing judges the call itself: the project-manager session makes it and no hook checks it. Nothing binds a change that does not pass through `/pap:pm launch`: a `/change` the human invokes directly, a solo session, or a session not started by `pap claude`. Planned: the `pr-checks` server gate (backlog H-017).

### 21.1 A spec is accepted by a recorded yes after review, before the code

A change started with `/intent` (rule 20.2) has a `changes/<slug>/spec.md`, as its class asks, that records the human's yes (`accepted-by:`, `accepted-on:`), given after every spec review finding has a disposition recorded in `changes/<slug>/reviews/`, and is committed on `change/<slug>` after `intent.md` and before any code; the one pull request carries them in that order, and a commit to `spec.md` after code exists is spec rework, with its reason in the commit message.

- Decision: [0021](decisions/0021-a-spec-is-accepted-after-review-with-its-operation-designed-in.md), with [0020](decisions/0020-intent-is-accepted-by-a-recorded-yes-on-the-change-branch.md)
- Enforced by: Nothing yet. Taught by the `/spec` skill ([`plugins/pap/skills/spec/SKILL.md`](plugins/pap/skills/spec/SKILL.md)), which writes no acceptance line without the yes, and by the `/change` skill's step 3, which builds to the spec. Planned: the reusable `pr-checks` workflow checks that a pull request with a `Change:` line of class feature, infra, security-sensitive or bugfix carries `spec.md` with the acceptance lines and a `reviews/` file, and that `spec.md`'s first commit follows `intent.md`'s and precedes the first commit outside `changes/`, `features/` and `product/`.

### 21.2 A feature, infra or security-sensitive spec designs its operation

The `spec.md` of a feature, infra or security-sensitive change has an Operations section with Signals (one per success measure in the intent), Good (the control band and its window), Wrong (what a breach looks like, how fast it is noticed, the first checks), Undo (revert the merge, a flag off or a config rollback, with the steps for anything outside git) and at least one operational scenario in Given/When/Then; the pull request's "How to revert" is the Undo.

- Decision: [0021](decisions/0021-a-spec-is-accepted-after-review-with-its-operation-designed-in.md)
- Enforced by: Nothing yet. Taught by the `/spec` skill ([`plugins/pap/skills/spec/SKILL.md`](plugins/pap/skills/spec/SKILL.md), step 5) and the `/change` skill's step 6, whose body template carries "How to revert". Planned: the reusable `pr-checks` workflow refuses a pull request of those classes whose `spec.md` lacks the four headings.

### 22.1 No branch takes a force push

No push to any branch rewrites its history; a branch behind main merges main. The owner overrides on purpose with a force push from their own terminal, which the `all-branches` ruleset's owner bypass (rule 23.3) lets through.

- Decision: [0022](decisions/0022-no-branch-takes-a-force-push.md); the override amended by [0023](decisions/0023-agents-act-on-github-as-their-own-app.md): once agents push as the agent app, the owner's bypass of rule 23.3 replaces disabling the ruleset
- Enforced by: Repository ruleset [`.github/rulesets/all-branches.json`](.github/rulesets/all-branches.json) (`non_fast_forward` on `~ALL`, the owner as its one bypass actor, Renovate's and Dependabot's branches excluded), applied by `pap repo apply`; `pap repo status` reports it disabled or changed as drift ([`scripts/repo-sync.sh`](scripts/repo-sync.sh)). Claude Code `PreToolUse` hook [`plugins/pap/hooks/guard-route.sh`](plugins/pap/hooks/guard-route.sh) running [`scripts/guard-branch.sh`](scripts/guard-branch.sh) `push-args`, which refuses an agent's `git push` with `--force`, `-f`, `--force-with-lease`, `--force-if-includes`, `--mirror` or a `+<refspec>`. It does not follow `bash -c`, `eval`, scripts or a push refspec in git config, and on `renovate/` and `dependabot/` branches it is the only enforcer; nothing refuses an agent disabling the ruleset through `gh api`.

### 23.1 An agent session acts on GitHub as the agent app

In a repository that adopts PAP, every push, pull request, label and comment an agent session makes is made with the agent app's installation token, minted on demand by `pap agent-token`; the owner's stored sign-in is used by a person at a terminal, by `/pap:reviewed` and `/pap:accept`, and by nothing else.

- Decision: [0023](decisions/0023-agents-act-on-github-as-their-own-app.md)
- Enforced by: The `gh` shim [`scripts/shim/gh`](scripts/shim/gh), first on `PATH` in agent shells because `pap claude` puts pap's own `scripts/shim` there (Claude Code's Bash tool runs commands non-interactively, so the base layer's mise `[env]` path reaches only interactive shells and `mise exec`/`mise run`), in a session started by `pap claude` handles every `gh` call in every directory, adopting or not: it sets `GH_TOKEN` from `pap agent-token --repo` ([`bin/pap`](bin/pap)), a token scoped to the one repository the call names (`-R`/`--repo`, `GH_REPO`, a `gh api repos/<owner>/<name>` endpoint, else `origin`), and answers git's `gh auth git-credential get` itself for the repository in the request's path (`pap claude` sets, at git's command scope, an empty github.com helper then `!gh auth git-credential`, so the shim is git's only helper there whatever the config files hold, and `credential.https://github.com.useHttpPath`), so `gh` and git's pushes and fetches act as the app; a call with no repository, a repository the installation does not cover, another host, or a failed mint is refused with the reason, a refused credential tells git `quit=1`, the real `gh` never runs from the shim without a token, the agent directory with `CLAUDECODE` unset counting as the session (gh's keyring fallback, [`docs/agent-identity-security.md`](docs/agent-identity-security.md#the-finding-pushes-as-you-outside-adopting-repositories)), and in a dev container with no key it steps aside, by the record. `pap doctor` checks the key, the client id, that the installation covers this repository (a token scoped to it mints), an HTTPS origin, `gh` by name as git's credential helper, in an agent shell that `gh` resolves to the shim, and, as a warning, the global `insteadOf` rewrite of GitHub's SSH URLs that `pap agent-setup` offers. Claude Code `PreToolUse` hook [`plugins/pap/hooks/guard-route.sh`](plugins/pap/hooks/guard-route.sh) running [`scripts/guard-branch.sh`](scripts/guard-branch.sh) `push-args` refuses an agent's `git push` to an SSH remote in an adopting repository, naming the `git remote set-url` fix. The same hook refuses, in an adopting repository, an agent's `gh` run by a path, absolute or relative (also after `env`, `command` or `exec`), or with a `PATH=` assignment, which skip the shim; `command gh` and `env gh` find the shim and pass. None of these binds a session not started with `pap claude` outside an adopting repository whose project does not adopt PAP: its `PATH` lacks the shim, so a plain `gh` is the real one with your own sign-in (`pap doctor` reports it as drift); in an adopting repository, or anywhere in a session whose project adopts PAP, rule 23.4's hook check refuses its `gh` and its git calls to GitHub. Nor do they bind a `gh` run with both `CLAUDECODE` unset and `GH_CONFIG_DIR` changed (`env -i` drops both), a `gh` reached through `bash -c`, `eval`, a script, a path the hook cannot parse or a renamed link, or a git credential helper other than `gh` by name (`pap doctor` reports one). Each of those reaches the real `gh`, which with an empty agent directory still answers from the owner's unkeyed keyring entry; [`docs/agent-identity-security.md`](docs/agent-identity-security.md) has the threat model. Planned: rules 23.2 and 23.3 add GitHub's own enforcement.

### 23.2 `owner-reviewed` counts only when an owner added it

A `risk:high` pull request passes only when the latest `labeled` event for `owner-reviewed`, after any `unlabeled`, has an actor of type `User` whose login is an owner in the base branch's `.github/CODEOWNERS`; a label added by a Bot actor, the agent app included, or by any other user, is as if absent and is removed.

- Decision: [0023](decisions/0023-agents-act-on-github-as-their-own-app.md); narrows [0016](decisions/0016-risk-labels-and-an-owner-reviewed-label-replace-approved-by.md)'s rule 16.1
- Enforced by: The reusable `pr-checks` workflow in `blairforce1/.github` (blairforce1/.github#17) reads the pull request's issue events and judges the gate on the latest `owner-reviewed` `labeled` event's actor type and login against the base branch's `CODEOWNERS`, removing any other label and saying why; its `merge-report` job, on the `closed` event the callers trigger on, warns and comments when the pull request's `merged_by` is a Bot.

### 23.3 The owner bypasses the `all-branches` ruleset; the app never does

`.github/rulesets/all-branches.json` lists the owner, and no `Integration`, as its one bypass actor, mode `always`; `main.json` lists none.

- Decision: [0023](decisions/0023-agents-act-on-github-as-their-own-app.md); amends [0022](decisions/0022-no-branch-takes-a-force-push.md)'s override
- Enforced by: `pap repo apply` ([`scripts/repo-sync.sh`](scripts/repo-sync.sh)) writes the owner, resolved from the repository at apply time, as the one actor: `OrganizationAdmin` on an organisation's repository; the owner's `User` on a personal one, or `RepositoryRole` admin if GitHub refuses the `User` with HTTP 422. `pap repo status` reports an `Integration` actor, a missing owner, or any other actor as drift. From a token without administration (the agent app's), status reports the bypass actors `skipped` and apply refuses before writing, so only the owner's run can confirm the list. Still escaping: anyone with admin editing the list in the settings until the next status run.

### 23.4 An agent shell carries no owner sign-in

The owner's `gh` sign-in stays in gh's default directory, its token in the keyring; Claude Code is started with `GH_CONFIG_DIR` set to an agent directory that never holds a sign-in, so no agent shell has a stored GitHub account, and only the scripts of `/pap:reviewed` and `/pap:accept` reach the owner's.

- Decision: [0023](decisions/0023-agents-act-on-github-as-their-own-app.md)
- Enforced by: `pap claude` ([`bin/pap`](bin/pap)) starts Claude Code with `GH_CONFIG_DIR` set to the agent directory (`gh-agent` beside pap's config, made mode 700) and the four GitHub token variables unset. The `gh` shim [`scripts/shim/gh`](scripts/shim/gh) refuses without running `gh`, in an agent session in an adopting repository, unless `GH_CONFIG_DIR` is exactly that directory, and, in every directory of a session started by `pap claude`, when that directory holds a sign-in; in such a session it never runs the real `gh` without a `pap-agent` token, which gh's keyring fallback would otherwise answer with the owner's. Claude Code `PreToolUse` hook [`plugins/pap/hooks/guard-route.sh`](plugins/pap/hooks/guard-route.sh) refuses, in every repository, an agent's command that changes `GH_CONFIG_DIR` (set, `+=`, export, unset, `env -u`, `env -i`), reads gh's keyring entry (service `gh:github.com`, through `secret-tool` or `security`), runs `gh auth token` or `gh auth status -t`, or runs `reviewed.sh` or `accept.sh`; and, in an adopting repository or in any directory of a session whose project (`CLAUDE_PROJECT_DIR`) adopts PAP, an agent's `gh` by name, or `git` `push`, `fetch`, `pull`, `clone`, `ls-remote` or `remote update` to a GitHub HTTPS remote, unless the session was started by `pap claude`: the `gh` first on the hook's `PATH` (Claude Code runs hooks with its own environment) must be the shim, and the shim, run with `PAP_SHIM_CHECK=1`, must accept the session by its own tests (a shim without that check mode fails it), and a dev container with no key passes as the shim steps aside there, judged by `pap agent-key status`, never by a shim in the working tree; a skill's own preprocessing never reaches the hook, so the owner's invocation passes. [`reviewed.sh`](plugins/pap/skills/reviewed/reviewed.sh) and [`accept.sh`](plugins/pap/skills/accept/accept.sh) run `gh` from gh's default directory with the token variables and `CLAUDECODE` unset; accept's push keeps the caller's environment and only its credential helper acts as the owner; their skills keep `disable-model-invocation: true`. `pap doctor` reports the owner's sign-in (never read from an agent shell) and a token in `hosts.yml` instead of the keyring (a warning), the agent directory there, mode 700 and empty, and whether its shell is an agent shell started by `pap claude`. Still escaping, as [`docs/agent-identity-security.md`](docs/agent-identity-security.md) lists: an agent reading the keyring or a file of the owner's by any means the hook cannot parse, since it runs as the same user; a session not started by `pap claude` outside an adopting repository whose project does not adopt PAP, where its `gh` is the real one with the owner's sign-in; a `gh` reached past the shim, which gh's keyring fallback answers with the owner's token; and a `GH_CONFIG_DIR`, `HOME` or `XDG_CONFIG_HOME` changed unparsed, outside an adopting repository, where the shim does not check; the two scripts through `bash -c`, `eval`, a copy or a link; a git hook of accept's push reading the owner helper from `GIT_CONFIG_PARAMETERS`; and the cached installation token, mode 0600 for at most an hour.

### 25.1 `pap claude` starts a project-manager session; `--solo` is the owner's

`pap claude` in an adopting repository starts a PM session; `--solo` is the owner's, and is refused in an agent shell.

- Decision: [0025](decisions/0025-pap-runs-as-the-project-manager-by-default.md)
- Enforced by: `pap claude` ([`bin/pap`](bin/pap)) sets `PAP_MODE` in Claude Code's environment before it starts: `pm` in a repository with an executable `scripts/guard-branch.sh` when the pap plugin is installed, `solo` with `--solo` wherever it is run, and unset otherwise. Without the plugin it says so, prints the install command and starts a session with no mode, never one called PM with no guard. It refuses `--solo` in an agent shell before anything else (`CLAUDECODE` set, `GH_CONFIG_DIR` the agent directory, or the `gh` shim first on `PATH`), and writes one line a start, with the mode and the repository, to `sessions.log` under pap's state directory. Claude Code `PreToolUse` hook [`plugins/pap/hooks/guard-route.sh`](plugins/pap/hooks/guard-route.sh) refuses, in every repository and for every caller, a command that sets or unsets `PAP_MODE` (an assignment, `export` and its kin, `unset`, `env -u`). Still escaping: a session started as plain `claude` has no mode and is bound by none of rules 25.1 to 25.3 (`pap shell-init` routes plain `claude` through `pap claude` in an adopting repository, and `pap doctor` reports a shell without it; planned: the `pr-checks` server gate, backlog H-017); a `PAP_MODE` changed through `bash -c`, `eval` or a script, which the hook does not follow; a second Claude Code started from inside the session.

### 25.2 A project-manager session writes only the PM paths

A PM session writes only the PM paths (`changes/<slug>/**`, `features/<slug>.feature` and `product/**` in its own repository, and the tracker); any other write is refused with the route named. Sub-agents are not bound by it.

- Decision: [0025](decisions/0025-pap-runs-as-the-project-manager-by-default.md)
- Enforced by: Claude Code `PreToolUse` hook [`plugins/pap/hooks/guard-pm.sh`](plugins/pap/hooks/guard-pm.sh) via [`hooks.json`](plugins/pap/hooks/hooks.json), before Edit, Write and NotebookEdit. In a session started in PM mode (`PAP_MODE=pm` in the hook's own environment) it judges a call that carries no agent id, the main session's, by where the path resolves after `..` and symbolic links, from its deepest existing parent when it does not exist yet ([`plugins/pap/hooks/pm-lib.sh`](plugins/pap/hooks/pm-lib.sh)). It lets through a PM path in the session's own repository and its work trees, the tracker, and a file in no adopting repository. It refuses anything else in its own repository, naming the routes; every path in another adopting repository, the PM paths included; the guard's own files (Claude Code's settings, the installed plugins, pap's state and config directories apart from the tracker); and a path it cannot resolve. [`plugins/pap/hooks/guard-route.sh`](plugins/pap/hooks/guard-route.sh) refuses the main session's `git commit` when the work tree it runs in holds any change outside the PM paths, staged, unstaged, or untracked and not ignored. Each refusal is a line in `refusals.log` under pap's state directory. A call with an agent id is a sub-agent's and is never judged, so a cycle is refused no path. [`plugins/pap/hooks/session-start.sh`](plugins/pap/hooks/session-start.sh) checks at every start that the main session's own hook input carries no agent id; if it does, the role opens with a warning that the PM paths are not enforced and the `sessions.log` line ends `:unbound`. Still escaping: a shell command that changes a file and never commits it; a commit or ref written by `git merge`, `cherry-pick`, `revert`, `am`, `rebase`, `commit-tree` or `update-ref`, or through `gh api` to a repository's contents; a write through `bash -c`, `eval` or a script that then commits past the parse; a commit with `--git-dir` or `GIT_DIR`; any other tool that writes a file, an MCP server's for one; any sub-agent, so a PM that has a general-purpose agent make the edit passes; a second Claude Code started from the session without `pap claude`; a session with no mode (rule 25.1). A call the hooks cannot read is let through, said, and logged as an `unread` line.

### 25.3 A project-manager session is given its role and the tracker's state at every start

A PM session is given its role and the tracker's state whenever it starts, and launches and resumes nothing until the owner says.

- Decision: [0025](decisions/0025-pap-runs-as-the-project-manager-by-default.md)
- Enforced by: Partly: Claude Code `SessionStart` hook [`plugins/pap/hooks/session-start.sh`](plugins/pap/hooks/session-start.sh) via [`hooks.json`](plugins/pap/hooks/hooks.json) runs at `pap claude`, on a resume, after a `/clear` and after a compaction. In a PM session it gives the role (at most 80 lines and 8 KB), where the tracker is, whether it is uncommitted, and the state file's first 60 lines marked as data, and logs `role:<source>` in `sessions.log`. A solo session is given one line and logged `solo:<source>`; a session with no mode is given nothing. `/pap:pm start` ([`plugins/pap/skills/pm/pap-pm.sh`](plugins/pap/skills/pm/pap-pm.sh)) reports and launches nothing, and stops on an uncommitted tracker until the owner commits or discards it. What the model does with the role is not enforced: a launch the owner did not type is refused (rule 18.2), but nothing refuses a PM that spawns an agent with the Agent tool or messages a cycle before the owner says. Planned: the eval suite (backlog H-010).

### 25.4 An ask no route covers stops

An ask no route covers stops: an `/intent` in pap, the text of an issue for `blairforce1/pap` elsewhere.

- Decision: [0025](decisions/0025-pap-runs-as-the-project-manager-by-default.md)
- Enforced by: Nothing yet. Taught by the role [`plugins/pap/hooks/session-start.sh`](plugins/pap/hooks/session-start.sh) gives: in pap the PM proposes an `/intent` for the missing route; in any other adopting repository it gives the owner the text of an issue, which the owner files, carrying nothing from that repository. [`plugins/pap/hooks/guard-pm.sh`](plugins/pap/hooks/guard-pm.sh) refuses a PM session's write in pap from another repository and names the issue (rule 25.2). Nothing refuses an improvised route, or a `gh issue create` by the PM. Planned: the eval suite (backlog H-010).

### 25.5 A cycle's pull request carries its route

A cycle's pull request carries a `Route:` line with its route and its item of rule 20.2.

- Decision: [0025](decisions/0025-pap-runs-as-the-project-manager-by-default.md)
- Enforced by: Nothing yet. Taught by the `/change` skill ([`plugins/pap/skills/change/SKILL.md`](plugins/pap/skills/change/SKILL.md)), whose pull request body template copies the brief's first two lines, unchanged, onto one `Route:` line; `/pap:pm launch` has checked those two lines (rules 18.8 and 20.2). A change the human invoked directly has no brief and no line. Nothing refuses a cycle's pull request without it. Planned: the `pr-checks` server gate (backlog H-017).
