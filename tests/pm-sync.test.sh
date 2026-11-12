#!/bin/sh
# pm-sync.test.sh: the scenarios of features/pm-sync.feature, bound by ID,
# for the sync form of /pap:pm's script (changes/pm-sync/spec.md). The
# guard's half is elsewhere: pm-sync-15, and a second case of pm-sync-8, are
# in tests/pm-mode.test.sh, beside the guard and launch cases they extend.
#
# Usage: sh tests/pm-sync.test.sh
#
# Never touches the network, the real home or pap's real state directory:
# HOME, XDG_STATE_HOME and XDG_CONFIG_HOME are under a temporary directory,
# and pap's releases are read from a local repository, as PAP_SOURCE. The
# script runs from a copy of plugins/pap, as an installed plugin's does.
#
# Each case takes a world of its own (world): an adopting repository built
# by scripts/assemble.sh from the base layer, with a pin and a recorded
# version, origin https://github.com/olive/trial.git; a state directory;
# and a tracker started, clean and held by session S1, which is noted as
# running with this suite's own process id.
#
# Prints one TAP-style line per case and exits 1 if any case fails. Needs
# git and cksum; jq for the cases that run a hook, skipped without it.
#
# SC2319: each case passes the exit status of its condition on purpose.
# SC2016: the skill's own text is matched as written.
# shellcheck disable=SC2319,SC2016

set -u
# shellcheck disable=SC1091 # tests/clean-env.sh, sourced from this directory
. "$(dirname "$0")/clean-env.sh"
unset CLAUDE_CODE_SESSION_ID PAP_SOURCE PAP_PM_READ_LIMIT 2>/dev/null || true

here="$(cd "$(dirname "$0")/.." && pwd)"
command -v git >/dev/null 2>&1 || { printf 'Bail out! git not found\n'; exit 1; }

# pwd -P: macOS's temporary directory is under a symlink.
T="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$T"' EXIT INT TERM
mkdir -p "$T/home" "$T/xdg/pap"
export HOME="$T/home" XDG_CONFIG_HOME="$T/xdg" GIT_CONFIG_GLOBAL="$T/gitconfig" \
  GIT_CONFIG_NOSYSTEM=1 GIT_CEILING_DIRECTORIES="$T"
printf '[init]\n\tdefaultBranch = main\n[user]\n\tname = test\n\temail = test@example.invalid\n[commit]\n\tgpgsign = false\n' > "$GIT_CONFIG_GLOBAL"

n=0
failed=0
result() { # result <ok 0|1> <label> [detail]
  n=$((n + 1))
  if [ "$1" = 0 ]; then
    printf 'ok %d - %s\n' "$n" "$2"
  else
    printf 'not ok %d - %s\n' "$n" "$2"
    [ -n "${3:-}" ] && printf '%s\n' "$3" | sed 's/^/# /'
    failed=$((failed + 1))
  fi
}

cp -R "$here/plugins/pap" "$T/plugin"
script="$T/plugin/skills/pm/pap-pm.sh"
tab="$(printf '\t')"

# --- pap's releases --------------------------------------------------------------

# source_with <dir> <tag>...: a repository whose tags are the ones named.
source_with() {
  s_d="$1"
  shift
  git init -q "$s_d"
  git -C "$s_d" commit -q --allow-empty -m release
  for s_t in "$@"; do git -C "$s_d" tag "$s_t"; done
}
source_with "$T/source" v0.19.0 v0.19.1 v0.20.0
# from <source>: where what follows reads pap's releases.
from() { PAP_SOURCE="$1"; export PAP_SOURCE; }
from "$T/source"

# --- The world -------------------------------------------------------------------

