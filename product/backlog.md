# Backlog: PAP

Hypotheses, not features. Ordered by value and risk. Rewritten when findings come back.

This file is the backlog (decision 0011). An issue may propose an item; the item exists once it is merged here. Every change names one of these in its `intent.md`, or says it is reactive and why.

Last reviewed: 2026-11-05

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

**H-012** We believe a packaged project-manager role (a `/pap:pm` skill, a `pap:member` agent, tracker and brief templates) will produce changes run through cycles with less rework and no work lost to a shutdown, measured by cycles that get a message after their first report (decision 0018).
Related: decisions 0002, 0018; `CLAUDE.md` (one pull request per agent context). Class: feature
Built in slices: `/pap:pm` (`start`, `launch`, `event`, `pause`, `relaunch`, `audit`, the last classifying each rule as project or general); the `pap:member` agent definition; the tracker and brief templates (the state file with its PAP candidates section); the PM console, designed separately. The first three ship in one release, the intervention's boundary.

**H-013** We believe a cycle with two members, a developer and a QA, will produce less rework than a one-member cycle with a fresh-context review before its pull request (decision 0019, proposed in a parallel pull request), measured by messages to a cycle after its first report and by tokens on the cycles that got one (the one-member median today is 690k, decision 0018), over a handful of real changes on each arm; the second member stays only if it beats the review arm on both.
Related: decisions 0002, 0018, 0019; H-012. Class: feature
Method: a role is added only when its measurement wins; the arm without it is the control, as Anthropic's guidance on folding subagents into the main loop has it (decision 0018, evidence).
Before the trial: decision 0002's stop, which `CLAUDE.md` states as one pull request per agent context, has to be restated as one pull request per cycle; that is a later decision, not part of 0018.

**H-015** We believe an operations member that owns phases 8 to 10 (designs the signals, control bands and undo at spec time; delivers in stages: merge to staging, then live behind a flag, promoted when the bands hold; watches the operation window on a schedule; on a breach runs the pre-authorised reversible actions and opens the revert as a pull request for the human; turns every breach into findings and an eval) will produce escapes caught inside the operation window rather than by a user, measured by escapes caught in the window as a share of all escapes, and by time from breach to undo.
Related: process 5.9, 5.11, 6.2; decision 0021 (the spec's Operations section is its input, and its operational scenarios are what it binds); H-005 (`/findings`); H-013's method, a role is added only when its measurement wins. Class: feature
Pilot on a real product's first deployment, not on pap, which deploys nothing. Automatic action on a live system, even a reversible and pre-authorised one, needs its own decision record before the watcher acts; until then it proposes and the human runs the undo (process 5.9).

**H-016** We believe giving agent sessions their own GitHub identity, a GitHub App whose installation token `pap agent-token` mints on demand, will produce GitHub controls that bind the agent and not the owner, measured by GitHub acts of an agent attributed to the owner (pull-request authors and `labeled` events, at 0) and by GitHub-side refusals of an agent's settings write and of an agent-added `owner-reviewed` (decision 0023, proposed).
Related: decisions 0005, 0016, 0018, 0022; rules 23.1 to 23.4. Class: infra
Built in slices, in this order (decision 0023, point 5): `pap agent-token`, `pap agent-key`, the `gh` shim in the base layer and the `pap doctor` checks, proving on the way whether Pull requests write alone carries a pull request's labels and comments; the boundary (`pap claude` starting Claude Code with `GH_CONFIG_DIR` unset, the owner's directory in `pap doctor` and the account-setup guide, the shim's refusal of a set `GH_CONFIG_DIR`, `/pap:reviewed` and `/pap:accept` running as the owner through it, the hook rule refusing `GH_CONFIG_DIR` in an agent's command); the actor-and-owner check and the `closed`-event merge report in the reusable `pr-checks`; the owner's bypass actor in `all-branches.json` through `pap repo apply` and `status`, which ships last; the docs and the dated notes on 0016 and 0022. The owner's one-time setup (register `pap-agent`, install it, import the key, sign `gh` in to the owner's directory) precedes the first slice's use.

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
