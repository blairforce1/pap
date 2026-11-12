# 0027. An agent opens its pull request from a worktree, with its class label

- **Status:** proposed
- **Date:** 2026-11-12
- **Deciders:** blairforce1, with Claude
- **Supersedes:** none; narrows rule 18.1 of
  [0018](0018-a-project-manager-session-launches-cycles-and-keeps-the-tracker.md):
  the process housekeeping pull request a project-manager session may
  open when the owner asks is now opened from a linked work tree, with a
  class label, as every other agent pull request is. Builds on
  [0002](0002-skills-stop-at-draft-pr.md) and
  [0025](0025-pap-runs-as-the-project-manager-by-default.md), and amends
  neither
- **PIP:** reactive. A cycle in an adopting repository skipped `/change`.
  It switched the main checkout, which parallel sessions share, onto a
  change branch and left it there, and it opened its pull request with no
  `class:*` label. Nothing stopped it until `pr-checks` failed. Sent back
  to add the label, its command was denied by Claude Code's permission
  classifier, and the owner added the label by hand
- **Expected effect:** across pap, arapsys-ap and business-os, from the
  day the last of the three has both the plugin and the `pap` command of
  the release below. Over the first 20 pull requests the agent app opens:
  pull requests with no class label 60 seconds after they were opened
  stay at 0, read by the query under "The measure". Over 30 days:
  project-manager session starts whose session log line names a main
  checkout off `main`, 0; false refusals, 0, a `path-without-dashes` line
  apart; `unread` lines of rule 27, 0. Refusals of kind
  `pr-main-checkout`, `pr-label`, `branch-switch` and `unplaced` are
  counted beside them as saves, once for a session and form. The
  baseline is under "The measure"
- **Introduced in:** not yet released; the release that ships rules 27.1 and 27.2
- **Revisit:** after 20 change PRs: both effects; the saves, the false refusals and the `unread` lines in the refusal log; whether a pull request or a branch switch got through one of the limits below; which of these refusals stay once H-017's server gate exists

The accepted spec is
[`changes/cycle-pr-guard/spec.md`](../changes/cycle-pr-guard/spec.md),
with its intent, plan and reviews beside it. It holds the behaviour, the
refusal texts and the Operations section; this record holds the decision
and does not repeat them.

## Context

`/change` carries a change: the work tree, the commits, the checks, the
cold review and the draft pull request with its class label. A cycle that
skips the skill was stopped by nothing on the machine. The two things
that then went wrong were both visible in one command each: a
`gh pr create` with no class label, and a `git switch` in the main
checkout.

The guard that runs before every Bash call of an agent
([`plugins/pap/hooks/guard-route.sh`](../plugins/pap/hooks/guard-route.sh))
already works out the directory a command runs in. Decision 0025 gave a
session a mode, so the guard can tell a project-manager session, whose
agents never need either command outside `/change`, from a solo session,
which is the owner's.

## Decision

1. **The pull request.** In a project-manager session, an agent's
   `gh pr create` or `gh pr new` is refused in the main checkout of an
   adopting repository, whatever its labels, and anywhere else unless it
   gives exactly one class label written out in the command. The branch
   is not looked at: in an adopting repository every pull request an
   agent opens is a change pull request (decision 0002).
2. **The branch.** In a project-manager session, an agent's `git switch`
   or `git checkout` in the main checkout of an adopting repository is
   refused, unless it switches to `main`, restores a path after `--`, or
   names nothing. Nothing is refused in a linked work tree.
3. **A directory the guard cannot place is refused.** One that does not
   exist as the guard runs, or is written with a variable, `pushd`,
   `cd -` or a git directory given by `GIT_DIR`, `GIT_WORK_TREE`,
   `--git-dir` or `--work-tree`: the agent is told to run the command by
   itself, from the work tree.
4. **Who is bound.** The main session and every sub-agent of a
   project-manager session. A solo session, a session with no mode and
   the owner's own shell are not.
5. **Each refusal is logged.** One line in the refusal log, with a kind
   (`pr-main-checkout`, `pr-label`, `branch-switch`,
   `path-without-dashes`, `unplaced`) and, as an eighth field, the form
   refused: `gh pr create`, or `git switch` or `git checkout` with its
   options and `<word>` for each other word. Never the command, which may
   hold a body or a token. The log is advisory: the callers it records
   can write to it.
6. **The main checkout is read, twice.** The hook that gives a
   project-manager session its role reads the main checkout at every
   start and, off `main`, records it in the session log and tells the
   session to tell the owner first. `pap doctor` reads it when the owner
   asks. Neither switches anything.
7. **A cycle that cannot label says so.** The two cycle definitions tell
   a cycle whose label command Claude Code denies to end with `ASK:` and
   the one command. That is wording. No permission rule is specified and
   `pap doctor` checks none.

### Rules

- **27.1** An agent of a project-manager session opens a pull request
  only from a linked work tree, with exactly one class label.
- **27.2** An agent of a project-manager session never switches the
  branch of the main checkout; switching it back to `main` is never
  refused.

### The measure

The first effect is read in each repository by this query, with `since`
set to the day the windows start. It prints one line for each of the
first 20 pull requests the agent app opened that had no class label 60
seconds after it was opened, and nothing when there is none:

```sh
since=<YYYY-MM-DD>T00:00:00Z
gh pr list --state all --limit 200 --json number,author,createdAt \
  --jq "[.[] | select(.author.is_bot and (.author.login | endswith(\"pap-agent\")) and .createdAt >= \"$since\")]
        | sort_by(.createdAt) | .[:20] | .[] | [.number, .createdAt] | @tsv" |
  while read -r n created; do
    gh api "repos/{owner}/{repo}/issues/$n/events" --paginate \
      --jq "[.[] | select(.event == \"labeled\" and (.label.name | startswith(\"class:\"))
                 and ((.created_at | fromdateiso8601) - (\"$created\" | fromdateiso8601)) <= 60)]
            | if length == 0 then \"#$n unlabelled at 60 seconds\" else empty end"
  done
```

