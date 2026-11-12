# Intent: pm-sync

```text
id:                 pm-sync
class:              feature
product:            PAP
source:             none
hypothesis:         H-012
invariants-touched: INV-003, INV-011; tests/**, product/domain.md, rules.md, plugins/pap/hooks/** (risk:high)
accepted-by:        @blairforce1
accepted-on:        2026-11-12
generated-by:       Claude Fable 5.2 via Claude Code
skills:             pap:intent 0.19.1
prompt:             /intent pm-sync feature a sync form of /pap:pm that writes the template-sync brief for a version, logs the restate and leaves the launch to the owner
```

Edited 2026-11-12: the spec showed two more protected paths are touched, `rules.md` for the "Enforced by" line of rule 18.3 and `plugins/pap/hooks/**` for one line of the PM role, and the rule constraint is reworded to match.

## Problem

The owner of an adopting repository cannot take a new pap version without
the PM agent hand-writing a sync brief from a doc. Agents paraphrase the
template, drop a rule or leave off `Mechanical: yes`, so the owner has to
read each brief to trust it, and a wrong one costs a cycle.

## Desired outcome

In a PM session of an adopting repository, the owner types
`/pap:pm sync <version>`, or says "take pap 0.19.1" or "take the latest
pap". The brief for that template sync is then in the tracker, written from
a template the plugin ships, with the same text every time and
`Mechanical: yes` on it. The restate is logged, the tracker is committed
and the owner is given the launch line to type.

- With no version, or "latest", it resolves to the newest released pap at
  that moment. The brief names the exact version, never the word "latest".
- If the repository already records that version, it says so and writes
  nothing.
- In pap's own repository it refuses and says why.
- The PM may run it on the owner's word; the launch is still typed by the
  owner.

## Non-goals

- It does not launch the cycle, run `pap sync` or bump the pin. The cycle
  does the last two.
- It does not close or touch Renovate's pull request.
- It is not a general brief generator. Release bumps and other cycles keep
  hand-written briefs.
- It does not sync pap's own repository.
- It is not the rest of H-012: `event`, `audit` and `relaunch` stay apart.

## Constraints

- The launch is untouched and still typed by the owner. A brief written by
  `sync` passes the launch's existing checks with no change to them.
- One source for the brief's text: the plugin's template. The "Take a new
  version" section of `docs/run-a-project.md` shrinks to point at the
  command.
- `pap-pm.sh` stays POSIX shell. `sync` reads `.config/pap.toml` and the
  pin file and writes neither.
- No rule's statement and no decision record changes.
- The brief's budget is 80k tokens.
- No version bump in this change.

## Success measure

Read from the tracker's event log in adopting repositories, over 30 days
from release. Of the first five template-sync cycles launched, five have a
brief written by `sync` and none written by hand, and none of the five gets
a message after its first report for a reason other than a merge conflict.
With fewer than five syncs in the window, it reads over what there is.

## Open questions

- How "latest" is looked up, and what happens with no network: carried
  forward to the spec, the PM proposes and the owner confirms.
- Whether a restate logged by the script, not by the PM's hand, fits the
  wording of the rules on restating: carried forward to the spec. If it
  does not, a decision record is needed and the owner decides.
- What `sync` does when a brief for that version already exists, or the
  version is older than the one recorded: carried forward to the spec, the
  owner decides.
