# 0018. A project-manager session briefs lanes and keeps the tracker; it opens, approves and merges nothing

- **Status:** proposed
- **Date:** 2026-11-05
- **Deciders:** blairforce1, with Claude
- **Supersedes:** none; extends [0002](0002-skills-stop-at-draft-pr.md) to the session that spawns the agents, and records what `CLAUDE.md` has said since #67 (one pull request per agent context)
- **PIP:** the owner's ask of 2026-11-04: package the project-manager role so other projects can reuse it. For sixteen days one session has run every change in an adopting repository through background sub-agents, from rules that live in its own memory and a private tracker. Nothing in PAP describes the role, and each of its eleven briefing rules was learned from a miss: one brief the human had not confirmed spent about 325k tokens building the wrong thing; one lane took nine send-backs
- **Expected effect:** in a repository run under `/pap:pm`, lanes that get a message after their first report ↓ from 18% (19 of 108) to under 10% over the first 20 lanes; audit findings that repeat a rule in the table below at 0
- **Introduced in:** not yet released; the release that ships `/pap:pm`
- **Revisit:** when 20 lanes have reported under a `/pap:pm` session in an adopting repository: both effects, from the event log, and how many events the tracker lost to a shutdown

## Context

Since 2026-10-21 one Claude Code session in an adopting repository has run
every change as the project manager (PM). It writes the brief, spawns one
background sub-agent (a lane) per `/change`, logs each event in a tracker
it commits, relays what the human must decide, pauses and resumes lanes
across shutdowns, and audits time and tokens. Before it, four terminals
each ran a change and the human relayed between them by hand: told each
one "main moved", kept a save-point file, re-briefed each session after a
shutdown, and pasted an `Approved-by:` line after every push.

What the PM learned is in three places, none of them PAP: the session's
memory, the project's `CLAUDE.md` and the tracker's audit section. PAP's
own `CLAUDE.md` has carried one line of the role since #67, that the
project-manager session opens no change pull requests, with no record
behind it. A second project would start from nothing and pay for the same
misses.

### Evidence

Counted from the PM session's transcript (counts only, never content) and
from `gh`, 2026-10-21 to 2026-11-05.

| Measure                                                 | Value                                                        |
| ------------------------------------------------------- | ------------------------------------------------------------ |
| Lane launches (`Agent` calls naming a `/change`)        | 111, of which 7 re-ran a paused change                       |
| Other agents (research, one judgement call)             | 4                                                            |
| Pull requests merged across the three repositories      | 118: 107 from `change/`, 10 by Renovate                      |
| Change pull requests closed unmerged                    | 1 (its premise was false)                                    |
| Tokens per lane, last completion notice                 | median 157k, quartiles 118k and 235k, max 739k; 21.1M in all |
| Minutes to a lane's first report                        | median 11, quartiles 5 and 20, max 109                       |
| Messages to a lane after its first report               | 36, to 19 of 108 lanes; 89 lanes got none; one got 9         |
| Tokens, lanes with such a message against lanes without | median 690k against 157k                                     |
| Messages to a lane before its first report              | 23; `PAUSE` 2                                                |
| Launches that named a model or an effort                | 22 of 111, all after the first audit                         |
| Tracker commits                                         | 281                                                          |
| Audits, and findings turned into briefing rules         | 3, and 11                                                    |

The after-report count folds two things the transcript cannot separate: a
send-back for rework, and an answer to a question the lane's report
raised. The agreed first line for a question, `OWNER:`, appears in one
notice of 108; lanes asked in the body of the change skill's report
instead. That is the case for a fixed report line below.

The eleven misses and the rule each one produced, as the next brief
carried it:

| Miss                                                                                                                                                      | Rule                                                                                                                                                              |
| --------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| A feature built before anyone checked the mailbox it depended on; closed unmerged                                                                         | The PM verifies the premise (mail, API, existing code) before briefing                                                                                            |
| A new page restructured three times after the code was written                                                                                            | A design pass, and the human's yes on the layout, before the lane builds                                                                                          |
| Nine separate send-backs on one lane, each a full verify cycle                                                                                            | Demo the first runnable cut, collect feedback, send one batched round                                                                                             |
| Every lane on the PM's model at default effort                                                                                                            | Model and effort set per brief, by the task                                                                                                                       |
| Docs-only lanes re-ran the full test suite                                                                                                                | A docs-only brief may say check-only                                                                                                                              |
| Coverage failed in CI after a local pass                                                                                                                  | A code brief requires the coverage ratchet locally before push                                                                                                    |
| A decision lane over-built from a brief that listed six open questions; another brief spent about 325k tokens on a workflow when a local skill was wanted | Restate the ask in one line and get a yes before any brief; a decision brief asks for the simplest mechanism that works, from a one-paragraph design agreed first |
| Page problems surfaced only in live use at real volume; the proof had used two items                                                                      | Demo a UI change at realistic volume (fakes are fine) before asking for review                                                                                    |
| A check skipped twice because the lane's rules forbade a write the human had already approved                                                             | The brief pre-authorises the specific writes the human has said go to                                                                                             |
| Adding the review label from a phone cost four round trips                                                                                                | When the human may be on a phone, the report gives the browser steps up front                                                                                     |
| Dependency-update pull requests touching protected config each needed the owner's label                                                                   | Group them so one review covers the batch                                                                                                                         |

## Decision

1. **The PM is the main session, and the only thing that spawns lanes.**
   Only a top-level session runs background agents and speaks to the
   human, so the PM is that session. A lane is a background sub-agent the
   PM spawns with one brief and nothing else, so the brief carries the
   standing rules. The PM owns the brief, the tracker, the relay to the
   human, pause and resume, and the audit.
2. **The PM touches no pull request and does no owner's act.** It opens no
   change pull request (process housekeeping the human asks for is the
   one exception, as `CLAUDE.md` says), approves nothing, adds no
   `owner-reviewed`, writes no `Approved-by:`, merges nothing, and writes
   no settings, in GitHub or in the repository. A refusal stands: an act
   a hook or the harness refused a lane is neither done by the PM in the
   lane's place nor handed to another lane; it goes to the human as a
   decision, with the lane's output ready for when the human allows it.
3. **The lane contract.** A lane is one `/change`, one worktree, one draft
   pull request, then stop (0002). It works only in its worktree and on
   the paths its brief names, pushes after every commit, and after every
   commit writes a save point in its own memory file: worktree, branch,
   head, done, next, open questions. It cannot reach the human. It ends
   its turn with the change skill's report, or with a first line the PM
   routes on: `ASK:` when only the human can decide or act, `PAUSED:`
   after a pause. The PM logs beside each report the tokens and wall
   time its completion notice carries.
4. **Restate and yes before any brief; a question is answered, not
   built.** Before a lane is spawned, the PM restates the ask in one line
   and gets the human's yes, and logs both. Before the yes it checks the
   premise it can check, and for anything with a structure to choose it
   brings a one-paragraph design. "Why", "should we" and "what would it
   take" are questions: the PM answers them and launches nothing until
   the human says go.
5. **The tracker is a short state file and an append-only event log,
   committed on every event.** The state file says what is in flight,
   what waits on the human, what is scheduled and what is next, and is
   rewritten. The event log takes one line per launch, report, message
   to a lane, pause, resume, merge, decision and audit, and is never
   edited. Both live with the project, in its private companion
   repository when it has one, never in PAP, and the PM is their only
   writer; a lane writes its own evidence paths and nothing else. Every
   event is committed because a shutdown can come at any time and the
   tracker is what the PM resumes from.
6. **Pause and resume.** On pause the PM sends `PAUSE` to every running
   lane and waits for each `PAUSED:`. A lane on `PAUSE` finishes or
   abandons its step at the nearest safe point, commits what passes the
   hooks, pushes, writes its save point with exactly what is next, and
   ends with `PAUSED:` and what is uncommitted. The PM commits the
   tracker and tells the human it is safe to stop. On resume the PM
   reads the tracker and the save points and spawns a fresh lane on the
   same `/change`; the worktree script reports `resumed` and the lane
   carries on from "next". A lane's context is never saved; its save
   point is.
