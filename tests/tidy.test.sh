#!/bin/sh
# tidy.test.sh: tests for templates/base/scripts/tidy.sh.
#
# Usage: sh tests/tidy.test.sh
#
# Builds a bare origin and a clone in a temporary directory with a branch
# per case, each in its own worktree, deletes some upstreams as a merged
# pull request would, and runs tidy from the main checkout. Prints one
# TAP-style line per case and exits 1 if any case fails. Needs git;
# touches nothing outside the temporary directory.
#
# SC2319: each case passes the exit status of its condition on purpose.
# shellcheck disable=SC2319

set -u

here="$(cd "$(dirname "$0")/.." && pwd)"
tidy="$here/templates/base/scripts/tidy.sh"

command -v git >/dev/null 2>&1 || { printf 'Bail out! git not found\n'; exit 1; }

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT INT TERM

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
g() { git -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false "$@"; }
has_branch() { git -C "$T/repo" show-ref -q --verify "refs/heads/$1"; }

git init -q --bare -b main "$T/origin.git"
git clone -q "$T/origin.git" "$T/repo" 2>/dev/null
echo one > "$T/repo/file"
g -C "$T/repo" add file
g -C "$T/repo" commit -q -m first
git -C "$T/repo" push -q origin main

# change <name>: a worktree on change/<name> with one commit of its own,
# pushed with an upstream. The commit never reaches main, as under a squash
# merge, so only the gone upstream says the branch is done.
change() {
  git -C "$T/repo" worktree add -q -b "change/$1" "$T/repo-$1" main
  echo "$1" > "$T/repo-$1/$1"
  g -C "$T/repo-$1" add "$1"
  g -C "$T/repo-$1" commit -q -m "$1"
  git -C "$T/repo-$1" push -q -u origin "change/$1" 2>/dev/null
}
change merged
change live
change dirty
echo scratch > "$T/repo-merged/scratch.log" # untracked: --force removes it
echo edited >> "$T/repo-dirty/file"         # tracked: tidy must not
git -C "$T/repo" push -q origin --delete change/merged change/dirty

out="$(cd "$T/repo" && sh "$tidy" 2>&1)"; rc=$?
[ "$rc" = 0 ]
result $? "tidy exits 0" "$rc $out"

! has_branch change/merged && [ ! -e "$T/repo-merged" ] &&
  printf '%s\n' "$out" | grep -q "branch change/merged"
result $? "merged: worktree and branch removed, and reported" "$out"

has_branch change/live && [ -d "$T/repo-live" ] &&
  printf '%s\n' "$out" | grep -q "change/live: upstream origin/change/live"
result $? "live upstream: branch and worktree kept" "$out"

has_branch change/dirty && grep -q edited "$T/repo-dirty/file" &&
  printf '%s\n' "$out" | grep -q "change/dirty: .*SKIPPED: uncommitted tracked changes"
result $? "dirty tracked file: skipped and reported" "$out"

[ "$(git -C "$T/repo" branch --show-current)" = main ] && has_branch main
result $? "main checkout untouched"

# The current branch is never deleted, even with its upstream gone.
git -C "$T/repo" push -q origin --delete change/live
out="$(cd "$T/repo-live" && sh "$tidy" 2>&1)"; rc=$?
[ "$rc" = 0 ] && has_branch change/live &&
  printf '%s\n' "$out" | grep -q "change/live: upstream gone, but it is the current branch"
result $? "current branch: kept though its upstream is gone" "$rc $out"

# Clean the dirty worktree and run from the main checkout: it goes, and
# so does change/live, current only inside its own worktree. A third run
# has nothing to do.
git -C "$T/repo-dirty" checkout -q -- file
out="$(cd "$T/repo" && sh "$tidy" 2>&1)"
! has_branch change/dirty && [ ! -e "$T/repo-dirty" ] &&
  ! has_branch change/live && [ ! -e "$T/repo-live" ]
result $? "once cleaned, from the main checkout: both removed" "$out"

out="$(cd "$T/repo" && sh "$tidy" 2>&1)"
printf '%s\n' "$out" | grep -q "^Nothing to do"
result $? "nothing gone: reports nothing to do" "$out"

printf '1..%d\n' "$n"
[ "$failed" = 0 ]
