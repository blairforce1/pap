# Changelog

All notable changes to the plugins in this marketplace are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
spec-review and pm-console are versioned on their own. From 0.5.0 the pap
plugin shares the repository's one tag series, `v<x.y.z>`, with the CLI and
templates; `mise run release` refuses a version the two plugin manifests do
not carry.

## pm-console

### [0.2.0] - 2026-11-05

#### Added

- A class band above the prompt while `/intent`, `/change` or
  `/pap:pm launch` is typed: the seven classes with the ceremony each gets.
  `/spec <slug>` takes no class: only its slug is checked, with a warning
  when the branch holds no `changes/<slug>/intent.md`.
  A bad class or slug is painted red and refused at submit with the reason
  (`process`: not a class; process records use infra). An existing
  `change/<slug>` branch is warned about, not refused.
- `/pm exit`: asks the PM to pause every cycle, push the tracker and save
  its memory, then call the new `exit_ready` tool, which puts `/exit` in the
  prompt box. An exit that skips it while cycles run leaves an inbox item
  for the next session.

### [0.1.1] - 2026-11-05

#### Added

- An icon: a red lens in a navy disc, as `.claude-plugin/icon.png` with its
  SVG source `icon.svg`, shown at the top of the README.

### [0.1.0] - 2026-11-05

#### Added

- First release: a pane beside the chat for the project-manager session of
  decision 0018 (proposed). Tabs for the inbox (what each cycle's report asks
  of the Project Lead, grouped by pull request, with the report and a link
  behind each group), the running cycles, each repository's PAP state and CI
  timings, and a status line. Tools `inbox_add`, `inbox_note`, `inbox_done`,
  `inbox_list`, `ci_repos` and `pap_repos`. No repositories are set until
  the PM calls `ci_repos` and `pap_repos`.

#### Changed

- The pane says cycles, not lanes: the tab, the rows and the README. `inbox_add`
  takes `cycle` and still accepts `lane` as an alias; stored items keep their
  `lane` field, so saved inboxes load.

## spec-review

### [1.3.1] - 2026-09-23

#### Changed

