#!/bin/sh
# SC2016: backticks in the pull request body are Markdown, not expansions.
# shellcheck disable=SC2016
# accept.sh: accept proposed decision records at the Project Lead's word.
# The /pap:accept skill runs it when a person invokes the skill; the model
# never decides to accept a record, and an agent never runs this script.
#
# Usage: accept.sh [--repo <path>] <NNNN> [NNNN ...]
#        accept.sh "[--repo <path>] <NNNN> [NNNN ...]"    one word, as a skill may pass it
#
# The first line printed names the repository acted on, `Repository:
# owner/name (path)`, so a wrong one is seen at once. That is the current
# repository, or the checkout given with --repo (before or after the ids),
# which is refused unless it is a git checkout with an origin. The script
# enters it in its own process; the caller's directory is untouched. The skill
# passes its arguments as one word that is split on spaces, so a --repo path
# with a space needs the script run directly.
#
# In that repository: fetches origin and finds each record as
# decisions/<NNNN>-*.md on origin/main. Refuses, saying why and changing
# nothing, when an id is not four digits, when no record has it, when the
# record is not on origin/main yet, when its Status is not `proposed`, or
# when change/accept-<ids> already exists. Otherwise prints each record's
# title and the lead of each Decision item, then, in a worktree on a new
# change/accept-<ids> branch from a fresh origin/main (the /change worktree
# script), rewrites only each Status line to
# `accepted (<gh login>, YYYY-MM-DD)`, commits, pushes, opens a draft pull
# request with class:docs and prints its URL. It never merges, never adds
# a label but class:docs and never writes an Approved-by line.
# A refusal prints "refused:" and exits 0, so a skill invocation renders it;
# a git or gh failure exits 1. Ids are checked before any use.
# Every gh call, and the credential the push asks for, run as the owner
# from gh's default directory (rule 23.4). The fetch goes as whoever the
# shim says.
set -u

usage='usage: /pap:accept [--repo <path>] <NNNN> [NNNN ...]'
refuse() { printf 'refused: %s\n' "$1"; exit 0; }
fail() { printf '%s\n' "$1" >&2; exit 1; }
here="$(cd "$(dirname "$0")" && pwd)"

# One word holding every argument is split here, on purpose.
# shellcheck disable=SC2086
if [ "$#" -eq 1 ]; then set -- $1; fi
# --repo <path> may come before or after the ids; the rest are ids.
repo=""
ids=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo)
      [ "$#" -ge 2 ] || refuse "--repo needs a path. $usage"
      repo="$2"
      shift 2 ;;
    *) ids="$ids $1"; shift ;;
  esac
done
# shellcheck disable=SC2086
set -- $ids
case "$repo" in "~"/*) repo="$HOME/${repo#"~"/}" ;; esac

if [ -n "$repo" ]; then
  [ -d "$repo" ] || refuse "--repo '$repo' is not a directory."
  cd "$repo" || refuse "cannot enter --repo '$repo'."
fi
git rev-parse --git-dir > /dev/null 2>&1 || refuse "not inside a git repository."
top="$(git rev-parse --show-toplevel)"
cd "$top" || fail "cannot enter $top."
origin="$(git remote get-url origin 2> /dev/null)" || refuse "$top has no origin remote."
name="$(printf '%s\n' "$origin" | sed 's#/*$##; s#\.git$##; s#.*[:/]\([^/:]*/[^/]*\)$#\1#')"
shown="$top"
case "$top" in "$HOME"/*) shown="~${top#"$HOME"}" ;; esac
printf 'Repository: %s (%s)\n' "$name" "$shown"

[ "$#" -ge 1 ] || refuse "$usage"
for id in "$@"; do
  case "$id" in [0-9][0-9][0-9][0-9]) ;; *) refuse "'$id' is not a four-digit record number. $usage" ;; esac
done
# shellcheck disable=SC2046
set -- $(printf '%s\n' "$@" | sort -u)

# Rule 23.4: this script is the one door back to the owner's sign-in. Every
# gh call below runs as the owner, from gh's own default directory, where
# the owner signed in (gh resolves it, without GH_CONFIG_DIR, as
# $XDG_CONFIG_HOME/gh, else ~/.config/gh, macOS included), with the token
# variables unset so the agent app's token cannot stand in, and CLAUDECODE
# unset so the gh shim passes through instead of refusing a GH_CONFIG_DIR
# that is not the agent's.
owner_gh="${XDG_CONFIG_HOME:-$HOME/.config}/gh"
[ -d "$owner_gh" ] ||
  refuse "gh has no default directory at $owner_gh, so this cannot act as you. Sign in from your own terminal with gh auth login, then invoke this again."
as_owner() { (unset GH_TOKEN GITHUB_TOKEN GH_ENTERPRISE_TOKEN GITHUB_ENTERPRISE_TOKEN CLAUDECODE; GH_CONFIG_DIR="$owner_gh"; export GH_CONFIG_DIR; "$@"); }
gh() { as_owner command gh "$@"; }

# The default branch is main, as the /change worktree script assumes.
git fetch -q origin || fail "git could not fetch origin."
git rev-parse -q --verify refs/remotes/origin/main > /dev/null || fail "no origin/main."

# field <name>: the value of a record header line, "- **Name:** value", on stdin.
field() { sed -n "s/^- \*\*$1:\*\* *//p" | head -n 1; }