S1=0f6b2c1e-1a2b-4c3d-8e4f-5a6b7c8d9e01
S2=7d2e9a40-0b1c-4d2e-9f3a-4b5c6d7e8f02
S3=3c9d8e7f-6a5b-4c4d-8e3f-2a1b0c9d8e03
k=0
record() { printf '# Written by pap init.\nversion = "%s"\nlayers = [%s]\n' "$1" "${2:-\"base\", \"risk\"}" > "$A/.config/pap.toml"; }
pin() {
  mkdir -p "$A/.config/mise/conf.d"
  printf '[tools]\n"github:blairforce1/pap" = { version = "%s", asset_pattern = "pap-*.tar.gz" }\n' "$1" \
    > "$A/.config/mise/conf.d/pap.toml"
}
at() { PAP_PM_NOW="2026-11-12T$1Z"; export PAP_PM_NOW; }
# pm <argument>...: /pap:pm's script, as the skill runs it in the
# repository. Sets out (stdout and stderr) and rc. sync adds S1's id.
pm() {
  out="$(cd "$A" && sh "$script" "$@" 2>&1)"
  rc=$?
}
sync() { pm sync "$@" --session "$S1"; }
# world [pin or -] [recorded]: see the header. $name is the repository's
# directory name and $origin its origin; $started=no leaves the tracker
# absent. repo0 is the repository as git sees it, ignored files included.
name=repo origin=https://github.com/olive/trial.git started=yes
world() {
  k=$((k + 1))
  A="$T/w$k/$name"
  XDG_STATE_HOME="$T/w$k/state"
  export XDG_STATE_HOME
  pmd="$XDG_STATE_HOME/pap/pm"
  key="${origin#https://github.com/}"
  key="${key%.git}"
  trk="$pmd/trackers/$key"
  lockf="$pmd/locks/$(printf '%s' "$key" | tr '/' '%')"
  mkdir -p "$T/w$k"
  sh "$here/scripts/assemble.sh" base "$A" >/dev/null || { printf 'Bail out! assemble failed\n'; exit 1; }
  record "${2:-0.19.0}"
  [ "${1:-0.19.0}" = - ] || pin "${1:-0.19.0}"
  git init -q "$A"
  git -C "$A" add -A
  git -C "$A" commit -q -m init
  git -C "$A" remote add origin "$origin"
  mkdir -p "$pmd/live"
  printf '%s\n' "$$" > "$pmd/live/$S1"
  at 10:00:00
  [ "$started" = no ] || pm start --session "$S1"
  at 10:05:00
  repo0="$(git -C "$A" status --porcelain --ignored; git -C "$A" rev-parse HEAD)"
  snap
}
# recommit: the repository's files as changed since world, committed.
recommit() {
  git -C "$A" add -A
  git -C "$A" commit -q -m changed
  repo0="$(git -C "$A" status --porcelain --ignored; git -C "$A" rev-parse HEAD)"
}
tevent() { printf '%s\t%s\t%s\t%s\n' "$PAP_PM_NOW" "$1" "$2" "$3" >> "$trk/events.tsv"; }
tcommit() { git -C "$trk" add -A && git -C "$trk" commit -q -m test && snap; }
sig() { if [ -e "$1" ]; then cksum < "$1"; else echo absent; fi; }
# snap: the tracker and its lock as they are. kept: they are that still.
tstate() {
  git -C "$trk" rev-parse HEAD 2>/dev/null
  git -C "$trk" status --porcelain --untracked-files=all 2>/dev/null
  sig "$trk/events.tsv"
  sig "$lockf"
  ls "$trk/briefs" 2>/dev/null
  ls "$pmd/live"
}
snap() { t0="$(tstate)"; }
kept() { [ "$(tstate)" = "$t0" ]; }
has() { printf '%s\n' "$out" | grep -qF -- "$1"; }
# refused <code> <text>...: the exit code, each text in what it said, and
# the tracker, its lock and the sessions noted as running as they were.
refused() {
  r_c="$1"
  shift
  [ "$rc" = "$r_c" ] || return 1
  for r_t in "$@"; do has "$r_t" || return 1; done
  kept
}
unchanged() { [ "$(git -C "$A" status --porcelain --ignored; git -C "$A" rev-parse HEAD)" = "$repo0" ]; }
slug=sync-template-0.19.1
brief() { printf '%s\n' "$trk/briefs/sync-template-$1.md"; }

# --- A repository that already records the version --------------------------------

world
from "$T/nowhere"
sync 0.19.0
from "$T/source"
[ "$rc" = 0 ] && has "pap-pm: this repository already records pap 0.19.0 (.config/pap.toml); nothing to prepare, and nothing is written" &&
  ! has "newest" && kept && unchanged
result $? "pm-sync-9: sync for the recorded version says the repository already records it, exits 0 and leaves the tracker unchanged, with a source of releases that does not exist" "exit $rc; $out"

# --- A version sync cannot take: the rows that read no release -----------------------

world
sync 0.18.2
refused 24 "pap 0.18.2 is older than the recorded version, 0.19.0" "a downgrade is done by hand"
result $? "pm-sync-10: 0.18.2 is refused with 24, naming that it is older than the recorded version, and the tracker is unchanged" "exit $rc; $out"
sync newest
refused 22 && [ "$(printf '%s\n' "$out" | sed -n 1p)" = "pap-pm: a version is three numbers, as 0.19.1, or latest" ]
result $? "pm-sync-10: newest is refused with 22, saying a version is three numbers, as 0.19.1, or latest, and the tracker is unchanged" "exit $rc; $out"
x=""
for v in 0.19 0.19.1.2 01.19.1 0.019.1 0.19.x 0.19.1-rc.1 v 0..1 .19.1 0.19. vlatest V0.19.1 "0.19.1 0.20.0"; do
  pm sync "$v" --session "$S1"
  refused 22 "a version is three numbers" || x="$x [$v: exit $rc]"
done
[ -z "$x" ]
result $? "pm-sync-10: a version that is not three numbers without a leading zero is refused with 22, whatever else it is" "$x"
(cd "$A" && sh "$script" sync 0.19.1 0.20.0 --session "$S1" >/dev/null 2>&1)
[ $? = 2 ] && kept
result $? "pm-sync-10: two versions are a misuse, exit 2" ""

# --- A repository with no pin ---------------------------------------------------------

origin=https://github.com/blairforce1/pap.git
world - 0.10.0
origin=https://github.com/olive/trial.git
sync 0.19.1
refused 21 ".config/mise/conf.d/pap.toml pins no release of pap" "pap sync is run by hand"
result $? "pm-sync-11: pap itself, which has no pin file, is refused with 21: it pins no release of pap and pap sync is run there by hand" "exit $rc; $out"
world - 0.19.0
printf 'version = "unreleased"\ncommit = "0123456789abcdef0123456789abcdef01234567"\nlayers = ["base"]\n' > "$A/.config/pap.toml"
recommit
sync 0.19.1
refused 21 ".config/mise/conf.d/pap.toml pins no release of pap" "pap sync is run by hand" && unchanged
result $? "pm-sync-11: a repository whose template came from a checkout of pap is refused with 21 the same way" "exit $rc; $out"
world - 0.19.0
mkdir -p "$A/.config/mise/conf.d"
printf '[tools]\njq = "1.8.2"\n' > "$A/.config/mise/conf.d/pap.toml"
recommit
sync 0.19.1
refused 21 "pins no release of pap"
result $? "pm-sync-11: a pin file that pins other tools and no pap is refused with 21" "exit $rc; $out"