7. **An efficiency audit every five merged change PRs and at every
   resume.** It measures CI time per workflow per pull request, tokens
   and wall time per lane from the completion notices, messages per lane
   after its first report, and the project's metered costs. Each finding
   ends in a fix written as a rule the next brief carries, and the audit
   goes in the tracker with the fix beside each number. A miss the human
   spots first is itself a finding.
8. **Project rules live with the project.** PAP carries the role: this
   record, then the skill, the agent definition and the templates. What a
   project learns about itself (what the human is called, which API needs
   a lock, which checks a code brief must run, what a lane may write)
   lives in that project's `CLAUDE.md` and the PM's memory, and the brief
   skeleton has a slot for it. PAP never carries a project's specifics.

The reason that carried it: a lane starts blank and the PM's context ends,
so everything that must survive is either in the brief or committed.

## Considered options

- **Each terminal its own change, the human relaying.** The era before
  2026-10-21. Lost: every "main moved", every resume and every save point
  was the human's work, and the tracker was a hand-written file.
- **The PM as a tool, not a session.** Lost: only the main session can
  spawn background agents and talk to the human; a tool could track, not
  brief.
- **Foreground lanes.** 38 of the 111 launches were. Lost as the default:
  the PM blocks while the lane runs, and cannot pause it, run a second,
  or answer the human.
- **One tracker file.** Lost: state and log grew into one file, 358 lines
  by the end and rewritten on every event, with what the human needs to
  read buried under what happened.
- **Lanes write the tracker.** Lost: parallel writers conflict. One
  writer, and lanes write their own evidence paths.
- **Brief without restating the ask.** Lost: about 325k tokens built the
  wrong thing once.
- **Skip the audit; the human spots waste.** Lost: that is the miss that
  created the audit, and every "why is this slow" is a finding the PM
  should have had first.
- **Carry a project's rules in PAP's skill text.** Lost: PAP is public and
  generic, and the rules that bit were the project's own.

## Consequences

- Packaging, as later changes that cite this record and backlog item
  H-012: a `/pap:pm` skill with `start`, `brief`, `event`, `pause`,
  `resume` and `audit`, for the main session only; a `pap:lane` agent
  definition wrapping `/change` with the standing rules, the save point
  and the report format; templates for the tracker (state file and event
  log) and for the brief, with the eleven-rule checklist and the project
  slot; and a PM console (lane inbox, lanes, CI stats, status line),
  designed separately. The record ships with the first of them, so the
  tag that changes what the process asks of a human ships the tool
  (0001).
- Easier: a second project starts with the eleven rules instead of the
  eleven misses.
- Easier: a shutdown costs nothing committed. The tracker, the save
  points and the pushed branches are the state; the PM's context never
  was.
- Harder: the PM reads reports, never the work. A wrong report is as
  confident as a right one; the human's live test and the audit are the
  correction, and 19 of 108 lanes needed one.
- Harder: the human is a lane's only route to an approval, through the
  PM, and a lane waiting on `ASK:` holds a worktree and does nothing.
- Limit: tokens are counted per lane from completion notices, which are
  cumulative, so a lane's cost is its last notice. The PM's own tokens
  are not attributed to a change.
- Limit: `ASK:` and `PAUSED:` are text the PM matches. A lane that
  forgets the line is a lane the PM has to read; the `pap:lane`
  definition is where the line is taught.
- Measurement: the first effect is counted from the event log's
  message-to-lane lines over the first 20 lanes; the second from each
  audit's findings, matched by hand against the table above.
- Follow-up: rules 18.1 to 18.4 are enforced by nothing until the skill
  ships; each names the check it plans.

## Where it is taught or enforced

Backs [`rules.md`](../rules.md) 18.1 (the project-manager session opens,
approves and merges nothing), 18.2 (a lane is briefed after a restated
yes), 18.3 (the tracker is committed on every event) and 18.4 (an audit
every five merged change PRs and at every resume). Taught in `CLAUDE.md`
(one pull request per agent context) and the `/change` skill's stop.
Enforced by nothing yet beyond what rule 16.2's hook refuses any agent;
backlog item H-012 builds the skill, the agent and the templates.