- The GDPR and AI Act dates live in one shared reference,
  `references/regulatory-dates.md`, instead of in each skill (#15).

### [1.3.0] - 2026-09-23

#### Added

- Every skill has an `argument-hint` of `<spec path>`.
- `spec-review-full` states in its executive verdict that it is not legal
  advice, an audit or a conformity assessment whenever a regulatory
  perspective ran.
- `spec-review-soc2` asks whether a Type 1 or Type 2 report is intended,
  and over what window.
- `spec-review-ai-act` points UK-only deployments to the ICO's automated
  decision-making and profiling guidance, and notes that the statutory AI
  and ADM code required by SI 2026/425 had not been published.

#### Changed

- `spec-review-gdpr` and `spec-review-ai-act` share one Relaxed under
  vocabulary.
- `spec-review-ux` reviews for the users the spec names and states its
  professional-user assumption only when the spec names none.

#### Fixed

- `spec-review-qa` no longer flags RFC 2119 uppercase SHOULD as a weasel
  word in specs that adopt the keywords.

### [1.2.0] - 2026-09-23

#### Added

- `spec-review-security` reviews AI and agent components (prompt
  injection, excessive agency, unvalidated output, retrieval stores,
  supply chain, unbounded consumption, agent-specific threats), anchored
  to the OWASP LLM and Agentic Top 10 lists by risk name and MITRE ATLAS.
- A triggering eval suite under `evals/` for `claude plugin eval`.

#### Changed

- All five Well-Architected perspectives carry a `WAF principle` column,
  filled with the pillar's design principles by exact name.
- `spec-review-soc2` cites Trust Services Criteria IDs on every item; the
  column is now `Criteria reference`, since boundary definition sits in the
  Description Criteria.

#### Fixed

- `spec-review-ux` no longer fires on requests for feedback on mockups or
  screenshots.
- Operations, security and reliability no longer duplicate the cost, gdpr
  and performance perspectives.
- `spec-review-iso27001` names CC9.2 as the nearest match to A.5.23.

### [1.1.0] - 2026-09-23

#### Added

- Every perspective's findings table has `Invariant` and `Disposition`
  columns, and each perspective reads the change's `intent.md` and
  `product/invariants.md` when the spec sits in `changes/<id>/`.
- `spec-review-full` runs the perspectives the task class makes mandatory
  before adding any by content, and maps "compliance" to the applicable
  regulatory perspectives.

#### Fixed

- `spec-review-gdpr`: UK cookie consent exemptions (PECR regulation 6, in
  force 5 February 2026) listed as UK looser, not stricter; a passing
  design is no longer called compliant.
- `spec-review-reliability`: the timeout inversion is stated the right way
  round.
- `spec-review-gdpr` and `spec-review-ai-act` no longer ask for checks their
  disallowed web tools cannot perform; both carry a last-verified date.
- `spec-review-full` no longer lists the removed `SII-` prefix.
- `spec-review-full` keeps the highest single-perspective severity instead of
  raising it by vote, sets the overall verdict by rule, and passes each
  subagent the perspective's full text, the PAP context and its read-only
  restrictions.
- `spec-review-ai-act` continues past a prohibition not yet in application,
  and ties its UK statement to the verification date.
- `spec-review-security` words a Blocker as a design-level judgement.
- Descriptions point code requests at `/code-review`; no `code-review-*`
  skills exist.

### [1.0.0] - 2026-09-21

#### Added

- Twelve `spec-review-*` skills moved from the blairforce1 dotfiles:
  `full`, `security`, `reliability`, `operations`, `cost`, `performance`,
  `qa`, `ux`, `gdpr`, `ai-act`, `soc2`, `iso27001`.

#### Changed

- `spec-review-full` resolves perspective skills via `${CLAUDE_PLUGIN_ROOT}`
  instead of the user skills directory.

## pap

### [Unreleased]

#### Fixed

- `pap doctor` said `ok  pap plugin installed` for a plugin many releases
  behind the pap running it: a 0.5.0 plugin under pap 0.18.0 has none of the
  hooks that pap relies on, and nothing said so. doctor now reads the
  plugin's version from Claude Code's `installed_plugins.json` and compares
  it with its own. An older plugin is `drift`, with both versions, the
  command that updates it and the restart it needs. A newer plugin is a
  warning that names the pap to move to, and does not fail doctor: a
  repository may pin an older pap on purpose. Equal versions are `ok`, with
  the version in the line. A plugin installed in more than one scope is
  judged by its oldest version, and the line says so. An unreleased pap, or
  a version that cannot be read, compares nothing. The spec-review plugin is
  versioned on its own and is not compared.

### [0.18.1] - 2026-11-10

#### Added

- `docs/troubleshooting.md`: an entry for the line `claude` prints when
  the terminal recorded an older pap than the one on `PATH`, with what it
  means and the fix.
- `product/backlog.md`: H-018, a launcher that resolves pap for the
  repository at launch, so that a session is started by the version the
  repository pins.

#### Fixed

- pap printed one fixed command for getting its plugin, `claude plugin
  install pap --marketplace blairforce1/pap`. Claude Code refuses it where
  the marketplace is already listed as a directory, and it is the wrong
  command for a plugin that is installed. `pap doctor`, `pap claude` and
  `pap new` now print the command that fits the machine: `claude plugin
  update pap@<marketplace>` when the plugin is installed, `claude plugin
  install pap@<marketplace>` without `--marketplace` when the marketplace
  is already known, and the first-install form otherwise.
- After an upgrade, `claude` in a terminal that was already open ran the
  old pap that `pap shell-init` had recorded, silently. The function now
  runs the `pap` on `PATH` when it is another file with the higher version
  (or an unreleased checkout against a recorded release) and says so in one
  line. `pap doctor` reports a recorded pap older than itself as drift.

### [0.18.0] - 2026-11-10

#### Added

- `pap new <name>`: one command, run from your own terminal, from nothing
  to a greenfield PAP repository and a welcome session in it. Preflight
  checks the shell, the parameters, your `gh` sign-in and scopes, the
  `pap-agent` app and what already exists; then the first commit, the
  repository, the one direct push to `main`, clone setup, `pap repo apply`
  and an agent token, in that order. A stop names its step and the command
  that resumes it; nothing is ever deleted. It replaces the greenfield
  runbook in `docs/agent-onboarding.md`, which now carries an install
  prompt pinned to an exact version. `scripts/release.sh` refuses a
  release that prompt does not name.
- `/pap:pm start` and `/pap:pm launch <slug>` (decision 0025), run by
  `plugins/pap/skills/pm/pap-pm.sh`: the tracker, its lock and its push,
  and the launch checks. A launch is refused, and no cycle starts, with
  an exit code from 10 to 19 naming the reason: among them, the owner did
  not type `/pap:pm launch <slug>` in that session, the event log has no
  `restate` event for the slug, or the brief names no route, no item of
  rule 20.2 or no budget. `pap-pm.sh` also has `commit` and
  `discard [--confirm]`.
- A guard on the PM paths (rule 25.2): a project-manager session's Edit,
  Write and NotebookEdit are refused outside the PM paths:
  `changes/<slug>/**`, `features/<slug>.feature` and `product/**` in its
  own repository, and the tracker. The refusal names the route. Its
  `git commit` is refused when the work tree holds any change outside
  those paths. Sub-agents are not bound, so a cycle is refused no path.
  Each refusal is logged.
- A project-manager session is given its role and the tracker's state at
  every start, resume, `/clear` and compaction (rule 25.3).
- The `Route:` line in a pull request body (rule 25.5): `/change` copies
  the route and the rule 20.2 item from a project-manager's brief.
- Decision 0025 (proposed) and rules 25.1 to 25.5. Rules 18.2, 18.7, 18.8
  and 20.2 name what now enforces them.
- `pap claude --help`. `pap claude` logs each start, and says when the pap
  plugin is missing: it then starts a session with no mode.
- `docs/agent-onboarding.md`: what a Claude Code session follows to bring
  a repository onto PAP, with a prompt to paste for each path, the
  brownfield runbook with a check per step, when to stop and ask, and what
  done looks like. `llms.txt`: an index of the guides, the reference and
  the layer READMEs. `README.md` and `docs/README.md` link to both.

#### Changed

- `pap claude` in an adopting repository now starts a project-manager
  session (decision 0025, rule 25.1), where it started a plain one. That
  session writes only the PM paths; everything else goes through a cycle
  it launches. `pap claude --solo` is the way to a session without the
  mode. `--solo` is the owner's: it is refused in an agent shell.
- `docs/run-a-project.md`, `docs/getting-started.md` and `CLAUDE.md` say
  what is now a command.
- The "Enforced by" lines of rules 18.1 and 18.3 say what `/pap:pm` now
  does and what still escapes; 18.3 goes from "Nothing yet" to "Partly".
  Neither rule's own sentence changed. `README.md`'s Quick start and its
  "Several changes at once" paragraph describe PM mode as shipped:
  `pap claude` starts the project-manager session, `pap claude --solo`
  one without the mode, and the owner types `/pap:pm start` and
  `/pap:pm launch <slug>`.

### [0.17.0] - 2026-11-10

#### Added

- `scripts/heavy-build.sh` (the .NET layer) logs each heavy build it runs,
  its UTC start, verb and project or solution file (no other argument),
  battery or mains and duration, to
  `${XDG_STATE_HOME:-$HOME/.local/state}/pap/heavy-builds.log`, outside
  every repository, so decision 0015's revisit can count them (0015
  amended).
