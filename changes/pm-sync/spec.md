# Spec: pm-sync

```text
id:                 pm-sync
class:              feature
intent:             changes/pm-sync/intent.md
scenarios:          features/pm-sync.feature, pm-sync-1 to pm-sync-20
accepted-by:        @blairforce1
accepted-on:        2026-11-12
generated-by:       Claude Fable 5.2 via Claude Code
skills:             pap:spec 0.19.1; spec-review 1.3.1
prompt:             /spec pm-sync
```

## Functional behaviour

`/pap:pm` gains a fifth form, `sync [<version> | latest]`. In a PM session
of an adopting repository it prepares one template sync and stops: it
writes the sync brief into the tracker, logs the restate, commits the
tracker and gives the launch line. The owner types it, or says "take pap
0.19.1" or "take the latest pap" and the PM session runs it. Either way
the owner types `/pap:pm launch sync-template-<version>` to start the
cycle. A sync leaves no launch record and starts nothing.

**The version.** A version is three numbers, as `0.19.1`. No version, or
`latest`, means the newest release of pap at that moment, by version
order. Every sync that gets as far as needing them reads pap's releases,
named version or not, and gives up on that read after 30 seconds. The
version must be a release. What happens next is decided by the recorded
version first and the pin second:

| Version against the recorded version | Version against the pin | Outcome                                             |
| ------------------------------------ | ----------------------- | --------------------------------------------------- |
| equal                                | any                     | already recorded: says so, writes nothing, no error |
| older                                | any                     | refused: older than the recorded version            |
| newer                                | older                   | refused: older than the pin                         |
| newer                                | equal                   | the brief is written; the pin is already there      |
| newer                                | newer                   | the brief is written                                |

The fourth row is the state after a pin bump has merged and before the
template is synced, the one INV-011 describes.

**The sync brief.** One template, shipped in the pap plugin, is the only
source of its text. `sync` replaces five placeholders and changes no other
character: `<version>`, `<recorded>` (the recorded version), `<layers>`
(the recorded layers, separated by a comma and a space), `<root>` (the
repository's root, an absolute path) and `<date>` (the UTC date,
`YYYY-MM-DD`, from the clock the event log uses). The template, word for
word:

```text
/change sync-template-<version> chore Record: none
Rule 20.2: exempt: template sync. Prepared by /pap:pm sync on <date>; the owner's typed launch is the ask.
Budget: 80k tokens beyond your starting context.
Mechanical: yes

Repository: <root>. Your first act there is the /change skill with the
first line of this brief.

This repository records template <recorded>, layers <layers>. Take it to
pap <version>.

Steps, in the worktree the skill makes:
1. Set the pap pin in .config/mise/conf.d/pap.toml to <version>. Commit
   only if the file changed.
2. Run: mise install && pap sync
3. Commit the sync's output exactly as the tool wrote it.
4. If a tool pin moved, run mise install again.
5. Run mise run check and mise run test on the final head.

Rules:
- If .config/pap.toml does not record <recorded> when you start, stop
  with ASK:.
- Edit nothing the sync wrote. A conflict that needs a judgement about
  what this repository wants: stop with ASK:. List every conflict you
  resolve in the pull request, with the side taken.
- A file the sync touched that the template did not change between
  <recorded> and <version> is a finding: report it.
- Never run pap repo apply, never add owner-reviewed, never merge.
- Push after every commit. One draft pull request, then stop.

Done: the /change skill's chat report; ASK: if only the owner can
decide; PAUSED: at the budget cap, with what is left.
```

A test binds the built template to this text, line for line.

The 80k budget is the owner's figure from the intent, not a measured
median; a sync across several releases that outruns it ends `PAUSED:`,
which is accepted. The owner may delete the `Mechanical: yes` line from a
written brief before launching, when conflicts are expected and the cycle
should resolve them; the checksum then shows the edit, and the measure
does not count that brief as hand-written. The root is absolute because
the cycle is told where the repository is by it; a tracker is private to
its owner, and that is assumed here.

**What is filled in is checked first.** The brief is a cycle's whole
prompt, so no value reaches it, the slug, the file name or the event log
unchecked. Each of these is refused, naming the file or the source it came
from, before anything is written:

- a version, typed or resolved from `latest`, that is not three numbers
  separated by dots, each without a leading zero (a typed version may
  start with `v`, which is dropped);
- a recorded version or a pin that is not such a version;
- a layer that is not lowercase letters, or no layer at all;
- a root that holds a control character or a line break.

A release is a tag at pap's source of exactly `v` and such a version.
Every other tag there is ignored, a pre-release included. Order is numeric
part by part, so 0.10.0 is newer than 0.9.0. A source that answers with no
release is refused as one that cannot be read.

**The doc.** The "Take a new version" section of `docs/run-a-project.md`
keeps when to sync, the "Which agent" paragraph and what follows the
merge. It loses its copy of the brief and its list of rules, and gains:
the command; the first release of pap that has it, by number; the command
that updates the plugin; that a session without `sync` updates the plugin
and writes no brief by hand; and a link to the template file. The new
refusals are added to `docs/troubleshooting.md`.

**The restate event.** Its text is `sync: take pap <version>: sync the
template from <recorded> to <version>; brief <checksum>`, where the
checksum is `cksum`'s first field over the brief as written. The prefix
and the checksum tell a sync brief from a hand-written one, and show an
edit made after `sync` wrote it. They are a convention against drift, not
a control: a PM session that set out to forge both could.

**A brief that already exists.** `sync` refuses while the slug has a
launch event with no later merge event and no later decision event
starting "abandoned": in flight, reported or paused. Otherwise it writes
the brief again and logs a new restate event; it says an earlier brief was
replaced, and the tracker's history keeps that one.

**The order of the checks.** The first that fails decides the refusal:

1. The arguments: the form, the version's shape, the session id's shape.
2. The repository: it adopts PAP; it has a pin; the pin, the recorded
   version, the layers and the root are well formed.
3. For a named version, the decision table above. "Already recorded" is
   decided here, with no network.
4. The session id is a running session's.
5. The tracker, read and not yet taken: started, not held by another
   session, clean, its event log readable, and for a named version the
   slug not in flight.
6. pap's releases are read, for at most 30 seconds. The named version is a
   release, or `latest` is resolved; for `latest`, steps 3 and 5's
   checks on the version and the slug are made now.
7. The tracker is taken, the brief written, the restate logged, the
   tracker committed and pushed.

So nothing decidable on the machine waits for the network, and the
tracker is not held during the read.

**Refusals.** Each writes nothing, leaves the tracker as it was, says why
and what to do next:

| Case                                                                                                                                 | Says                                                                                                          |
| ------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------- |
| The repository has no pin: `.config/mise/conf.d/pap.toml` is absent or pins no pap (pap itself, or a template taken from a checkout) | the file read; it pins no release of pap; `pap sync` is run there by hand                                     |
| The version is not three numbers and not `latest`                                                                                    | what a version looks like                                                                                     |
| pap has no such release                                                                                                              | the version asked for and the newest release                                                                  |
| The version is older than the recorded version or the pin                                                                            | both versions; a downgrade is done by hand                                                                    |
| The releases cannot be read within 30 seconds, or the source lists none                                                              | the source tried and git's last line; that `PAP_SOURCE` overrides the source; nothing can be prepared offline |
| The pin, the recorded version, a layer or the root is not well formed                                                                | the file and the value's fault                                                                                |
| The slug was launched and is neither merged nor abandoned                                                                            | the slug and which: in flight, reported or paused                                                             |
| The tracker is absent, uncommitted or held by another session                                                                        | as `start` and `launch` say it                                                                                |
| The event log has a line that cannot be read                                                                                         | as a launch says it                                                                                           |
| The session id is one no running session of this machine has                                                                         | that the id is not a running session's; nothing is locked or written                                          |
| git refuses the tracker's commit                                                                                                     | git's last line; the brief and the event log are put back as they were, an earlier brief included             |

A repository that already records the version is not a refusal: `sync`
says so, writes nothing and ends without error. When the ask was `latest`
it adds that this is the newest release.

