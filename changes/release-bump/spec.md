# Spec: release-bump

```text
id:                 release-bump
class:              feature
intent:             changes/release-bump/intent.md
scenarios:          features/release-bump.feature, release-bump-1 to release-bump-21
accepted-by:        @blairforce1
accepted-on:        2026-11-13
generated-by:       Claude Opus 5.5 via Claude Code
skills:             pap:spec 0.19.1; spec-review 1.3.1
prompt:             /spec release-bump
```

## Functional behaviour

The owner names the next version. The release-bump command is run with that version and, from a cycle, a route. It refuses unless the release bump can be made whole. Otherwise it:

1. Fetches `origin/main` and makes the work tree `../pap-release-<version>` on `change/release-<version>` from it. It then runs the rest from that work tree's own copy of the script, never the caller's.
2. Moves the four version places from the current version to the new one.
3. Renames the unreleased section's heading `### [<version>] - <date>`, with the UTC date, and adds an empty `### [Unreleased]` heading and one blank line above it. It asserts that the staged diff is exactly those lines.
4. Runs `mise run check` and `mise run test` on the head. These repeat what CI runs, which buys a failure before the push, when undoing is cheap.
5. Commits with a conventional subject and every git hook, then pushes with an upstream (`push -u`), never with force.
6. Opens the draft pull request with `class:chore`, reads the label back and adds it again if it is missing.
7. Waits up to two minutes for the risk label and answers the protected-path box from it.
8. Prints the pull request's URL.

It prints one line to stderr for each step, with that step's elapsed time.

Every network step has a timeout, and nothing prompts (`GIT_TERMINAL_PROMPT=0`). The command never runs a switch, checkout, stash or reset outside the work tree it made, so the caller's checkout keeps its branch, HEAD and index. It never merges, marks ready, adds `owner-reviewed`, pushes `main`, cuts the release or tags. Nothing is retried: a failure is undone and reported.

**Refusals** (exit 1, nothing made). The command refuses, naming the reason and, where something is left over, the one command that clears it, when:

- the version is not x.y.z without leading zeros, or is not above the current version, compared number by number;
- `origin/main` cannot be fetched;
- the version places disagree;
- the unreleased section is empty;
- `change/release-<version>` exists locally or on origin, a work tree for it is open, or a directory is at its path;
- a route is given without `--by`, or a `--by` value is not `<agent> on <model>` in the characters `A-Z a-z 0-9 space . : _ -` only, or is longer than 100 bytes;
- a route holds a newline or carriage return, has a first line other than `/change release-<version> chore Record: none` for the version given, or has a second line not of the form `Rule 20.2: ...`;
- `GIT_CONFIG_PARAMETERS`, `GIT_CONFIG_COUNT`, `GIT_CONFIG_GLOBAL`, `GIT_CONFIG_SYSTEM`, `GIT_DIR` or `GIT_WORK_TREE` is set, or the work tree's `core.hooksPath` is not the repository's own.

**Undo.** A failure, or an INT, TERM or HUP, before the pull request opens is undone from the work tree, in this order:

1. The pushed branch is deleted, only if origin still points at this run's commit. After a push that errors, `ls-remote` decides.
2. The work tree is removed.
3. The local branch is removed.

This is exit 2. The command removes only what this run recorded making. The push of a new branch is the commit point: if a second run's push is rejected, that run undoes only its local state.

Once the pull request is open, a failure leaves it open. That is exit 3, which names the pull request and the command that closes it with its branch. Anything an undo cannot remove is also exit 3, which names what is left and the command that removes it.

**The re-answer form.** `mise run release-bump --answer-risk <version>` refuses unless the open pull request's head is `change/release-<version>`, it is a draft, and its only commit is the command's. It rewrites the protected-path box and its next line from the label as it is now, and nothing else. It exits 0 when it has answered and 1 when it refuses.

**The release cycle.** A release cycle is a mechanical cycle (decision 0024) whose brief has four lines first, in order: `/change release-<version> chore Record: none`, `Rule 20.2: exempt: version bump. <why>`, `Mechanical: yes`, `Release bump: <version>`. The `Release bump:` line takes precedence over the agent's `/change` first act. The cycle's first act after `cd` to the repository is the command, run in the background with the brief's first two lines as the route and `--by` naming its own agent type and model; it waits for one completion notice. It does not invoke `/change`. Then it:

- reads the diff against the release bump's lines and reads the class and risk labels;
- watches the required checks in the background, for up to 10 minutes;
- uses the re-answer form once if the box reads "not read";
- reports in the `/change` report's format, saying that it ran the command and which model it ran on.

A required check that fails, a diff line that is not the release bump's, a refusal, exit 2 or exit 3, or a conflict ends with `ASK:` and what it found. A `risk:high` label, or a risk still not read after the re-answer, is reported as the box reads. The cycle edits no file of the pull request, retries nothing and opens no pull request another way.

