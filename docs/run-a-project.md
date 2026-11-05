# Run a project

How one session runs many changes at once as the project manager (PM).
The reference is decision
[0018](../decisions/0018-a-project-manager-session-launches-cycles-and-keeps-the-tracker.md)
and rules 18.1 to 18.7 in [`rules.md`](../rules.md). The console is the
[`pm-console` plugin](../plugins/pm-console/README.md).

**What is a command today and what is not.** The PM way of working is
written down and the console exists. The `/pap:pm` skill (`start`,
`launch`, `event`, `relaunch`, `audit`), the `pap:member` agent
definition and the tracker and brief templates are planned, backlog item
H-012. Until they ship you run the role by hand, from the rules below, in
a Claude Code session you brief as the PM; `/change` itself is a command.

## Vocabulary

The names are the Team Software Process's. A **cycle** is one change: one
`/change`, one worktree, one draft pull request, one report. It is run by
**members** in **roles**: one member today, the developer, a background
sub-agent the PM spawns with one brief; QA, research and review roles may
follow (H-013, H-015). A **launch** starts a cycle: the brief, the PM's
one-line restatement of the ask and your yes. A **relaunch** resumes a
cycle from its save point after a pause. A **postmortem** closes a cycle:
its report with its cost line. The efficiency audit is the team
postmortem across cycles.

## The PM session

One top-level Claude Code session in the project, briefed as the PM. Only
a top-level session can spawn background agents and talk to you, so the PM
is that session. It owns the brief, the tracker, the relay to you, pause
and relaunch, and the audit.

It touches no pull request and does no owner's act: it opens no change
pull request (process housekeeping you ask for is the one exception),
approves nothing, adds no `owner-reviewed`, writes no `Approved-by:`,
merges nothing, and writes no GitHub or repository settings. An act a hook
refused a cycle is not done by the PM in its place; it comes to you as a
decision.

Install the console in that session:

```text
/plugin install pm-console --marketplace blairforce1/pap
```

and have the PM call `ci_repos` and `pap_repos` with the repositories to
watch, for example `["acme/widgets"]` and
`[{"repo": "acme/widgets", "path": "/srv/src/widgets"}]`. The lists are
kept per machine.

## Restate and yes, then launch

Before any brief, the PM restates your ask in one line and gets your yes,
and logs both (rule 18.2). It checks the premise it can check first (the
mailbox, the API, the existing code), and for anything with a structure to
choose brings a one-paragraph design. "Why", "should we" and "what would it
take" are questions: the PM answers them and launches nothing until you
say go.

A launch is a background sub-agent given one brief and nothing else, so
the brief carries everything: the `/change <slug> <class>` line; what to
build; the standing rules (the worktree, the paths it may touch, push
after every commit, a save point after every commit, the report format,
`ASK:` and `PAUSED:`); the model and effort for the task; and a **budget**
in tokens or wall time, set from the last audit's medians (rule 18.7). At
the cap the cycle stops at its nearest safe point and ends with `PAUSED:`
and what is left.

Decision 0018 lists the eleven rules the first sixteen days produced, each
from a miss; the brief template that carries them is part of H-012. Until
then, copy the table into your own brief skeleton.

## The cycle's report

A cycle ends its turn with the change skill's report, or with a first line
the PM routes on: `ASK:` when only you can decide or act, `PAUSED:` after a
pause. The PM logs the report with the tokens and wall time its completion
notice carries; that is the cycle's postmortem. What the report asks of you
goes on the console's inbox.

**Three send-backs end a cycle** (rule 18.6). After the third message
asking for changes since its first report, the cycle stops and replies
`ASK:`; by then the approach is in question, not the diff. A fix round
re-checks only the diff since the last report and repeats no earlier
finding.

## The tracker

A short **state file** (what is in flight, what waits on you, what is
scheduled, what is next; rewritten) and an append-only **event log** (one
line per launch, postmortem, message to a cycle, pause, relaunch, merge,
decision and audit; never edited). Both are committed on every event
(rule 18.3), because a shutdown can come at any time and the tracker is
what the PM resumes from. They live with the project, in its private
companion repository when it has one, never in PAP, and the PM is their
only writer. The templates are part of H-012; until then two Markdown
files of your own shape.

## Pause and relaunch

On pause the PM sends `PAUSE` to every running cycle and waits for each
`PAUSED:`. A cycle on `PAUSE` finishes or abandons its step at the nearest
safe point, commits what passes the hooks, pushes, writes its save point
(worktree, branch, head, done, next, open questions) and ends with
`PAUSED:` and what is uncommitted. The PM commits the tracker and tells
you it is safe to stop. In the console, `/pm exit` runs this sequence and
puts `/exit` in the prompt box when it is done.

On relaunch the PM reads the tracker and the save points and spawns a
fresh member on the same `/change`; the worktree script prints `resumed`
and the cycle carries on from "next". A member's context is never saved;
the cycle's save point is.

## The console

Four tabs, each with its count: **Inbox**, what each cycle's report asks
of you, grouped by pull request, with the report behind it and items to
tick; **Cycles**, this session's background agents; **PAP**, per
repository, the pinned version against the latest release, `pap repo
status` drift, records still `proposed`, revisits due, backlog hypotheses
by state, open pull requests and `risk:high` ones waiting for
`owner-reviewed`, and median lead time; **CI**, the average and slowest
run per workflow. `/pm` opens the pane and refreshes the figures.

A **class band** shows above the prompt while you type `/intent`,
`/change` or `/pap:pm launch`: the seven classes with the ceremony each
gets, the one typed in bold. A bad class or slug is refused before the
skill runs (`process` says: not a class; process records use `infra`). The
status line always shows cycles running, items waiting on you, decisions
proposed, revisits due and the slowest CI workflow.

## Efficiency audits

Every five merged change pull requests and at every relaunch (rule 18.4),
the PM audits: CI time per workflow per pull request, tokens and wall time
per cycle, messages per cycle after its first report, rounds to pass per
merged pull request, and the project's metered costs. Its medians set the
next budgets. Each finding ends in a fix written as a rule the next brief
carries, and the audit goes in the tracker with the fix beside each
number. A miss you spot first is itself a finding.

## Lessons upstream

Each new rule an audit writes is classified as **project** or **general**
(rule 18.5): the test is whether it still makes sense in a repository that
has never heard of this project. Project rules live in the project's
`CLAUDE.md` and the PM's memory. A general rule goes on a PAP candidates
list in the tracker's state file (the rule, the miss as numbers, the
date), due at three candidates or when the oldest is 30 days old. With
your yes, a cycle carries them to PAP through an ordinary `/change` there,
rewritten without the project and checked for public safety (no project
names, people, addresses or data). The PM never writes to PAP itself.
