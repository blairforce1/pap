#!/bin/sh
# pm-sync.test.sh: the scenarios of features/pm-sync.feature, bound by ID,
# for the sync form of /pap:pm's script (changes/pm-sync/spec.md). The
# scenarios bound elsewhere: pm-sync-8 and pm-sync-15 in
# tests/pm-mode.test.sh, beside the launch and guard cases they extend.
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
# git and cksum.
#
# SC2319: each case passes the exit status of its condition on purpose.
# shellcheck disable=SC2319

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
PAP_SOURCE="$T/source"
export PAP_SOURCE

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
PAP_SOURCE="$T/nowhere" sync 0.19.0
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
PAP_SOURCE="$T/nowhere" sync 0.19.1
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

printf '1..%d\n' "$n"
[ "$failed" = 0 ] || { printf '# %d of %d failed\n' "$failed" "$n"; exit 1; }