# --- A slug launched and neither merged nor abandoned ----------------------------------

for st in "in flight" reported paused; do
  world
  tevent restate "$slug" "sync: take pap 0.19.1: sync the template from 0.19.0 to 0.19.1; brief 1"
  tevent launch "$slug" "/change $slug chore Record: none; Rule 20.2: exempt: template sync; pap:cycle-mechanical"
  [ "$st" != reported ] || tevent report "$slug" "draft pull request open"
  [ "$st" != paused ] || tevent pause "$slug" "after the pin"
  tcommit
  sync 0.19.1
  refused 15 "\"$slug\" is $st: launched, and neither merged nor abandoned"
  result $? "pm-sync-13: a sync whose cycle is $st is refused with 15, saying $slug is $st, and the tracker is unchanged" "exit $rc; $out"
done

# --- A tracker sync cannot write --------------------------------------------------------

started=no
world
started=yes
sync 0.19.1
refused 19 "the tracker is not started; the owner types /pap:pm start" && [ ! -e "$trk" ]
result $? "pm-sync-14: an absent tracker is refused with 19, saying the owner types /pap:pm start, and none is started" "exit $rc; $out"
world
tevent decision - "a line appended and not committed"
snap
sync 0.19.1
refused 4 "has uncommitted changes" "/pap:pm start" "commits or discards it first"
result $? "pm-sync-14: an uncommitted tracker is refused with 4, saying the owner commits or discards it first, and it is unchanged" "exit $rc; $out"
world
printf '%s\n' "$$" > "$pmd/live/$S2"
printf '%s\n' "$S2" > "$lockf"
snap
sync 0.19.1
refused 17 "session $S2 holds the tracker"
result $? "pm-sync-14: a tracker held by another running session is refused with 17, naming the session, and the lock stays that session's" "exit $rc; $out"
world
printf 'not an event line\n' >> "$trk/events.tsv"
tcommit
sync 0.19.1
refused 16 "line 2 of the event log" "cannot be read"
result $? "pm-sync-14: an event log line that cannot be read is refused with 16, naming the line, and the tracker is unchanged" "exit $rc; $out"

# --- The session id -----------------------------------------------------------------------

world
pm sync 0.19.1 --session "$S3"
refused 27 "the session id $S3 is not a running session's on this machine; nothing is locked or written" &&
  [ ! -e "$pmd/live/$S3" ] && [ "$(cat "$lockf")" = "$S1" ]
result $? "pm-sync-18: a session id no running session has is refused with 27; no session is noted as running, and the lock is held by whoever held it" "exit $rc; $out"
# 4194304 is above the largest process id Linux and macOS give.
printf '4194304\n' > "$pmd/live/$S3"
snap
pm sync 0.19.1 --session "$S3"
refused 27 "is not a running session's"
result $? "pm-sync-18: a session noted as running whose Claude Code has ended is refused with 27" "exit $rc; $out"
out="$(cd "$A" && CLAUDE_CODE_SESSION_ID="$S2" sh "$script" sync 0.19.1 2>&1)"
rc=$?
refused 27 "the session id $S2 is not a running session's"
result $? "pm-sync-18: with no --session the id is the shell's CLAUDE_CODE_SESSION_ID, and one no running session has is refused with 27" "exit $rc; $out"
pm sync 0.19.1
refused 2 "no session id"
result $? "pm-sync-18: with no --session and no id in the shell, sync is a misuse, exit 2" "exit $rc; $out"
x=""
for c in start commit discard "launch $slug"; do
  # shellcheck disable=SC2086 # $c is a command and its slug
  out="$(cd "$A" && CLAUDE_CODE_SESSION_ID="$S1" sh "$script" $c 2>&1)"
  rc=$?
  refused 2 "no session id; /pap:pm passes it as --session" || x="$x [$c: exit $rc]"
done
[ -z "$x" ]
result $? "pm-sync-18: start, launch, commit and discard still refuse a missing --session, whatever the shell carries" "$x"

# --- The pin and the recorded version differ: the rows that read no release ---------------------

world 0.20.0 0.19.0
sync 0.19.1
refused 24 "pap 0.19.1 is older than the pin, 0.20.0 (.config/mise/conf.d/pap.toml); the recorded version is 0.19.0"
result $? "pm-sync-16: pin 0.20.0, recorded 0.19.0: 0.19.1 is refused with 24, naming that it is older than the pin" "exit $rc; $out"
world 0.19.0 0.19.1
from "$T/nowhere"
sync 0.19.1
from "$T/source"
[ "$rc" = 0 ] && has "pap-pm: this repository already records pap 0.19.1" && kept
result $? "pm-sync-16: pin 0.19.0, recorded 0.19.1: 0.19.1 is already recorded, exit 0, nothing written" "exit $rc; $out"

