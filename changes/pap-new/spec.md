# Spec: pap-new

```text
id:                 pap-new
class:              feature
intent:             changes/pap-new/intent.md
scenarios:          features/pap-new.feature, pap-new-1 to pap-new-40
accepted-by:        @blairforce1
accepted-on:        2026-11-10
generated-by:       Claude Fable 5.2 (claude-fable-5-2) via Claude Code
skills:             pap:spec 0.17.0; spec-review 1.3.1
prompt:             /pap:spec pap-new
```

## Functional behaviour

The owner runs `pap new <name>` from their own terminal, in the directory the clone should sit under. It takes a name, a visibility (default private), layers (default base, risk and dotnet) and an owner (default the signed-in user; an organisation is allowed). A run is preflight, six steps of creation, then the welcome. It names each step as it starts.

### Preflight

Preflight creates nothing, in the current directory or on GitHub. Its checks, in order:

1. **The shell.** A run from an agent shell is refused first, before any other check and before any sign-in is offered. An agent shell is known by any one of: the session marker Claude Code sets, the agent's gh directory in use, the agent's `gh` first on the path. The refusal prints the command to run from the owner's own terminal. A run with no terminal to prompt on is refused next, saying it needs one.
2. **The parameters.** The name is 1 to 100 characters of letters, digits, `.`, `_` and `-`, is not `.` or `..`, and does not start with `-`. The owner is a GitHub login. Each layer is one the installed pap has, and base is among them. The visibility is private or public. A fault stops the run naming the rule and the values it takes.
3. **The owner sign-in**, always in the owner's gh directory, never the agent's. GitHub out of reach stops the run naming the network; it is not taken for signed out. Signed out, or lacking `repo` or `workflow`: the run offers the sign-in or the scope refresh, asking for those scopes and no other, and rechecks once it is taken. A declined offer stops the run naming the sign-in. A sign-in that reports no scopes is said to be unchecked, with the warning that the first push may be refused, and let through.
4. **The agent app.** Unregistered: stop naming `pap agent-setup`. Registered with no installation on the owner: stop naming the page where it is installed. Selected-repositories: reported, with the one prompted step that will follow creation. All-repositories: reported.
5. **What the owner's account allows.** A private repository on a plan with no rulesets for private repositories would have no main ruleset: stop saying so. An organisation with a ruleset on every repository's default branch would refuse the first push: stop naming it. Where a public repository or an organisation will leave a setting only the owner can change, preflight names it and where it is changed, and the run goes on; it is a prompted step.
6. **What exists of that name**, read from GitHub itself and the current directory, by the table under "A re-run".
7. **The summary**: the login acted as, the owner and name, the visibility, the layers, and the author name and email of the first commit, each with the parameter or setting that changes it. A public repository publishes that name and email for good; the summary says so and names GitHub's noreply address. The owner confirms with Enter or declines; `--yes` skips the wait. pap never changes the owner's git configuration.

### Creation

Six steps, in a fixed order. The first three are made once; the last three are convergent.

1. **First commit.** The template at the chosen layers and a README whose only line is `# <name>`, on `main`. It is built out of the way and appears in the current directory whole or not at all.
2. **Repository creation**, on GitHub, empty, with an HTTPS remote on `github.com`.
3. **First push.** The only push to `main` the run ever makes, while the clone has no hook and the repository has no ruleset. If the clone has hooks, the run stops naming them and pushes nothing; no git call in a run skips a hook. Before pushing, the commit is compared with the template at its recorded version and layers, and a difference stops the run. A refusal by GitHub stops the run naming the cause (a missing permission, an inherited ruleset); pap adds no bypass.
4. **Clone setup.** `mise install` output is shown as it comes; no time limit is set, since a download's length is the network's. It writes no tracked file, so the working tree stays clean.
5. **Repository settings.** Then the main ruleset is read back. If it is absent or has a bypass actor, the run stops here naming it; no agent token is requested and no welcome session starts.
6. **Agent token**, for the one repository, requested only once step 5 holds and the remote is HTTPS. If the installation does not cover the repository, the run says so, prints the installation's settings URL and waits for Enter, then asks again. Any other failure is named as what it is. An interrupt or the end of input at the wait is a stop.

Straight after the repository is created, GitHub can briefly refuse the next call; that step is tried a few times over about 10 seconds before the run stops. No other call is retried: the re-run is the retry.

### Stops