**After the commit.** The tracker is pushed as `commit` pushes it: where
it has a remote, for at most 30 seconds, never failing the command. A push
that fails is said, the commit stands and `sync` still succeeds.

**The PM session.** The skill stays the owner's to type: a PM session
cannot see or invoke it until then. So the role a PM session is given when
it starts gains the spoken path: on the owner's own instruction to take a
pap version, run the script's `sync` form, give the owner the launch line,
and stop; never write a sync brief by hand; never invoke the launch. The
role gives the script's path, as it already does for `commit`. The script
takes the session id from the session's own environment when none is
passed, so the PM session never supplies one. For `sync`, an id that no
running session of this machine has is refused before the tracker's lock
is touched. The skill's body says the same for the typed form, and its argument hint
and its list of forms name the fifth.

The role and the skill also say: a question about versions is answered,
and only an instruction runs `sync`; before running it the PM session
says it is reading pap's releases; on any refusal it tells the owner and
stops, with no retry; on an uncommitted tracker it names `/pap:pm start`,
whose commit-or-discard question is the owner's; and a launch that
refuses a sync brief is reported to the owner, never fixed by hand. A
sync brief that is never launched costs nothing and needs no clearing.

Scenarios added, in `features/pm-sync.feature`:

- `pm-sync-1` sync with a version writes the sync brief: the main path.
- `pm-sync-2` sync with no version takes the newest release: "latest", and that the brief never says it.
- `pm-sync-3` the sync brief is the plugin's template, filled: the one source, and the lines a launch checks.
- `pm-sync-4` the same ask on the same day writes the same brief: the text does not drift, and a brief may be rewritten.
- `pm-sync-5` sync starts no cycle and changes nothing in the repository: the first non-goal, and INV-011.
- `pm-sync-6` the PM session runs sync on the owner's word: the spoken ask.
- `pm-sync-7` the owner launches the sync brief: the launch's checks are unchanged and it picks the mechanical cycle.
- `pm-sync-8` the PM session cannot launch the sync brief itself: the launch stays the owner's.
- `pm-sync-9` the repository already records the version: says so, writes nothing.
- `pm-sync-10` a version sync cannot take is refused: older, not a release, not a version.
- `pm-sync-11` a repository with no pin is refused: pap itself.
- `pm-sync-12` the releases cannot be read: no network.
- `pm-sync-13` a sync launched and neither merged nor abandoned is refused: in flight, reported or paused.
- `pm-sync-14` a tracker sync cannot write is refused: absent, uncommitted, held, or with an unreadable event log.
- `pm-sync-15` a sub-agent runs sync: the guard's existing refusal covers the new form.

