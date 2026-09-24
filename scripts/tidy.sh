#!/bin/sh
# tidy.sh: clean up after merged changes. `mise run tidy` runs it.
#
# Usage: scripts/tidy.sh
#
# Fetches with --prune, then for every local branch whose upstream is gone
# removes its worktree (--force: scratch output is often left behind) and
# deletes the branch with -D. -D, not -d: a squash merge leaves the branch
# tip off main, so --merged never sees it; a gone upstream is the signal
# that the pull request was merged and its branch deleted. Then prunes the
# worktree list and prints what it removed and what it left.
#
# Never touched: the main checkout, the current branch, a branch that still
# has an upstream or has none, and a worktree with uncommitted tracked
# changes, which is reported and skipped. Untracked files do not count:
# they are the scratch output --force is for.

set -eu

say() { printf '%s\n' "$@"; }

git fetch --prune --quiet
# A worktree whose directory was deleted by hand still holds its branch;
# prune first so -D can delete it.
git worktree prune

current="$(git branch --show-current)"
# The first entry of the list is always the main checkout.
list="$(git worktree list --porcelain)"
main="$(printf '%s\n' "$list" | sed -n '1s/^worktree //p')"

# worktree_of <branch>: the path of the worktree that has it checked out.
worktree_of() {
  printf '%s\n' "$list" | awk -v ref="branch refs/heads/$1" '
    /^worktree / { p = substr($0, 10) }
    $0 == ref { print p; exit }'
}

removed=""
left=""
stuck=0
refs="$(git for-each-ref --format='%(refname:short)	%(upstream:short)	%(upstream:track)' refs/heads)"
tab="$(printf '\t')"
while IFS="$tab" read -r b up track; do
  [ -n "$b" ] || continue
  if [ -z "$up" ]; then
    left="$left$b: no upstream
"
  elif [ "$track" != "[gone]" ]; then
    left="$left$b: upstream $up
"
  elif [ "$b" = "$current" ]; then
    stuck=$((stuck + 1))
    left="$left$b: upstream gone, but it is the current branch
"
  else
    wt="$(worktree_of "$b")"
    if [ -n "$wt" ] && [ "$wt" = "$main" ]; then
      stuck=$((stuck + 1))
      left="$left$b: upstream gone, but checked out in the main checkout
"
      continue
    fi
    if [ -n "$wt" ] && [ -n "$(git -C "$wt" status --porcelain --untracked-files=no)" ]; then
      stuck=$((stuck + 1))
      left="$left$b: upstream gone, SKIPPED: uncommitted tracked changes in $wt
"
      continue
    fi
    if [ -n "$wt" ]; then
      git worktree remove --force "$wt"
      removed="${removed}worktree $wt
"
    fi
    git branch -q -D "$b"
    removed="${removed}branch $b
"
  fi
done <<EOF
$refs
EOF

git worktree prune

if [ -z "$removed" ] && [ "$stuck" -eq 0 ]; then
  say "Nothing to do: no local branch has a gone upstream."
elif [ -z "$removed" ]; then
  say "Removed nothing."
else
  say "Removed:"
  printf '%s' "$removed" | sed 's/^/  /'
fi
if [ -n "$left" ]; then
  say "Left:"
  printf '%s' "$left" | sed 's/^/  /'
fi