# Every check passes before anything is written.
paths=""
for id in "$@"; do
  path="$(git ls-tree --name-only origin/main decisions/ | grep "^decisions/$id-.*\.md$" | head -n 1)"
  if [ -z "$path" ]; then
    # shellcheck disable=SC2010
    if ls decisions 2> /dev/null | grep -q "^$id-.*\.md$" ||
      git log --all --format= --name-only -- 'decisions/*.md' | grep -q "^decisions/$id-"; then
      refuse "decision $id is not on main (found on another branch); merge its pull request first."
    fi
    refuse "no decision record $id under decisions/."
  fi
  status="$(git show "origin/main:$path" | field Status)"
  [ "$status" = proposed ] || refuse "decision $id is '$status', not proposed."
  paths="$paths $path"
done

slug="accept-$(printf '%s-' "$@" | sed 's/-$//')"
branch="change/$slug"
if git rev-parse -q --verify "refs/heads/$branch" > /dev/null ||
  git rev-parse -q --verify "refs/remotes/origin/$branch" > /dev/null; then
  refuse "$branch already exists; close or merge its pull request, or delete the branch."
fi

login="$(gh api user --jq .login)" || fail "gh could not read the signed-in user."
case "$login" in '' | *[!A-Za-z0-9-]*) fail "gh returned an unexpected login: '$login'." ;; esac
day="$(date +%Y-%m-%d)"
new="accepted ($login, $day)"

# What is accepted: the title and each Decision item's bold lead, else the
# section's first line.
summary() { # summary <path on origin/main>
  git show "origin/main:$1" | awk '
    NR == 1 { sub(/^# /, ""); print "  " $0; next }
    /^## Decision/ { d = 1; next }
    /^## / { if (d) exit }
    !d { next }
    /^[0-9]+\. / { if (item != "") emit(); item = $0; next }
    /^$/ { if (item != "") emit(); next }
    { sub(/^ +/, ""); if (item != "") item = item " " $0; else if (first == "") first = $0 }
    END { if (item != "") emit(); if (!shown && first != "") print "    " substr(first, 1, 160) }
    function emit(  t) {
      t = item; item = ""
      if (match(t, /\*\*[^*]+\*\*/)) t = substr(t, RSTART + 2, RLENGTH - 4)
      else t = substr(t, 1, 160)
      if (shown < 8) print "    - " t
      shown++
    }'
}

printf 'Accepting, as %s on %s:\n' "$login" "$day"
for path in $paths; do summary "$path"; done

wt="$(sh "$here/../change/worktree.sh" "$slug")" || fail "the worktree step failed: $wt"
case "$wt" in "created "*) wt="${wt#created }" ;; *) fail "the worktree step did not create a new branch: $wt" ;; esac

