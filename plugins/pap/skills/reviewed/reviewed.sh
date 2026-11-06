#!/bin/sh
# reviewed.sh: add the owner-reviewed label to a risk:high pull request the
# Project Lead has reviewed (decision 0016, rule 16.1). The /pap:reviewed
# skill runs it when a person invokes the skill; the model never decides to
# add the label, and an agent never runs this script (rule 16.2).
#
# Usage: reviewed.sh <pr-number> [sha7+]
#        reviewed.sh "<pr-number> [sha7+]"    one word, as a skill may pass it
#
# In the current repository, through gh: reads the pull request's state,
# head and labels; refuses, saying why, when it is not open, when the SHA
# given is not a prefix of its head, when it has no risk label yet, or when
# it is risk:medium or risk:low (no owner-reviewed needed); else adds
# owner-reviewed, reads the labels back and prints the head it labelled.
# A refusal prints "refused:" and exits 0, so a skill invocation renders it;
# a gh failure, or a label that did not land, exits 1. Arguments are checked
# (digits only; 7 to 40 hex characters) before any use and always quoted.
# Every gh call runs as the owner from gh's default directory (rule 23.4).
set -u

usage='usage: /pap:reviewed <PR#> [sha7+]'
refuse() { printf 'refused: %s\n' "$1"; exit 0; }
fail() { printf '%s\n' "$1" >&2; exit 1; }

# One word holding both arguments is split here, on purpose.
# shellcheck disable=SC2086
if [ "$#" -eq 1 ]; then set -- $1; fi
[ "$#" -ge 1 ] && [ "$#" -le 2 ] || refuse "$usage"
n="$1"
sha="${2:-}"
case "$n" in '' | *[!0-9]*) refuse "'$n' is not a pull request number. $usage" ;; esac
if [ -n "$sha" ]; then
  case "$sha" in *[!0-9A-Fa-f]*) refuse "'$sha' is not 7 to 40 hex characters. $usage" ;; esac
  [ "${#sha}" -ge 7 ] && [ "${#sha}" -le 40 ] || refuse "'$sha' is not 7 to 40 hex characters. $usage"
  sha="$(printf '%s' "$sha" | tr '[:upper:]' '[:lower:]')"
fi

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

repo="$(gh repo view --json nameWithOwner --jq .nameWithOwner)" || fail "gh could not read the repository here."
pr="$(gh pr view "$n" --json headRefOid,labels,state \
  --jq '[.state, .headRefOid, ([.labels[].name] | join(","))] | @tsv')" \
  || fail "gh could not read pull request #$n in $repo."
state="$(printf '%s\n' "$pr" | cut -f1)"
head="$(printf '%s\n' "$pr" | cut -f2 | tr '[:upper:]' '[:lower:]')"
labels="$(printf '%s\n' "$pr" | cut -f3)"
head7="$(printf '%.7s' "$head")"
has() { case ",$labels," in *",$1,"*) return 0 ;; *) return 1 ;; esac; }

[ "$state" = OPEN ] || refuse "$repo#$n is $state, not open."
if [ -n "$sha" ]; then
  case "$head" in "$sha"*) ;; *) refuse "$sha is not a prefix of the head $head7 of $repo#$n." ;; esac
fi
level="$(printf '%s\n' "$labels" | tr ',' '\n' | sed -n 's/^risk://p' | head -n 1)"
case "$level" in
  '') refuse "$repo#$n has no risk label yet; wait for pr-checks to label it." ;;
  high) ;;
  *) refuse "$repo#$n is risk:$level; risk:$level needs no owner-reviewed." ;;
esac
if has owner-reviewed; then
  printf '%s#%s already has owner-reviewed at head %s.\n' "$repo" "$n" "$head7"
  exit 0
fi

gh pr edit "$n" --add-label owner-reviewed > /dev/null || fail "gh could not add owner-reviewed to $repo#$n."
after="$(gh pr view "$n" --json headRefOid,labels --jq '[.headRefOid, ([.labels[].name] | join(","))] | @tsv')" \
  || fail "gh could not read $repo#$n back after labelling."
head_after="$(printf '%s\n' "$after" | cut -f1 | tr '[:upper:]' '[:lower:]')"
labels="$(printf '%s\n' "$after" | cut -f2)"
has owner-reviewed || fail "owner-reviewed is not on $repo#$n after adding it; check the labels by hand."
printf 'owner-reviewed added to %s#%s at head %s. Labels: %s.\n' "$repo" "$n" "$head7" "$labels"
[ "$head_after" = "$head" ] \
  || printf 'warning: the head moved to %s while labelling; pr-checks removes owner-reviewed on a push, so review the new head.\n' "$(printf '%.7s' "$head_after")"
exit 0
