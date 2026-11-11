# Run a project

How one session runs many changes at once as the project manager (PM).
The reference is decisions
[0018](../decisions/0018-a-project-manager-session-launches-cycles-and-keeps-the-tracker.md)
and
[0025](../decisions/0025-pap-runs-as-the-project-manager-by-default.md),
and rules 18.1 to 18.8 and 25.1 to 25.5 in [`rules.md`](../rules.md). The
console is the [`pm-console` plugin](../plugins/pm-console/README.md).

## What is a command today and what is not

A command today:

- `pap claude`, in a repository that adopts PAP, starts a PM session. That
  is the default (rule 25.1); you no longer brief a session into the role.
- `pap claude --solo`, from your own terminal, starts a session without
  the mode. It is refused in an agent shell.
- `/pap:pm start` starts the tracker, or reports where things stand.
- `/pap:pm launch <slug>` launches one cycle. You type it; the PM cannot.
- `/pap:pm exit` pauses every cycle in flight, commits the tracker and
  tells you whether it is safe to stop (see
  [Pause and relaunch](#pause-and-relaunch)).
- `/pap:pm console` opens the console's pane and refreshes its figures.
- `/envision`, `/intent`, `/spec` and `/change`, as before, and
  `/pap:plan <slug>` for the plan of a feature, infra or
  security-sensitive change (decision
  [0026](../decisions/0026-a-reviewed-plan-sits-between-the-spec-and-the-code.md)). The cycle
  agents ship in the pap plugin (decision
  [0024](../decisions/0024-cycles-run-as-slim-plugin-agents.md)):
  `pap:cycle`, `pap:cycle-mechanical` for bumps and syncs, and
  `pap:reviewer` for `/change`'s cold review.

Still by hand: `/pap:pm event`, `audit` and a full `relaunch` are planned,
backlog item H-012. Until they ship the PM appends the event lines itself
(see [The tracker](#the-tracker)), audits from the rules below, and
relaunches from the save points.

Not pap's at all: the model and its version. pap ships no model. Both
come from your own Claude Code install and account, and pap pins
neither. What Claude Code may be used for is set by
[Anthropic's usage policy](https://www.anthropic.com/legal/aup); you are
the one deploying it.

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

Start it with `pap claude` in the repository. It needs the pap plugin,
which carries the role and the guard; without it `pap claude` says so,
prints the command that installs it on this machine and starts a session
with no mode. Only a
top-level session can spawn background agents and talk to you, so the PM
is that session. It owns the brief, the tracker, the relay to you, pause
and relaunch, and the audit.

The session is given its role when it starts, and again on a resume,
after a `/clear` and after a compaction (rule 25.3). Its first line tells
you it is a PM session. The mode belongs to the start, not the
conversation: `pap claude --resume` gives the resumed conversation the
mode of this start. A session started as plain `claude` has no mode and is
not bound; `eval "$(pap shell-init bash)"` makes plain `claude` run `pap
claude` in every PAP repository.

**What it does with an ask.** A question is answered and nothing is
launched. An ask that is not ripe is talked through. A ripe ask gets one
proposed route: `/envision` when there is no product layer; `/intent`,
then `/spec`, when rule 20.2 says the change needs one, both run by the PM
itself, and `/pap:plan` after `/spec` for a feature, infra or
security-sensitive change; a cycle for everything else. A skill you
invoke yourself runs as invoked. An ask no route covers stops (rule 25.4): in an adopting
repository the PM hands you the text of an issue for pap, and you file
it.

**What it may write.** Only the PM paths: `changes/<slug>/`,
`features/<slug>.feature`, `product/` and the tracker. Any other Edit or
Write is refused, with the route named. In another adopting repository it
writes nothing. Rule 25.2 has the detail and the limits. Three of them
matter day to day:

- **Shell edits are caught only at the commit.** A file changed by `sed`
  or a redirect is not refused as it is made. The PM's `git commit` is.
- **A stray file blocks the PM's commit.** The whole work tree is judged,
  so the commit is refused when anything outside the PM paths is changed
  there: staged, unstaged or untracked. In the main checkout that can be a
  parallel session's file. The PM reports the files and stops. The fix is
  to commit from the change's own work tree, or to have whoever owns the
  file move it. Never stash, clean, check out or delete a file to clear
  the block, and do not let the PM do so.
- **Sub-agents are not bound.** A cycle writes any path, as before.

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

## Restate, brief, and you type the launch

Type `/pap:pm start` once before the first launch; in a new repository,
after `/envision`.

Before any brief, the PM restates your ask in one line and logs it as a
`restate` event. It checks the premise it can check first (the mailbox,
the API, the existing code), and for anything with a structure to choose
brings a one-paragraph design. Then it writes the brief and gives you the
command. You type it:

```text
/pap:pm launch <slug>
```

That typed line is your yes (rule 18.2). A spoken yes is not enough, and
a launch the PM invokes itself is refused. One typed line serves one
launch.

The launch checks three lines of the brief and refuses without them:

1. Line 1, the route: `/intent <slug> <class>` or `/change <slug> <class>
   [Record: NNNN]` (rule 18.8).
2. Line 2, the item of rule 20.2 that decided it: `Rule 20.2: item 1`,
   `Rule 20.2: item 2` or `Rule 20.2: exempt: <which>`. You can overrule
   the route.
3. A `Budget:` line with a number, in tokens or wall time, set from the
   last audit's medians (rule 18.7). At the cap the cycle stops at its
   nearest safe point and ends with `PAUSED:` and what is left.

It also refuses a slug with no `restate` event, a slug already in flight,
and an event log with a line it cannot read. Nothing caps how many cycles
run at once; each is a line you typed.

Last, it refuses a build whose plan is not accepted, with exit 20. That
applies to a `/change` brief of class feature, infra or
security-sensitive whose second line names item 1 or 2 of rule 20.2,
unless the change's branch already carries code and no plan. It reads the
tip of the local `change/<slug>` and fetches nothing. It says which of
five things it found: the plan is absent, the plan is a draft, the spec
changed after the plan's yes, the change branch cannot be read, or the
plan cannot be read. Then run `/pap:plan <slug>`, give your yes, and type
the launch again; the refused line is used up. A launch from
another clone needs the branch there first. If you believe the refusal
is wrong, run the build as `/change` in a solo session. The plan itself
is in [Make a change](make-a-change.md#3-papplan).

On a pass the cycle starts in the background as `pap:cycle`, or
`pap:cycle-mechanical` when the brief says `Mechanical: yes`, and never
as general-purpose (decision 0024). It is given the brief and nothing
else, so the brief also carries what to build; the standing rules (the
worktree, the paths it may touch, push after every commit, a save point
after every commit, the report format, `ASK:` and `PAUSED:`); and the
model and effort for the task. The cycle's pull request carries the
brief's first two lines as a `Route:` line (rule 25.5), and a `Plan:`
line: `Plan: changes/<slug>/plan.md, <n> deviations`, or `Plan: none`.

Decision 0018 lists the eleven rules the first sixteen days produced, each
from a miss. A brief template that carries them is part of H-012. Until
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

The tracker is what the PM resumes from after a `/clear` or a shutdown.
It is a git repository of its own, outside the project, one per
repository:

```text
${XDG_STATE_HOME:-~/.local/state}/pap/pm/trackers/<owner>/<name>/
  events.tsv         the event log
  state.md           the state file
  briefs/<slug>.md   one brief a cycle
```

- **The event log** is append-only, one line an event, four tab-separated
  fields: UTC time, event, slug or `-`, one line of text. The events are
  `start`, `restate`, `yes`, `launch`, `report`, `message`, `pause`,
  `resume`, `merge` and `decision`.
- **The state file** has three headings: In flight, Waiting on the owner,
  Next. In flight is never written by hand; `start` and `launch` rewrite
  it from the event log.

`/pap:pm` writes `start`, `yes` and `launch`. The rest are still by hand:
the PM appends the line and commits the tracker, on every event (rule
18.3). A cycle that died, or did not start, stays in flight until you say
so and the PM logs a `decision` event whose text starts `abandoned`.

The PM is the tracker's only writer, and one PM session holds it at a
time. A second session is told which one holds it and writes nothing. On
an uncommitted tracker `/pap:pm start` shows the change and asks you to
commit or discard it; discarding takes a second yes.

**On one machine by default.** To keep it in a private companion
repository, clone that repository and add one line to pap's machine
config (`agent.conf` in `${XDG_CONFIG_HOME:-~/.config}/pap/`; on macOS
`~/Library/Application Support/pap/`), naming a directory in the clone:

```text
tracker.<owner>/<name>=<path>
```

Every commit is then pushed. A push that fails or runs over 30 seconds is
reported as committed but not pushed, and the next push carries both. The
line is yours to write; the PM session cannot. The tracker never lives in
PAP.

Keep people's names and third parties' words out of briefs and event
lines. Deleting the tracker's directory loses the tracker and nothing in
the project.

## Pause and relaunch

On pause the PM sends `PAUSE` to every running cycle and waits for each
`PAUSED:`. A cycle on `PAUSE` finishes or abandons its step at the nearest
safe point, commits what passes the hooks, pushes, writes its save point
(worktree, branch, head, done, next, open questions) and ends with
`PAUSED:` and what is uncommitted. The PM commits the tracker and tells
you it is safe to stop. `/pap:pm exit` runs this sequence. With the
console loaded it puts `/exit` in the prompt box when it is done; without
it the PM says in one line whether it is safe to type `/exit`.

A relaunch is still by hand. The PM reads the tracker and the save
points, and you launch a fresh member on the same `/change`; the worktree script prints `resumed`
and the cycle carries on from "next". A member's context is never saved;
the cycle's save point is.

## When something refuses

The guard keeps four logs under `${XDG_STATE_HOME:-~/.local/state}/pap/pm/`,
one line an event, each line naming its repository:

| Log            | One line for                                                                                |
| -------------- | ------------------------------------------------------------------------------------------- |
| `sessions.log` | each start, with its mode, and each time a role was given                                   |
| `refusals.log` | each refused write or commit, and each call the guard could not read                        |
| `messages.log` | each message the PM sent a sub-agent, and each sub-agent stop                               |
| `launches.log` | each `/pap:pm launch <slug>` you typed, and each launch refused for its plan (`refused-20`) |

First checks, all read-only:

1. Read the refusal: its rule, its path and what it names instead.
2. `claude --version`, against the version on the last good start in
   `sessions.log`. A line ending `:unbound`, or a warning in the PM's
   first line, means this Claude Code does not let the guard tell the PM
   from a sub-agent, and the PM paths are not enforced.
3. The last lines of `refusals.log` and `sessions.log`.
4. The pap plugin and the pap command are the same release. `pap doctor`
   compares them in its `pap plugin installed` line. A plugin that is
   behind is `drift`, with the command that updates it; restart Claude
   Code after it. A plugin that is ahead is a warning: the pap command is
   the older one. A pap that is not a release compares nothing; there,
   read `claude plugin list` and `mise ls` yourself.
5. `pap doctor` in the repository.

Only then carry on with `pap claude --solo`. That is the undo for one
session: the mode and the PM paths are off, every other rule holds, and
`/pap:pm start` and `launch` still work. The undo for everyone is a revert
and a patch release; the spec's
[Operations section](../changes/pm-mode/spec.md#operations) has the
steps.

## The console

Four tabs, each with its count: **Inbox**, what each cycle's report asks
of you, grouped by pull request, with the report behind it and items to
tick; **Cycles**, this session's background agents; **PAP**, per
repository, the pinned version against the latest release, `pap repo
status` drift, records still `proposed`, revisits due, backlog hypotheses
by state, open pull requests and `risk:high` ones waiting for
`owner-reviewed`, and median lead time; **CI**, the average and slowest
run per workflow. `/pap:pm console` opens the pane and refreshes the
figures. The console registers no command of its own.

A **class band** shows above the prompt while you type `/intent`,
`/change` or `/pap:pm launch`: the seven classes with the ceremony each
gets, the one typed in bold. A bad class or slug is refused before the
skill runs (`process` says: not a class; process records use `infra`). A
launch needs no class on the line: it comes from the brief. The
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
