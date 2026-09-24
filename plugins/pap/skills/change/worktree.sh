#!/bin/sh
# worktree.sh: the worktree step of /change.
#
# Usage: worktree.sh <slug>
#
# Run from any checkout of the repository. Puts change/<slug> in a worktree
# beside the main checkout, at <main>/../<repo>-<slug>, and never switches
# the branch of an existing checkout. Prints one line and exits:
#   0  created <path>   no branch existed; a new one from a fresh origin/main
#   0  resumed <path>   change/<slug> existed, locally or on origin
#   3  exists <path>    a worktree for change/<slug> already exists; stop
#   1  (on stderr)      bad slug, no origin/main, or the path is taken
# An existing change branch is never recreated or reset (decision 0002).

set -eu

die() { printf 'worktree: %s\n' "$*" >&2; exit 1; }

[ "$#" -eq 1 ] || die "usage: worktree.sh <slug>"
slug="$1"
case "$slug" in
  '' | [.-]* | *[!A-Za-z0-9._-]* | *..*) die "not a change slug: $slug" ;;
esac
branch="change/$slug"

common="$(git rev-parse --path-format=absolute --git-common-dir)" || die "not in a git repository"
main="$(dirname "$common")"
path="$(dirname "$main")/$(basename "$main")-$slug"

existing="$(git worktree list --porcelain | awk -v b="refs/heads/$branch" '
  /^worktree / { w = substr($0, 10) }
  $0 == "branch " b { print w; exit }')"
if [ -n "$existing" ]; then
  printf 'exists %s\n' "$existing"
  exit 3
fi

[ ! -e "$path" ] || die "$path exists and is not a worktree of $branch"

git fetch -q origin || die "cannot fetch origin"
git rev-parse -q --verify refs/remotes/origin/main >/dev/null || die "no origin/main"

if git rev-parse -q --verify "refs/heads/$branch" >/dev/null; then
  git worktree add -q "$path" "$branch"
  printf 'resumed %s\n' "$path"
elif git rev-parse -q --verify "refs/remotes/origin/$branch" >/dev/null; then
  git worktree add -q --track -b "$branch" "$path" "origin/$branch"
  printf 'resumed %s\n' "$path"
else
  git worktree add -q --no-track -b "$branch" "$path" origin/main
  printf 'created %s\n' "$path"
fi