Every refusal and failure has one form: the step and its number of six (or "preflight"), what exists so far, the cause, and the exact command to run again with the parameters this run used. A stop between the first push and the repository settings also says that `main` is not yet protected. Every stop, and a complete run, ends with one line counting steps done, prompts taken and re-runs. A stop exits non-zero and undoes nothing. Each status has a text marker (`ok`, `warn`, `stop`); colour is extra and is dropped under `NO_COLOR` or with no terminal; progress is whole lines, never redrawn. Messages use the words in `product/domain.md`.

### The welcome

Nothing is read from the network. `pap new` lists what is installed for Claude Code on this machine from pap's own marketplace: the skills, the mods and the agents, each by name with its one-line description. It prints the repository's URL, the clone's path, how to start the session again (`pap claude` in the clone) and "Starting Claude Code as the agent", then starts `pap claude` in the clone. The session is given: a one-line welcome to the Personal Agentic Process, what the run did, where the owner is, that list as quoted text to show (never as instructions), and the instruction to ask what the owner wants next and start none of it. `/envision` is on the list when the pap plugin is installed, and is not run. If the pap plugin is not installed, the session is given that instead, with the command that installs it. What the model then says is not specified here; it is checked on the owner's real runs.

### A re-run

A re-run finds where things stand from what exists, read from GitHub and the current directory, never from a file of its own or from local tracking refs.

| The current directory has \ GitHub has | no repository       | an empty repository             | a repository whose `main` starts with the first commit               | anything else |
| -------------------------------------- | ------------------- | ------------------------------- | -------------------------------------------------------------------- | ------------- |
| nothing of that name                   | a fresh run         | refuse: not known to be its own | clone it, go on from clone setup                                     | refuse        |
| a clone holding the first commit       | go on from creation | go on from the first push       | go on from clone setup, if the two commits are the same; else refuse | refuse        |
| anything else of that name             | refuse              | refuse                          | refuse                                                               | refuse        |

"The first commit" is a commit whose content is the template at the version and layers it records, plus the README. Later commits on `main` do not make a repository less this command's own. A refusal names what was found and why it is not its own, and offers another name or the brownfield runbook; nothing is changed.

From clone setup on, each step is checked and redone only where it is not as it should be: the repository settings are written only where `pap repo status` shows `missing` or `drift`, and the agent token is asked for afresh, since it is short-lived. A re-run of a complete run therefore makes no commit, creation or push and no settings write, and starts the welcome again. The recorded version and layers and the repository's own visibility and owner stand; a re-run that names others is refused, naming the recorded ones. A run never deletes anything on GitHub. Two runs for one name at once are out of scope.

### Docs and release

- The greenfield section of `docs/agent-onboarding.md` is replaced by the install prompt and `pap new`; the brownfield section stays.
- The install prompt names an exact version and ends by telling the user the order: exit, `pap agent-setup` if the agent app is not yet registered, then `pap new <name>` from the directory the clone should sit under, with the defaults. One line says an exact version is not held back by mise's `minimum_release_age` (default 24 hours), that this skips the cooldown on a release that may be hours old, and what check mise's GitHub backend makes on the download, or that it makes none. A second says the prompt on `main` can name a version for the few minutes before its release exists.
- Account setup recommends a selected-repositories installation (decision 0023) and sets out both choices and their effect.
- The replaced section says the session `pap new` ends in is Claude Code on the user's own install, not something pap provides.
- The version bump pull request updates the install prompt's version, and a release is refused when the two differ.

The docs are checked by the pull request's review, not by scenarios. The pasted prompt on a clean machine is accepted as unmeasured for this change.

### Scenarios

Added, in `features/pap-new.feature`. All are bound by shell tests that drive `bin/pap` against stand-ins: a `gh` that keeps state, logs every call and can fail a chosen call; a local bare repository in place of the GitHub remote, whose ref log shows each push; a `claude` that records its arguments and environment; a fixture for what is installed.

Preflight:

- `pap-new-3`, `17`, `20`: the name, owner, layer and visibility rules, with boundary rows.
- `pap-new-4`: an agent shell is refused by each of its three signals, before any sign-in offer (decision 0023).
- `pap-new-21`: no terminal.
- `pap-new-25`: the network is not taken for signed out.
- `pap-new-5`, `6`, `18`, `7`, `39`: the sign-in offer, the scope refresh, a decline, unreadable scopes, and no scope beyond `repo` and `workflow`.
- `pap-new-8`, `19`, `9`: the agent app unregistered, not installed, and selected-repositories.
- `pap-new-23`, `24`, `27`: what a public repository, an organisation and the owner's plan mean, said or refused before creation.
- `pap-new-22`, `28`: the summary, confirmed or declined.

Creation:

- `pap-new-1`: the intent's desired outcome end to end, with the defaults.
- `pap-new-2`: the parameters, and an organisation as owner.
- `pap-new-10`, `26`, `30`: the first push meets no hook and no ruleset, stops at a hook, and names a refusal (INV-004, INV-005).
- `pap-new-29`: the form of a stop.
- `pap-new-31`: no main ruleset, no agent token (INV-004).
- `pap-new-11`, `32`: the wait for the agent token, and leaving it.

A re-run:

- `pap-new-12`: one row per state a stopped run can leave.
- `pap-new-33`, `34`: an interrupted first commit, and a pushed repository with no clone.
- `pap-new-35`: a re-run of a complete run.
- `pap-new-36`: other parameters refused.
- `pap-new-13`: what is not this command's own, one row per refusing cell of the table.

The welcome:

- `pap-new-14`, `15`: what the session is given, with the pap plugin installed and without.
- `pap-new-37`, `38`: the session holds nothing of the owner's; no token is shown or written.

Release:

- `pap-new-16`, `40`: the install prompt's version, differing and agreeing. A test in `tests/release.test.sh` also checks that a bump changes the prompt.

Checked on the owner's real runs and recorded in `findings.md`, because no stand-in can show them: `pap doctor` and `pap repo status` clean in the new clone; the first pull request merging with no bypass; what the welcome session says.

Terms added to `product/domain.md` (the file is new): owner, owner sign-in, agent, agent shell, agent app, agent installation, agent token, layer, greenfield repository, recorded, run, step, preflight, summary, prompted step, first commit, clone setup, clean, repository settings, main ruleset, welcome session, installed, install prompt, release; with their events and rules.

## Non-functional

