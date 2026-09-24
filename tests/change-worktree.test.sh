#!/bin/sh
# change-worktree.test.sh: tests for plugins/pap/skills/change/worktree.sh.
#
# Usage: sh tests/change-worktree.test.sh
#
# Builds a bare origin and a clone in a temporary directory and runs the
# /change worktree step against them: a new change, a resumed local branch,
# a branch only on origin, an existing worktree, and the refusals. Prints
# one TAP-style line per case and exits 1 if any case fails. Needs git;
# touches nothing outside the temporary directory.
#
# SC2319: each case passes the exit status of its condition on purpose.
# shellcheck disable=SC2319

set -u

here="$(cd "$(dirname "$0")/.." && pwd)"
wt="$here/plugins/pap/skills/change/worktree.sh"

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

git init -q --bare -b main "$T/origin.git"
git clone -q "$T/origin.git" "$T/repo" 2>/dev/null
g -C "$T/repo" commit -q --allow-empty -m first
git -C "$T/repo" push -q origin main
# origin/main moves on after the clone last fetched: a new change must
# start from the fresh tip, not the stale one.
git clone -q "$T/origin.git" "$T/other"
g -C "$T/other" commit -q --allow-empty -m second
git -C "$T/other" push -q origin main
tip="$(git -C "$T/other" rev-parse HEAD)"

run() { (cd "$1" && sh "$wt" "$2" 2>&1); }

# A new change.
out="$(run "$T/repo" new-one)"; rc=$?
[ "$rc" = 0 ] && [ "$out" = "created $T/repo-new-one" ]
result $? "new: created beside the main checkout" "$rc $out"
[ "$(git -C "$T/repo-new-one" branch --show-current)" = change/new-one ]
result $? "new: worktree is on change/new-one"
[ "$(git -C "$T/repo-new-one" rev-parse HEAD)" = "$tip" ]
result $? "new: branches from a freshly fetched origin/main"
[ "$(git -C "$T/repo" branch --show-current)" = main ]
result $? "new: the main checkout's branch is unchanged"

# The worktree already exists: stop and print the path, from either checkout.
out="$(run "$T/repo" new-one)"; rc=$?
[ "$rc" = 3 ] && [ "$out" = "exists $T/repo-new-one" ]
result $? "existing worktree: exit 3 and its path" "$rc $out"
out="$(run "$T/repo-new-one" new-one)"; rc=$?
[ "$rc" = 3 ] && [ "$out" = "exists $T/repo-new-one" ]
result $? "existing worktree: same answer from inside it" "$rc $out"

# A local branch with work on it and no worktree: resumed, not reset.
g -C "$T/repo-new-one" commit -q --allow-empty -m work
work="$(git -C "$T/repo-new-one" rev-parse HEAD)"
git -C "$T/repo" worktree remove "$T/repo-new-one"
out="$(run "$T/repo" new-one)"; rc=$?
[ "$rc" = 0 ] && [ "$out" = "resumed $T/repo-new-one" ]
result $? "local branch: resumed" "$rc $out"
[ "$(git -C "$T/repo-new-one" rev-parse HEAD)" = "$work" ]
result $? "local branch: its commits are kept"

# A branch that exists only on origin: resumed, tracking it.
g -C "$T/other" switch -q -c change/remote-one
g -C "$T/other" commit -q --allow-empty -m remote-work
git -C "$T/other" push -q origin change/remote-one
rwork="$(git -C "$T/other" rev-parse HEAD)"
out="$(run "$T/repo" remote-one)"; rc=$?
[ "$rc" = 0 ] && [ "$out" = "resumed $T/repo-remote-one" ] &&
  [ "$(git -C "$T/repo-remote-one" rev-parse HEAD)" = "$rwork" ]
result $? "origin-only branch: resumed at its tip" "$rc $out"
[ "$(git -C "$T/repo-remote-one" rev-parse --abbrev-ref '@{upstream}')" = origin/change/remote-one ]
result $? "origin-only branch: tracks origin"

# Refusals.
mkdir "$T/repo-taken"
out="$(run "$T/repo" taken)"; rc=$?
[ "$rc" = 1 ] && printf '%s\n' "$out" | grep -q 'exists and is not a worktree'
result $? "path taken by a plain directory: refused" "$rc $out"
! git -C "$T/repo" rev-parse -q --verify refs/heads/change/taken >/dev/null
result $? "path taken: no branch created"
for bad in '' '-x' '.x' 'a/b' 'a..b' 'a b'; do
  out="$(run "$T/repo" "$bad")"; rc=$?
  [ "$rc" = 1 ] && printf '%s\n' "$out" | grep -q 'not a change slug'
  result $? "bad slug '$bad': refused" "$rc $out"
done

printf '1..%d\n' "$n"
[ "$failed" = 0 ]