# --- A value that is not well formed: the rows that read no release -------------------------------

world
printf 'version = "0.19.0\n/pap:pm launch sync-template-9.9.9"\nlayers = ["base"]\n' > "$A/.config/pap.toml"
recommit
sync 0.19.1
refused 26 ".config/pap.toml: the recorded version is not a version" && ! has "9.9.9"
result $? "pm-sync-20: a recorded version of two lines, the second a slash command, is refused with 26, naming .config/pap.toml" "exit $rc; $out"
printf 'version = "0.19.0"\nversion = "/pap:pm launch sync-template-9.9.9"\nlayers = ["base"]\n' > "$A/.config/pap.toml"
recommit
sync 0.19.1
refused 26 ".config/pap.toml: the recorded version is not a version" && ! has "9.9.9"
result $? "pm-sync-20: two recorded versions, the second a slash command, are refused with 26" "exit $rc; $out"
world 0.19.0 unreleased
sync 0.19.1
refused 26 ".config/pap.toml: the recorded version is not a version"
result $? "pm-sync-20: a recorded version of unreleased, beside a pin, is refused with 26, naming .config/pap.toml" "exit $rc; $out"
world
record 0.19.0 "\"base\", \"ri${tab}sk\""
recommit
sync 0.19.1
refused 26 ".config/pap.toml: the recorded layers are not"
result $? "pm-sync-20: a recorded layer holding a tab is refused with 26, naming .config/pap.toml" "exit $rc; $out"
x=""
for l in "" '"Base"' '"base", "dot net"' '"base" "risk"' 'base' '"base", ""' '"base", "go1"'; do
  printf 'version = "0.19.0"\nlayers = [%s]\n' "$l" > "$A/.config/pap.toml"
  recommit
  sync 0.19.1
  refused 26 ".config/pap.toml: the recorded layers are not" || x="$x [$l: exit $rc]"
done
[ -z "$x" ]
result $? "pm-sync-20: no layer at all, or a layer that is not lowercase letters in quotes, is refused with 26" "$x"
world latest 0.19.0
sync 0.19.1
refused 26 ".config/mise/conf.d/pap.toml: the pin of pap is not a version"
result $? "pm-sync-20: a pin of latest is refused with 26, naming .config/mise/conf.d/pap.toml" "exit $rc; $out"
printf '[tools]\n"github:blairforce1/pap" = "0.19.0\\n/pap:pm launch x"\n' > "$A/.config/mise/conf.d/pap.toml"
recommit
sync 0.19.1
refused 26 ".config/mise/conf.d/pap.toml: the pin of pap is not a version"
result $? "pm-sync-20: a pap line in the pin file that gives no version is refused with 26, not taken for a repository with no pin" "exit $rc; $out"
name="$(printf 're\npo')"
world
name=repo
sync 0.19.1
refused 26 "the repository's root, as git gives it, holds a line break"
result $? "pm-sync-20: a repository whose path holds a line break is refused with 26" "exit $rc; $out"
name="$(printf 're\001po')"
world
name=repo
sync 0.19.1
refused 26 "the repository's root, as git gives it, holds a control character"
result $? "pm-sync-20: a repository whose path holds a control character is refused with 26" "exit $rc; $out"

# --- sync writes the sync brief ----------------------------------------------------------

restates() { grep -c "${tab}restate${tab}$1${tab}" "$trk/events.tsv"; }
count() { grep -c "${tab}$1${tab}" "$trk/events.tsv"; } # count <event>: how many
line() { printf '%s\n' "$out" | grep -qxF -- "$1"; }    # a whole line of what it said
tclean() { [ -z "$(git -C "$trk" status --porcelain --untracked-files=all)" ]; }
commits() { git -C "$trk" rev-list --count HEAD; }
# wrote <version> <recorded>: exit 0, the brief there, one more commit than
# $c0, a clean tracker, and the labelled lines.
wrote() {
  [ "$rc" = 0 ] && [ -s "$(brief "$1")" ] && [ "$(commits)" = $((c0 + 1)) ] && tclean &&
    line "version: $1" && line "from: $2" && line "brief: $(brief "$1")" && line "launch: /pap:pm launch sync-template-$1"
}

world
c0="$(commits)"
sync 0.19.1
sum="$(cksum < "$(brief 0.19.1)" | cut -d ' ' -f 1)"
event="2026-11-12T10:05:00Z${tab}restate${tab}$slug${tab}sync: take pap 0.19.1: sync the template from 0.19.0 to 0.19.1; brief $sum"
wrote 0.19.1 0.19.0 && line "replaced: no" && [ "$(restates "$slug")" = 1 ] && [ -n "$sum" ] &&
  [ "$(tail -n 1 "$trk/events.tsv")" = "$event" ] &&
  [ "$(git -C "$trk" show --name-only --format= HEAD | sort | tr '\n' ' ')" = "briefs/$slug.md events.tsv " ]
result $? "pm-sync-1: sync 0.19.1 writes the brief of sync-template-0.19.1, logs one restate event whose text ends in the brief's checksum, commits the tracker and gives the launch line" "exit $rc; $out; $(tail -n 1 "$trk/events.tsv")"
[ "$(count yes)" = 0 ] && [ "$(count launch)" = 0 ] && [ ! -e "$pmd/launches.log" ] && unchanged &&
  [ "$(git -C "$A" show HEAD:.config/pap.toml | cksum)" = "$(cksum < "$A/.config/pap.toml")" ] &&
  [ "$(git -C "$A" show HEAD:.config/mise/conf.d/pap.toml | cksum)" = "$(cksum < "$A/.config/mise/conf.d/pap.toml")" ]
