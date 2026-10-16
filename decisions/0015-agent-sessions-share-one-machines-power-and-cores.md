# 0015. Agent sessions share one machine's power and cores

- **Status:** proposed
- **Date:** 2026-10-16
- **Deciders:** blairforce1, with Claude
- **Supersedes:** none
- **PIP:** the 2026-10-16 measurement on a Framework 16 (Fedora, AMD) on battery: 53 W drawn against 8 to 15 W in light use, load average 9.7, from several Claude Code sessions building at once (one running `dotnet build -f net10.0-android -c Release` in an agent loop), an Android emulator (`-gpu swangle`, software rendering) left at about 9% CPU between uses, and two .NET SDKs (nix 10.0.302, mise 10.0.401) each with its own MSBuild nodes and VBCSCompiler; the battery itself at 94.5% capacity after 40 cycles
- **Expected effect:** heavy builds running at once on one machine ↓ from 2 or more to 1; .NET SDKs with live build servers ↓ from 2 to 1; battery draw with two agent sessions building ↓ from 53 W to under 30 W
- **Introduced in:** v0.8.0
- **Revisit:** after 10 change PRs: whether a session transcript shows a heavy build run outside `scripts/heavy-build.sh`, whether a session's end ever disturbed another session's build, and the battery draw re-measured with two sessions building

## Context

Agent sessions on one machine do not know of each other. Each builds as if
it had the machine to itself, and the machine is a laptop. Four things
added up to 53 W:

- Release Android builds. Two sessions each started one; with AOT a
  Release build costs several times what Debug does, and two at once take
  longer than two in sequence. Neither session needed Release: the change
  under test concerned Debug behaviour.
- An emulator a project script started (`experiments/kit/emulator.sh` in
  replete) and nothing stopped. Software rendering kept it at 9% CPU with
  nothing building. That project's own fix is deferred and is not part of
  this record; what this record provides is the place for it to run.
- Two SDKs. `global.json` in the template pinned `rollForward:
  latestPatch`, which stays inside one feature band: a project pinned at
  10.0.3xx cannot use the 10.0.401 beside it, so a lagging pin forces a
  second SDK, and each SDK runs its own MSBuild nodes and compiler server.
- Idle build servers. MSBuild worker nodes (node reuse) and VBCSCompiler
  stay after a build, at 1 to 2% CPU each. They cost RAM more than
  battery; VBCSCompiler exits after about ten minutes idle on its own.

## Decision

Four parts under one reason: sessions share one machine's cores and
power, so the mechanisms that stack them are capped, and what a session
starts is stopped when it ends.

1. **Heavy builds are capped and serialised per machine** (rule 15.1). A
   heavy build is an Android, iOS or Mac Catalyst target, a Release
   configuration or an AOT build. It holds the machine's one lock,
   `${XDG_RUNTIME_DIR:-/tmp}/pap-heavy-build.lock`, while it runs, so a
   second session's heavy build waits for the first; on battery it runs
   with at most two MSBuild nodes (`-m:2`). The .NET layer ships
   `scripts/heavy-build.sh`, which does both around `dotnet <verb>
   <arguments>`. The shell holds the lock, not dotnet: the worker nodes
   and compiler server a build leaves behind would otherwise inherit it
   and never release it, so dotnet runs with the lock's descriptor
   closed. Battery is read generically: any `/sys/class/power_supply/*`
   of type Mains is an adapter, whatever its name (ACAD, AC, ADP1), and
   the machine is on battery when it has one and none is online; on macOS
   `pmset -g batt` says "Battery Power"; where neither answers, mains is
   assumed. `flock` is util-linux; without it the build runs unlocked and
   says so.
2. **Agents build Debug unless the change concerns Release behaviour.**
   The `/change` skill says so, and sends a heavy build through the
   script.
3. **A `SessionEnd` hook in the pap plugin** (`hooks/session-end.sh`)
   starts a detached cleanup and returns at once: `dotnet build-server
   shutdown` when no other Claude Code session runs on the machine, and
   `mise run session-end` when the repository defines that task, the
   place for a project's own cleanup. It never fails or delays the exit:
   the work is detached, each step is capped at five minutes, output goes
   nowhere, a missing tool is skipped.
4. **One SDK serves every project.** The template's `global.json` rolls
   forward with `latestFeature`: the newest installed 10.0 SDK at or above
   the pin builds every project. Developer machines give up the exact SDK
   version; CI still installs the pin through mise.

The reason that carried it: the cost came from mechanisms, not from any
one session's judgement, so the fix is in the mechanisms.

## Measurement

Two things were checked before relying on them.

The hook. Claude Code's documentation: `SessionEnd` hooks "share a
1.5-second budget", a plugin hook's own `timeout` does not raise it, the
hook "can't block session termination", stdout goes to the debug log,
and work that must outlive the run belongs in a fully detached process.
So the hook forks its cleanup with `setsid` (or `nohup`) with stdin,
stdout and stderr on `/dev/null`, and exits 0; the test shows it back in
under a second while the cleanup is still running.

`dotnet build-server shutdown` against another session's build. The
command is machine-wide for the SDK that runs it, and PAP expects
parallel sessions, so it had to be shown not to break a build in flight.
Measured with two shells in a scratch directory on SDK 10.0.401 (mise),
while six idle MSBuild nodes and a compiler server of SDK 10.0.302 (nix)
belonging to other sessions were watched:

| Case                                                                                | `dotnet build-server shutdown`                                                                                                     | The build                                |
| ----------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------- |
| Idle: one worker node and one VBCSCompiler left by an earlier build                 | 0.48 s; both exited                                                                                                                | none                                     |
| Nothing running                                                                     | 0.47 s                                                                                                                             | none                                     |
| A busy worker node: two projects each in `Exec sleep 40`, `-m:2`, `--msbuild`       | 0.59 s, "shut down successfully"; the busy node was left alone and outlived the build                                              | 0 errors in 41 s                         |
| An in-flight compile: 12,000 classes, 17 MB of source, 11 s alone, `--vbcscompiler` | blocked 15.6 s until the compile finished, then the server exited; a build started after it got a new server and finished in 1.5 s | 0 errors; "server processed compilation" |
| Everything, while the two-project build was busy                                    | 0.57 s                                                                                                                             | 0 errors                                 |

In every case the 10.0.302 nodes and compiler were untouched: the command
reaches the servers of the SDK that runs it. So the command cannot break
a parallel build, and an unconditional shutdown would have been safe.
What it costs a live session is a cold server on its next build. The
hook therefore shuts the servers down only from the last session on the
machine; an earlier one leaves them for the sessions still running.
Another session is a process named `claude` other than this one; the
Chrome native host is a `claude` process too and is not a session.

## Considered options

- **A `PreToolUse` hook that rewrites `dotnet build` commands** to add
  the lock and the cap. Lost: a parser of build command lines in a hook,
  for a rule a script and a sentence in the skill carry. A hook that
  refuses a bare heavy build and names the script is the planned
  enforcement, and refusing is simpler than rewriting.
- **Shut the build servers down at every session's end.** Measured safe
  (above). Lost: every session's end would cost the sessions still
  running a cold server, for idle processes whose cost is RAM.
- **Skip the shutdown while any build runs** instead of while any session
  runs. Lost: an idle node and a busy one look the same from outside,
  and the measurement shows a busy one is left alone anyway.
- **Cap MSBuild on mains too.** Lost: on mains the cores are the point.
- **`nodeReuse:false` for heavy builds**, so they leave no nodes. Not
  taken: the nodes' cost is RAM, and the session's end covers them.
- **Keep `latestPatch`**, bumping lagging pins faster. Lost: Renovate
  already proposes the bump weekly and the lag still happened; one lagging
  repository is enough for a second SDK.
- **`latestMajor`.** Lost: an 11.0 SDK would build net10.0 projects with a
  compiler the repository was not written against.

## Consequences

- Easier: two sessions' heavy builds run one after the other, and a
  session on battery builds on two nodes without anyone remembering `-m`.
- Easier: a project has one place, the `session-end` task, for what it
  starts and must stop; replete's emulator is the first customer.
- Easier: a machine whose last session has ended has no build servers of
  that session's SDK.
- Harder: a heavy build waits for another session's. A stuck build holds
  the lock until it dies; Claude Code's Bash timeout kills the waiting
  script, which releases its wait.
- Harder: a `packages.lock.json` written by a newer SDK can name implicit
  package versions the pinned SDK does not, and CI's locked restore then
  fails (NU1004). The lock file is written with the pinned SDK.
- Limit: the lock and the cap exist only for a build run through the
  script; nothing refuses a bare `dotnet build -c Release`. Rule 15.1 is
  enforced by nothing yet.
- Limit: the shutdown reaches the SDK the session's `dotnet` resolves;
  another SDK's servers stay. Part 4 is what reduces the SDK count.
- Limit: a compile request that reaches a draining compiler server was
  not measured; Roslyn's client falls back to an in-process compile when
  the server refuses, so a slower build is the worst expected.
- Limit: a session that dies without `SessionEnd` leaves its servers to
  their own idle exits. Another session's name other than `claude` is not
  seen, so the shutdown runs and that session pays a cold start.
- Limit: no `flock` on macOS without Homebrew; the build runs unlocked
  and says so. `pmset` is read but was not measured.
- Follow-up: replete defines `session-end` to stop the emulator its
  `experiments/kit/emulator.sh` starts.
- Follow-up: the `PreToolUse` hook refuses an agent's bare `dotnet build`
  or `dotnet publish` of a heavy target in an adopting repository and
  names the script.
- Follow-up: the battery draw is re-measured with two sessions building,
  for the Revisit.

## Where it is taught or enforced

Backs [`rules.md`](../rules.md) 15.1 (heavy builds are capped and
serialised per machine), enforced by nothing yet. Taught in
`templates/dotnet/README.md` and the `/change` skill
(`plugins/pap/skills/change/SKILL.md`). Implemented in
`templates/dotnet/scripts/heavy-build.sh` (tested in
`tests/heavy-build.test.sh`), `plugins/pap/hooks/session-end.sh` through
`plugins/pap/hooks/hooks.json` (tested in `tests/session-end.test.sh`) and
`templates/dotnet/global.json`. The status lifecycle follows
[0001](0001-process-changes-are-measured-interventions.md).
