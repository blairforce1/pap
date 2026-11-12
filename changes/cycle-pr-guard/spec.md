# Spec: cycle-pr-guard

```text
id:                 cycle-pr-guard
class:              infra
intent:             changes/cycle-pr-guard/intent.md
scenarios:          features/cycle-pr-guard.feature, cycle-pr-guard-1 to cycle-pr-guard-17
accepted-by:        @blairforce1
accepted-on:        2026-11-12
generated-by:       Claude Fable 5.2 via Claude Code
skills:             pap:spec 0.19.1; spec-review 1.3.1
prompt:             /spec cycle-pr-guard
```

## Functional behaviour

The guard that runs before every Bash call of an agent gains two rules,
recorded in decision 0027. Both bind the callers of a PM session: its
main session and every sub-agent of it. A solo session, a session with no
mode and the owner's own shell are not bound.

**Where a command runs.** The directory the guard already works out for a
command: the session's directory, as moved by a `cd` earlier in the
command and by `git -C`. The guard places it as one of: in the main
checkout of an adopting repository (the work tree whose git directory is
the repository's own); in a linked work tree of one; in no adopting
repository; or not placed. It is not placed when the directory does not
exist as the guard runs, as when the same command creates it, or when it
is written with a variable, `pushd`, `cd -`, or a git directory given by
`GIT_DIR`, `GIT_WORK_TREE`, `--git-dir` or `--work-tree`.

**A directory that is not placed is refused.** When a command names one
of the four verbs below and its directory is not placed, and the
session's own project is an adopting repository, the call is refused and
told to run that command by itself, from the work tree. This is the same
direction as a label the guard cannot read.

**Rule 27.1, the pull request.** A `gh pr create` (or `gh pr new`) is
bound when its directory is in an adopting repository, or when the
session's own project is one, wherever the command runs and whatever `-R`
names. It is checked in this order, and the first failure refuses it:

1. Its directory is not placed: refused.
2. It runs in the main checkout: refused, whatever its labels.
3. It gives no class label: refused.

A command gives a class label when exactly one of its label values is
one. The values are those of every `--label` and `-l`, split on commas,
with spaces trimmed. A value is a class label when it is `class:` and one
of feature, infra, security-sensitive, bugfix, spike, chore, docs, in
lowercase. A value holding `$` or a backquote cannot be read and is
ignored: one literal class label beside it passes, and none beside it is
refused. Two literal class labels are refused.

The branch is not looked at: in an adopting repository every pull request
an agent opens is a change pull request (decision 0002). A pull request
opened through `gh api` or GraphQL is not seen by this rule; decision
0027 names that as a limit, left to H-017. Nothing compares the label
with the class the change's intent gives; that too is H-017's.

**Rule 27.2, the branch.** It binds a `git switch` or `git checkout`
whose directory is in the main checkout of an adopting repository, or is
not placed. In the main checkout only these forms are let through:

- `git switch` whose one word that is not an option is `main`, with none
  of `-c`, `-C`, `--create`, `--force-create`, `-d`, `--detach`,
  `--orphan`;
- `git checkout` whose one word that is not an option is `main`, with
  none of `-b`, `-B`, `--detach`, `--orphan`;
- `git checkout` with a `--` that at least one word follows, and none of
  those four options before it: a path restore;
- `git checkout` with no word that is not an option, and none of those
  four options.

Every other `git switch` and `git checkout` there is refused: a branch, a
commit, `-`, a path written without `--`, and `git checkout <branch> --`,
where the trailing `--` makes the word a branch. Every other git command
is let through by this rule, `fetch`, `pull`, `worktree`, `branch` and
`status` among them, and nothing is refused in a linked work tree.

Some of those other commands can also take the main checkout off `main`:
`git branch -m`, `git stash branch`, `git rebase <upstream> <branch>`,
`git bisect start` and `git symbolic-ref HEAD`. They are limits of this
rule, named in decision 0027; the reading of the main checkout below is
what finds them.

**The refusals.** Two lines on the guard's usual channel, as its other
refusals are, and the call is blocked. `<directory>` is the directory the
command runs in, as the guard worked it out:

```text
guard-route: refusing gh pr create in the main checkout, <directory>
guard-route: rule 27.1: a change pull request is opened from its worktree on change/<id>, made by /change.

guard-route: refusing gh pr create with no class label in <directory>
guard-route: rule 27.1: run /change, which opens the pull request with --label class:<class>.

guard-route: refusing to switch the branch of the main checkout, <directory>
guard-route: rule 27.2: parallel sessions share it; work in a worktree on change/<id>, made by /change. To restore a path: git checkout -- <path>.

guard-route: refusing <gh pr create | a branch switch> in a directory the guard cannot place: <the directory as written>
guard-route: rule <27.1 | 27.2>: run it as its own command, from the worktree made by /change.
```

**The log.** Each refusal adds one line to the refusal log, in the shape
its lines already have: the time, the session, the mode, the caller, the
directory, the repository and a kind. The kinds are `pr-main-checkout`,
`pr-label`, `branch-switch`, `path-without-dashes` (a `git checkout` of
one word with no `--`, which may be a path) and `unplaced`. The line also
carries what was refused, as the verb and its form: `gh pr create`,
`git switch` or `git checkout`, never the whole command, which may hold a
body or a token. A refusal is still made when the line cannot be written,
and the guard then says so in a third line. The log is advisory: the
callers it records can write to it, so what it shows is checked against
the session's transcript before anything is concluded.

**What the guard cannot read.** A `gh pr create`, `git switch` or
`git checkout` the guard cannot parse, in a PM session, is let through
and leaves one line of kind `unread`. A `gh` or `git` reached through
`bash -c`, a script or an alias is not seen at all, and a missing `jq` or
a git call that does not return lets the call through as today. These are
the intent's first non-goal, named as limits in decision 0027 and left to
H-017. The guard is a check on an agent that drifts, not on one that is
steered.

**The reading at session start.** When a PM session starts, the hook that
gives it its role reads the main checkout of its repository. On `main` it
adds nothing. Off `main` it adds to that start's line in the session log
the branch, or that the checkout is detached, and tells the PM session in
its role: the main checkout is on `<branch>`; tell the owner first, and
do not switch it yourself while a session may be using it. This is the
recorded reading the second measure is read from; `pap doctor` is the
owner's reading on demand.

**pap doctor.** Its git section gains one item, the main checkout of the
repository it is run in, from any of its work trees. In an adopting
repository: `ok` on `main`; `drift` on another branch, naming the branch,
the main checkout's path and `git switch main`; `drift` at a detached
commit, saying so. A drift counts toward its exit 1. It is `skipped`
outside a repository, in a repository that does not adopt PAP, and in
one with no main checkout. `main` is the branch every adopting repository
has (decision 0002).

**The adoption guides.** `docs/agent-onboarding.md` and
`docs/getting-started.md` adopt on `change/adopt-pap` in the main
checkout and then ask for `pap doctor` to exit 0. Both are amended here:
the adoption step names this item as one the guide gives the human,
expected until the adoption pull request merges; and the later steps that
have an agent switch a branch or open a pull request in the main checkout
move to a work tree made by `/change`.

**The label a cycle cannot add.** With rule 27.1 an agent's pull request
is opened with its class label, so the follow-up `gh pr edit --add-label`
is left for a label that raced the creation. `plugins/pap/agents/cycle.md`
and `plugins/pap/agents/cycle-mechanical.md` each gain this sentence, word
for word: "If Claude Code denies the command that labels your pull
request, do not try it another way: end with `ASK:` and give the owner
this one command, `gh pr edit <number> --add-label class:<class>`." That
is wording, not a control. `docs/troubleshooting.md` gains two entries:
the denied label, telling the owner to compare the command with that
shape before running it; and a repository with no `class:*` labels, where
`gh pr create --label` fails and the fix is the owner's `pap repo apply`.
No permission rule is specified and `pap doctor` checks none: see Open
questions.

**Decision 0027** ships with the change, with the header every record
has, its PIP included. It records rules 27.1 and 27.2; who the guard is
for; the limits named above; that it narrows rule 18.1, whose process
housekeeping pull request is now opened from a work tree too; the measure
below as its expected effect, with the query that reads it; and the
revisit, written as decision 0010 types it: `after 20 change PRs`.
`rules.md` gains 27.1 and 27.2, and 18.1's entry gains a pointer to 27.1.
`docs/run-a-project.md` gains the new kinds where it describes the
refusal log.

Scenarios added, in `features/cycle-pr-guard.feature`:

- `cycle-pr-guard-1` gh pr create with no class label is refused: the first symptom, for both callers.
- `cycle-pr-guard-2` gh pr create with one class label is let through: what `/change` runs keeps working.
- `cycle-pr-guard-3` gh pr create in the main checkout is refused: the second symptom.
- `cycle-pr-guard-4` a switch of the main checkout's branch is refused: the third.
- `cycle-pr-guard-5` what the main checkout is for keeps working: the intent's second constraint.
- `cycle-pr-guard-6` a branch switched in a linked work tree is not this rule's.
- `cycle-pr-guard-7` outside a PM session, or outside an adopting repository, nothing new is refused: the third non-goal.
- `cycle-pr-guard-8` whatever the guard refused before it refuses still.
- `cycle-pr-guard-9` a refusal leaves one line in the refusal log.
- `cycle-pr-guard-10` pap doctor reads the main checkout.
- `cycle-pr-guard-11` pap doctor outside a repository.
- `cycle-pr-guard-12` a cycle's label command is denied: bound to the quoted sentence in the two cycle definitions; no session is run, and that is accepted.
- `cycle-pr-guard-13` a directory the guard cannot place is refused.
- `cycle-pr-guard-14` gh pr create outside the repository is still bound by the session's project.
- `cycle-pr-guard-15` a PM session that starts with the main checkout off main is told, and the start is recorded.
- `cycle-pr-guard-16` a command the guard cannot read leaves an unread line.
- `cycle-pr-guard-17` a refusal whose log line cannot be written is still made.

Terms added to `product/domain.md`: Main checkout, Class label; the events
"An agent opens a pull request" and "An agent switches a branch"; two
rules; the definitions of the Refusal log and the Session log gain the
new lines.

## Non-functional

| What is measured                                                                                                                                             | Threshold                                                 | Test tier   |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------- | ----------- |
| git processes the guard starts, for a Bash call that runs neither `gh pr create`/`new` nor `git switch`/`checkout`                                           | 0 more than before this change                            | integration |
| git processes the guard starts to place the directories of one Bash call that runs one or more of them, in a PM session; a refusal's log line is not counted | 2 more than before this change, at most                   | integration |
| git processes the guard starts for any Bash call outside a PM session                                                                                        | 0 more than before this change                            | integration |
| Commands of scenario 5 refused under rule 27.1 or 27.2                                                                                                       | 0                                                         | integration |
| Cases of the guard's test suite as it stood before this change that fail                                                                                     | 0                                                         | integration |
| Shell the hooks need                                                                                                                                         | POSIX `sh` and `jq`, as today; shellcheck clean (INV-003) | unit        |

Processes are counted by a stand-in `git` first on the path, as the
guard's tests count them today.

## Operations

**Rollout.** The rules and the session-start reading ship in the pap
plugin; the doctor item ships in the `pap` command, which a repository
pins. Both arrive with the release decision 0027 names as "Introduced
in". In each of the three repositories the owner updates the plugin and
restarts its sessions, then takes the release with a template sync.
`pap doctor` shows both are live: its plugin line, and the new item. A
session on the older plugin is not bound, and until the pin is bumped the
doctor item is absent. The measure's windows start on the day the last of
the three repositories has both.

**Signals.**

| Signal                         | Measures                                                                                                                                        | Read from                                                                                   |
| ------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| Unlabelled agent pull requests | The intent's first measure: pull requests the agent app opened that had no class label 60 seconds after they were opened                        | GitHub: each pull request's creation time and labeled events, by the query in decision 0027 |
| Main checkout off main         | The intent's second measure: PM session starts whose session log line names a main checkout off `main`                                          | the session log                                                                             |
| Saves                          | Beside the second measure: refusals of kind `pr-main-checkout`, `pr-label`, `branch-switch` and `unplaced`, counted once for a session and form | the refusal log                                                                             |
| False refusals                 | Health: a refusal of those kinds whose form was one scenario 5 lets through, or `/change`'s own; and every `path-without-dashes` line           | the refusal log, checked against the session's transcript                                   |
| Unread                         | Health: lines of kind `unread` in PM sessions                                                                                                   | the refusal log                                                                             |

The baseline for the first, counted in pap on 2026-11-12 in the signal's
own terms: of the last 20 pull requests the agent app opened (#126 to
#145), 0 had no class label 60 seconds after opening; each had it within
two seconds. The one known failure is the incident the intent reacts to,
in another repository. The owner counts the other two repositories with
the same query and writes all three into decision 0027 before the
release, so the prediction comes before the outcome.

**Good.** Over the first 20 pull requests the agent app opens after the
windows start, across the three repositories: unlabelled agent pull
requests 0. Over 30 days: main checkout off main 0 PM session starts;
false refusals 0, a `path-without-dashes` line apart; unread 0.

**Wrong.** An agent's pull request sits unlabelled; a PM session starts
with the main checkout off `main`; or a cycle reports a refusal of a
command it needed. Noticed when `pr-checks` fails, in the PM session's
first line, or in the cycle's report. First checks:

1. `grep -E 'pr-main-checkout|pr-label|branch-switch|unplaced|path-without-dashes|unread' "${XDG_STATE_HOME:-$HOME/.local/state}/pap/pm/refusals.log"`
2. `git -C <repository> worktree list`: which branch is the main checkout on?
3. `gh pr view <n> --json labels,author`: who opened it, and with what?
4. `pap doctor`: is the plugin at the release that has rule 27, and is the main checkout item there?

**Undo.** Revert the merge: the two rules, the session-start reading,
decision 0027 and the doctor item go together, and the logs keep their
lines. Outside git: none. An adopting repository gets the undo with the
next release of the plugin and of pap. Until then a `gh pr create` that
is wrongly refused is run from a solo session, `pap claude --solo`, which
the rules do not bind and which keeps the agent as the pull request's
author, so it still counts in the measure; a branch switch is the
owner's, at their own shell. This text is the pull request's "How to
revert".

**Operational scenarios.**

```gherkin
Scenario: An agent's pull request has no class label
  Given cycle-pr-guard is live
  When a pull request the agent app opened has no class label 60 seconds after it was opened
  Then the owner reads how it was opened from the session's transcript and the refusal log
  And a way past the guard that is not one of decision 0027's limits opens a bugfix; one that is goes to H-017's intent

Scenario: The main checkout is off main
  Given cycle-pr-guard is live
  When a PM session starts with the main checkout off main
  Then the PM session tells the owner first, and switches nothing
  And the owner checks that no session is running there and that git status is clean, then runs git switch main; uncommitted work found there is the owner's to place, never stashed or discarded by an agent
  And the owner reads the refusal log near that time: no line means a limit of rule 27.2, a command the guard did not see, a line that could not be written, or a session on an older plugin

Scenario: The guard refuses what it should not
  Given cycle-pr-guard is live
  When a refusal of the four kinds is for a form scenario 5 lets through, or for /change itself
  Then a bugfix is opened with the form, and the command is run from a solo session meanwhile
  And a second false refusal of a different form before the fix reverts the merge
```

## Areas of concern

- **`git checkout` is ambiguous by design.** `git checkout README.md`
  restores a path and `git checkout topic` switches. The guard cannot
  tell them apart without asking git, so it refuses both in the main
  checkout unless `--` is given. A path restore an agent wrote the short
  way is refused with the fix named.
- **Every `gh pr create` in the main checkout, housekeeping included.**
  Rule 18.1 lets a PM session open a process housekeeping pull request
  when the owner asks. Under 27.1 it too is opened from a linked work
  tree. Nothing is lost, but the exception narrows.
- **The measure and the baseline.** pap's baseline is already 0 of 20, so
  the first measure cannot improve here; it guards against the incident's
  return and is read mostly in the other two repositories.
- **Two readings of the main checkout.** `pap doctor` reads it when the
  owner asks; the session-start hook reads and records it at every PM
  session start. The second is what the measure uses, and it is one more
  thing the hook does at start.
- **INV-003 and one more process.** The hook asks git where a command
  runs, on a path every Bash call takes. The thresholds keep that to PM sessions
  and to the calls that run one of the four verbs: two more processes at
  most.
- **The intent's fifth outcome is met by its second half.** A cycle is
  not given a permission; the adopter is told what is missing, by the
  cycle's `ASK:` and the troubleshooting entry.
- **Paths the intent lists and this may not touch.** `scripts/guard-branch.sh`
  is in the intent's list; nothing here needs it changed.

## Open questions

- How the hook tells the main checkout from a worktree, and which commands
  there stay allowed: answered, in "Where a command runs" and rule 27.2.
- Whether a fresh cycle's label step inside `/change` is denied in auto
  mode at all: answered in part. The label given on `gh pr create` is not
  denied: 20 of pap's last 20 agent pull requests carry it from the agent,
  four of them opened by cycles on plugin 0.19. The denial in the incident
  was of a later `gh pr edit --add-label`, and it was not reproduced here:
  doing so needs an agent's pull request with no label, which rule 27.1
  now stops. So no permission rule and no `pap doctor` check is specified,
  as the intent asked; the cycle says what it could not do.
- Which of these local refusals stay once H-017's server gate exists:
  still open: the owner, H-017's intent.

## Intent churn

Three things the intent did not have, found in drafting and in the
review:

- Its first outcome says "on a `change/*` branch". The spec does not look
  at the branch: every pull request an agent of a PM session opens is
  bound. The outcome is reworded.
- Its fourth outcome has `pap doctor` report the main checkout. The
  review showed that leaves no record, so a reading at PM session start
  is added to the outcome.
- `product/domain.md` and the docs are touched, and `product/**` is a
  protected path the intent did not list. `invariants-touched` gains it.

The churn is the owner's to accept with this spec. Churn commit:
`intent(cycle-pr-guard): churn, every branch is bound and the session start records the main checkout`.