for path in $paths; do
  f="$wt/$path"
  { sed "s/^- \*\*Status:\*\* proposed\$/- **Status:** $new/" "$f" > "$f.tmp" && mv "$f.tmp" "$f"; } ||
    fail "could not rewrite $path."
  # Exactly one line changed: the Status line.
  stat="$(git -C "$wt" diff --numstat -- "$path")"
  [ "$stat" = "1	1	$path" ] || fail "$path changed more than its Status line; see $wt."
done

ids="$(printf '%s, ' "$@" | sed 's/, $//')"
title="docs(decisions): accept $ids"
# shellcheck disable=SC2086
git -C "$wt" add -- $paths || fail "git add failed in $wt."
git -C "$wt" commit -q -m "$title" \
  -m "Status set to $new at the Project Lead's /pap:accept." || fail "git commit failed in $wt."
# The push itself keeps the agent's environment, so git hooks do not run
# with the owner's: only git's credential helper, for this push, is gh as
# the owner. An empty credential.helper first clears every configured one.
q="'$(printf '%s' "$owner_gh" | sed "s/'/'\\\\''/g")'"
helper="!env -u GH_TOKEN -u GITHUB_TOKEN -u GH_ENTERPRISE_TOKEN -u GITHUB_ENTERPRISE_TOKEN -u CLAUDECODE GH_CONFIG_DIR=$q gh auth git-credential"
git -C "$wt" -c credential.helper= -c "credential.helper=$helper" push -q -u origin "$branch" || fail "git push of $branch failed."

# The protected-path box: decisions/** is fixed high in risk mode (decision
# 0016); otherwise a CODEOWNERS path needs the owner's Approved-by line,
# which only the owner writes (decisions 0012, 0013).
head7="$(git -C "$wt" rev-parse --short=7 HEAD)"
if git cat-file -e origin/main:.github/risk.yml 2> /dev/null; then
  box='- [ ] No protected path touched, or the owner has approved the head: `Approved-by: @login <sha>` below, or (risk mode) the `owner-reviewed` label
Risk: high; the owner adds owner-reviewed after review'
elif git show origin/main:.github/CODEOWNERS 2> /dev/null | grep -q '^/*decisions'; then
  box="- [ ] No protected path touched, or the owner has approved the head: \`Approved-by: @login <sha>\` below, or (risk mode) the \`owner-reviewed\` label
Head to approve: $head7"
else
  box='- [x] No protected path touched, or the owner has approved the head: `Approved-by: @login <sha>` below, or (risk mode) the `owner-reviewed` label'
fi

body="$(mktemp)" || fail "mktemp failed."
{
  printf 'Change: none\nRecord: none\n\n## Summary\n'
  printf 'The Project Lead accepts decision %s with `/pap:accept`. Each Status line now reads `%s`; nothing else in the records changed.\n\n' "$ids" "$new"
  for path in $paths; do printf -- '- `%s`: Status `proposed` to `%s`.\n' "$path" "$new"; done
  printf '\nDecisions and tradeoffs to review:\n- none; the acceptance is the Project Lead'"'"'s act, made by invoking the skill.\n\n'
  printf '## Verification\n| Check | Result |\n| --- | --- |\n'
  for path in $paths; do printf '| `%s` on main | Status was `proposed` |\n' "$path"; done
  printf '| Diff | one line per record, the Status line (`git diff --numstat`) |\n'
  printf '| Local checks | not run: a one-line Status edit per record; CI runs them |\n\n'
  printf '## Checks\nTick a box only if it is true. An unticked box needs a one-line reason below it, otherwise the PR is not ready.\n'
  printf -- '- [x] Verification run and output shown above\n%s\n' "$box"
  printf -- '- [x] Generated content carries provenance (model, skill, prompt)\n'
  printf 'Provenance: no generated content; the Status lines were set by the `/pap:accept` script at the Project Lead'"'"'s invocation.\n'
} > "$body"
url="$(cd "$wt" && gh pr create --draft --title "$title" --body-file "$body" --label class:docs)" ||
  { rm -f "$body"; fail "gh could not open the pull request; $branch is pushed."; }
rm -f "$body"
printf 'Opened %s (draft) from %s at %s.\n' "$url" "$branch" "$head7"
printf 'Merge it to accept; once merged, run `mise run tidy` to remove %s.\n' "$wt"
exit 0
