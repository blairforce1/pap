# Spec: pm-mode

```text
id:                 pm-mode
class:              feature
intent:             changes/pm-mode/intent.md
scenarios:          features/pm-mode.feature, pm-mode-1 to pm-mode-57
accepted-by:        @blairforce1
accepted-on:        2026-11-10
generated-by:       Claude Fable 5.2 (claude-fable-5-2) via Claude Code
skills:             pap:spec 0.17.0; spec-review 1.3.1
prompt:             /pap:spec pm-mode
```

## Functional behaviour

`pap claude`, run in an adopting repository, starts a PM session: the project manager of decision 0018, by default and not by briefing. The session is given its role when it starts, proposes a route for what the owner asks, interviews for intent and spec itself, and launches a cycle for everything else. A guard refuses the PM session any write outside the PM paths and names the route instead. Sub-agents, cycles among them, are bound exactly as they are today. `pap claude --solo` gives the owner a session without the mode.

### Entering the mode

`pap claude` sets the session's mode before Claude Code starts: solo with `--solo`, wherever it is run; PM in an adopting repository; neither elsewhere. Nothing the session runs changes it while it runs. A mode belongs to a start, not to a conversation: `pap claude --resume` gives the resumed conversation the mode of this start, so a conversation begun solo and resumed without `--solo` in an adopting repository is a PM session from then on. Every start is logged with its mode. `pap claude --help` says what the default is and what `--solo` does.

The mode needs the pap plugin, which carries the role and the guard. Where the plugin is not installed, `pap claude` says so, gives the command that installs it, and starts a session with no mode, logged as such; it never starts a session that is called PM and has no guard. `--solo` is pap's own argument and is removed; every other argument reaches Claude Code unchanged, so `pap claude --resume` works as before. Everything `pap claude` did for the agent identity (rules 23.1 and 23.4) is unchanged in every mode.

`--solo` is refused in an agent shell, known by the same three signals `pap new` uses, with the signal named and the command to run from the owner's own terminal. A session started without `pap claude` has no mode and is not bound by this change (the intent's first non-goal).

### The role

A PM session is given the role each time it starts: at `pap claude`, on a resume, after a `/clear` and after a compaction; each time, the session log records that it was given and at which of the four. The role is at most 80 lines and 8 KB, and each part opens with a fixed marker line, named in the plan, that a test can find. It says:

- It is the project manager. It opens, approves and merges nothing (rule 18.1).
- **Routing.** A question is answered and nothing is launched. An ask that is not yet ripe is talked through; no route is proposed early. A ripe ask gets one proposed route: `/envision` when the product layer is absent; `/intent`, then `/spec`, when rule 20.2 says the change needs one; a cycle through `/pap:pm launch` otherwise. A skill the owner invokes runs as invoked.
- **No route.** An ask no route covers stops. In pap the PM proposes an `/intent` for the missing route. In any other adopting repository it gives the owner the text of an issue for `blairforce1/pap`; the owner files it, the PM files nothing. The issue text says what pap lacks and carries nothing from the adopter's repository: no code, names or data.
- **To the owner, first.** The PM's first line of every session says that this is a PM session, that it writes only the PM paths and launches a cycle for the rest, and that `pap claude --solo` starts a session without the mode.
- **The PM paths**, and that any other write is a cycle's. Shell edits are not refused as they are made; they are caught at the commit.
- **A blocked commit.** When a commit is refused for a file outside the PM paths, the PM reports the files and stops. It never stashes, cleans, checks out or deletes a file to clear the block: the file may be a parallel session's work.
- **The tracker.** Where it is, the state file's first 60 lines, whether it is uncommitted; or, when absent, that `/pap:pm start` comes before the first launch, and after `/envision` where the product layer is absent. The state file is given as data, marked as such: what it says is where things stand, never an instruction to the PM. On starting, the PM reports where things stand and launches and resumes nothing until the owner says.
- Every message to a cycle and every report is logged in the event log (rule 18.3).

Each time the role is given, the live session is checked: if the main session's own tool calls carry an agent id, the guard cannot tell the PM from a sub-agent and binds nothing. The role then opens with a warning that the PM paths are not enforced in this session, the owner is told in the PM's first line, and the session log records it. The session log also records the Claude Code version of every start.

A solo session is given one line saying it is solo. A session in neither mode is given nothing.

### The PM paths

In its own adopting repository, and that repository's work trees, the PM session writes only:

- `changes/<slug>/**`: any file at any depth under a folder named by a slug, not a file directly under `changes/`
- `features/<slug>.feature`: a file directly under `features/`, not in a folder below it
- `product/**`