result $? "pm-sync-5: sync logs no yes event and no launch event, leaves no launch record, and changes no file of the repository: the pin and the recorded version are as they were" "$(git -C "$A" status --porcelain --ignored)"

world
c0="$(commits)"
out="$(cd "$A" && CLAUDE_CODE_SESSION_ID="$S1" sh "$script" sync 0.19.1 2>&1)"
rc=$?
wrote 0.19.1 0.19.0
result $? "pm-sync-1: with no --session, sync takes the session id from the shell's CLAUDE_CODE_SESSION_ID" "exit $rc; $out"

for what in "" latest; do
  world
  c0="$(commits)"
  # shellcheck disable=SC2086 # no version is no argument
  sync $what
  wrote 0.20.0 0.19.0 && grep -q '^pap 0\.20\.0\.$' "$(brief 0.20.0)" && ! grep -qi latest "$(brief 0.20.0)" &&
    ! grep -qi latest "$trk/events.tsv" && [ "$(ls "$trk/briefs")" = sync-template-0.20.0.md ]
  result $? "pm-sync-2: sync for ${what:-no version} writes the brief of sync-template-0.20.0, which names 0.20.0 and nowhere the word latest" "exit $rc; $out"
done
source_with "$T/source-order" v0.9.0 v0.10.0 v0.2.11
world 0.9.0 0.9.0
c0="$(commits)"
from "$T/source-order"
sync latest
from "$T/source"
wrote 0.10.0 0.9.0
result $? "pm-sync-2: the newest release is by version order, part by part as numbers: 0.10.0 is newer than 0.9.0" "exit $rc; $out"
world 0.20.0 0.20.0
sync latest
[ "$rc" = 0 ] && has "pap-pm: this repository already records pap 0.20.0" && line "pap-pm: 0.20.0 is the newest release of pap" && kept
result $? "pm-sync-9: latest in a repository that records the newest release says so, adds that it is the newest, and writes nothing" "exit $rc; $out"
world
tevent launch sync-template-0.20.0 "/change sync-template-0.20.0 chore Record: none; Rule 20.2: exempt: template sync; pap:cycle-mechanical"
tcommit
sync latest
refused 15 "\"sync-template-0.20.0\" is in flight"
result $? "pm-sync-13: latest is refused with 15 when the newest release's sync is in flight, once the release is known" "exit $rc; $out"

# --- The brief is the template, filled --------------------------------------------------------

name='re&po\1 <version>'
world
name=repo
c0="$(commits)"
sync 0.19.1
cat > "$T/expected" <<EOF
/change sync-template-0.19.1 chore Record: none
Rule 20.2: exempt: template sync. Prepared by /pap:pm sync on 2026-11-12; the owner's typed launch is the ask.
Budget: 80k tokens beyond your starting context.
Mechanical: yes

Repository: $A. Your first act there is the /change skill with the
first line of this brief.

This repository records template 0.19.0, layers base, risk. Take it to
pap 0.19.1.

Steps, in the worktree the skill makes:
1. Set the pap pin in .config/mise/conf.d/pap.toml to 0.19.1. Commit
   only if the file changed.
2. Run: mise install && pap sync
3. Commit the sync's output exactly as the tool wrote it.
4. If a tool pin moved, run mise install again.
5. Run mise run check and mise run test on the final head.

Rules:
- If .config/pap.toml does not record 0.19.0 when you start, stop
  with ASK:.
- Edit nothing the sync wrote. A conflict that needs a judgement about
  what this repository wants: stop with ASK:. List every conflict you
  resolve in the pull request, with the side taken.
- A file the sync touched that the template did not change between
  0.19.0 and 0.19.1 is a finding: report it.
- Never run pap repo apply, never add owner-reviewed, never merge.
- Push after every commit. One draft pull request, then stop.

Done: the /change skill's chat report; ASK: if only the owner can
decide; PAUSED: at the budget cap, with what is left.
EOF
wrote 0.19.1 0.19.0 && cmp -s "$T/expected" "$(brief 0.19.1)" && grep -qF 'Repository: '"$T/w$k"'/re&po\1 <version>. Your' "$(brief 0.19.1)"
result $? "pm-sync-3: the sync brief is the template with the version, the recorded version, the layers, the date and the root filled in, byte for byte, an & and a \\ in the root kept" "$(diff "$T/expected" "$(brief 0.19.1)" 2>&1)"
# The spec's block, between the fence after "word for word:" and its end.
awk '/^word:$/ { near = 1 } near && /^```text$/ { on = 1; near = 0; next } on && /^```$/ { exit } on' \
  "$here/changes/pm-sync/spec.md" > "$T/spec-block"