**Provenance.** The body's Provenance line names the command and who ran it. That is the `--by` value the cycle passes, its agent and model as `<agent> on <model>` (for example `pap:cycle-mechanical on Claude Haiku 5.5`), written as text, never evaluated; with no `--by`, the owner, from a terminal. Run from a terminal, the command acts as the owner. In an agent shell it acts as the agent app (decision 0023), because it calls the `gh` on its `PATH`. This is a side effect, not a goal, and it is outside the measure. The `--by` value is the caller's own claim, not verified: the PM compares it with the model in the report event.

**What it leaves to others.** The decisions' "Introduced in" lines are not touched, and scenario 2 forbids that edit. A bump that falls behind main after its unreleased section has changed is closed with its branch and run again, never merged with main by hand.

Scenarios added, in `features/release-bump.feature`:

- `release-bump-1` The command opens a draft pull request: a linked work tree, one class label, exit 0, the caller's checkout unchanged (rules 27.1, 27.2).
- `release-bump-2` The diff is exactly the bump's lines (decision 0024, point 5).
- `release-bump-3` The unreleased section is dated, in UTC.
- `release-bump-4` The head passes the four conditions `scripts/release.sh` checks.
- `release-bump-5`, `-6` The body answers every Checks box and declares what made it, with and without a route (INV-009, rule 25.5).
- `release-bump-7` The protected-path box follows the risk label (decision 0016).
- `release-bump-8` A class label lost to the race is added again (#29).
- `release-bump-9` A refused run makes nothing (exit 1), version boundaries included.
- `release-bump-20` A version above the current one is taken, compared number by number (0.19.10, 0.100.0, 1.0.0).
- `release-bump-10` A route or a `--by` value that would write into the body, or a route without `--by`, is refused.
- `release-bump-21` A `--by` value of 100 characters is taken.
- `release-bump-11` Hooks switched off through the environment are refused (INV-005).
- `release-bump-12` to `-14` A failure before the open is undone (exit 2): a check, a hook, the open after the push.
- `release-bump-15` A failure after the open leaves the pull request named (exit 3).
- `release-bump-16` An interrupted run is undone.
- `release-bump-17` The re-answer form rewrites the box and nothing else.
- `release-bump-18` The command does nothing the owner keeps (INV-004, INV-006, rule 16.2).
- `release-bump-19` The release cycle runs the command, verifies, and stops at what it cannot verify.

Terms added to `product/domain.md`: Version places, Unreleased section, Release bump, Release-bump command. The event The release-bump command is run, and three rules.

## Non-functional

| What is measured                                           | Threshold                                                  | Test tier                        |
| ---------------------------------------------------------- | ---------------------------------------------------------- | -------------------------------- |
| Tokens a release-bump cycle, the completion notice's total | at most 30k (baseline 49k to 86k, the same total)          | acceptance: the next three bumps |
| Lines of a release pull request the command did not make   | 0                                                          | acceptance: the next three bumps |
| Time the command takes, by its own per-step timing         | under 6 minutes, the risk wait included                    | acceptance: the next three bumps |
| Time a refused run takes                                   | under 15 seconds, with a 10-second fetch timeout           | acceptance: the next three bumps |
| Portability                                                | POSIX `sh`; `shellcheck -s sh` and the repository's checks | unit                             |

The token estimate: about 18k agent load and brief, 2k command output, 5k verification and check reads, and 2k report, so about 27k. It assumes the cold review is skipped (decision 0024). The integration tests put a `gh` stub on `PATH` and shorten the risk wait through an environment variable. They bind behaviour, not time. Scenario 19 is bound by a text check on `pap:cycle-mechanical`'s wording, the `--by` it passes included, then by acceptance on the next bumps.

## Security

The threat this design defends against is an agent that drifts (decision 0027's scope), not one that is steered. The command holds no secret: `gh` and `git` act as whoever the shell is, and it sets no `GH_TOKEN`. The route and the `--by` value are written to the body file as text, never evaluated, and the form of each is checked first; a route without `--by` is refused, so an agent cannot leave the body saying the owner ran it. The body file sits in a directory only that run uses (`mktemp -d`), and the exit trap removes it. The command keeps by itself what the guard cannot see inside a script (decision 0027, Limits):

- a linked work tree and exactly one class label;
- every hook, with the environment that would switch hooks off refused;
- a draft only;
- the caller's checkout untouched;
- a delete only of this run's own commit.

## Interfaces and contracts

- `mise run release-bump <version> [--route "<line 1>" "<line 2>"] [--by "<agent> on <model>"]`. Exits: 0 opened, 1 refused (nothing made), 2 failed and undone, 3 failed and not wholly undone (it names what is left and the command that removes it).
- `mise run release-bump --answer-risk <version>`. Exits: 0 answered, 1 refused.
- The four conditions scenario 4 binds are plugin.json, the marketplace entry, the dated heading and the install prompt. They have one definition, which the command and `scripts/release.sh` share. `release.sh` keeps its tag and archive checks and cuts the release after the merge.
- The release brief's first line stays the `/change` route, so `/pap:pm launch` checks it unchanged (rules 18.8, 20.2). `Mechanical: yes` launches `pap:cycle-mechanical`.

## Operations

**Signals.**

| Signal          | Measures                                                             | Read from                                                 |
| --------------- | -------------------------------------------------------------------- | --------------------------------------------------------- |
| Cycle tokens    | the intent's measure, with the model beside it                       | the report event (tokens, minutes, model)                 |
| Hand edits      | release pull requests with a commit or line the command did not make | `gh pr view <n> --json commits,files`                     |
| Command minutes | the command's time by step                                           | its stderr, quoted in the cycle's report                  |
| Undone runs     | runs that exited 2 or 3                                              | cycle reports only; terminal runs are outside the measure |
| Release refuses | `scripts/release.sh` refusing after a bump merged                    | the PM's release run                                      |

**Good.** Over the next three release bumps, or 30 days, whichever is longer:

- cycle tokens at most 30k on each bump;
- hand edits 0 of 3;
- command minutes under 6;
- exit 3 never;
- release refuses 0 of 3.

The first bump is the live check of exits 2 and 3 against real GitHub. After the window, a dated note in this spec sets the bands from the three figures.

**Wrong.** Any one of these:

- a cycle over 30k;
- a release pull request with an extra commit;
- a command over 6 minutes;
- an exit 3;
- `release.sh` refusing a merged bump;
- a bump overtaken on main.

It is noticed at the cycle's report, or at the PM's release run, within the release's day. First checks:

1. `gh pr view <n> --json commits,files,labels,body,mergeable`: what the pull request carries beyond the bump, and whether it conflicts.
2. `git -C ../pap-release-<version> status` and `git ls-remote origin "change/release-<version>"`: what an exit 3 left.
3. The cycle's report, its `ASK:` line and the command's per-step lines, against its exit.
4. `mise run release <version> --dry-run`: which check refuses.

**Undo.** Revert the merge of this change. The command and the agent text go, and release bumps run on the full cycle as before. A release bump that is open, overtaken on main or left by an exit 3 is closed with its branch, as the owner's act (`gh pr close <n> --delete-branch`). Then `mise run tidy`, and run it again. A release already cut from a bump stays: ship a later version rather than delete it. Outside git: none. This text is the pull request's "How to revert".

**Operational scenarios.**

```gherkin
Scenario: Cycle tokens breach their band
  Given release-bump is live
  When a release-bump cycle reports more than 30k tokens
  Then the PM reads the report event's figures and the command's per-step lines before the next bump
  And the owner is told in the report, with the figure and the model

Scenario: A release pull request carries a hand edit
  Given release-bump is live
  When a release pull request holds a commit the command did not make
  Then the owner does not merge it as a bump; it is closed and run again
  And the owner is told at the report

Scenario: A run is left half made
  Given release-bump is live
  When the command exits 3
  Then the cycle ends with ASK: and the command that removes what is left
  And the owner is told before any other release bump runs
```

## Areas of concern

- Decision 0024 and the mechanical agent's text say a cycle's first act is `/change`. A dated note on 0024 records the release exception. Both passages of the agent's wording change: the first act, and the instruction to "push what is committed". No rule states a first act.
- The same note records the reading behind the cold-review skip: the empty `[Unreleased]` heading and its blank line, added above the dated heading, are part of "a new version heading" (point 5, as #144 read it).
- The guard cannot see `gh` inside a script (decision 0027, Limits). The command's own refusals are the only check on its work tree, label, environment and route, and the tests bind them.
- Undoing a pushed branch is a push that deletes. Decision 0022 refuses force pushes, not deletes. The pre-push hook needs the change branch checked out, so the delete runs from the work tree, first.
- `/change`'s body template lives in its skill. The command's body is a fixed file beside it in `scripts/`. `release-bump-5` binds it to what the reusable `pr-checks` reads.

## Open questions

- Run from the owner's terminal: answered. It works the same, as a side effect; it is not a goal and not measured.
- The class label: answered, always `chore`.
- A rule or a dated note on decision 0024 for the first-act exception: answered. A dated note on 0024, which also records the cold-review reading, plus the agent's wording.
- Where the pull request body's template lives: answered. A file beside the command in `scripts/`; the plan names it.
- Option B, the script run inside `/change`, as the comparison: answered as an estimate, not built. B costs about 40k to 55k a bump, against A's 27k. The measure reads A's actual figure.
- Whether the bump fills "Introduced in: not yet released": answered by the owner, 2026-11-13: no. It is a change of its own.

## Intent churn

None.
