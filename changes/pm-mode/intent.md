# Intent: pm-mode

```text
id:                 pm-mode
class:              feature
product:            PAP
source:             none
hypothesis:         H-012
invariants-touched: INV-003, INV-005, INV-006, INV-008; plugins/pap/hooks/**, rules.md, decisions/**, product/**, tests/**, CLAUDE.md (risk:high)
accepted-by:        @blairforce1
accepted-on:        2026-11-10
generated-by:       Claude Fable 5.2 via Claude Code
skills:             pap:intent 0.17.0
prompt:             /intent pm-mode feature pap runs in PM mode by default: pap claude and pap new start a session that proposes the route in conversation, interviews for intent and spec, launches cycles for everything else, and can itself write only the tracker and changes/<slug>/
```

## Problem

The owner can ask a session for an ad hoc edit and get one. Rules 20.1,
20.2 and 21.1 are enforced by nothing, and the project-manager role that
would route the ask is run by hand, because `/pap:pm` has not shipped.
Protocol is followed only when the owner remembers to invoke it.

## Desired outcome

- pap runs in PM mode by default: `pap claude` and `pap new` start a
  session as the project manager.
- In conversation, the PM proposes the route when the ask is ripe:
  `/envision` when there is no product layer, `/intent` for a change. The
  owner can still invoke a skill directly.
- The PM interviews for intent and spec, and launches a cycle for
  everything else (`/pap:pm start`, `/pap:pm launch`).
- The PM session can itself write only the tracker and `changes/<slug>/`.
  Any other write is refused, with the route named.
- After a `/clear`, the PM resumes from a minimal committed tracker.
- An ask no route covers stops. In pap the PM proposes an `/intent`; in an
  adopting repository it hands the owner the text of an issue for
  `blairforce1/pap`, which the owner files.
- A solo session stays available behind a human-only flag.
- The backlog records what is left: `event`, `audit` and full `relaunch`
  under H-012, roles under H-013, and a new item for the server gate.

## Non-goals

- It does not bind a session started outside PM mode. The `pr-checks`
  server gate is a separate intent, next.
- No `event`, `audit` or full `relaunch`; they remain wanted and stay on
  the backlog.
- The hook does not judge rule 20.2. The PM makes the call, records it in
  the brief, and the owner can overrule it.
- The PM opens, approves and merges nothing (rule 18.1 unchanged).
- No second member or QA role (H-013, still wanted).

## Constraints

- A new decision record 0025 carries the new rules; 0018 is not amended.
- `guard-route.sh` refuses nothing less than it does today.
- Cycle agents are not blocked from editing protected paths (the H-003
  lesson: that gate blocked 10 of 10 changes).
- `pap new`'s existing scenarios keep passing, bar the welcome-session
  ones this change rewrites.
- The solo flag is refused in an agent shell, as `pap new` is.
- Hooks stay POSIX shell.

## Success measure

Over the first 10 change pull requests merged after release in pap and the
trial repository, read from `gh` and git:

- Ad hoc changes at 0: no change pull request without an accepted
  `intent.md` or a route line naming its rule 20.2 item.
- Cycles that get a message after their first report: at most 1 of 10,
  down from 18% (decision 0018, which keeps its own 20-cycle window).

## Open questions

- How the hook tells the PM from a cycle: carried forward to spec, spec author.
- How the mode is entered (`pap claude` plus a `SessionStart` hook, or otherwise): carried forward to spec, spec author.
- The minimal tracker's format and location: carried forward to spec, spec author.
- One pull request or a split: carried forward to spec, spec author proposes, owner decides.
