# Backlog: PAP

Hypotheses, not features. Ordered by value and risk. Rewritten when findings come back.

This file is the backlog (decision 0011). An issue may propose an item; the item exists once it is merged here. Every change names one of these in its `intent.md`, or says it is reactive and why.

Last reviewed: 2026-11-12

## Recommended first slice

**H-001** We believe giving every principle and section of the process document a stable ID, and a `pap coverage` check that maps each ID to a rule, a backlog item or an explicit deferral, will produce a process whose unbuilt parts are visible without a manual review, measured by uncovered IDs and by `rules.md` entries whose enforcement column disagrees with the ruleset and workflows, both reported in every `/change` report and both at 0 before each release.
Tests invariant: none directly. It closes the gap behind the 2026-09-25 review, which found unbuilt and misdescribed controls only because the human asked. Envision would pick H-004 instead, because INV-010 (events carry the process version) is the riskiest invariant: every measure depends on it. Confirm or swap.
Class: infra
Status: built in change process-coverage (`pap coverage`).

## Ranked

Proposed order; confirm or reorder.

**H-002** We believe adopting v0.5.0 in the trial app repository will produce real changes carried by the process, measured by change pull requests merged there under PAP.
Related: vision §Done enough to matter. Class: infra

**H-003** We believe making a missing approval on a protected path fail `pr-checks` will produce protected paths that do not change unapproved, measured by merged pull requests touching a protected path with no recorded approval, at 0.
Related: vision §Done enough to matter; process principles 9 and 11. Class: security-sensitive
Status: built by decisions 0012 and 0013 (`pr-checks` refuses a protected path without an owner's `Approved-by:` line for the head). Dropped: denying agent Edit and Write on protected paths in the `PreToolUse` hook, because it would have blocked 10 of the last 10 change pull requests; the approval gate, not the edit, is the control.

**H-004** We believe deriving CDEvents from the GitHub pull request timeline (phase and return labels, reviews, merges), each carrying the pinned process version, will produce interventions settled without hand counting, measured by records past their revisit trigger that reach a `measured:` status from derived data alone.
Related: vision §How we will know. Class: feature

**H-005** We believe `/intent` and `/findings` skills will produce closed changes whose escapes are attributed to a phase, measured by the share of closed changes with a merged `findings.md`.
Related: vision §How we will know; process 5.11. Class: feature
Built in slices: `/intent` landed (decision 0020: the interview, the recorded yes, `intent.md` committed on the change branch before the spec and the code); `/findings` next, which rule 17.2 also waits for.

**H-011** We believe a spec whose acceptance scenarios are written in a shared domain vocabulary and bound to tests will produce conformance to the spec that is checked rather than judged, measured by `fix:` or `revert:` pull requests merged within 14 days that touch a file a scenario-carrying change changed (decision 0017).
Related: process 5.4, 5.6, 5.8; decision 0017. Class: feature
Built in slices: `product/domain.md` and `/envision` seeding it; `/spec` with scenarios and the process amendments; the binding check (rule 17.1); `pr-checks` for rules 17.3 and 17.4; a vocabulary pass in `spec-review-qa`; executed runners in the dotnet and go layers. The first three ship in one release, the intervention's boundary. `/spec` reads `intent.md`, so H-005's `/intent` comes first; rule 17.2 needs its `/findings`.
Status: the `/spec` slice landed (decision 0021): scenarios in `features/<slug>.feature` tagged `@id` and `@pending`, terms seeded into `product/domain.md` by the spec that first needs them (the `/envision` slice is still to come), the review board run by class with dispositions recorded, the human's yes recorded in `spec.md`, and an Operations section for feature, infra and security-sensitive changes. Next: the binding check.

**H-012** We believe a packaged project-manager role (a `/pap:pm` skill, the `pap:cycle` agent (decision 0024), tracker and brief templates) will produce changes run through cycles with less rework and no work lost to a shutdown, measured by cycles that get a message after their first report (decision 0018).
Related: decisions 0002, 0018; `CLAUDE.md` (one pull request per agent context). Class: feature
Built in slices: `/pap:pm` (`start`, `launch`, `event`, `pause`, `relaunch`, `audit`, the last classifying each rule as project or general); the `pap:cycle` agent definition (shipped, decision 0024); the tracker and brief templates (the state file with its PAP candidates section); the PM console, designed separately. The first three ship in one release, the intervention's boundary.
Status: PM mode by default landed (decision 0025). Shipped: `pap claude` starts a PM session in an adopting repository, with `--solo` as the owner's way out; `/pap:pm start` and `/pap:pm launch <slug>`, the launch typed by the owner and its checks a script; the minimal tracker, a git repository of its own outside the project with an event log, a state file and the briefs. Left: `event`, `audit` and a full `relaunch`; a brief template beyond the three lines the launch checks; the state file's PAP candidates section. Until `event` ships the PM appends event lines itself, and pausing stays with the console's `/pm exit`.

**H-013** We believe a cycle with two members, a developer and a QA, will produce less rework than a one-member cycle with a fresh-context review before its pull request (decision 0019, proposed in a parallel pull request), measured by messages to a cycle after its first report and by tokens on the cycles that got one (the one-member median today is 690k, decision 0018), over a handful of real changes on each arm; the second member stays only if it beats the review arm on both.
Related: decisions 0002, 0018, 0019; H-012. Class: feature
Method: a role is added only when its measurement wins; the arm without it is the control, as Anthropic's guidance on folding subagents into the main loop has it (decision 0018, evidence).
Before the trial: decision 0002's stop, which `CLAUDE.md` states as one pull request per agent context, has to be restated as one pull request per cycle; that is a later decision, not part of 0018.

**H-015** We believe an operations member that owns phases 8 to 10 (designs the signals, control bands and undo at spec time; delivers in stages: merge to staging, then live behind a flag, promoted when the bands hold; watches the operation window on a schedule; on a breach runs the pre-authorised reversible actions and opens the revert as a pull request for the human; turns every breach into findings and an eval) will produce escapes caught inside the operation window rather than by a user, measured by escapes caught in the window as a share of all escapes, and by time from breach to undo.
Related: process 5.9, 5.11, 6.2; decision 0021 (the spec's Operations section is its input, and its operational scenarios are what it binds); H-005 (`/findings`); H-013's method, a role is added only when its measurement wins. Class: feature
Pilot on a real product's first deployment, not on pap, which deploys nothing. Automatic action on a live system, even a reversible and pre-authorised one, needs its own decision record before the watcher acts; until then it proposes and the human runs the undo (process 5.9).

**H-016** We believe giving agent sessions their own GitHub identity, a GitHub App whose installation token `pap agent-token` mints on demand, will produce GitHub controls that bind the agent and not the owner, measured by GitHub acts of an agent attributed to the owner (pull-request authors and `labeled` events, at 0) and by GitHub-side refusals of an agent's settings write and of an agent-added `owner-reviewed` (decision 0023).
Related: decisions 0005, 0016, 0018, 0022; rules 23.1 to 23.4. Class: infra
Built in slices, in this order (decision 0023, point 5): `pap agent-token`, `pap agent-key`, the `gh` shim in the base layer and the `pap doctor` checks, proving on the way whether Pull requests write alone carries a pull request's labels and comments; the boundary (`pap claude` starting Claude Code with `GH_CONFIG_DIR` unset, the owner's directory in `pap doctor` and the account-setup guide, the shim's refusal of a set `GH_CONFIG_DIR`, `/pap:reviewed` and `/pap:accept` running as the owner through it, the hook rule refusing `GH_CONFIG_DIR` in an agent's command); the actor-and-owner check and the `closed`-event merge report in the reusable `pr-checks`; the owner's bypass actor in `all-branches.json` through `pap repo apply` and `status`, which ships last; the docs and the dated notes on 0016 and 0022. The owner's one-time setup (register `pap-agent`, install it, import the key, sign `gh` in to the owner's directory) precedes the first slice's use.

**H-017** We believe a `pr-checks` server gate that refuses a change pull request carrying neither an accepted `intent.md` nor a `Route:` line tied to a logged launch will produce changes that follow the route whichever session made them, measured by merged change pull requests with neither, at 0, counted the same way for sessions started with and without `pap claude`.
Related: decision 0025 (rules 25.1, 25.2 and 25.5 name what it would close); rules 20.1, 20.2 and 21.1, whose planned `pr-checks` checks it carries; the pm-mode intent's first non-goal and its spec review's SEC-003. Class: security-sensitive
Why: PM mode binds only a session `pap claude` started, and only its main session. A session started as plain `claude` has no mode, and a PM that has a sub-agent make the edit passes the guard. Both are closed only where the session cannot reach: at the pull request.
Open for its intent: how a launch logged on one machine is shown to the server, so that a writing sub-agent is tied to it; whether a PM session's `gh pr create` is refused (rule 18.1 keeps the housekeeping exception).

**H-018** We believe a launcher that resolves pap for the repository at launch will produce sessions whose `pap claude`, gh shim and mode match the repository's pin, measured by sessions started by a pap other than the repository's pinned version, at 0 (the session log could carry the launcher's version).
Related: decision 0023 (rule 23.4, `pap claude`); decision 0025; #131. Class: feature
Why: `pap shell-init` records the absolute path of one pap install when a terminal starts, and #131 only lets a newer release on `PATH` win. Neither reads the pap version the repository pins in `.config/mise/conf.d/pap.toml`, so two repositories pinned at different versions are launched by the same pap. The owner, 2026-11-10: the launcher should "honour the version pinned within a repo, ideally", and it is "quite important".
Open for its intent (rule 20.2 item 2, so it needs an `/intent`): which design. The candidates are resolving with `mise exec -- pap claude` at launch, calling `pap` by name on `PATH`, or recording mise's shim; none is chosen. A plugin cannot replace the launcher: `PAP_MODE`, the agent gh directory and the shim must be in Claude Code's own environment before it starts.

**H-019** We believe a PM session that saves the owner every turn that carries no decision (it suggests only lines the owner can type in that session; the yes to a plan ends with the brief written, the restate logged and the launch line printed, as `/pap:pm sync` does; `/pap:pm start` and every status read GitHub for the open pull requests and log their merges; `/intent`, `/spec` and `/pap:plan` end with a short summary and open their files in the owner's editor) will produce changes carried with fewer owner turns, measured by owner messages that only relay a fact the session could read (a merge, a pull request's state) or retype a line the session could not run, at 0 over the next ten changes.
Related: decisions 0018, 0025, 0026 (step 6 of `/pap:plan` says not to write the brief); rule 18.2 (the owner still types every launch). Class: feature
Why: on 2026-11-12 the owner said a pull request had merged four times, retyped a `/change` line a PM session cannot run, and gave a plan's yes followed by a separate brief and launch. All three skills remove their worktree at the end, so opening the files means opening them from the branch or keeping the worktree until launch.
Open for its intent: which editor and how it is configured; whether a merge read from GitHub is logged without the owner's word.

**H-020** We believe size limits counted from a proxy the spec already has (at most 20 scenarios a change at the spec's yes, with `/spec` proposing the split above it; intent and spec limits in words, not pages; each build pull request reporting its changed lines beside an estimate of scenarios times 60) will produce changes whose size is known before code and that fit one sitting, measured by specs over the cap at their yes (3 of the last 5 today, to 0) and by actual over estimated lines.
Related: decisions 0020, 0021, 0026; process principle 3; PSP's proxy-based estimating (PROBE). Class: infra
Why: feature specs have no limit and run 3,494 to 7,134 words (with their feature files 5,200 to 11,100), 17 to 57 scenarios; six of seven intents run 518 to 875 words against "half a page". The only two plans within 1000 words had 17 and 20 scenarios, so a larger spec is found unplannable only after its yes. Over the last five feature pull requests a scenario came to 49 to 81 changed lines outside `changes/` and `features/`.
Method: PROBE sizes a design from its parts using the owner's own history. The scenario is the part; what does not carry over is the effort regression (no token figures per cycle yet, H-006) and prediction intervals at five data points. The size table is recalculated quarterly from merged pull requests.

**H-021** We believe a plan that cuts a change into parcels (the accepted intent, spec and plan merged first as their own pull request; each parcel then one cycle and one pull request from main, either complete, binding whole scenarios, or dark, reached by no released entry point; serial unless the parcels share no files and neither waits on the other) will produce pull requests the owner reviews in one sitting, measured by changed lines per merged pull request of the feature, infra and security-sensitive classes (median 1,879 outside `changes/` and `features/` over #126, #127, #139, #146 and #147, to at most 700).
Related: decision 0026, which it amends, with 0002, 0020 and rule 2.2 (one pull request a change); rules 17.2, 17.3, 18.2, 20.1, 21.1, 26.1 to 26.3; the launch's plan check, which reads `change/<slug>`; every revisit that counts change pull requests; H-020 (the size a parcel is held to). Class: feature
Why: every change that went through intent, spec and plan landed as one pull request of 13 to 28 files; in #146 and #147 the accepted artefacts were 42 to 46% of the diff.
First slice: two pull requests only, the artefacts then one build, which proves the launch reading the plan from main. Not in it: stacked branches, a parcel with its own intent or spec, tests split from their code, parallel parcels by default, a size gate that refuses.
Open for its intent: whether it amends 0026 now or waits for 0026's revisit.

**H-022** We believe a tracker that records interrupted and deferred work (an intent, spec or plan begun and not finished; a cycle's merge read from GitHub) and a PM console that shows it as open work (changes between intent and merge, accepted plans not yet built, each plan opened in the editor from the console; backlog hypotheses not yet dropped; revisits due), in place of the CI tab, will produce no work forgotten between sessions, measured by work the owner had to remind the PM of, at 0.
Related: decision 0018 (rule 18.3, the event log); the pm-console plugin; H-012. Class: feature
Why: on 2026-11-12 the tracker said "Waiting on the owner: nothing" while an intent interview was half done, and kept a merged cycle in flight. Intent, spec and plan runs log no events. The CI tab has not been used.

**H-023** We believe a PM console that guides the owner through pap (a list of the commands and skills that can be run in the session, with one line each on what it does and when; more on the command being typed, as the console's class band already reads the prompt; and where the current change stands in intent, spec, plan, build and merge, with the next command) will produce sessions where the owner types the right command first, measured by commands the owner typed in a PM session that the session could not run or that were refused for their form, at 0 over a month.
Related: the pm-console plugin (its class band reads the prompt as it is typed); H-019; H-022 (the change's stage comes from the same events). Class: feature

**H-024** We believe an efficiency audit that the tracker calls due (at five merged change pull requests since the last audit, said by `/pap:pm start` and at each merge) and that reads its numbers from the event log (each report event carrying the cycle's tokens and minutes) will produce audits run on time, measured by audits run against audits due, and briefs whose budgets hold, measured by cycles over their brief's budget.
Related: decision 0018, point 7 (the audit) and point 3 (budgets set from its medians); rule 18.3; H-012 (`/pap:pm audit`); H-006. Class: feature
Why: the first audit ran on 2026-11-12 at 14 merges, when the owner asked: 0 of 2 due had run. None of 17 report events carried tokens or minutes, so the numbers came from session transcripts. Budgets of 40k to 80k were guessed; cycles ran docs 52k to 71k, release bumps 49k to 86k, bugfixes 82k to 98k, feature builds 98k to 309k.

**H-025** We believe a spec review sized to the change (perspectives chosen by what the spec touches, not by class alone; the register holding Blockers and Majors, with the rest as one list the owner can take or leave whole) will produce shorter specs at the same quality, measured by tokens a spec review (about 1M today) and spec words at the yes (H-020), with escapes traced to the spec (decision 0017) not rising.
Related: decision 0021 (the board by class); the spec-review plugin; H-020. Class: infra
Why: a feature spec's review runs eight or nine perspectives at 98k to 121k tokens each and returns about 60 findings, of which 95% are accepted (QA 102 of 104). Each accepted finding is an edit to the spec, which is how specs reach 4,000 to 7,000 words.

**H-026** We believe a release script that makes the version bump end to end (the version in `plugins/pap/.claude-plugin/plugin.json`, the pap entry of `.claude-plugin/marketplace.json` and the install prompt of `docs/agent-onboarding.md`, and the `[Unreleased]` heading under `## pap` in `CHANGELOG.md` dated; then the worktree, the commit, the push and the draft pull request with its class label), with the cycle only running it, watching the checks and verifying the result, will produce releases that cost a fraction of a cycle, measured by tokens a release bump (49k to 86k on the full cycle today, to the floor of a mechanical cycle).
Related: `scripts/release.sh` (which already refuses a release unless those four places agree); decisions 0024 (the mechanical cycle) and 0027 (a pull request from a worktree with one class label); `/pap:pm sync`, which writes its brief by script the same way. Class: feature
Why: five bumps ran on the full `pap:cycle`, 4 to 8 minutes each, for a diff of about five lines in known places.

## Unranked

**H-006** We believe joining Claude Code's telemetry to the change id will produce inner-loop measures per change, measured by the share of changes with token and rework-share data.
Related: vision §Assumptions to test. Class: feature

**H-007** We believe diff coverage and cognitive complexity, reported as signals with a `REVIEW.md` in the base template, will produce more defects caught before merge, measured by review yield (caught before merge against escaped).
Related: process 5.8. Class: feature

**H-008** We believe a scheduled monthly review, with process section 6.4 as its brief, will produce drift caught between releases, measured by drift signals (section 6.5) found by the review before a human asks.
Related: vision §How we will know. Class: infra

**H-009** We believe `pap career export` will produce one evidence fragment per closed change at no marginal cost beyond a fragment review, measured by fragments per closed change (spec: `spec-career-export-1.md`).
Related: vision §Non-goals (export, not render). Class: feature

**H-010** We believe an outcome eval suite of real tasks, run on every change to skills, hooks or model, will produce configuration changes that do not silently regress, measured by eval pass rate per configuration version.
Related: process 6.2. Class: infra
Runner: PAP is a plugin, so `claude plugin eval` ([docs](https://code.claude.com/docs/en/plugin-evals); with and without the plugin as baseline, graders, non-zero exit for CI) is the intended harness, gated in the tests workflow. A decision record follows when the first suite lands. Case design follows [Automating eval design and hillclimbing](https://claude.dev/blog/automating-eval-design-and-hillclimbing/).

**H-014** We believe auto-merging `risk:low` pull requests on green checks will produce faster flow with no loss of quality, measured by the rate of `fix:` or `revert:` pull requests touching them within 14 days, which stays at or below the human-merged rate.
Related: decision 0016, rule 16.2. Class: infra
Parked. It contradicts decision 0016 and rule 16.2 today (an agent never merges; the owner merges every pull request), so it waits until 0016's revisit comes back clean. Precedent: the Claude Code team merges low-risk pull requests without a human ([Solving code review at Anthropic](https://claude.dev/blog/solving-code-review-at-anthropic/)).

## Dropped

- Uber-style scalar PR risk score: no action a solo reviewer can take on a number. Its useful half returns as the attention plan in H-007.