[ "$(wc -l < "$T/spec-block" | tr -d ' ')" = 32 ] && cmp -s "$T/spec-block" "$here/plugins/pap/skills/pm/sync-brief.txt"
result $? "pm-sync-3: the template the plugin ships is the spec's text, line for line" "$(diff "$T/spec-block" "$here/plugins/pap/skills/pm/sync-brief.txt" 2>&1 | head -n 10)"
# A control: a template one character off writes a brief the comparison fails.
cp -R "$T/plugin" "$T/plugin-off"
sed 's/^- Never run pap repo apply/- never run pap repo apply/' "$T/plugin/skills/pm/sync-brief.txt" > "$T/plugin-off/skills/pm/sync-brief.txt"
script_was="$script"
script="$T/plugin-off/skills/pm/pap-pm.sh"
sync 0.19.1
script="$script_was"
[ "$rc" = 0 ] && ! cmp -s "$T/expected" "$(brief 0.19.1)" && [ "$(diff "$T/expected" "$(brief 0.19.1)" | grep -c '^[<>]')" = 2 ]
result $? "pm-sync-3: a template one character off writes a brief that the comparison tells apart" "exit $rc; $out"

# --- The same ask on the same day ---------------------------------------------------------------

world
sync 0.19.1
tevent launch "$slug" "/change $slug chore Record: none; Rule 20.2: exempt: template sync; pap:cycle-mechanical"
tevent decision "$slug" "abandoned: did not start"
tcommit
cp "$(brief 0.19.1)" "$T/brief-first"
first="$(grep "${tab}restate${tab}" "$trk/events.tsv" | cut -f 4)"
c0="$(commits)"
at 23:59:59
sync 0.19.1
wrote 0.19.1 0.19.0 && cmp -s "$T/brief-first" "$(brief 0.19.1)" && [ "$(restates "$slug")" = 2 ] &&
  [ "$(tail -n 1 "$trk/events.tsv" | cut -f 4)" = "$first" ] && line "replaced: yes" &&
  line "pap-pm: an earlier brief for $slug was replaced; the tracker's history keeps it"
result $? "pm-sync-4: the same ask on the same UTC day, after the cycle was abandoned, writes the brief byte for byte again, logs a second restate event and says an earlier brief was replaced" "exit $rc; $out"
PAP_PM_NOW=2026-11-13T00:00:00Z
sync 0.19.1
[ "$rc" = 0 ] && [ "$(diff "$T/brief-first" "$(brief 0.19.1)" | grep -c '^[<>]')" = 2 ] &&
  [ "$(sed -n 2p "$(brief 0.19.1)")" = "Rule 20.2: exempt: template sync. Prepared by /pap:pm sync on 2026-11-13; the owner's typed launch is the ask." ] &&
  [ "$(restates "$slug")" = 3 ] && [ "$(tail -n 1 "$trk/events.tsv" | cut -f 4)" != "$first" ]
result $? "pm-sync-4: on the next UTC day only the brief's second line differs, and the restate event's checksum with it" "exit $rc; $out"
PAP_PM_NOW=2026-11-13T00:01:00Z
tevent launch "$slug" "/change $slug chore Record: none; Rule 20.2: exempt: template sync; pap:cycle-mechanical"
tevent report "$slug" "draft pull request open"
tevent merge "$slug" "merged"
tcommit
c0="$(commits)"
sync 0.19.1
wrote 0.19.1 0.19.0 && line "replaced: yes"
result $? "pm-sync-13: a sync whose cycle merged is not refused" "exit $rc; $out"

# --- The owner launches the sync brief --------------------------------------------------------------

# typed: the UserPromptSubmit hook, given the owner's typed launch.
typed() {
  printf '{"session_id":"%s","transcript_path":"/x/t.jsonl","cwd":"%s","permission_mode":"default","hook_event_name":"UserPromptSubmit","prompt":"/pap:pm launch %s"}' \
    "$S1" "$A" "$1" | env PAP_MODE=pm CLAUDE_PROJECT_DIR="$A" CLAUDE_PLUGIN_ROOT="$T/plugin" "$T/plugin/hooks/pm-log.sh" prompt
}
if command -v jq >/dev/null 2>&1; then
  world
  sync 0.19.1
  snap
  pm launch "$slug" --session "$S1"
  refused 10 "the owner types the command: /pap:pm launch $slug (rule 18.2)" && [ "$(count launch)" = 0 ] && ! line "agent: pap:cycle-mechanical"
  result $? "pm-sync-8: after a sync, a launch of the sync brief that the owner did not type is refused with 10, as any launch with no launch record is" "exit $rc; $out"
  at 10:06:00
  typed "$slug"
  at 10:07:00
  pm launch "$slug" --session "$S1"
  [ "$rc" = 0 ] && line "agent: pap:cycle-mechanical" && line "brief: $(brief 0.19.1)" && [ "$(count yes)" = 1 ] && [ "$(count launch)" = 1 ] && tclean
  result $? "pm-sync-7: the owner's typed launch of the sync brief passes the launch's checks as they are, and names the mechanical cycle" "exit $rc; $out"
  at 10:08:00
  typed "$slug"
  at 10:09:00
  pm launch "$slug" --session "$S1"
  [ "$rc" = 15 ] && [ "$(tail -n 1 "$pmd/launches.log" | cut -f 4,5)" = "$slug${tab}used" ]
  result $? "pm-sync-7: a refused launch of a sync slug leaves a used line in launches.log, the signal the spec reads" "exit $rc; $(tail -n 1 "$pmd/launches.log")"
else
  n=$((n + 1))
  printf 'ok %d - pm-sync-7: the owner launches the sync brief # SKIP jq is not on PATH\n' "$n"
