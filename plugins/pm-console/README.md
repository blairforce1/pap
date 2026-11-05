# pm-console

<img src=".claude-plugin/icon.png" width="96" height="96" alt="PM console icon">

A pane beside the chat for a Claude Code session working as the project
manager (PM) under PAP, the way decision 0018 (proposed) describes: one main
session briefs one background cycle per change and keeps the tracker. When
several cycles finish around the same time, their reports scroll past. The
console keeps what they asked of you in one place, with the cycles, the state
of each PAP repository and the CI timings beside it.

```
status line:  PM > 2 running - 3 waiting on you - 1 decisions proposed - CI slowest tests ~3m22
┌ PM console ────────────────────────────────────────────────────────┐
│ [ 1 Inbox 3 ] [ 2 Cycles 2 ] [ 3 PAP 1 ] [ 4 CI ]                  │
│                                                                    │
│ WAITING ON YOU (3)                                                 │
│ widgets#41                              cycle 12 - 2h - 2 >        │
│   [ ] review and merge                                             │
│   [ ] decide: keep the old export for one release, or drop it      │
│ widgets#43                              cycle 14 - 20m - 1 >       │
│   [ ] add owner-reviewed, then merge                               │
│ Open a group to see the report and tick items.                     │
└────────────────────────────────────────────────────────────────────┘
```

## Install

```
/plugin install pm-console --marketplace blairforce1/pap
```

The pane opens by itself when the terminal is wide enough for a sidebar;
`/pm` opens it otherwise and refreshes the PAP and CI figures. It shows
nothing project-specific until the PM sets the repositories: the CI and PAP
tabs say `no repos set; ask the PM to call ci_repos / pap_repos` until then.

## Tabs

Four tabs, each with its count on the tab: **Inbox** (items waiting on you),
**Cycles** (running), **PAP** (decisions proposed) and **CI**. Switch with a
click, with `ctrl+x` `tab` to focus the pane and then the arrow keys and
Enter, or with the keys `1` to `4` once the pane has focus.

### Inbox

What each cycle's report asks of the Project Lead: review, decide, merge, run
a command. Items are grouped by the pull request or thing they concern
(`widgets#41`), oldest group first, and a group with nothing open drops out
of the list. Open a group to read the cycle's report and tick items off:

- `b` back to the list;
- `c` copy the link the PM attached (the pull request, usually);
- `a` all done: ticks every item in the group and returns to the list;
- press an item to tick or untick it alone.

Done items stay until you press `✓ n done · clear`. The inbox lives in the
plugin store, so it survives a restart; the tracker stays the record of
truth.

### Cycles

This session's background agents, read from the engine every 15 seconds:
task, status, model and how long ago each started. Up to the last fifteen.

### PAP

For each repository the PM named with `pap_repos`:

- the pinned PAP version against the latest release, and `pap repo status`
  drift;
- decision records still `proposed`, and revisits due (`pap revisits`);
- backlog hypotheses ("experiments") by state, read from
  `product/backlog.md`: a `Status:` line wins, otherwise the section it
  sits in (Confirmed or Built means built, Dropped means dropped);
- open pull requests, and `risk:high` ones waiting for `owner-reviewed`;
- median lead time from pull request opened to merged over the last ten.

Refreshed every 30 minutes and on `/pm`. The pap repository itself runs
`bin/pap`; every other repository runs the `pap` its mise config pins.

### CI

The average and slowest successful run per workflow over the last 20 runs
of each repository the PM named with `ci_repos`, from `gh run list`,
slowest first. Refreshed every 10 minutes and on `/pm`.

## Status line

One line, always visible: cycles running, items waiting on you, decisions
proposed and revisits due (once the PAP tab has read its repos), and the
slowest CI workflow.

## Tools

The PM session calls these; you can also ask it to.

| Tool         | What it does                                                                                                                                                                                                                                                                                   |
| ------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `inbox_add`  | Adds what a cycle's report asks of you: `cycle` (number or slug; `lane` still works as an alias), `items` (one short imperative line each), optional `ref` to group by (`widgets#41`), `detail` (the report, shown when you open the group) and `url` (what `c` copies). Returns the item ids. |
| `inbox_note` | Sets or replaces `detail` and `url` on every item with a `ref`, to fill in or correct what the detail view shows.                                                                                                                                                                              |
| `inbox_done` | Marks items done by id, for when you tell the PM you did them instead of ticking.                                                                                                                                                                                                              |
| `inbox_list` | Lists the open items with their ids; the PM calls it on resume to reconcile with the tracker.                                                                                                                                                                                                  |
| `ci_repos`   | Sets the repositories (`owner/name`) the CI tab reads, for example `["acme/widgets", "acme/gadgets"]`.                                                                                                                                                                                         |
| `pap_repos`  | Sets the repositories the PAP tab reads: `owner/name` plus the local checkout path of each, for example `[{"repo": "acme/widgets", "path": "/srv/src/widgets"}]`.                                                                                                                              |

The repository lists are kept in the plugin store, so they are set once per
machine, not per session.

## Limits

- CI time is the run's wall time, from creation to last update, so it
  includes time spent queued.
- Token counts per cycle are not shown: the engine's agent list does not
  carry them. The PM records them in the tracker from each cycle's
  completion notice.
- `gh` must be signed in on the machine, and `mise` must provide `pap` in
  each repository the PAP tab reads.
- Rework rate (pull requests sent back) is not shown yet: it needs PAP's
  pull request timeline events (backlog H-004) to be counted reliably.
