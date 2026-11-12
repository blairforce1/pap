---
name: pm
description: The owner's project-manager commands (decisions 0018 and 0025). /pap:pm start starts or reports the tracker; /pap:pm launch <slug> launches one cycle from its brief after the checks pass; /pap:pm sync [<version> | latest] prepares one template sync and launches nothing; /pap:pm exit pauses every cycle and saves before the owner quits; /pap:pm console opens and refreshes the pm-console pane. Only the owner invokes it, by typing it; the typed launch is the yes of rule 18.2. Runs in the main session, PM or solo, never in a sub-agent.
argument-hint: start | launch <slug> | sync [<version> | latest] | exit | console
disable-model-invocation: true
---

# PM

`$ARGUMENTS` is `start`, `launch <slug>`, `sync [<version> | latest]`, `exit` or `console`. Anything else: say the five forms and stop.

Every step of `start`, `launch` and `sync` is one run of the script, in the repository the tracker is for. Its exit code decides what you do; its output is what you tell the owner. Do not work around a refusal.

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

- **Not 0.** The launch is refused and no cycle starts. Say why, as printed, with its rule. Exit 10 means the owner did not type the command: give them `/pap:pm launch <slug>` to type, and stop. For 11 to 14, fix what it names (the restate event, the brief), commit the tracker, and ask the owner to type the launch again: a typed line serves one launch. Exit 20 means the build needs a plan and its plan is not accepted (rule 26.2): say which of the five it found, as printed, and that `/pap:plan <slug>` comes first; edit nothing to get past it, and if the owner believes the refusal is wrong, the way through is theirs, `/change` in a solo session. Once the plan is accepted the owner types the launch again.
- **0.** The yes and launch events are logged and the tracker is committed. Now start exactly one cycle with the Agent tool: `subagent_type` the `agent:` line it printed, `run_in_background` true, and as the prompt the contents of the file on its `brief:` line and nothing else. If the cycle fails to start, append a `decision` event for the slug with the text `abandoned: did not start` and run `commit`.

## sync [<version> | latest]

Prepares one template sync, the way an adopting repository takes a new pap version, and stops. Say first that you are reading pap's releases, then run `sync <version>`; with no version, or `latest`, run `sync latest`, which takes the newest release.

- **Exit 0, with a `launch:` line.** The sync brief is written from the plugin's template, [sync-brief.txt](sync-brief.txt), the restate is logged and the tracker is committed. Tell the owner the version, the version it comes from (`from:`), whether an earlier brief was replaced (`replaced:`), and give them the `launch:` line to type. Then stop. Never invoke the launch yourself: it starts nothing until the owner types it.
- **Exit 0, with no `launch:` line.** The repository already records that version. Say so, as printed. Nothing was written.
- **Not 0.** Nothing was written and the tracker is as it was. Tell the owner why, as printed, and stop: no retry. For exit 4, an uncommitted tracker, name `/pap:pm start`, whose commit-or-discard question is the owner's.

Never write a sync brief by hand, in place of a refused `sync` or otherwise. A launch that refuses a sync brief is reported to the owner, never fixed by hand.

A PM session is given the same form in its role, for when the owner asks in words ("take pap 0.19.1", "take the latest pap") without typing this command: it runs the script's `sync` with no `--session`, and the script reads the session's id from its own shell. A question about versions is answered; only an instruction runs `sync`.

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

`event`, `audit` and a full `relaunch` are not commands yet (H-012); `sync` logs its own restate event. Until they are, append `restate`, `report`, `message`, `pause`, `resume`, `merge` and `decision` lines to the tracker's `events.tsv` yourself, one line an event, four tab-separated fields, then run `commit`:

```sh
printf '%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" restate <slug> "<the ask, restated in one line>" >> <tracker>/events.tsv
```

`start` prints where the tracker is. Never edit an earlier line, and never write In flight by hand: `start` and `launch` rewrite it from the events. A cycle that died, or was lost with its session, is cleared only when the owner says so: a `decision` event whose text starts `abandoned`, with the reason.