- `pm-sync-16` the pin is ahead of the recorded version: the brief is written (INV-011's state).
- `pm-sync-17` git refuses the tracker's commit: the tracker is put back.
- `pm-sync-18` a session id no running session has: refused, nothing locked.
- `pm-sync-19` a version typed with a leading v: taken as the version.
- `pm-sync-20` a value that is not well formed is refused: nothing unchecked reaches the brief.

`pm-sync-6` is bound by a structure test to the wording of the role a PM
session is given, the text it reads at every start, and to the skill's; no
session is run, and that is an accepted gap the "Hand-written syncs"
signal watches. `pm-sync-8`
and `pm-sync-15` are bound to tests that exist, extended to name the new
form. The rest are bound to tests that run the script against a throwaway
repository and tracker, with pap's releases read from a local source.

Terms added to `product/domain.md`: Pin, Template sync, Sync brief; the
event "/pap:pm sync is run"; two rules.

## Non-functional

| What is measured                                                                                                                                   | Threshold                              | Test tier   |
| -------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------- | ----------- |
| Time for `sync` to give up on the read of pap's releases. The push after the commit keeps its own 30 seconds, so a whole `sync` is bounded near 60 | 30 seconds at most                     | integration |
| Files changed in the adopting repository by any `sync`                                                                                             | 0                                      | integration |
| Files changed in the tracker by a refused `sync`, a refused commit included                                                                        | 0                                      | integration |
| Bytes that differ between two sync briefs for one repository, version and UTC day                                                                  | 0                                      | integration |
| Shell the script needs                                                                                                                             | POSIX `sh`; shellcheck clean (INV-003) | unit        |

## Interfaces and contracts

- **Added:** the script form `sync [<version> | latest] --session <id>`,
  run as the other forms are, and the skill form `/pap:pm sync`. Each
  refusal that is new has an exit code of its own, none of them a code
  `start` or `launch` uses for another meaning; a refusal the script
  already has keeps its code (2, 15, 16, 17, 18, 19, and 4 for an
  uncommitted tracker). "Already recorded" exits 0. The plan picks the new numbers.
- **Output on success:** labelled lines the skill reads, after any line
  the script already prints: `version:`, `from:` (the recorded version),
  `brief:` (its path), `replaced:` (yes or no) and `launch:` (the line to
  type).
- **Consumed:** pap's releases, read from the same source `pap sync
  --version` fetches from: by default pap's repository on github.com,
  which learns the caller's address and nothing else; `PAP_SOURCE`
  overrides it, for a mirror. `.config/pap.toml`
  and `.config/mise/conf.d/pap.toml`, read only.
- **Must not break:** `start`, `launch`, `commit` and `discard`, their exit
  codes and their output. The launch's checks are not changed: a sync
  brief passes them as written. The event log's format and its ten events.
- **The console.** pm-console's class band does not know the new form. It
  is not changed here; typing `/pap:pm sync` shows no band. A known gap,
  left for a console follow-up.
- **Known gap.** `/pap:pm start` does not list a sync brief that was
  prepared and never launched. Left for the rest of H-012.
- **Tests.** Each bound test asserts the exit code and, where this spec
  gives a full line, the full line. The 30-second limit is tested with a
  source that never answers and the limit shortened for the test.

## Security

`sync` reads a version from the owner's message and puts it into a file
name, a slug and a brief a cycle will follow. So do four values it reads from the repository and from pap's source. Each
has a shape, checked before anything is written ("What is filled in is
checked first"), and a value that fails is refused, so no unchecked text
reaches the brief, the slug, the path or the event log. By default it contacts one host, pap's source, and sends nothing but the
request for its tags. The read never prompts and offers no stored
credential. The brief gives the cycle no tool, path or permission a
hand-written sync brief does not.

## Operations

**Signals.**

| Signal                | Measures                                                                                                                               | Read from                                                        |
| --------------------- | -------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| Hand-written syncs    | The intent's first measure: launches of a `sync-template-*` slug whose last restate event before the launch does not start `sync: `    | the tracker's event log                                          |
| Messages to a sync    | The intent's second measure: `message` events for a `sync-template-*` slug after its first `report` event, with their text             | the tracker's event log                                          |
| Costly syncs          | Health: `sync-template-*` slugs with a `pause` event, or with more than one `launch` event                                             | the tracker's event log                                          |
| Refused sync launches | Health: any launch of a `sync-template-*` slug that was refused. The log line does not carry the cause; the refusal the owner saw does | `launches.log`, lines marked `used` for a `sync-template-*` slug |

**Good.** Over an operation window of 30 days from the release that
carries this change, across the first five template syncs launched in
adopting repositories (or all of them, if fewer): hand-written syncs 0;
messages to a sync 0 whose text is about anything but a merge conflict;
costly syncs 0;
refused sync launches 0 whose cause was the brief (its restate, route,
rule 20.2 line or budget).

**Wrong.** A PM session writes a sync brief by hand, a sync cycle needs a
message that is not about a conflict, or a launch refuses a brief `sync`
wrote. Noticed by the owner: at once when a launch is refused, and otherwise at
day 30, when the owner reads the four signals with the first checks below
and writes the result to `changes/pm-sync/findings.md`. Message text is
classified where it is; none of it is copied into the findings. First checks:

1. `grep -P '\t(restate|launch|message)\tsync-template-' events.tsv` in the tracker.
2. `cksum briefs/sync-template-<version>.md` against the checksum in its last restate event: was it edited after `sync` wrote it?
3. `grep sync-template- launches.log` under pap's state directory.
4. `claude plugin list`: is the pap plugin at the release that has `sync`?

**Undo.** Revert the merge. Outside git: none. Sync briefs already in a
tracker stay valid as ordinary briefs, and a tracker needs no repair. An
adopting repository gets the undo with the next release of the plugin;
until then its PM session writes a sync brief by hand from the template
file the doc links to. This text is the pull request's "How to
revert".

**Operational scenarios.**

```gherkin
Scenario: A sync brief is written by hand
  Given pm-sync is live
  When a sync-template launch follows a restate event that does not start "sync: ", within the 30 days
  Then the owner finds it at the day-30 reading, with the session's transcript as the first place to look
  And a second one in the window opens a bugfix on the skill's wording

Scenario: A sync cycle needs a message that is not about a conflict
  Given pm-sync is live
  When a message event follows the first report of a sync-template cycle and is not about a merge conflict
  Then the brief template is read against the message and corrected by a bugfix
  And the owner is told in the PM session that logged the message

Scenario: The launch refuses a sync brief
  Given pm-sync is live
  When a launch of a sync-template slug is refused for its restate, route, rule 20.2 line or budget
  Then the owner reads the cause from the refusal
  And a cause in the brief opens a bugfix on the template; the merge is reverted only if a second sync brief is refused for the same cause before the fix
  And the owner is told by the refusal itself
```

## Areas of concern

- **The intent's "no rule changes" against `rules.md`.** No rule's
  statement changes: rule 18.2 asks that the event log carry the restate
  and the owner's yes, and it does. But rule 18.3's "Enforced by" line
  says the PM appends every event but three by hand, and after this change
  `sync` writes a restate too. That line should say so, and `rules.md` is
  a protected path the intent did not list. See Intent churn.
- **The PM runs `sync` without the owner typing it.** The skill is the
  owner's to invoke and keeps `disable-model-invocation`; a PM session
  runs the script form only, as it already runs `commit`, and learns it
  from the role. That is safe only because `sync` starts nothing: the yes of
  rule 18.2 is still the typed launch. A reviewer should check nothing
  here lets a spoken ask become a launch.
- **Who asked.** The brief's second line says only that `sync` prepared
  it; the owner's ask is the typed launch. A PM session that ran `sync`
  unasked leaves a brief and a restate event, and nothing else.
- **One host.** `sync` depends on pap's source being reachable, where the
  hand-written brief did not. Refusing when it is not is the price of
  never writing a brief for a version that does not exist.
- **The doc and the template.** The doc loses its copy of the brief. A
  PM session on a plugin older than this change reads a doc that names a
  command it does not have.

## Open questions

- How "latest" is looked up, and what happens with no network: answered,
  from pap's releases at the source `pap sync --version` uses, newest by
  version order; with no answer in 30 seconds `sync` refuses and writes
  nothing, for a named version too.
- Whether a restate logged by the script fits the rules on restating:
  answered, it does. Rule 18.2 asks what the event log carries, not whose
  hand wrote it. No decision record is needed. Rule 18.3's "Enforced by"
  line is brought up to date.
- What `sync` does when a brief for that version exists, or the version is
  older than the one recorded: answered, it refuses a slug in flight and
  otherwise writes the brief again with a new restate event; it refuses an
  older version, and a downgrade is done by hand.
- How a PM session that has not had `/pap:pm` typed knows the form and its
  session id: answered, the role names the form and the script's path, and
  the script reads the session id from the session's environment. Which
  variable carries it is the plan's.

## Intent churn

The intent lists `tests/**` and `product/domain.md` as the protected paths
touched. Drafting showed `rules.md` is touched too, for the "Enforced by"
line of rule 18.3 and no rule's statement. The spec
review showed a PM session cannot see the skill, so the spoken ask needs a
line in the role, which is written by a hook under `plugins/pap/hooks/**`,
a protected path too. The owner chose that over dropping the spoken ask
(spec review, QA-002). The intent's `invariants-touched` gains `rules.md`
and `plugins/pap/hooks/**`, and its constraint reads "No rule's statement
and no decision record changes." The churn is the owner's to accept with
this spec. Churn commit: `intent(pm-sync): churn, the role and rules.md's
enforced-by line name sync`.
