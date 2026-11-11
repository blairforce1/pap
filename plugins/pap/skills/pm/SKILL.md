---
name: pm
description: The owner's project-manager commands (decisions 0018 and 0025). /pap:pm start starts or reports the tracker; /pap:pm launch <slug> launches one cycle from its brief after the checks pass; /pap:pm exit pauses every cycle and saves before the owner quits; /pap:pm console opens and refreshes the pm-console pane. Only the owner invokes it, by typing it; the typed launch is the yes of rule 18.2. Runs in the main session, PM or solo, never in a sub-agent.
argument-hint: start | launch <slug> | exit | console
disable-model-invocation: true
---

# PM

`$ARGUMENTS` is `start`, `launch <slug>`, `exit` or `console`. Anything else: say the four forms and stop.

Every step of `start` and `launch` is one run of the script, in the repository the tracker is for. Its exit code decides what you do; its output is what you tell the owner. Do not work around a refusal.

```sh
sh "${CLAUDE_SKILL_DIR}/pap-pm.sh" <command> --session "${CLAUDE_SESSION_ID}"
```

## start

Run `start`.

- **Exit 0.** Report from the state file it printed: what is in flight, what waits on the owner, what is next. Say a take-over or an earlier key if it printed one. Launch and resume nothing.
- **Exit 4, an uncommitted tracker.** Show the owner the change as printed, file by file, with the likely cause, and ask: commit or discard? Do nothing else until the owner answers.
  - Commit: run `commit`.
  - Discard: run `discard`, which changes nothing. Tell the owner the change will be lost for good and ask them to confirm a second time. Only on that second yes run `discard --confirm`.
- **Exit 17.** Another session holds the tracker. Say which, and write nothing to the tracker in this session.

## launch <slug>

Run `launch <slug>`.

- **Not 0.** The launch is refused and no cycle starts. Say why, as printed, with its rule. Exit 10 means the owner did not type the command: give them `/pap:pm launch <slug>` to type, and stop. For 11 to 14, fix what it names (the restate event, the brief), commit the tracker, and ask the owner to type the launch again: a typed line serves one launch.
- **0.** The yes and launch events are logged and the tracker is committed. Now start exactly one cycle with the Agent tool: `subagent_type` the `agent:` line it printed, `run_in_background` true, and as the prompt the contents of the file on its `brief:` line and nothing else. If the cycle fails to start, append a `decision` event for the slug with the text `abandoned: did not start` and run `commit`.

## exit

The owner wants to stop. Run the pause now, in this order. Ask nothing else first, and keep the final message short.

1. Read In flight in the tracker's `state.md`. Send `PAUSE` to every cycle it lists and wait for each `PAUSED:` reply with its save point. A listed cycle that is not running in this session cannot be paused: name it in step 4.
2. Append a `pause` event for each cycle that paused, its save point as the text (see [Events you append](#events-you-append)), then run `commit`, which also pushes a companion tracker. With no cycle in flight, still run `commit`. A commit that fails, or a push it says failed, is not safe: say so in step 4.
3. Save your memory: what was running, the open pull requests, the resume order.
4. Last, and never skipped: tell the owner whether it is safe to stop.
   - If the tool `exit_ready` is present (the pm-console plugin's, `mcp__pm-console__exit_ready`), call it: `ok` true when every step above is done, else `ok` false and a `note` naming what is not done. The console then puts `/exit` in the prompt box, or toasts the note.
   - If it is absent, tell the owner in one line whether it is safe to type `/exit`, and if not, what is not done.

## console

If the tool `console_open` is present (the pm-console plugin's, `mcp__pm-console__console_open`), call it: it opens the pane and refreshes the PAP and CI figures. Say so in one line.

If it is absent, say the console is not loaded in this session, and name the check: `pap doctor` says whether the plugin is installed, and a session started with `--debug` logs why a mod's start-up hook was skipped. Do nothing else.

## Events you append

`event`, `audit` and a full `relaunch` are not commands yet (H-012). Until they are, append `restate`, `report`, `message`, `pause`, `resume`, `merge` and `decision` lines to the tracker's `events.tsv` yourself, one line an event, four tab-separated fields, then run `commit`:

```sh
printf '%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" restate <slug> "<the ask, restated in one line>" >> <tracker>/events.tsv
```

`start` prints where the tracker is. Never edit an earlier line, and never write In flight by hand: `start` and `launch` rewrite it from the events. A cycle that died, or was lost with its session, is cleared only when the owner says so: a `decision` event whose text starts `abandoned`, with the reason.
