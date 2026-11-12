# Plan: pm-sync

```text
id:                 pm-sync
class:              feature
spec:               changes/pm-sync/spec.md
accepted-by:        @blairforce1
accepted-on:        2026-11-12
generated-by:       Claude Fable 5.2 via Claude Code
reviewed-by:        Claude Sonnet via pap:plan-reviewer
skills:             pap:plan 0.19.1
prompt:             /pap:plan pm-sync
```

## Increments

1. **The gate.** A fifth fact in `tests/hook-input.probe.sh`: the
   shell's `CLAUDE_CODE_SESSION_ID` equals the hooks' `session_id`.
   Run by hand first. False: stop, return to spec. `ASK:` for the
   doc's release number unless the owner gave it. No scenario.
2. **The checks that write nothing.** The `sync` form in `pap-pm.sh`,
   up to check 5. Satisfies pm-sync-9, pm-sync-11, pm-sync-13,
   pm-sync-14, pm-sync-18, whose `@pending` tags it removes; and the
   rows of pm-sync-10, pm-sync-16 and pm-sync-20 that read no release,
   whose tags stay.
3. **The releases and the write.** Satisfies pm-sync-1, pm-sync-2,
   pm-sync-3, pm-sync-4, pm-sync-5, pm-sync-7, pm-sync-12, pm-sync-17,
   pm-sync-19, and the rest of pm-sync-10, pm-sync-16 and pm-sync-20;
   removes all twelve tags.
4. **The PM session.** The role's line, the skill's fifth form, the
   guard and launch tests. Satisfies pm-sync-6, pm-sync-8, pm-sync-15;
   removes their tags.
5. **The docs and the rule's line.** `docs/run-a-project.md`,
   `docs/troubleshooting.md`, rule 18.3's "Enforced by", the
   changelog. No scenario.

## Design

- **Template.** New file `plugins/pap/skills/pm/sync-brief.txt`, the
  spec's text word for word.
- **Fill.** In awk: values come through `ENVIRON`, and each
  placeholder is replaced by `index` and `substr`, never `gsub` or
  `sed`, so `&` and `\` stay literal. The root is filled last.
- **Reads.** `.config/pap.toml` and the `"github:blairforce1/pap"`
  line of the pin file, by patterns copied from `bin/pap`, not
  sourced.
- **Releases.** `git -c credential.helper= ls-remote --tags --refs` on
  `${PAP_SOURCE:-https://github.com/blairforce1/pap.git}`, with
  `GIT_TERMINAL_PROMPT=0`. Tags kept: exactly `v` and a version;
  sorted numerically. A new `limit <seconds>` carries
  `${PAP_PM_READ_LIMIT:-30}`; `limit30` stays, as `limit 30`.
- **Session id.** For `sync` only: `--session`, else
  `CLAUDE_CODE_SESSION_ID`. The other four forms still exit 2 with
  none. The spec words the fallback for the whole script; narrowing
  it is the owner's to confirm.
- **Checks 4 and 5.** `alive` on a `live/<id>` file that already
  exists, and `held_by_other`, split out of `take_lock`. Both only
  read. `take_lock`, which writes, runs at step 7. A wrong variable
  is refused with 27.
- **Write.** Back up the event log and any earlier brief, write
  `briefs/sync-template-<version>.md`, append the restate event with
  `cksum`'s first field, `tcommit`. If git refuses: put both back and
  reset the index, as `launch` does.
- **Exit codes.** New, listed in the script's header: 21 no pin; 22
  not a version; 23 no such release; 24 older than the recorded
  version or the pin; 25 releases not read; 26 a value not well
  formed; 27 not a running session's id. Kept: 2, 4, 15, 16, 17, 18,
  19. Already recorded: 0.
- **Role and skill.** One line in the `[pap-pm:launch]` part of
  `session-start.sh`, no new marker. `SKILL.md`: the hint, the forms,
  a `sync` section.
- **Decision record.** None.

## Fit

- **Seams.** `sync` is a fifth `case` arm, on `pm-lib.sh` and the
  script's `tcommit`, `tpush`, `log_bad`, `dirty` and `alive`.
- **Left alone.** `start`, `launch`, `commit` and `discard`: codes,
  output, push; the launch's checks; `pm-lib.sh`; `guard-route.sh`;
  pm-console; `product/domain.md`.
- **Invariants.** INV-003: POSIX `sh` only. INV-011: both files read,
  neither written.
- **Protected paths.** `tests/**`, `rules.md`, `plugins/pap/hooks/**`.

## Tests

In a new `tests/pm-sync.test.sh` unless said, tier integration: a
throwaway repository from `scripts/assemble.sh`, `live/` files planted
with a live pid, a local bare repository as `PAP_SOURCE` tagged
`v0.19.0`, `v0.19.1`, `v0.20.0`. Every case: the exit code and the
spec's full line.

- pm-sync-1, 2, 19: exit 0, the restate line with the brief's `cksum`,
  a clean tracker, the `launch:` line.
- pm-sync-3: `cmp` against a heredoc, the spec's block with fixed
  values typed in, the root holding `&` and `\`; the shipped template
  against the block itself. A control: one character changed fails.
- pm-sync-4: `cmp` of two briefs on one `PAP_PM_NOW` day, two restate
  events, `replaced: yes`.
- pm-sync-5: the repository's `git status --porcelain --ignored`
  unchanged; no yes or launch event.
- pm-sync-6: structure; the role's launch part and `SKILL.md` each
  hold the script's path with `sync`, "never write a sync brief by
  hand", "never invoke the launch", and that a question is answered.
- pm-sync-7: a launch record, then `launch`: exit 0,
  `agent: pap:cycle-mechanical`.
- pm-sync-8, 15: `tests/pm-mode.test.sh`; the no-record launch and the
  guard cases extended to sync.
- pm-sync-9: exit 0 with a `PAP_SOURCE` that does not exist.
- pm-sync-10, 11, 13, 14, 16, 18, 20: codes 24, 23, 22, 21, 15, 19, 4,
  17, 16, 27, 26; the tracker's `HEAD` and status unchanged; for 18,
  no `live/` or lock file made. Beside 20: a repository whose path
  holds a line break, 26. Its last row adds `v0.21.0-rc.1`: 0.20.0.
- pm-sync-12: code 25 from a source with no tag, and from one with
  pre-release tags only. No local path hangs, so the source that never
  answers is a `git` stand-in whose `ls-remote` is `exec sleep`;
  `PAP_PM_READ_LIMIT=2`, code 25 inside 5 seconds.
- pm-sync-17: a refusing `pre-commit` hook, which `tcommit` never
  skips, in a default tracker and a companion clone: code 18, the
  hook's line, the event log and brief `cmp`-equal to copies.
- Non-functional. Give-up time: pm-sync-12. Repository files changed:
  pm-sync-5. Tracker files changed by a refusal: every refusal case.
  Bytes that differ: pm-sync-4. Shell: unit; `shellcheck -s sh` and
  `dash -n`, run by `tests/pm-mode.test.sh`.

## Observation

- **Hand-written syncs.** Increment 3 builds the `sync: ` prefix and
  the checksum the signal reads.
- **Messages to a sync, costly syncs.** No increment: events already
  logged.
- **Refused sync launches.** No increment: `launch` already writes a
  `used` line for any slug it refuses; pm-sync-7's test reads one.
- **Once merged.** The owner's first `/pap:pm sync` prints a `launch:`
  line, and that launch is not refused. At day 30 the owner writes
  `changes/pm-sync/findings.md` from the spec's four first checks.