The baseline, by the same query:

| Repository  | Pull requests    | Unlabelled at 60 seconds | Counted    |
| ----------- | ---------------- | ------------------------ | ---------- |
| pap         | 20, #126 to #145 | 0                        | 2026-11-12 |
| arapsys-ap  | 7, #10 to #16    | 1 (#15)                  | 2026-11-12 |
| business-os | 4, #126 to #129  | 0                        | 2026-11-12 |

arapsys-ap and business-os have fewer than 20 agent pull requests, so
each row counts all of them, taken as the last ones before the guard
reaches the repository.

pap's baseline is already 0 of 20, each labelled within two seconds, so
the measure cannot improve here. It guards against the incident's return
and is read mostly in the other two repositories. The second effect is
read from the session log's seventh field, `main-checkout:<branch>` or
`main-checkout:detached`, and the others from the refusal log, each
checked against the session's transcript before anything is concluded.

### Limits

The guard is a check on an agent that drifts, not on one that is steered.
It does not stop, and H-017's server gate is where these close:

- a pull request opened through `gh api` or GraphQL;
- a `gh` or `git` reached through `bash -c`, `eval`, a script or an
  alias, which the guard does not see at all;
- one of the four verbs after a word the guard does not take for a
  command's head (`then`, `command`, `xargs`), or in a command it cannot
  parse: let through, and logged as an `unread` line;
- a session with no hooks, a session with no mode, a solo session, and a
  session on a plugin older than this release;
- a missing `jq`, or a git call that does not return: the call is let
  through, as before;
- other commands that take the main checkout off `main`:
  `git branch -m`, `git stash branch`, `git rebase <upstream> <branch>`,
  `git bisect start` and `git symbolic-ref HEAD`. The reading at session
  start is what finds them;
- a label that is not the class the change's intent gives: nothing
  compares them;
- proof that `/change` ran: the rules refuse two symptoms of skipping
  it, not a pull request's Checks answers or its cold review.

Three more are costs the rules accept:

- **A path restore written the short way is refused.** `git checkout
  README.md` and `git checkout topic` cannot be told apart without asking
  git, so both are refused in the main checkout, with
  `git checkout -- <path>` named. Each is a `path-without-dashes` line.
- **A call across three or more directories.** Placing a directory costs
  one git process, kept for the call. A call that runs the verbs in one
  or two directories costs two more at most, which is the spec's
  threshold and what is tested. One that runs them in three or more
  costs one for each, over that threshold.
- **A refusal whose line cannot be written is still made.** The guard
  then says so in a third line.

## Considered options

- **Wait for H-017's server gate.** Lost: the incident cost a shared
  checkout on the machine, which no server sees.
- **Bind solo sessions too.** Lost: a solo session is the owner's, and is
  the way through a wrong refusal.
- **Bind only pull requests on a `change/*` branch.** Lost in the spec's
  review: a cycle that skips `/change` may skip its branch name as well.
- **Give a cycle the permission to label.** Not taken: the denial was not
  reproduced, and with rule 27.1 the label is on the pull request as it
  is opened. The cycle says what it could not do.
- **`pap doctor` alone reads the main checkout.** Lost in the spec's
  review: it leaves no record, so the second effect would rest on recall.
- **Ask git whether a word is a branch or a path.** Lost: one more
  process on a path every Bash call takes (INV-003), to save a `--`.

## Consequences

- Easier: the two symptoms are stopped where they happen, with the way
  through named, before `pr-checks`.
- Easier: a main checkout left off `main` is said at the next
  project-manager session's start, and recorded.
- Harder: a project-manager session's housekeeping pull request needs a
  work tree and a class label.
- Harder: a refusal the agent needed is the owner's to run, from a solo
  session or their own shell, until a fix ships.
- Limit: everything under "Limits". The server gate remains the control.
- Undo: revert the merge. The two rules, the session-start reading, this
  record and the doctor item go together, and the logs keep their lines.
  Nothing outside git is changed. An adopting repository gets the undo
  with the next release of the plugin and of pap; until then a
  `gh pr create` that is wrongly refused is run from a solo session,
  `pap claude --solo`.

## Where it is taught or enforced

Backs [`rules.md`](../rules.md) 27.1 and 27.2, and the pointer on 18.1.

- [`plugins/pap/hooks/guard-route.sh`](../plugins/pap/hooks/guard-route.sh)
  refuses under both rules and writes the refusal log through
  [`plugins/pap/hooks/pm-lib.sh`](../plugins/pap/hooks/pm-lib.sh).
- [`plugins/pap/hooks/session-start.sh`](../plugins/pap/hooks/session-start.sh)
  reads the main checkout at a project-manager session's start.
- `pap doctor` ([`bin/pap`](../bin/pap)) has the item "main checkout on
  main".
- [`plugins/pap/agents/cycle.md`](../plugins/pap/agents/cycle.md) and
  [`plugins/pap/agents/cycle-mechanical.md`](../plugins/pap/agents/cycle-mechanical.md)
  carry the sentence for a denied label command.
- [`tests/cycle-pr-guard.test.sh`](../tests/cycle-pr-guard.test.sh) and
  [`tests/pap.test.sh`](../tests/pap.test.sh) bind the scenarios of
  [`features/cycle-pr-guard.feature`](../features/cycle-pr-guard.feature).