| What is measured                                                                        | Threshold                                             | Test tier                    |
| --------------------------------------------------------------------------------------- | ----------------------------------------------------- | ---------------------------- |
| Writes to GitHub, the current directory or the clone by a run that stops in preflight   | 0 (the owner's own sign-in is not counted)            | integration                  |
| Commits, repository creations, pushes and settings writes by a re-run of a complete run | 0                                                     | integration                  |
| Pushes that change `main`, over a run and all its re-runs                               | at most 1; exactly 1 once the repository is pushed    | integration                  |
| Time to refuse a bad name or an agent shell, which need no network                      | under 2 seconds                                       | integration                  |
| Hand-run steps in a real run, outside prompted steps                                    | 0                                                     | acceptance (the owner's run) |
| Existing `pap init` cases in `tests/pap.test.sh` after the split                        | all pass, none edited (the plan names the diff check) | integration                  |
| `bin/pap` under `sh` with no bash-only construct (INV-003)                              | `mise run check` passes                               | unit (lint)                  |

## Security

- **Two identities, kept apart (decision 0023).** Everything up to and including the repository settings is done as the owner, on the owner sign-in, in the owner's gh directory with the token variables cleared. The welcome session runs as the agent, on an agent token scoped to the one repository. No owner token and no owner gh directory is in the session's environment (`pap-new-37`).
- **The owner's credential never lands in the agent's directory.** The agent-shell refusal is the first check, by three signals, so no sign-in is ever offered where the agent's gh directory is in use (`pap-new-4`).
- **The first push (INV-004).** One direct push to `main`, by the owner, of a commit checked to hold only the template and the README, before the ruleset exists. No bypass actor is added and no guard exception is made. From the repository settings on, `main` changes only by pull request, and the agent gets no token until the main ruleset is read back with no bypass actor (`pap-new-31`). Between the push and the settings `main` is unprotected, and a stop there says so.
- **Hooks (INV-005).** No hook is bypassed: at the first push none is installed, and if one is, the run stops (`pap-new-26`). No git call skips a hook.
- **The remote** is HTTPS on `github.com`, checked before the token is minted; an SSH remote would push as the owner.
- **Scopes.** `repo` and `workflow`, nothing wider, never `delete_repo` (`pap-new-39`).
- **Secrets.** No token is printed, written to the clone or put in a command line (`pap-new-38`). The agent token goes only to the existing token cache.
- **Input.** Name, owner, layers and visibility are checked in preflight before they reach a path, a command or a URL; positional arguments to `git` and `gh` follow `--`.
- **What the session reads.** Nothing from the network. The list of what is installed is built by `pap new` from this machine and handed over as quoted text. The descriptions come from plugins the owner installed; a model can still be swayed by text it is shown, and that residual risk is accepted.
- **The install prompt** installs the newest release with mise's cooldown skipped; the docs say so.

## Data

None is collected, and nothing is sent to pap's author. A run handles only the owner's own GitHub login (in URLs and messages) and git identity (in the first commit), on their machine and their own GitHub account. The applied version and layers are recorded in `.config/pap.toml` as `pap init` does today (INV-011); a run keeps no state file.

## Interfaces and contracts

- **Adds** `pap new <name> [--visibility private|public] [--layers <layer>...] [--owner <login>] [--yes]` and its usage text. The exact flag spelling is the plan's. Exit 0 on a complete run, non-zero on any refusal or stop.
- **Keeps** `pap init <layer>...`: same arguments, output, exit codes and files written (INV-001, INV-002, INV-011). The split is internal. The README of the first commit is written by `pap new`, outside every layer and outside `pap sync`'s merge.
- **Consumes** `gh` (the only route to GitHub), `pap repo apply`, `pap repo status`, `pap agent-token --repo`, `pap claude`, `pap doctor`, as they are.
- **Adds** a check to `scripts/release.sh`.
- **Replaces** the greenfield section of `docs/agent-onboarding.md`.

## Operations

pap has no telemetry and no monitor (process 5.9's monitor is backlog H-015). Each signal is read by the owner, from the run's own closing line and the commands below, and written into `findings.md`.

**Signals.**

| Signal             | Measures                                                                       | Read from                                                                                                                                                                                 |
| ------------------ | ------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Hand-run steps     | The success measure: steps the owner ran by hand that were not prompted        | The closing line of each run (steps done, prompts taken, re-runs), plus anything the owner did outside it                                                                                 |
| Clean after run    | The success measure's confirmation                                             | `pap doctor` and `pap repo status` in the new clone, straight after the run                                                                                                               |
| Ruleset bypass     | The success measure's "no bypass", and INV-004                                 | `gh api repos/<owner>/<name>/rulesets` (bypass actors) and `.../rule-suites` (bypassed results), read after the repository's first pull request merges and again at the end of the window |
| Stops not resumed  | Health: runs that stopped and that a re-run did not carry to the welcome       | The step a stop names, and the re-run                                                                                                                                                     |
| `pap init` callers | Health: the split changed nothing for `init`, `sync` or an adopting repository | `mise run test` in pap; `pap init` and `pap sync` in the trial repository at the release                                                                                                  |
| Release refusals   | Health: the install prompt's version follows the release                       | `scripts/release.sh` output at each release                                                                                                                                               |

**Good.** Judged over the first 3 repositories the owner creates with `pap new` at the release tag, inside an operation window of 30 days from the release. If fewer than 3 are created in the window, `findings.md` says the measure was not read. A public or organisation run counts; the setting it leaves is a prompted step.

- Hand-run steps: 0 in each of the 3 runs.
- Clean after run: both commands exit 0 in each of the 3, with no item `missing` or `drift`.
- Ruleset bypass: 0 bypass actors and 0 bypassed rule suites in each of the 3, at both reads.
- Stops not resumed: 0 over the window. A stop that a re-run completes is inside the band and is noted.
- `pap init` callers: 0 failures over the window.
- Release refusals: 0 releases cut with a stale prompt; a refusal that the bump then fixes is the check working.

**Wrong.** A run that stops and will not resume, a step the owner has to work out by hand, a `missing` or `drift` item, or a bypass on a new repository. A stop is noticed at once, at the terminal; a bypass is noticed at the two reads above, so within the window at the latest. First checks, all read-only:

1. Read the stop: its step, its cause and the command it gives.
2. `pap repo status --repo <owner>/<name>` from the owner's terminal.
3. `pap doctor` in the clone.
4. `gh api repos/<owner>/<name>/rulesets` and `git -C <name> log --oneline origin/main`: one first commit, no bypass actor.
5. `pap agent-token --repo <owner>/<name>` from the owner's terminal: its message names an installation that does not cover the repository.

Only then run the command the stop gave.

**Undo.** Revert the merge and release a patch; a revert on `main` reaches nobody until it is tagged, because consumers pin the tag. The revert restores the greenfield runbook and the old prompt. In order:

1. Revert the merge by pull request.
2. Bump the version by pull request (plugin, marketplace, changelog, the install prompt) and run `scripts/release.sh`. Both pull requests are `risk:high`; expect the patch within the hour once started.
3. Machines move to the patch: `mise use -g github:blairforce1/pap@<patch>`. An exact version is not held back by mise's cooldown.
4. Repositories that pin the reverted release in `.config/mise/conf.d/pap.toml` (every repository `pap new` made at it, and any adopter that bumped to it) move their pin to the patch by pull request. Find them with `gh search code --owner <owner> '<version>' --filename pap.toml`.
5. Repositories `pap new` already made are otherwise ordinary adopting repositories and stay as they are.
6. A run stopped on the reverted release cannot be resumed by the patch, which has no `pap new`: finish it from the brownfield runbook, or delete the repository by hand in GitHub's settings. pap deletes nothing.

This text is the pull request's "How to revert".

**Operational scenarios.**

```gherkin
Scenario: A run needs a step by hand
  Given pap-new is live
  When hand-run steps is above 0 in any of the first 3 runs
  Then the owner notes the step and the run's closing line as a finding (5.9: moderate, diagnosis only)
  And the human is told by the run itself, at the terminal

Scenario: A stop is not resumed
  Given pap-new is live
  When a re-run of a stopped run does not reach the welcome session
  Then the owner runs the first checks and finishes from the brownfield runbook
  And a bugfix intent is opened citing the step, and the human is told at the terminal

Scenario: A new repository has a ruleset bypass
  Given pap-new is live
  When ruleset bypass is above 0 at either read on any repository pap new made
  Then the owner runs pap repo apply and pap repo status there, and the merge is reverted and a patch released (5.9: severe, the pre-approved rollback)
  And a bypassed rule suite is recorded as an escape, not repaired, and the human is told by the read

Scenario: pap init regresses
  Given pap-new is live
  When pap init or pap sync fails in a repository where the previous release passed
  Then the merge is reverted, a patch released and that repository's pin moved to it
  And the human is told by the failing command
```

## Areas of concern

- **INV-004 against the first push.** The invariant says `main` changes only by pull request; this change makes one direct push by design, before the ruleset exists. Three reviewers asked for the exception to be recorded in a decision record (SEC-004); the owner rejected that. The exception stands on the intent's constraint alone.
- **The first pull request needs no bypass.** #125 has it merge through one because `pr-checks` is not yet on the base branch. Here the template is on `main` from the first commit. The "no bypass" measure rests on that, and only a real run can show it.
- **A free personal plan.** A private repository there can have no main ruleset, so `pap new` refuses it. A new adopter on that plan must choose public or upgrade.
- **A longer preflight.** Preflight now asks GitHub about the plan, the organisation's rulesets and the installation before it creates anything. Each is a call that can fail; the alternative was a half-made repository.
- **A confirmation on every run.** The summary adds one Enter, counted as a prompted step. `--yes` skips it.
- **An organisation as owner.** Allowed and specified, but the 3 measured runs are likely all personal, so "clean" for an organisation is the least-tested claim here.
- **The default layers include dotnet.** The owner's choice; the summary shows it before anything is made.
- **The signals are the owner's own reading.** No monitor exists; a bypass on a repository nobody reads again is not noticed.

## Open questions

- The backlog hypothesis for a one-command greenfield start: still open: @blairforce1, a separate backlog change.
- The new-adopter path from the pasted prompt on a clean machine: answered, accepted as unmeasured by @blairforce1 for this change; the release check (`pap-new-16`, `40`) keeps the version right.
- How a re-run knows where it stopped: answered, from what exists in the current directory and on GitHub, by the table under "A re-run", with no state file.
- Defaults for visibility and layers, and whether `owner` may be an organisation: answered, private; base, risk and dotnet; either a personal account or an organisation.
- Whether the welcome reads `main` or the installed version's tag: answered, neither. The welcome reads no page; it lists what is installed on the machine, so it cannot name a command the installed pap lacks.
- Whether an exact version skips mise's `minimum_release_age`: answered, yes. mise's settings reference: "Exact versions such as `node@22.5.0`, and versions recorded in `mise.lock`, are not filtered." The example there is not a `github:` tool; the plan confirms it with one install of a release under 24 hours old, or says it could not.
- What check mise's GitHub backend makes on a downloaded release: still open: the plan, before the docs line is written (SEC-008).
- Actions minutes per pull request at the default layers: still open: @blairforce1, findings (COST-001).

## Intent churn

Two things, each with its churn commit.

- Spec review found that the intent's "recommends an all-repositories `pap-agent` installation for a personal account" contradicts decision 0023 point 1 (SEC-003). The intent now recommends a selected-repositories installation. Commit: `intent(pap-new): churn, recommend a selected-repositories installation`.
- At the restatement the owner made the welcome simpler: it reads no page from pap's docs and lists the pap skills, mods and agents installed on the machine. The intent's End bullet and its open question on `main` against the tag are changed to match. Commit: `intent(pap-new): churn, the welcome lists what is installed`.
