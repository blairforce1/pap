# 0025. pap runs as the project manager by default

- **Status:** proposed
- **Date:** 2026-11-10
- **Deciders:** blairforce1, with Claude
- **Supersedes:** none.
  [0018](0018-a-project-manager-session-launches-cycles-and-keeps-the-tracker.md)
  is built on and not amended. Rules 18.2, 18.7, 18.8 and 20.2 get an
  enforcer
- **PIP:** the owner's ask of 2026-11-10: pap runs in PM mode by default,
  and the session can itself write only the tracker and what its interview
  skills write. Behind it, the revisits of 2026-11-09:
  [0020](0020-intent-is-accepted-by-a-recorded-yes-on-the-change-branch.md)
  found 0 of 20 change pull requests carrying an accepted `intent.md`
  ("every cycle came from a project manager's brief to `/change`, as
  before the record"), and
  [0021](0021-a-spec-is-accepted-after-review-with-its-operation-designed-in.md)
  found 0 of 12 with a spec. Rules 20.1, 20.2 and 21.1 are enforced by
  nothing, and 0018's role is run by hand because `/pap:pm` had not
  shipped. The process is followed only when the owner remembers to invoke
  it
- **Expected effect:** change pull requests merged with neither an
  accepted `intent.md` nor a `Route:` line naming an item of rule 20.2 ↓
  from 20 of 20 (0020's window, where none had either) to 0 of the first
  10 merged after the release, in pap and the trial repository, read from
  `gh` and git; cycles that get a message after their first report ↓ from
  18% (19 of 108, decision 0018) to at most 1 of those 10, read from the
  message log the guard writes. 0018 keeps its own 20-cycle window
- **Introduced in:** v0.18.0, the release that ships PM mode in
  `pap claude`, `/pap:pm start` and `/pap:pm launch`
- **Revisit:** after 10 change PRs from #129: both effects; the health signals of the spec's Operations section (cycle refusals, PM refusals, solo share, guard not binding, unread calls); whether a change got through one of rule 25.2's limits. #129 is the pull request that releases PM mode as v0.18.0, so the ten are the ones merged after the release

Note (2026-11-10): the Revisit start moved from #126 to #129, the pull
request that releases PM mode as v0.18.0, as the line promised. The ten
change pull requests are those merged after #129.

The accepted spec is
[`changes/pm-mode/spec.md`](../changes/pm-mode/spec.md), with its intent
and review beside it. It holds the behaviour, the formats and the
Operations section; this record holds the decision and does not repeat
them.

## Context

Decision 0018 describes a project-manager (PM) session and plans a
`/pap:pm` skill to carry it. Until now the role was a briefing: a session
was the PM because the owner told it so, and nothing stopped that session,
or any other, from making an edit the owner asked for in passing. Decision
0020's rule 20.2 puts the routing call with the PM, so with no PM the call
was not made.

Three facts about Claude Code make a default possible. They were probed
on 2026-11-10 against Claude Code 2.1.322, before any code:

- A hook runs in Claude Code's own environment, so a variable set before
  Claude Code starts is seen by every hook and changed by no command the
  session runs. This is the reasoning of rule 23.4's session check.
- The hook input of a sub-agent's tool call carries `agent_id` and
  `agent_type`. The main session's carries neither.
- `UserPromptSubmit` receives the line the owner typed, `/pap:pm launch
  <slug>` included. A sub-agent's report reaches the same hook wrapped in
  an `<agent-message …>` tag, so it cannot stand in for the typed command,
  and a skill the model invokes submits no prompt.

pap ships no model. It is shell scripts, hooks and skill text around
Claude Code, and it does not change Claude Code's intended purpose,
software development. An adopter is the deployer of Claude Code; pap is
not its provider. The model and its version are Claude Code's, chosen by
the adopter's own install and account, and pap pins neither.

## Decision

1. **`pap claude` sets the mode.** In an adopting repository with the pap
   plugin installed it starts a PM session; with `--solo` it starts a solo
   session, anywhere; elsewhere, or without the plugin, the session has no
   mode. The mode is `PAP_MODE` in Claude Code's environment and belongs
   to a start, not a conversation. A session is never called PM without
   the guard.
2. **The guard binds the main session of a PM session, and nothing
   else.** A call with no agent id is the PM's. A sub-agent's call is
   never judged against the PM paths, whatever its type.
3. **The PM paths** are `changes/<slug>/**`, `features/<slug>.feature`
   and `product/**` in the session's own repository and its work trees,
   and the tracker. They are what `/intent`, `/spec` and `/envision` write
   in the main session. In any other adopting repository the PM session
   writes nothing.
4. **Two things are checked:** an Edit, Write or NotebookEdit call, and a
   `git commit`, for which the whole work tree is judged. The guard's own
   files (Claude Code's settings, the installed plugins, pap's state and
   config apart from the tracker) are refused to the PM session too.
5. **The role is given at every start:** at `pap claude`, on a resume,
   after a `/clear` and after a compaction, with the tracker's state as
   data. Each time, the hook checks that its own input carries no agent
   id; if it does, the role opens with a warning that the PM paths are not
   enforced, and the session log says so.
6. **The owner launches; the PM does not.** The typed command `/pap:pm
   launch <slug>` is the yes of rule 18.2. A hook records it where the PM
   session cannot write. The launch checks are a script with exit codes,
   not skill text.
7. **The minimal tracker** is a git repository of its own under pap's
   state directory, one per adopting repository, with one writer at a
   time. The owner may point it at a clone of a private companion
   repository with one config line; it is then pushed on every commit.
8. **`event`, `audit` and a full `relaunch` are not built here.** The PM
   appends those event lines itself until they ship (H-012).
9. **A session started without `pap claude` is not bound.** That is the
   server gate's work (H-017), a separate intent.

### Rules

- **25.1** `pap claude` in an adopting repository starts a PM session;
  `--solo` is the owner's, and is refused in an agent shell.
- **25.2** A PM session writes only the PM paths; any other write is
  refused with the route named. Sub-agents are not bound by it.
- **25.3** A PM session is given its role and the tracker's state
  whenever it starts, and launches and resumes nothing until the owner
  says.
- **25.4** An ask no route covers stops: an `/intent` in pap, the text of
  an issue for `blairforce1/pap` elsewhere.
- **25.5** A cycle's pull request carries a `Route:` line with its route
  and its item of rule 20.2.

### The limits of rule 25.2

The rule stops the PM typing an edit. It does not stop:

- a shell command that changes a file and never commits it;
- a commit or ref written by `git merge`, `cherry-pick`, `revert`, `am`,
  `rebase`, `commit-tree` or `update-ref`, or through `gh api` to a
  repository's contents;
- a write through `bash -c`, `eval` or a script that then commits past
  the parse, the limits `guard-route.sh` already lists;
- a commit made with `--git-dir` or `GIT_DIR`;
- a tool other than Edit, Write and NotebookEdit that writes a file, an
  MCP server's for one;
- any sub-agent: a PM that launches a general-purpose agent to make an
  edit passes the guard and breaks decision
  [0024](0024-cycles-run-as-slim-plugin-agents.md) point 2 instead;
- a second Claude Code started from the session without `pap claude`.

The first expected effect, read from merged pull requests, is what
catches a change that got through.

## Considered options

- **Keep the role a briefing.** Lost: it is today's arrangement, and it
  gave 0 of 20.
- **Give the role and no guard.** Lost: the role is text, and the skills
  that teach rules 20.1 and 21.1 were text too.
- **Bind cycles as well, or deny them protected paths.** Lost: the H-003
  lesson. That gate would have blocked 10 of the last 10 change pull
  requests. The approval at the pull request is the control, not the edit.
- **Refuse a PM spawn of any agent type but `pap:cycle` and
  `pap:cycle-mechanical`** (spec review, SEC-003). Rejected: a type list
  does not close delegation, because `pap:cycle` takes any prompt. Closing
  it needs a writing sub-agent tied to a logged launch, which is the
  server gate's (H-017).
- **Cap the cycles in flight** (COST-001). Lost: no cap. Every launch is
  a command the owner typed, and that is the bound; the state file shows
  the count. A cap would slow a day of small changes.
- **Parse shell commands for writes.** Lost: a rabbit hole with no
  honest end. The commit check is the boundary, and the rule says so.
- **Judge every command that writes a commit or a ref** (SEC-004). Lost:
  each is listed as a limit instead. Judging them widens a work-tree scan
  that already costs time on every PM commit.
- **A yes the PM logs after the owner says it** (SEC-006, UX-004). Lost:
  the gated party would write its own approval. The typed command, logged
  by a hook, costs the owner one line a launch.
- **A time fallback on the revisit** (OPS-010). Rejected: rule 10.1 types
  a revisit as one trigger, and pap merges ten change pull requests in
  days.
- **The tracker inside the project.** Decided by the owner on 2026-11-10:
  a repository of its own on the machine, with the companion clone as the
  option.
- **Several pull requests.** Decided by the owner on 2026-11-10: one.

## Consequences

- Easier: the owner no longer briefs a session into the role, and an ask
  made in passing is routed, not done.
- Easier: rules 18.2, 18.7, 18.8 and 20.2 have a script that refuses.
  After a `/clear` the PM resumes from a committed tracker.
- Harder: every launch is a typed line. A spoken yes is not enough.
- Harder: a PM commit is refused when anything outside the PM paths is
  dirty in its work tree, even a file the commit would not have taken. In
  the main checkout, which parallel sessions share, a stray file blocks
  the PM until its owner moves it. PM commits belong in a change's own
  work tree or the tracker. The PM must never stash, clean, check out or
  delete a file to clear the block.
- Limit: the guard is on the main session only, by design. The PM paths
  stop the PM typing, not the PM delegating.
- Limit: `product/**` is a PM path and a protected path. The PM can edit
  the vision, the invariants and the backlog directly; the control on them
  is still `risk:high` and `owner-reviewed` at the pull request.
- Limit: the PM paths are judged by path, not by branch. The PM can edit
  another change's `changes/` folder or scenarios. Rule 17.3 covers
  scenarios at the pull request; nothing covers a stray edit to another
  change's intent.
- Limit: a file changed through the shell and never committed is not
  refused.
- Limit: the event log's `restate`, `message` and `report` lines are the
  PM's own. The second effect is therefore counted from the message log
  the guard writes, and the event log is narrative.
- Limit: the tracker is on one machine unless the owner sets a companion
  clone. It survives a `/clear` and a shutdown, and is lost with the disk.
- Limit: routing, ripeness and "an ask no route covers" are judgement the
  role asks for. No scenario binds what the model does with the role until
  the eval suite exists (H-010). The hook does not judge rule 20.2.
- Limit: the agent-id test rests on Claude Code's hook input, which pap
  does not control. If a release puts an id on the main session's calls,
  the guard binds nothing; the live check says so at the next start. If a
  sub-agent's call lost its id, cycles would be refused: loud, and noticed
  on the first cycle.
- Limit: the logs are not tamper-proof. A shell command can change them,
  and a sub-agent is unbound.
- Data: the tracker and the logs hold slugs, paths, times, session ids
  and briefs. No token and no file content. Nothing leaves the machine
  unless the owner sets a companion clone; the recipient is then GitHub.
- Undo: `pap claude --solo` for one session, with no release. For
  everyone, a revert by pull request and a patch release; this record and
  rules 25.1 to 25.5 then stay, marked withdrawn. The spec's Operations
  section has the steps.
- Measurement: fewer than 10 change pull requests in the 30-day window
  means the effects were not read, and `findings.md` says so.

## Where it is taught or enforced

Enforced by `pap claude` ([`bin/pap`](../bin/pap)), which sets the mode
and refuses `--solo` in an agent shell;
[`plugins/pap/hooks/guard-pm.sh`](../plugins/pap/hooks/guard-pm.sh) for
Edit, Write and NotebookEdit;
[`plugins/pap/hooks/guard-route.sh`](../plugins/pap/hooks/guard-route.sh)
for the commit, a changed `PAP_MODE` and `/pap:pm`'s script run from a
sub-agent;
[`plugins/pap/hooks/session-start.sh`](../plugins/pap/hooks/session-start.sh)
for the role and the live check;
[`plugins/pap/hooks/pm-log.sh`](../plugins/pap/hooks/pm-log.sh) for the
typed launch and the message log; and
[`plugins/pap/skills/pm/pap-pm.sh`](../plugins/pap/skills/pm/pap-pm.sh)
for the tracker and the launch checks. The paths and the logs are defined
once, in
[`plugins/pap/hooks/pm-lib.sh`](../plugins/pap/hooks/pm-lib.sh). The
hooks are wired in
[`plugins/pap/hooks/hooks.json`](../plugins/pap/hooks/hooks.json).

Taught by the role text in `session-start.sh`, the `/pap:pm` skill
([`plugins/pap/skills/pm/SKILL.md`](../plugins/pap/skills/pm/SKILL.md)),
the `Route:` line in `/change`'s pull request body
([`plugins/pap/skills/change/SKILL.md`](../plugins/pap/skills/change/SKILL.md))
and [`docs/run-a-project.md`](../docs/run-a-project.md).

Checked by `tests/pm-mode.test.sh` against the scenarios in
`features/pm-mode.feature`. [`rules.md`](../rules.md) says, rule by rule,
what is enforced and what still escapes.