fi

# --- A version that is no release, and releases that cannot be read ------------------------------------

world
sync 0.19.5
refused 23 "pap has no release 0.19.5; the newest release is 0.20.0"
result $? "pm-sync-10: 0.19.5 is refused with 23, naming that pap has no such release and the newest one, and the tracker is unchanged" "exit $rc; $out"

source_with "$T/source-none"
source_with "$T/source-pre" v0.21.0-rc.1 v1.0 0.19.1 v01.2.3 release-0.19.1 v0.19.1.1
real_git="$(command -v git)"
mkdir -p "$T/slow"
printf '#!/bin/sh\ncase " $* " in *" ls-remote "*) exec sleep 60 ;; esac\nexec "%s" "$@"\n' "$real_git" > "$T/slow/git"
chmod +x "$T/slow/git"
world
for what in latest 0.19.1; do
  from "$T/nowhere"
  sync "$what"
  from "$T/source"
  refused 25 "pap's releases could not be read from $T/nowhere: " "nothing can be prepared offline" "try again" "PAP_SOURCE overrides the source"
  result $? "pm-sync-12: $what, with a source that cannot be read, is refused with 25, saying the releases could not be read and to try again, and the tracker is unchanged" "exit $rc; $out"
  from "$T/source-none"
  sync "$what"
  from "$T/source"
  refused 25 "pap's releases could not be read from $T/source-none: it lists no release of pap"
  result $? "pm-sync-12: $what, with a source that has no tag, is refused with 25" "exit $rc; $out"
  from "$T/source-pre"
  sync "$what"
  from "$T/source"
  refused 25 "it lists no release of pap"
  result $? "pm-sync-12: $what, with a source whose tags are pre-releases and other names only, is refused with 25" "exit $rc; $out"
  began="$(date +%s)"
  path_was="$PATH"
  PATH="$T/slow:$PATH" PAP_PM_READ_LIMIT=2
  export PAP_PM_READ_LIMIT
  sync "$what"
  PATH="$path_was"
  unset PAP_PM_READ_LIMIT
  took=$(($(date +%s) - began))
  refused 25 "no answer within 2 seconds" && [ "$took" -lt 5 ]
  result $? "pm-sync-12: $what, with a source that never answers and the limit set to 2 seconds, is refused with 25 inside 5 seconds" "exit $rc, $took seconds; $out"
done

# --- The pin ahead of the recorded version ----------------------------------------------------------------

for v in 0.19.1 0.20.0; do
  world 0.19.1 0.19.0
  c0="$(commits)"
  sync "$v"
  wrote "$v" 0.19.0 && unchanged
  result $? "pm-sync-16: pin 0.19.1, recorded 0.19.0: sync $v writes the brief of sync-template-$v" "exit $rc; $out"
done

# --- git refuses the tracker's commit --------------------------------------------------------------------------

# companion: the tracker of the next world is a folder in a clone of the
# owner's own, where the commit runs as the owner's does.
companion() {
  rm -rf "$T/companion.git" "$T/companion"
  git init -q --bare -b main "$T/companion.git"
  git clone -q "$T/companion.git" "$T/companion" 2>/dev/null
  mkdir "$T/companion/pm"
  printf 'tracker.olive/trial=%s\n' "$T/companion/pm" > "$XDG_CONFIG_HOME/pap/agent.conf"
}
refuse_commits() {
  mkdir -p "$hooks"
  printf '#!/bin/sh\necho "the hook refuses this commit" >&2\nexit 1\n' > "$hooks/pre-commit"
  chmod +x "$hooks/pre-commit"
}
for where in default companion; do
  [ "$where" = default ] || companion
  world
  if [ "$where" = default ]; then
    hooks="$trk/.git/hooks"
  else
    trk="$T/companion/pm" hooks="$T/companion/.git/hooks"
  fi
  refuse_commits
  snap
  sync 0.19.1
  refused 18 "the tracker could not be committed, so no sync is prepared: the hook refuses this commit" && [ ! -e "$trk/briefs" ]
  result $? "pm-sync-17: with no brief and a commit git refuses ($where tracker), sync is refused with 18, giving git's last line; no brief is left and the event log is as it was" "exit $rc; $out"
  rm "$hooks/pre-commit"
  sync 0.19.1
  cp "$(brief 0.19.1)" "$T/brief-kept"
  cp "$trk/events.tsv" "$T/events-kept"
  refuse_commits
  snap
  PAP_PM_NOW=2026-11-13T09:00:00Z
  sync 0.19.1
  refused 18 "the hook refuses this commit" && cmp -s "$T/brief-kept" "$(brief 0.19.1)" && cmp -s "$T/events-kept" "$trk/events.tsv" &&
    [ -z "$(git -C "$trk" status --porcelain --untracked-files=all -- .)" ] && [ -z "$(git -C "$trk" diff --cached --name-only)" ]
  result $? "pm-sync-17: with an earlier brief and a commit git refuses ($where tracker), sync is refused with 18; the earlier brief and the event log are byte for byte as they were, and nothing is staged" "exit $rc; $out"
  rm -f "$XDG_CONFIG_HOME/pap/agent.conf"
done

# --- A leading v, and a tag that is no release -------------------------------------------------------------------