- Rule 20.2: a change starts with `/intent`, then `/spec`, only when it
  needs one: it changes something a user, operator or adopter sees, or
  carries a design choice nothing on record settles, and not to record a
  decision the human already made in a message the brief cites. Rule 18.8: a PM
  brief's first line is its route, with one line naming the item that
  decided it. Decisions 0020 and 0021 amended, their revisits counted from
  the first change started with `/intent` and `/spec`.

#### Changed

- Decision 0022's Expected effect names the owner's own force push under
  0023 point 4's bypass as the override, in place of a disabled ruleset.
  Decision 0024's Revisit line is in the typed form, so `pap revisits` no
  longer reports it unknown. 0015, 0020, 0021, 0022 and 0024 stay
  `proposed`.
- The revisits of decisions 0015, 0019, 0020, 0021 and 0022 are written
  into their Result sections. 0019 is `measured:inconclusive` and kept,
  with point 1 to be amended by 0024. The four proposed records keep
  their status and end with a recommendation for the Project Lead: amend
  each. 0015, 0020 and 0021 get `when` revisits, 0022 a new count from
  #117.
- Docs catch up with 0.14.0 to 0.16.1 (decision 0023, slice e):
  `docs/account-setup.md` lists the agent app's permissions (Actions read
  included), installing it on every repository agents push to, and the
  owner bypass applied by `pap repo apply` from your own terminal, with
  what `OrganizationAdmin` means on an organisation;
  `docs/make-a-change.md` says what a PM-launched cycle is (`pap:cycle`,
  `pap:cycle-mechanical`, `cd` first), that `owner-reviewed` counts only
  from a code owner's own `labeled` event, and what the merge report
  does; `docs/troubleshooting.md` covers a stale `pap` on `PATH`, a cycle
  that branched the wrong repository and a bot-added `owner-reviewed`.
  Dated notes on decisions 0007, 0016, 0018 and 0023.

#### Fixed

- The `pap:reviewer` agent changes into the worktree before anything else
  and passes it as the `/code-review` target. It started in its
  launcher's directory, where `/code-review` with no target found a clean
  tree and returned nothing, so every cold review fell back to the
  reviewer's own read. `/change` step 5 says the same, and
  `tests/plugin-agents.test.sh` checks the reviewer's first line.

### [0.16.1] - 2026-11-09

#### Fixed

- A cycle started in its launcher's directory no longer makes its
  worktree in the launcher's repository: `pap:cycle` and
  `pap:cycle-mechanical` first `cd` to the repository the brief names (or
  ask), and `/change` step 1 checks `git rev-parse --show-toplevel`
  against it before running `worktree.sh`.

### [0.16.0] - 2026-11-09

#### Added

- Three agents in `plugins/pap/agents/` (decision 0024): `pap:cycle`, the
  agent a PM launches a cycle as, with only Bash, Read, Edit, Write, Grep,
  Glob, Skill and Agent, so it starts without the session's MCP tool
  schemas; `pap:cycle-mechanical`, the same on Haiku, for version bumps
  and syncs; and `pap:reviewer`, read-only on Sonnet, for the cold review.
- `tests/plugin-agents.test.sh` checks each agent file has frontmatter
  with `name`, `tools` and `model`.

#### Changed

- `/change` step 5 spawns the cold reviewer as `pap:reviewer`, falling
  back to a general-purpose subagent where the session cannot load it,
  and skips it for a mechanical change: only version strings, unedited
  sync output and changelog moves (decision 0024).