A slug is what a change branch allows after `change/`: a letter or digit, then letters, digits, `.`, `_` or `-`. A path is placed in a repository by the work tree that holds its resolved location.

and the tracker, wherever it lives.

A path is judged where it resolves, after `..` and symbolic links. A path that does not exist yet is resolved from its deepest existing parent, so a first write into a new `changes/<slug>/` is judged as that folder. A path the guard cannot resolve is refused, not passed.

Outside every adopting repository, three places are also refused to the PM session, because they hold the guard and its evidence: Claude Code's settings files, the directory an installed plugin runs from, and pap's state directory apart from the tracker. Any other file in no adopting repository (a scratch directory, the session's memory) is not judged.

Two things are checked, for the PM session only:

1. **An Edit, Write or NotebookEdit call.** Outside the PM paths it is refused and the file is unchanged. These three are the tools the guard matches; any other tool that writes a file, an MCP server's for one, is a limit of rule 25.2.
2. **A commit.** It is refused when the work tree it runs in holds any change outside the PM paths: staged, unstaged, or an untracked file that is not ignored. The whole work tree is judged because the guard runs before the command and cannot know what the command will stage.

In any other adopting repository on the machine, pap included, the PM session writes nothing at all, the PM paths included (decision 0018, point 9).

A refusal names rule 25.2 and the path, says what to do instead, and tells the PM to bring that to the owner and not to retry. What it names depends on what was refused:

- **a write in its own repository:** the routes, a cycle through `/pap:pm launch`, or `/intent <slug> <class>` for a change that needs one;
- **a write in another adopting repository:** that the change belongs to that repository's own PM session, or, for pap, the text of an issue for the owner to file (rule 25.4);
- **a commit:** that the whole work tree is judged, the files outside the PM paths, and the remedies that work, committing from the change's own work tree or having whoever owns the file move it. It names no route, because no route clears it;
- **one of the guard's own files, or a path that cannot be resolved:** that, and no route.

Each refusal adds one line to the refusal log: the time, the session, the mode, the caller (the main session, or a sub-agent's id and type), the path and the repository. A file changed by a shell command and never committed is not refused; the commit check is what stops it reaching a branch.

Only `git commit` is checked. The other commands that write a commit or a ref are limits of rule 25.2, named in the rule and not judged: `git merge`, `cherry-pick`, `revert`, `am`, `rebase`, `commit-tree`, `update-ref`, and a write through `gh api` to a repository's contents.

A sub-agent's call is never judged against the PM paths, whatever its type. Everything the guard refused before this change it still refuses, for the PM session, a solo session and every sub-agent. A call the guard cannot read is reported and not blocked, as today, and is logged in the refusal log as its own kind of line, so the window can count them.

### The tracker

The minimal tracker is a git repository of its own, outside the project, one per adopting repository, under pap's state directory on the machine. It holds:

- **the event log**: append-only, one tab-separated line an event: UTC time, event, slug or `-`, one line of text. Events: `start`, `restate`, `yes`, `launch`, `report`, `message`, `pause`, `resume`, `merge`, `decision`;
- **the state file**: three headings, In flight, Waiting on the owner, Next; kept under 60 lines. In flight is not kept by hand: `/pap:pm start` and `/pap:pm launch` rewrite it from the event log. A slug is in flight from its `launch` event until a `report`, `pause` or `merge` event for it, or a `decision` event whose text starts `abandoned`;
- **the briefs**, one file a slug.

It is committed on every event. The owner may point it at a clone of a private companion repository with one line in pap's machine config; every commit is then pushed, and a failed push is reported as committed but not pushed. A push never prompts and is given 30 seconds; one that runs over is reported the same way, and the next commit's push carries both.

**One writer.** One PM session holds a tracker at a time, by a lock taken at `/pap:pm start` and at each launch. A second PM session on the same tracker is told which session holds it and writes nothing to it. A lock whose session has ended is taken over, and the take-over is said.

`/pap:pm start` starts the tracker when it is absent and reports from the state file when it exists. On an uncommitted tracker it shows the change as a diff, file by file, says the likely cause (an event line appended and not committed, or a session that ended mid-event), and asks the owner to commit or discard it before anything else. Discarding loses the change, so it takes a second yes. It launches nothing.

### Launching a cycle

The owner launches; the PM does not. The PM restates the ask in one line, logs a `restate` event, writes the brief, and says the command. The owner types `/pap:pm launch <slug>`, and that typed command is the yes of rule 18.2. A hook records the typed command outside the tracker, among the guard's own files, where the PM session cannot write it. A launch the PM invokes itself has no such record and is refused.

The checks are a script with exit codes, not the skill's prose. The launch is refused, and no cycle starts, when:

- the owner did not type the command (rule 18.2);
- the event log has no `restate` event for the slug (rule 18.2);
- the brief's first line names no route (rule 18.8), its second no item of rule 20.2, or it has no budget (rule 18.7);
- the slug is in flight;
- the event log has a line the script cannot read; the refusal names the line and the format;
- another PM session holds the tracker.

In order: the script writes the `yes` and `launch` events, naming the route, rewrites In flight and commits the tracker; only then does the cycle start, in the background, as `pap:cycle`, or `pap:cycle-mechanical` for a mechanical change (decision 0024), with the brief and nothing else. If the commit fails, no cycle starts. If the cycle fails to start, the PM logs a `decision` event `abandoned: did not start`, which clears it from In flight.

A cycle that died, or was lost with its session, is cleared the same way: the owner says so, and the PM logs `decision` with `abandoned` and the reason. Nothing clears a cycle on a guess.

The cycle's `/change` copies the brief's route and rule 20.2 item into its pull request body as a `Route:` line, so the success measure can be read from `gh`.

Nothing caps how many cycles are in flight. Every launch is a command the owner typed, and that is the bound; the state file shows the count.

`/pap:pm` runs in the main session, PM or solo, so a solo session keeps `start` and `launch`. Its script is refused by the guard when a sub-agent calls it, as the owner's skill scripts already are. Pausing stays with the console's `/pm exit`. `event`, `audit` and a full `relaunch` are not built here: until they are, the PM appends `report`, `message`, `pause`, `resume`, `merge` and `decision` lines itself, in the format above.

### pap new

In a new clone the order is `/envision` first, then `/pap:pm start` before the first launch.

The welcome session is started by the same `pap claude`, in the clone, so it is a PM session. It is given what the run did and what is installed, as before, and the role, which in a clone with no product layer proposes `/envision`. It still starts nothing until the owner answers. No `pap new` scenario changes.

### The decision record, the backlog and the docs

Decision 0025 ships in the same pull request, with the owner's ask of 2026-11-10 and the revisits of 0020 and 0021 (0 of 20 changes started with `/intent`) as its PIP, the intent's two success measures as its expected effects, and a typed revisit after 10 change pull requests. It states that pap ships no model and does not change Claude Code's intended purpose, software development; an adopter is the deployer of Claude Code, and pap is not its provider. It carries:

- **25.1** `pap claude` in an adopting repository starts a PM session; `--solo` is the owner's, and is refused in an agent shell.
- **25.2** A PM session writes only the PM paths; any other write is refused with the route named. Sub-agents are not bound by it.
- **25.3** A PM session is given its role and the tracker's state whenever it starts, and launches and resumes nothing until the owner says.
- **25.4** An ask no route covers stops: an `/intent` in pap, the text of an issue for `blairforce1/pap` elsewhere.
- **25.5** A cycle's pull request carries a `Route:` line with its route and its item of rule 20.2.

The enforcement lines of rules 18.2, 18.7, 18.8 and 20.2 change from planned to what `/pap:pm launch` refuses. Decision 0018 is not amended. `product/backlog.md` records what is left: `event`, `audit` and full `relaunch` under H-012, roles under H-013, and a new item for the `pr-checks` server gate. `docs/run-a-project.md`, `docs/getting-started.md` and `CLAUDE.md` say what is now a command, and that the model and its version are Claude Code's, not pinned by pap.

### Scenarios

Added in `features/pm-mode.feature`:

- `pm-mode-1` pap claude starts a PM session: the default, the heart of the intent.
- `pm-mode-2` No product layer, told to propose /envision: the first route.
- `pm-mode-3` Told how to route an ask: questions, ripeness, rule 20.2.
- `pm-mode-4` The owner may still invoke a skill directly: the intent keeps it.
- `pm-mode-5` An ask with no route stops: in pap and elsewhere.
- `pm-mode-6` Outside an adopting repository, a session as before: the mode's edge.
- `pm-mode-7` Arguments still reach Claude Code: `--resume` must not break.
- `pm-mode-8` The owner starts a solo session: the way out stays open.
- `pm-mode-9` A solo session is refused from an agent shell: the flag is human-only.
- `pm-mode-10` The PM session writes a PM path: the skills it runs keep working.
- `pm-mode-11` Refused outside the PM paths, with the route: the control itself.
- `pm-mode-12` A path is judged where it resolves: `..` and links do not get round it.
- `pm-mode-13` A write outside every adopting repository passes: memory and scratch.
- `pm-mode-14` Refused in another adopting repository: the PM never writes pap from an adopter (0018, point 9).
- `pm-mode-15` A commit of PM paths only passes: `/intent` and `/spec` commit.
- `pm-mode-16` A commit from a work tree with a change outside is refused: shell writes stop here.
- `pm-mode-17` An untracked file outside stops the commit: `git add` in the same command.
- `pm-mode-18` A sub-agent writes any path: the H-003 lesson, cycles are not blocked.
- `pm-mode-19` A sub-agent commits outside the PM paths: the same, for commits.
- `pm-mode-20` What was refused before is still refused: the guard refuses nothing less.
- `pm-mode-21` A call the guard cannot read is reported, not blocked: the failure direction.
- `pm-mode-22` /pap:pm start starts the tracker: first use.
- `pm-mode-23` /pap:pm start reports where things stand: every later use.
- `pm-mode-24` /pap:pm start stops on an uncommitted tracker: rule 18.3.
- `pm-mode-25` Given the role and the state again: `/clear`, resume and compaction.
- `pm-mode-26` No tracker, told to start one: before the first launch.
- `pm-mode-27` A companion tracker is pushed: and a failed push is said.
- `pm-mode-28` A launch without a restated yes is refused: rule 18.2.
- `pm-mode-29` A launch from an incomplete brief is refused: rules 18.7, 18.8, 20.2.
- `pm-mode-30` A launch starts one cycle in the background: the agent type by kind.
- `pm-mode-31` A second launch of a cycle in flight is refused: one cycle a change.
- `pm-mode-32` A cycle's pull request carries its route: the signal for the first measure.
- `pm-mode-33` /pap:pm is for the PM session only: a cycle cannot launch cycles.
- `pm-mode-34` The welcome session is a PM session: `pap new`.
- `pm-mode-35` A session whose main calls carry an agent id is told the guard is not binding: the silent failure made loud (SEC-001).
- `pm-mode-36` The guard's own files are refused to the PM session: settings, the plugin, the logs (SEC-002).
- `pm-mode-37` Other commands that write a commit are not judged: the stated limit (SEC-004).
- `pm-mode-38` A first write into a new change folder is judged from its deepest existing parent (QA-003).
- `pm-mode-39` A path the guard cannot resolve is refused (QA-003).
- `pm-mode-40` A launch the owner did not type is refused: the yes is the owner's (UX-004, SEC-006).
- `pm-mode-41` A second PM session does not write the tracker: one writer (REL-003).
- `pm-mode-42` A lock left by an ended session is taken over (REL-003).
- `pm-mode-43` An abandoned cycle is no longer in flight: the way out for a dead cycle (REL-004).
- `pm-mode-44` A launch whose tracker commit fails starts no cycle: the order (REL-004).
- `pm-mode-45` An event log line that cannot be read stops the launch (QA-001, REL-007).
- `pm-mode-46` A message to a cycle is logged by the guard: the signal for the second measure (OPS-003).
- `pm-mode-47` The PM's first line tells the owner the mode and the way out (UX-001).
- `pm-mode-48` A solo session starts anywhere and is logged (QA-009).
- `pm-mode-49` A resume takes the mode of the start that resumed it (QA-009).
- `pm-mode-50` Without the pap plugin a session has no mode, and says why (QA-010).
- `pm-mode-51` /pap:pm works in a solo session: the undo keeps the launch path (OPS-004).
- `pm-mode-52` The PM writes nothing in another adopting repository, the PM paths included (QA-005, UX-003).
- `pm-mode-53` Discarding an uncommitted tracker takes a second yes (UX-005).
- `pm-mode-54` The role forbids clearing a blocked commit by stash, clean or delete (OPS-005).
- `pm-mode-55` A command that sets or unsets the mode is refused (SEC-007).
- `pm-mode-56` A repository whose key changed is told where its tracker is (REL-008).
- `pm-mode-57` A session started without pap claude is not bound: the intent's first non-goal (QA-011).

Scenarios 1 to 5, 25, 26, 34, 35, 47 and 54 are about what the session is given, not what the model then does with it; nothing in pap can bind a conversation until the eval suite exists (H-010).

Terms added to `product/domain.md`: adopting repository, product layer, session, PM session, solo session, sub-agent, role, ask, route, PM paths, write, guard, refusal log, session log, tracker, state file, event log, brief, cycle, companion repository; eight events and eight rules.

## Non-functional

| What is measured                                                                                                                    | Threshold                                                          | Test tier   |
| ----------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------ | ----------- |
| Time the guard adds to one Edit, Write or NotebookEdit call of a PM session, finding the repository and resolving the path included | at most 150 ms at the 95th percentile, over 100 calls              | integration |
| Existing guard expectations changed (`tests/guard-route.test.sh` before pm-mode)                                                    | 0                                                                  | integration |
| Sub-agent writes refused as outside the PM paths, across the suite                                                                  | 0                                                                  | integration |
| Size of the role                                                                                                                    | at most 80 lines and 8 KB, plus at most 60 lines of the state file | unit        |
| Time the session-start hook takes to give the role                                                                                  | at most 300 ms at the 95th percentile, over 20 starts              | integration |
| The PM session's first-turn context, with the role                                                                                  | measured once and recorded in `findings.md`; no threshold          | acceptance  |
| Shell the hooks and `pap claude` run under                                                                                          | POSIX `sh` (dash), `shellcheck -s sh` clean (INV-003)              | unit        |
| Time `pap claude` adds before Claude Code starts, with a stub in place of `claude`                                                  | at most 200 ms at the 95th percentile, over 20 starts              | integration |
| Time the guard adds to one `git commit` in a PM session, work-tree scan included, on pap and on the trial repository                | at most 500 ms at the 95th percentile, over 50 commits             | integration |
| Time the guard adds to one call of a sub-agent, a solo session or a session with no mode: it exits before any path or git work      | at most 30 ms at the 95th percentile, over 100 calls               | integration |

Each time is measured by the test suite on the owner's machine, in pap's own repository with a warm file cache, as the difference between a run with the guard and a run without; the commit row is also run in the trial repository. The zero rows are counts of failing cases in the suite.

## Security

- **The mode cannot be reset from inside.** The guard refuses a command that sets or unsets `PAP_MODE`, as it refuses one that changes `GH_CONFIG_DIR`, so a session cannot start a second Claude Code in another mode by that route. The limits of that parse are `guard-route.sh`'s own.
- **Where the mode lives.** The mode is in the environment `pap claude` gives Claude Code. The guard reads its own environment, which is Claude Code's, so no command the session runs can change what the guard sees (the reasoning of rule 23.4's session check). INV-005 holds: the guard is not a git hook and adds no way to skip one.
- **How the PM is told from a sub-agent.** Claude Code's hook input carries an agent id on a sub-agent's tool call and none on the main session's. The guard binds a call with no agent id in a PM session. The docs show this by example and do not state it outright, so the plan proves it with one probe before any code: a PM session and a sub-agent each make one write, and the two inputs are compared. If the main session's calls carry an agent id, this spec is returned to. After release the same check runs live, each time the role is given, so a Claude Code release that changes the input is said in the session and logged, not found by its absence.
- **Failure direction.** If a sub-agent's call ever lacked the id, cycles would be refused protected paths: loud, and noticed on the first cycle. If the guard cannot read a call it reports and does not block, as today.
- **The guard's own files.** Claude Code's settings, the installed plugin's directory and pap's state directory apart from the tracker are refused to the PM session's Edit, Write and NotebookEdit, so it cannot switch the guard off or rewrite the logs the signals read with those tools. The logs are not tamper-proof: a shell command can still change them, and a sub-agent is unbound.
- **What it does not stop**, stated as rule 25.2's limits: a shell command that changes a file and never commits it; a commit or ref written by `git merge`, `cherry-pick`, `revert`, `am`, `rebase`, `commit-tree` or `update-ref`, or through `gh api` to a repository's contents; a write through `bash -c`, `eval` or a script that then commits past the parse (the limits `guard-route.sh` already lists); a commit made with `--git-dir` or `GIT_DIR`; any sub-agent, so a PM that launches a general-purpose agent to make an edit passes the guard and breaks decision 0024 point 2 instead; a second Claude Code started from the session without `pap claude`. The first measure, read from merged pull requests, is what catches a change that got through.
- **The solo flag.** Refused in an agent shell before anything else, so a PM session cannot start itself a solo one. The session log records each solo start.
- **No new secret.** The tracker, the refusal log and the session log hold slugs, paths, times and briefs: no token, no file content. Their directory is the owner's, mode 700. A companion clone is pushed as the agent, by the shim, to a repository the installation covers, or the push fails and is said.
- **INV-006.** `/pap:pm` has no step that opens a pull request, labels or merges; its cycles stop at a draft pull request.

## Data

The tracker: a state file, an event log and briefs, in the formats under "The tracker". The refusal log: one tab-separated line a refusal (UTC time, session id, mode, caller, path, repository). The session log: one line a start (UTC time, session id, mode, repository, Claude Code version). The message log: one line for each message a PM session sends a sub-agent and each sub-agent stop (UTC time, session id, the sub-agent's id and type), written by the guard, not by the PM. The launch record: one line for each `/pap:pm launch <slug>` the owner typed. All four are among the guard's own files. The tracker and these logs live under pap's state directory, keyed by the repository's owner and name from `origin`, or, when it has none, by the path of its root, so two repositories never share a tracker. The key uses the owner's handle as a directory name and nothing more. When a repository's key changes (an `origin` added or renamed), `/pap:pm start` finds the tracker under the old key and says so; it does not silently start a new one.

Personal data: the logs hold times, paths (which may carry the machine's user name), repository names and session ids. Briefs and event lines are free text and may name people; the role tells the PM to keep names and third parties' words out of them. Nothing leaves the machine unless the owner points the tracker at a companion clone, which is the owner's choice and off by default; the recipient is then GitHub. No migration: a PM tracker kept by hand stays where it is, and the owner may copy its state into the new state file. Retention is the owner's; deleting the directory loses the tracker and nothing else in the project, and with it every recorded restate and yes, so a pending launch is restated. Erasing a tracker kept in a companion repository also needs that repository deleted or its history rewritten.

## Interfaces and contracts

Exposed:

- `pap claude [--solo] [arguments for claude]`.
- `PAP_MODE` in the session's environment: `pm`, `solo` or unset.
- The plugin's hooks: the guard also runs before Edit, Write and NotebookEdit, and a hook gives the role at session start.
- `/pap:pm start`, and `/pap:pm launch <slug>` typed by the owner; their checks are a script with exit codes.
- The plugin's hooks also record the owner's typed launch, and log messages to sub-agents and sub-agent stops.
- A `Route:` line in the pull request body `/change` writes.
- The tracker's formats, which `/pap:pm event` and `audit` will read (H-012).
- Decision 0025 and rules 25.1 to 25.5; pap's minor version, plugin and marketplace.

Must not break: every refusal `guard-route.sh` makes today; `pap new`'s scenarios; `pap init`, `sync`, `doctor`; a session started without `pap claude`; the console's `/pm exit`; `/intent`, `/spec`, `/envision`, `/pap:reviewed` and `/pap:accept` in a PM session.

Consumed: Claude Code's hook input (the agent id, the session-start source), which pap does not control. A Claude Code release that changes either is found by the probe, kept as a test.

## Operations

pap has no telemetry and no monitor (H-015). Every signal is read by the owner or the PM from `gh`, git and the logs the guard keeps on the machine, and written into `findings.md`.

**Signals.**

| Signal            | Measures                                                                                                                                 | Read from                                                                                                                                                                                                                                 |
| ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Ad hoc changes    | Success measure 1: change pull requests with neither an accepted `intent.md` nor a `Route:` line naming an item of rule 20.2             | `gh pr list --state merged --limit 100 --search 'head:change/'` in pap and the trial repository; each body for a `Route:` line that names item 1 or 2 or a listed exemption, each diff for `changes/<slug>/intent.md` with `accepted-by:` |
| Messaged cycles   | Success measure 2: cycles that got a message after their first report                                                                    | The message log: a message to a sub-agent after that sub-agent's first stop. Written by the guard; the event log's `message` lines are the narrative and are not counted                                                                  |
| Cycle refusals    | Health: a cycle refused a write as outside the PM paths (the H-003 failure)                                                              | The refusal log, which should hold PM-session lines only; a cycle's `ASK:` naming the guard                                                                                                                                               |
| PM refusals       | Health: how often the PM tries a write it may not make                                                                                   | The refusal log, lines per PM session                                                                                                                                                                                                     |
| Solo share        | Health: whether the mode is liveable or routinely escaped                                                                                | The session log: solo starts against PM starts                                                                                                                                                                                            |
| Guard not binding | Health: the live check found an agent id on the main session's calls, so the PM is unbound                                               | The session log; the warning at the top of the role                                                                                                                                                                                       |
| Sessions in mode  | Health: `pap claude` in an adopting repository gives a PM session, and the role is given at every start, resume, `/clear` and compaction | The session log: one line a start and one a role given                                                                                                                                                                                    |
| Unread calls      | Health: tool calls the guard could not read and let through                                                                              | The refusal log's unread lines                                                                                                                                                                                                            |

**Good.** Judged over the first 10 change pull requests merged after the release, across pap and the trial repository, inside an operation window of 30 days from the release. If fewer than 10 merge in the window, `findings.md` says the measures were not read.

- Ad hoc changes: 0 of 10.
- Messaged cycles: at most 1 of 10.
- Cycle refusals: 0 over the window.
- PM refusals: at most 3 in any one session. One is the guard working. None at all across the window, with PM sessions logged, is not a pass: it is checked against the session log's live-check lines before it is read as good.
- Guard not binding: 0 session starts logged with the warning that the PM paths are not enforced.
- Solo share: at most 2 solo starts in 10 session starts.
- Sessions in mode: every `pap claude` start in an adopting repository logs `pm` or `solo`, and every PM start, resume, `/clear` and compaction logs a role given.
- Unread calls: 0 over the window.

**Wrong.** A cycle stopped by the guard; a PM session that cannot write its tracker, an intent or a spec; a session that starts with no role; a merged change with no intent and no route; the owner starting solo by habit. A refusal is noticed at once, in the session that got it. A missing role is noticed at the session's first line. An ad hoc change is noticed when the 10 are read, so within the window at the latest. First checks, all read-only:

1. Read the refusal: its rule, its path and the route it names.
2. `claude --version`, against the Claude Code version in the session log's last good start.
3. The last lines of the refusal log and the session log under pap's state directory.
4. `claude plugin list` and `mise ls`: the pap plugin and the pap command are both the release; a skew between them is a finding.
5. `pap doctor` in the repository: the session was started by `pap claude`.
6. `mise run test` in pap at the release tag: the guard suite passes.

Only then start `pap claude --solo` to carry on.

**Undo.** In three steps, the first of which needs no release:

1. **Now, per session:** the owner runs `pap claude --solo`. The mode and the PM paths are off for that session; everything else holds, `/pap:pm start` and `launch` included.
2. **For everyone:** revert the merge by pull request, bump the version by pull request and run `scripts/release.sh`. The revert keeps decision 0025 and rules 25.1 to 25.5 in place, marked withdrawn, because rule numbers are never reused. Both pull requests are `risk:high`.
3. **Machines and repositories:** move to the patch with `mise use -g github:blairforce1/pap@<patch>` and update the plugin with `claude plugin install pap --marketplace blairforce1/pap`; repositories that pin the reverted release move their pin by pull request, found with `gh search code --owner <owner> '<version>' --filename pap.toml`.

Outside git: the tracker, the refusal log, the session log, the message log and the launch record stay under pap's state directory. They are harmless and the owner may delete them; a tracker in a companion clone is the owner's to keep. Pull requests already merged with a `Route:` line keep it. This text is the pull request's "How to revert".

**Operational scenarios.**

```gherkin
Scenario: A change merges with no intent and no route
  Given pm-mode is live
  When ad hoc changes is above 0 in the first 10 change pull requests
  Then the owner notes the pull request as a finding (5.9: moderate, diagnosis only)
  And the human is told by the read, in findings.md

Scenario: Cycles are still sent back
  Given pm-mode is live
  When messaged cycles is above 1 in the first 10
  Then the PM writes up which messages were rework and which were answers, as a finding (5.9: moderate)
  And the human is told in the state file's Waiting on the owner

Scenario: A cycle is refused by the guard
  Given pm-mode is live
  When cycle refusals is above 0 at any time in the window
  Then the owner carries on with pap claude --solo, and the merge is reverted and a patch released (5.9: severe, the pre-approved rollback)
  And the human is told by the cycle's ASK: and the refusal log

Scenario: The PM keeps trying to write
  Given pm-mode is live
  When PM refusals is above 3 in one session
  Then the PM stops and reports the paths refused, and the role's wording is a finding (5.9: moderate)
  And the human is told in the session

Scenario: The owner works solo by habit
  Given pm-mode is live
  When solo share is above 2 in 10 session starts
  Then the owner notes what each solo session was for as a finding, and a missing route becomes an /intent (5.9: moderate)
  And the human is told by the session log, read with the 10

Scenario: The guard stops binding the PM
  Given pm-mode is live
  When a session start is logged with the warning that the PM paths are not enforced
  Then the owner carries on with that knowledge or with pap claude --solo, and a bugfix intent is opened citing the Claude Code version (5.9: severe, propose through the normal gate)
  And the human is told in the PM's first line and by the session log

Scenario: The guard lets through a call it could not read
  Given pm-mode is live
  When unread calls is above 0 at any time in the window
  Then the owner notes the tool call and the Claude Code version as a finding, and a bugfix intent is opened if it repeats (5.9: moderate)
  And the human is told in the session that made the call

Scenario: A session starts with no role
  Given pm-mode is live
  When a pap claude start in an adopting repository shows no role and logs no mode
  Then the owner runs the first checks, and a bugfix intent is opened citing the session (5.9: moderate)
  And the human is told at the session's first line
```

## Areas of concern

- **The guard is on the main session only, and that is the design.** Any sub-agent is unbound, because binding cycles is the H-003 mistake. So the PM paths stop the PM typing, not the PM delegating: a general-purpose agent told to "just edit it" passes. What catches that is the first measure, after the merge.
- **`product/**` is a PM path and a protected path.** The owner widened the PM's writes to what its skills write (intent churn below). The PM can now edit the vision, the invariants and the backlog directly; the control on them is still the `risk:high` label and `owner-reviewed` at the pull request, not the guard.
- **Any slug, one repository.** The PM writes nothing in another adopting repository. Inside its own, the PM paths are judged by path, not by the branch, so the PM can edit another change's `changes/` folder or scenarios. Rule 17.3 covers scenarios at the pull request; nothing covers a stray edit to another change's intent.
- **Shell writes are caught only at the commit.** The intent says any other write is refused. A file changed by `sed` or a redirect and never committed is not. Parsing shell for writes was judged a rabbit hole; the commit check is the honest boundary.
- **The whole work tree is judged at a commit.** A PM commit is refused when anything outside the PM paths is dirty there, even a file the commit would not have taken. In the main checkout, which parallel sessions share, a stray file blocks the PM until it is gone; PM commits belong in a change work tree or the tracker.
- **The yes is a typed command.** A launch needs the owner to type `/pap:pm launch <slug>`; a spoken yes is not enough. That is one typed line a launch where 0018 asked for a yes, and it is what stops the PM recording its own approval. Whether Claude Code's prompt hook sees a typed slash command is proved by the plan's probe; if it does not, this is returned to.
- **The second measure is logged by the model.** `message` and `report` lines are appended by the PM until `/pap:pm event` ships. A PM that forgets a line under-counts send-backs. The count is now read from the message log the guard writes, so a forgotten line no longer under-counts; the event log's own lines are still the PM's, and are narrative.
- **The tracker is on one machine by default.** It survives a `/clear` and a shutdown, which is what the intent asks, and is lost with the disk unless the owner points it at a companion clone.
- **The role is text.** Routing, ripeness and "an ask no route covers" are judgement the role asks for and no scenario can bind until H-010's evals exist. The hook does not judge rule 20.2 (the intent's non-goal).
- **Process section 7.** No seventh manual step: the owner's yes to a restated ask and the issue they file are acts they already perform or choose to.
- **One large `risk:high` pull request**, by the owner's decision, touching `plugins/pap/hooks/**`, `rules.md`, `decisions/**`, `product/**`, `tests/**` and `CLAUDE.md`.

## Open questions

- How the hook tells the PM from a cycle: answered, by the agent id Claude Code puts on a sub-agent's tool call and not on the main session's; proved by a probe in the plan before code.
- How the mode is entered: answered, `pap claude` sets the mode in the session's environment, and a session-start hook gives the role at start, resume, `/clear` and compaction.
- The minimal tracker's format and location: answered by @blairforce1 on 2026-11-10, a git repository of its own on the machine, under pap's state directory, with the option of a companion clone; a state file, a tab-separated event log and the briefs.
- One pull request or a split: answered by @blairforce1 on 2026-11-10, one pull request.
- Whether background cycles survive a `/clear`: still open: the plan, by trial; the role tells the PM to resume nothing either way, and a lost cycle is cleared by an `abandoned` decision.
- Whether Claude Code's prompt hook sees the owner's typed `/pap:pm launch`: still open: the plan, by probe before code.
- Whether a PM session's `gh pr create` should be refused (rule 18.1 keeps the housekeeping exception, so it is judgement): still open: @blairforce1, the server-gate intent.

## Intent churn

One thing, with its churn commit. The intent said the PM session writes only the tracker and `changes/<slug>/`. `/spec` also writes `features/<slug>.feature` and `product/domain.md`, and `/envision` writes `product/**`, all in the main session, so the intent as written would have refused the PM's own skills. The owner widened the PM paths to what its skills write. Commit: `intent(pm-mode): churn, the PM writes what its skills write`.