world
c0="$(commits)"
sync v0.19.1
wrote 0.19.1 0.19.0 && [ "$(ls "$trk/briefs")" = "$slug.md" ] && ! grep -q 'v0\.19\.1' "$(brief 0.19.1)" "$trk/events.tsv"
result $? "pm-sync-19: v0.19.1 is taken as 0.19.1: the brief of sync-template-0.19.1, with no v in it" "exit $rc; $out"
source_with "$T/source-rc" v0.19.0 v0.19.1 v0.20.0 v0.21.0-rc.1
world
c0="$(commits)"
from "$T/source-rc"
sync latest
from "$T/source"
wrote 0.20.0 0.19.0
result $? "pm-sync-20: a newest tag of v0.21.0-rc.1 at pap's source is ignored, and latest takes 0.20.0" "exit $rc; $out"
snap
from "$T/source-rc"
sync 0.21.0
from "$T/source"
refused 23 "pap has no release 0.21.0; the newest release is 0.20.0"
result $? "pm-sync-20: the version of a pre-release tag is no release: 0.21.0 is refused with 23" "exit $rc; $out"

# --- The PM session runs sync on the owner's word ---------------------------------------------------------

# No session is run: the case reads the role a PM session is given at every
# start, as the session-start hook writes it, and the skill's text.
skill="$here/plugins/pap/skills/pm/SKILL.md"
if command -v jq >/dev/null 2>&1; then
  world
  ctx="$(printf '{"session_id":"%s","transcript_path":"/x/t.jsonl","cwd":"%s","hook_event_name":"SessionStart","source":"startup"}' "$S1" "$A" |
    env PAP_MODE=pm CLAUDE_PROJECT_DIR="$A" CLAUDE_PLUGIN_ROOT="$T/plugin" "$T/plugin/hooks/session-start.sh" 2>/dev/null |
    jq -r '.hookSpecificOutput.additionalContext // empty')"
  role="$(printf '%s\n' "$ctx" | awk '$0 == "[pap-pm:launch]" { on = 1; next } /^\[pap-pm:[a-z-]*\]$/ { on = 0 } on')"
  in_role() { printf '%s\n' "$role" | grep -qF -- "$1"; }
  x=""
  for t in "run sh \"$T/plugin/skills/pm/pap-pm.sh\" sync <version>, or sync latest" \
    "A question about versions is answered." "Only on the owner's own instruction to take one" \
    "say you are reading pap's releases" "give the owner the launch line it prints, and stop" \
    "Never write a sync brief by hand" "never invoke the launch" \
    "If it refuses, tell the owner what it said and stop: no retry" "on an uncommitted tracker, name /pap:pm start" \
    "A launch that refuses a sync brief is reported to the owner, never fixed by hand"; do
    in_role "$t" || x="$x [$t]"
  done
  [ -n "$role" ] && [ -z "$x" ] && [ "$(printf '%s\n' "$ctx" | grep -c '^\[pap-pm:[a-z-]*\]$')" = 8 ]
  result $? "pm-sync-6: the role a PM session is given names the script's sync form by its path, for the owner's own instruction only, with the launch line given and nothing launched, no brief by hand and no retry; it gains no part" "missing:$x"
  # The command the role gives runs as given, with no session id passed.
  c0="$(commits)"
  out="$(cd "$A" && CLAUDE_CODE_SESSION_ID="$S1" sh -c "$(printf '%s\n' "$role" | sed -n 's/.*run \(sh "[^"]*" sync\) <version>.*/\1/p') 0.19.1" 2>&1)"
  rc=$?
  wrote 0.19.1 0.19.0
  result $? "pm-sync-6: the command the role gives, run in the session's shell with no --session, prepares the sync" "exit $rc; $out"
else
  n=$((n + 1))
  printf 'ok %d - pm-sync-6: the role a PM session is given names the sync form # SKIP jq is not on PATH\n' "$n"
fi
x=""
for t in '^argument-hint: start | launch <slug> | sync \[<version> | latest\] | exit | console$' '^disable-model-invocation: true$' \
  '^sh "${CLAUDE_SKILL_DIR}/pap-pm.sh" <command> --session "${CLAUDE_SESSION_ID}"$' '^## sync \[<version> | latest\]$' \
  'Say first that you are reading pap.s releases, then run `sync <version>`' 'run `sync latest`, which takes the newest release' \
  'give them the `launch:` line to type. Then stop. Never invoke the launch yourself' \
  'Tell the owner why, as printed, and stop: no retry' 'name `/pap:pm start`, whose commit-or-discard question is the owner.s' \
  'Never write a sync brief by hand' 'A launch that refuses a sync brief is reported to the owner, never fixed by hand' \
  'A question about versions is answered; only an instruction runs `sync`' 'say the five forms and stop' \
  '\[sync-brief.txt\](sync-brief.txt)'; do
  grep -q -- "$t" "$skill" || x="$x [$t]"
done
[ -z "$x" ] && [ -f "$here/plugins/pap/skills/pm/sync-brief.txt" ]
result $? "pm-sync-6: the skill's text names the fifth form, stays the owner's to invoke, and says the same: the launch line and nothing launched, no brief by hand, no retry, a question is answered" "missing:$x"

printf '1..%d\n' "$n"
[ "$failed" = 0 ] || { printf '# %d of %d failed\n' "$failed" "$n"; exit 1; }