- The `all-branches` ruleset lists the repository's owner as its one
  bypass actor, mode `always` (decision 0023, slice d): `pap repo apply`
  resolves it at apply time, `OrganizationAdmin` on an organisation's
  repository, the owner's `User` on a personal one with `RepositoryRole`
  admin if GitHub refuses the `User`. The owner's override is now a plain
  force push from their terminal. `pap repo status` reports an
  `Integration`, a missing owner or any other actor as drift. Run
  `pap repo apply` in each adopting repository from your own terminal,
  then `pap repo status` to confirm.
- `pap repo status` from a token without administration (an agent
  shell) reports ruleset bypass actors, the Dependabot settings, push
  protection and CodeQL default setup `skipped`, "not visible to this
  token", instead of drift and error, and still compares the rest of each ruleset; `pap repo apply` from such a
  token refuses before writing anything.

### [0.15.0] - 2026-11-09

#### Added

- `pap repo status` reports, in a public repository, whether an active
  Actions policy allows `pull_request_target` for
  `.github/workflows/pr-checks.yml`: ok, missing, drift when it allows
  every workflow, or skipped when the policies API does not answer.

#### Changed

- Both `pr-checks.yml` callers also trigger on `closed`, so the reusable
  workflow's `pr-checks / merge-report` job (blairforce1/.github#17,
  decision 0023) runs and warns and comments when a bot merged the pull
  request; `checks` re-runs on close. `pr-checks / merge-report` is not a
  required check and must not become one: it is skipped on every other
  event. The risk README, rule 16.1, decision 0016 and the base README
  say the `owner-reviewed` label counts only from a CODEOWNERS owner by
  login, and that a bot-added label is removed with the reason.
- Docs for public repositories: GitHub's default event policy blocks
  `pull_request_target` there (brownouts now, enforced from 2026-12-02),
  so the `pr-checks` run ends in `startup_failure`. `docs/adopt-a-repo.md`,
  the base README and `docs/troubleshooting.md` say to create an Actions
  policy permitting the event for the pr-checks workflow path only, why
  that is safe and what must stay true; both `pr-checks.yml` callers point
  at it in their header. No behaviour change to the workflow.

#### Security

- `.github/risk.yml` rates `bin/pap`, `scripts/shim/**` and the
  `reviewed` and `accept` skills high (decision 0023): a pull request
  changing agent identity now needs `owner-reviewed`, not just a merge.
- The `pap-agent` app asks for Actions read (decision 0023, note of
  2026-11-09), so an agent session can read its own workflow runs and job
  logs. It also reads artifacts and caches; it cannot re-run, cancel or
  dispatch, and sees no secret. Never upload a secret as an artifact:
  GitHub masks registered secrets in logs, not artifacts. An existing app
  gains it by hand ([account
  setup](docs/account-setup.md#adding-a-permission-to-an-existing-app)).

### [0.14.0] - 2026-11-09

#### Security

- A `pap claude` shell pushed as the owner, not as `pap-agent`, to any
  repository that does not adopt PAP: the gh shim ran the real `gh`
  there, and gh's `auth git-credential`, with an empty config directory,
  falls back to the owner's unkeyed keyring token
  (`docs/agent-identity-security.md` has the gh v2.97.0 source lines).
  In a `pap claude` session the shim now handles every `gh` call in every
  directory: it mints a token scoped to the one repository the call names
  (`pap agent-token --repo`, new), answers git's credential requests
  itself, and refuses a call with no repository, a repository the
  installation does not cover (by name), or another host, never running
  the real `gh` without a token. `pap claude` makes the shim git's only
  credential helper for github.com at command scope, past any helper in
  your config, and sets `credential.https://github.com.useHttpPath`. The guard hook's `pap
  claude` check applies in any directory of a session whose project
  adopts PAP. `pap doctor` checks that the installation covers this
  repository. Install the app on every repository agents push to,
  adopting or not. Behaviour changes: a `gh` call across two
  repositories (a fork flow) is refused by GitHub, and a session started
  by an older `pap claude` must be restarted.

#### Added

- `pap shell-init bash|zsh` prints a `claude` function for an `eval` line
  in `~/.bashrc` or `~/.zshrc`: in a repository with an executable
  `scripts/guard-branch.sh` it runs `pap claude` through the absolute path
  of the pap that printed it (a pap on `PATH` with `pap claude` if that
  path is gone, else a warning and plain `claude`); elsewhere plain
  `claude`. `pap doctor` warns, in your own terminal, when this shell has
  not run it.

- Decision 0023's second slice (rule 23.4): `pap claude` starts Claude
  Code with `GH_CONFIG_DIR` set to an empty agent directory and the GitHub
  token variables unset, so agent shells find no stored account; your own
  sign-in stays in gh's default directory and the keyring. The `gh` shim
  refuses an agent session not started that way in an adopting
  repository; the guard hook refuses an agent's command that changes
  `GH_CONFIG_DIR`, reads gh's keyring entry or token, runs `reviewed.sh`
  or `accept.sh`, or (in an adopting repository) runs `gh` by path or with
  `PATH=`; `/pap:reviewed` and `/pap:accept` act as you from gh's default
  directory; `pap doctor` checks the sign-ins. New
  `docs/agent-identity-security.md`: what the agent can do, what is
  protected, and every known escape.
- Decision 0023's first slice (rule 23.1): `pap agent-key import` and
  `status` keep the `pap-agent` app's private key in the OS keyring;
  `pap agent-token` mints and caches an installation token for the
  repository's owner; the base layer's `gh` shim, first on `PATH`, runs
  `gh` and git's pushes with it in an agent session and never falls back
  to a stored sign-in; `pap doctor` checks what the app needs; the guard
  hook refuses an agent's push to an SSH remote. `pap agent-setup`
  registers the app by GitHub's manifest flow, keys the keyring without
  writing the key to disk, confirms the installation, offers to switch an
  SSH origin and to add the global SSH-to-HTTPS `insteadOf` rewrite (which
  `pap doctor` reports), and runs doctor's agent-app checks;
  `docs/account-setup.md` has it, with the manual steps as the fallback.
- Decision 0023: agent sessions act on GitHub as their own
  GitHub App, so GitHub can tell an agent's push, pull request, label or
  comment from the owner's; commits stay the owner's, SSH-signed, with the
  model trailer, and the owner's `gh` sign-in lives where no agent shell
  reaches it. Rules 23.1 to 23.4 with their planned checks; it amends
  0022's override and 0016's label gate once it ships. Backlog item H-016
  names the slices and their order.

#### Fixed

- The test suites unset the variables a `pap claude` session exports
  (`GIT_CONFIG_COUNT` and its keys, `GH_CONFIG_DIR`, the GitHub tokens,
  `CLAUDECODE`), so `mise run test` passes inside an agent session as in
  CI; `tests/accept.test.sh` case 18 failed there.
- The guard hook refuses, in an adopting repository, an agent's `gh` and
  git's `push`, `fetch`, `pull`, `clone`, `ls-remote` and `remote update` to
  a GitHub HTTPS remote unless the session was started by `pap claude`,
  naming `pap claude` and `pap claude --resume`. It asks the shim, in a new
  `PAP_SHIM_CHECK=1` check mode, so the shim's tests (agent directory,
  empty `hosts.yml`) live in one place; a shim without that mode fails it,
  and a dev container with no key passes. A
  session started as plain `claude`, and every cycle a PM session so
  started launches, is refused there; outside an adopting repository its
  `gh` is still the real one with your sign-in.
- Agent shells never got the `gh` shim: it reached `PATH` only through the
  base layer's mise `[env]`, which Claude Code's non-interactive Bash tool
  never applies, so `gh` was the real one, as the owner before rule 23.4
  and signed out after it. `pap claude` now puts pap's own `scripts/shim`
  first on `PATH`, where the shim calls its sibling `bin/pap` for the
  token, and `pap doctor` reports an agent shell whose `gh` is not the
  shim. `pap claude` stops with the reason when its install has no
  `scripts/shim/gh`. A session not started with `pap claude` still gets the real `gh`
  with your sign-in; rule 23.1 and `docs/agent-identity-security.md` now
  say so.

### [0.13.0] - 2026-11-06

#### Added

- `pap doctor` checks git, `gh` and its sign-in, `jq`, the `claude` CLI,
  the `pap` and `spec-review` plugins and `flock` (a warning only), and
  names the install command for each missing one on this platform: apt or
  dnf on Linux, Homebrew on macOS, a link otherwise; WSL counts as Linux.
  `pap doctor --fix` runs `mise trust` and `mise install` and nothing else.
- pap's own test suite runs on macOS as well as Linux (`tests (macos)`);
  Windows is supported through WSL2 only.

#### Fixed

- `scripts/gen-codeowners.sh` failed under macOS's `/bin/sh` (bash 3.2),
  which ends a `$(...)` at a `case` pattern's parenthesis.
- `pap measure` failed under macOS's awk, which cannot parse an unbracketed
  conditional in a `printf` argument list.

#### Changed

- The base layer pins `gh` and `jq` through mise, so `mise install`
  provides them. The prerequisites are now git, mise and Claude Code, then
  `gh auth login`.
- The base devcontainer has everything: `gh` and `jq` from mise (the GitHub
  CLI feature is gone), Claude Code from Anthropic's native installer,
  unpinned on purpose because it updates itself, the `pap` and
  `spec-review` plugins installed after create, and `pap doctor` run at the
  end of it.
- `mise run test` in pap runs every suite and names each that failed,
  rather than stopping at the first.

### [0.12.0] - 2026-11-05

#### Added

- `docs/`: user guides for adopting and using PAP without its author:
  getting started, adopt a repository, set up the account (the `.github`
  repository, labels, Renovate), start a project, make a change, run a
  project (the PM way of working and the console), decide and improve, and
  troubleshooting. Each says what is a command today, what is by hand and
  what is planned (`H-NNN`); the process document, `rules.md` and
  `decisions/` stay the reference. The README gains a Documentation section
  and a `docs/` row.
- Decision 0018 (proposed): a project-manager session launches one cycle
  per `/change` (a cycle is one change, run by one member today; the
  vocabulary is TSP's), keeps a tracker (a state file and an event log)
  committed on every event, pauses and relaunches cycles by save point,
  audits tokens and time every five merged change PRs, and opens,
  approves and merges nothing. Each audit classifies its rules as project
  or general; the general ones go back to PAP as an ordinary change, from
  a PAP candidates list in the tracker. Three send-backs end a cycle
  (`ASK:`), a fix round re-checks only the diff since the last report, and
  every brief carries a token or wall-time budget the cycle pauses at
  (`PAUSED:`), set from the audit's medians; the audit reports rounds to
  pass per merged pull request. Rules 18.1 to 18.7, enforced by nothing
  yet. Backlog item H-012 carries the `/pap:pm` skill, the `pap:member`
  agent, the templates and the console; H-013 trials a two-member cycle,
  developer and QA, against one member plus a fresh-context review
  (decision 0019).
- Decision 0019 (proposed): before `/change` opens its draft pull request,
  a read-only subagent given only the brief and the branch diff reviews it,
  with `/code-review low` where that skill exists; findings are fixed or
  answered, and Verification carries the review's row. Rule 19.1, taught by
  the skill and enforced by nothing yet. The control arm for backlog H-013
  (decision 0018).
- Decision 0021 (proposed): a spec is accepted by the human's yes after
  spec review, recorded in `spec.md` (`accepted-by:`, `accepted-on:`) and
  committed on the change branch after the intent and before the code, not
  by a separate merge; a feature, infra or security-sensitive spec designs
  its operation (Signals, Good, Wrong, Undo, and operational scenarios in
  Given/When/Then), and the pull request's "How to revert" is its Undo.
  Rules 21.1 and 21.2, taught by the skill and enforced by nothing yet.
  Delivers the `/spec` slice of decision 0017, whose status is unchanged,
  and closes the follow-up 0020 left: process principle 5, 5.1 rows 2 and
  3, 5.2, 5.4 and 5.5 say acceptance where the branch records it, and what
  a spec's Functional behaviour and Operations carry. Backlog H-015
  proposes an operations member for phases 8 to 10.
- `/spec <slug>`: reads the accepted `changes/<slug>/intent.md` and refuses
  without one; drafts `spec.md` with the sections the class requires,
  acceptance scenarios in `features/<slug>.feature` tagged `@id` and
  `@pending` in the words of `product/domain.md`, which it extends; the
  Operations section for feature, infra and security-sensitive; runs
  `spec-review-full` by class, records each disposition in
  `changes/<slug>/reviews/spec-review.md`, and on the yes commits
  `spec(<slug>): ...` and hands on to `/change`. Half a page for docs and
  chore, none for a spike. Main session only. The second slice of backlog
  item H-011.
- Decision 0020 (proposed): an intent is accepted by the human's yes to it
  restated in process 5.3's sections, recorded in `intent.md`
  (`accepted-by:`, `accepted-on:`), not by a separate merge; `intent.md`
  and `spec.md` are committed on the change branch before the code and the
  one pull request carries them in order; intent churn is still recorded.
  Rule 20.1, taught by the skill and enforced by nothing yet; rule 2.2
  narrowed for the intent and spec skills. Process 5.1 phase 1 and 5.3 amended to match;
  5.3's frontmatter gains `source:` (rule 11.2) and the two acceptance
  lines.
- `/intent <slug> <class>`, followed by the ask in the human's words: reads
  the product layer, interviews in small batches (one for `docs`, `chore`
  and `spike`), challenges the hypothesis or reactive reason, the measure,
  the non-goals, the invariants and protected paths, the class and the
  open questions, restates the intent for a yes, then writes and commits
  `changes/<slug>/intent.md` on `change/<slug>` and hands on to the spec.
  Main session only. The first slice of backlog item H-005.

- `/pap:accept <NNNN> [NNNN ...]`: a skill only a person can invoke that
  checks each decision record is on main and `proposed`, shows its title
  and Decision items, sets only its Status line to
  `accepted (<login>, YYYY-MM-DD)` on a new `change/accept-<ids>` branch,
  and opens a draft `class:docs` pull request; the model cannot invoke it.
- Decision 0022 (proposed): no branch takes a force push. Rule 22.1, with
  two enforcers, because agents push with the human's own credentials. A
  second ruleset, `.github/rulesets/all-branches.json`: `non_fast_forward`
  on every branch, no bypass actors, Renovate's and Dependabot's branches
  excluded, creating and deleting branches still allowed. `pap repo apply`
  creates or restores it; `pap repo status` reports it, and a disabled one
  as drift, which is how the deliberate override shows. And
  `scripts/guard-branch.sh push-args`, which the `PreToolUse` hook runs on
  an agent's `git push`, refuses `--force`, `-f`, `--force-with-lease`,
  `--force-if-includes`, `--mirror` and `+<refspec>` on any branch; a person at a
  terminal is unaffected.

#### Fixed

- `/pap:accept` printed nothing about the repository it acted on, so a run
  from a session in another adopting repository accepted that repository's
  records of the same numbers unnoticed. Its first line is now
  `Repository: owner/name (path)`, and `--repo <path>` (before or after the
  ids) runs it against another checkout, refusing a path that is not a git
  checkout with an origin. The skill tells the model to relay that line
  first and to flag a repository the ids do not seem to fit.

#### Changed

- `/change` has a new step 5, "Review cold", between the local checks and
  opening the pull request; the later steps are renumbered 6 and 7.
- `/change` builds to `changes/<slug>/spec.md` where the branch has one
  (its scenarios are the acceptance criteria), and its pull request body
  has a "How to revert" section, the spec's Undo where there is a spec.
- `/change` reads `changes/<slug>/intent.md` where the branch has one, as
  the brief's intent: its class and hypothesis stand, and a differing
  `<class>` argument or brief is reported as a contradiction.

### [0.11.0] - 2026-11-02

#### Added

- `/pap:reviewed <PR#> [sha7+]`: a skill only a person can invoke that adds
  `owner-reviewed` to an open `risk:high` pull request through `gh`, after
  checking the head; the model cannot invoke it (rule 16.1).
- Decision 0017 (proposed): a spec carries Gherkin scenarios in a living
  `features/` tree, each bound to a test or tagged pending, in words
  defined in `product/domain.md`; scenarios change only in the spec phase.
  Rules 17.1 to 17.4, enforced by nothing yet. Backlog item H-011 carries
  the build, in slices.

### [0.10.0] - 2026-10-30

#### Added

- `.github/labels/risk.yml`: `pap repo apply` creates `risk:high`,
  `risk:medium`, `risk:low` and `owner-reviewed` in a repository whose
  `.config/pap.toml` names the risk layer. Nothing created
  `owner-reviewed` before, so the owner could not add it.
- `.github/required-checks.yml` in an adopting repository lists required
  status checks of its own, which `pap repo apply` adds to the `main`
  ruleset and `pap repo status` reports by name.

#### Fixed

- `pap repo apply` no longer drops a required status check the live
  `main` ruleset has and `.github/rulesets/main.json` does not: adopting
  the risk layer in a repository removed its `coverage` check. It keeps
  such checks, lists them, and shows the ruleset diff; `--remove-checks`
  removes them. A check present only in a different order, or only kept,
  is not reported as drift.

### [0.9.0] - 2026-10-29

#### Added

- Decision 0016 (proposed): in a repository that opts in, a risk label and
  the owner's `owner-reviewed` label on high-risk pull requests replace the
  `Approved-by:` line of 0012 and 0013. Rules 16.1 and 16.2.
- The `risk` template layer: a sample `.github/risk.yml`, the opt-in to
  0016's risk mode, added with `pap init base risk`.
- The `guard-route.sh` hook enforces rule 16.2 in every adopting
  repository: it refuses an agent's `gh` call that adds the
  `owner-reviewed` label (`gh pr`/`gh issue` `edit --add-label` or
  `create --label`, `gh label edit --name`, `gh api` on an issue's labels
  or a label's `new_name`) and any merge (`gh pr merge`, `gh api -X PUT`
  on `pulls/<n>/merge`). Removing the label and other `gh` calls pass;
  GraphQL, `bash -c` and `eval` are not followed.

#### Changed

- `/change` answers the protected-path box from the `risk:*` label in a
  repository in risk mode, and ends its report with
  `Risk: high; add owner-reviewed after review` for a high-risk pull
  request instead of an `Approved-by:` line.
- The base README describes risk mode in its `pr-checks` row.
- The base layer's `pr-checks` caller runs on `pull_request_target`, so a
  pull request runs the base branch's copy and cannot edit its own check.
  Switching takes one pull request that cannot run the check: the base
  README's "Moving pr-checks to pull_request_target" gives a two-step way
  with no bypass, and the one-step way with a temporary ruleset bypass.
- `/change` states the stop rule per agent context, not per session: a
  background sub-agent under a project-manager session opens one pull
  request and stops, as a top-level session does.

### [0.8.0] - 2026-10-17

#### Added

- A `SessionEnd` hook (decision 0015). Detached from the session's exit,
  it runs `dotnet build-server shutdown` when no other Claude Code session
  is on the machine, and `mise run session-end` when the repository
  defines that task.
- The .NET layer ships `scripts/heavy-build.sh`: `dotnet <verb> <args>`
  under the machine's one heavy-build lock, with `-m:2` on battery
  (rule 15.1).

#### Changed

- `/change` builds Debug unless the change concerns Release behaviour, and
  sends a heavy build through `scripts/heavy-build.sh`.
- The .NET layer's `global.json` rolls forward with `latestFeature`, not
  `latestPatch`, so one installed 10.0 SDK serves every project.

### [0.7.0] - 2026-10-08

#### Added

- The base layer ships `.github/workflows/pr-checks.yml` and
  `.github/workflows/test.yml`, which provide the `pr-checks / checks` and
  `tests` checks the ruleset has required since 0.5.0. Without them the
  first pull request after `pap init` could not merge.
- `mise run test` in the base layer runs every `test:*` task and passes,
  saying so, when there is none. The .NET layer defines `test:dotnet`
  (`dotnet test`) and the Go layer `test:go` (`go test ./...`).

#### Changed

- `mise run release` refuses a version whose pap section in `CHANGELOG.md`
  at origin/main still reads `Unreleased`.
- `scripts/gen-codeowners.sh` reads the owner of the protected paths from
  an `Owner:` line in the "Protected paths" section of
  `product/invariants.md`, before `--owner` and the origin remote
  (decision 0014). The pre-commit hook and `mise run check:codeowners`
  pass no `--owner`, so in a repository an organisation owns they failed
  any CODEOWNERS that named a person. `/envision` asks for the line.
- `pap repo status` reports what GitHub makes of `.github/CODEOWNERS` on
  the default branch, with each error by line.

#### Fixed

- The release archive holds the whole tree. 0.5.0 and 0.6.0 were built with
  `git archive`, which left out every path `.gitattributes` marks
  `export-ignore`: `.github/rulesets/main.json` and `.github/labels.yml`,
  so `pap repo` failed from an installed release, and the base layer's
  `.github/` and `.devcontainer/`, so `pap init` from one wrote no security
  workflow, Renovate configuration or devcontainer. `mise run release` now
  refuses an archive whose paths are not the tree's.
- `pap init` stops with exit 1 when `mise trust`, `mise install` or `mise
  run setup` fails, and names what is left to run. It used to go on, print
  "Next:" and exit 0 with no tools and no hooks installed.
- The .NET layer's `check:dotnet` and `fmt:dotnet` pass, with a message,
  when the repository has no solution or project. `dotnet format` exits 1
  there, which failed `mise run check` and the required `security / check`
  in a repository that had adopted the layer and written no code.
- The base layer pins mikefarah's `yq`, which `pap repo status` and `pap
  repo apply` need. In a repository that had only run `mise install` they
  stopped with "yq not found", or refused the Python `yq` a distribution
  had installed.

### [0.6.0] - 2026-09-25

#### Added

- The `PreToolUse` hook refuses an agent's `gh pr create`, `gh pr edit`
  or `gh api` pulls write whose body carries an `Approved-by:` line, by
  `--body`, `--body-file <path>`, `--body-file -` from a heredoc, or a
  `body=` field or `--input` for `gh api` (decision 0012).

#### Changed

- `/change` drops an `Approved-by:` line when it rewrites a body, and its
  report says the owner must re-approve.
- `/change` answers an unticked protected-path box with `Head to approve:
  <short sha>`, updates it after every push, and ends its report with the
  `Approved-by: @login <sha>` line for the owner to paste (decision 0013).

### [0.5.0] - 2026-09-24

#### Added

- `bin/pap`: `init`, `sync`, `repo`, `codeowners` and `doctor` (#37).
  Run from a checkout with no release tag, `init` records
  `version = "unreleased"` and the commit, and `sync` merges from that
  commit.
- `mise run release <version> [--dry-run]`, the first release of the
  repository's one tag series.

#### Changed

- The plugin's version is the repository's release version.
- pap adopts its own base layer: `mise run check` and `mise run fmt`, the
  `security` workflow and the base hooks run on pap itself.

### [0.4.0] - 2026-09-24

#### Added

- `/change <slug> <class> [Record: NNNN]`: the per-change ceremony of
  decision 0002 as a skill. A worktree on `change/<slug>` from a fresh
  main, or the existing branch resumed (`skills/change/worktree.sh`), a
  contradictions-only read, background waits, `mise run check` and
  `mise run test`, a draft pull request with the class label read back
  after creation and every Checks box answered, and a fixed-shape report.

### [0.3.0] - 2026-09-24

#### Added

- The `PreToolUse` hook refuses an agent's hook bypass in a repository
  that adopts PAP (decision 0005): `LEFTHOOK` or `LEFTHOOK_EXCLUDE` set
  anywhere in the command, `git commit --no-verify` or `-n`, `git push
  --no-verify`, and `core.hooksPath` through `git config`, `-c` or
  `--config-env`. It follows `cd`, `git -C`, `env` and command sequences
  as the branch guard does. A commit message that mentions `--no-verify`
  and `git push -n` (a dry run) pass.

#### Fixed

- `env git commit` is recognised as a commit, so the branch guard no
  longer misses it.

### [0.2.0] - 2026-09-23

#### Fixed

- The branch guard hook checks the repository a command targets, not the
  session's: it follows `cd` and `git -C` and runs that repository's
  `scripts/guard-branch.sh`, only where the repository adopts decision 0002.
  A session on `main` no longer blocks commits to other repositories, a
  session elsewhere can no longer commit to a guarded `main` through `cd`,
  and `git -C <dir> commit` and `git -c key=value commit` are no longer
  missed.

### [0.1.0] - 2026-09-17

#### Added

- `envision` skill: interviews the human to produce the product layer.
