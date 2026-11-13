#!/bin/sh
# release-bump.sh: make a pap release bump end to end (changes/release-bump).
#
# Usage: mise run release-bump <version> [--route "<line 1>" "<line 2>"] [--by "<agent> on <model>"]
#        mise run release-bump --answer-risk <version>
#
# From a version the owner names, it makes the work tree
# ../pap-release-<version> on change/release-<version> from origin/main as
# this run fetched it, moves the four version places, dates the unreleased
# section in UTC, runs mise run check and mise run test, commits with every
# hook, pushes and opens the draft pull request with class:chore. Then it
# waits for the risk label and answers the protected-path box from it. It
# prints the pull request's URL.
#
# It refuses before it makes anything unless the release bump can be made
# whole: exit 1, nothing made. A failure, or an INT, TERM or HUP, before
# the pull request opens is undone (exit 2): the pushed branch if origin
# still points at this run's commit, then the work tree, then the local
# branch. A failure after the open leaves the pull request open, and
# anything an undo cannot remove is left: exit 3, naming what is left and
# the command that removes it. Nothing is retried.
#
# It never merges, marks ready, adds owner-reviewed, pushes main, cuts the
# release or tags. It acts as whoever the shell's git and gh are; it sets no
# GH_TOKEN. The route and the --by value are written into the body as
# text, never evaluated. A route needs --by: the body names who ran it.
#
# --answer-risk rewrites only the protected-path box of the open draft from
# change/release-<version>, from its risk label as it is now (exit 0), and
# refuses (exit 1) unless the draft's only commit is this command's.
#
# The environment: RELEASE_BUMP_NET_TIMEOUT (seconds, default 60) bounds
# ls-remote, the push and each gh call; the fetch has 10. RELEASE_BUMP_RISK_WAIT
# (seconds, default 120) bounds the wait for the risk label. Requires git,
# jq, gh and mise. POSIX sh.

set -u

GIT_TERMINAL_PROMPT=0
export GIT_TERMINAL_PROMPT

start="$(date +%s)"
net_timeout="${RELEASE_BUMP_NET_TIMEOUT:-60}"
risk_wait="${RELEASE_BUMP_RISK_WAIT:-120}"
run=""

elapsed() { echo $(($(date +%s) - start)); }
say() { printf 'release-bump: %s (%ss)\n' "$*" "$(elapsed)" >&2; }
refuse() {
  printf 'release-bump: refused: %s (%ss)\n' "$1" "$(elapsed)" >&2
  [ -z "${2:-}" ] || printf 'release-bump: to clear it: %s\n' "$2" >&2
  [ -z "$run" ] || rm -rf "$run"
  exit 1
}

# with_timeout <seconds> <output file> <command>...: run the command in its
# own process group, its output to the file. A watchdog sends TERM to the
# whole group (an ssh under a push included) at the limit; the status is
# then 124.
child=""
with_timeout() {
  wt_secs="$1" wt_out="$2"
  shift 2
  rm -f "$run/timed-out"
  set -m
  "$@" >"$wt_out" 2>&1 </dev/null &
  child=$!
  (
    sleep "$wt_secs"
    : >"$run/timed-out"
    kill -TERM -- "-$child" 2>/dev/null
  ) >/dev/null 2>&1 &
  wt_dog=$!
  set +m
  wait "$child"
  wt_status=$?
  kill -TERM -- "-$wt_dog" 2>/dev/null
  wait "$wt_dog" 2>/dev/null
  child=""
  if [ -e "$run/timed-out" ] && [ "$wt_status" != 0 ]; then
    rm -f "$run/timed-out"
    printf 'timed out after %ss\n' "$wt_secs" >>"$wt_out"
    return 124
  fi
  rm -f "$run/timed-out"
  return "$wt_status"
}

valid_version() {
  printf '%s\n' "$1" | grep -Eqx '(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)'
}

# above <a> <b>: a is above b, compared number by number.
above() {
  awk -v a="$1" -v b="$2" 'BEGIN {
    split(a, x, "."); split(b, y, ".")
    for (i = 1; i <= 3; i++) {
      if (x[i] + 0 > y[i] + 0) exit 0
      if (x[i] + 0 < y[i] + 0) exit 1
    }
    exit 1 }'
}

# The arguments. Kept in "$@" for the run from the work tree.
parse() {
  version="" route1="" route2="" by="" has_route=false has_by=false answer=false in_wt=false
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --route)
        [ "$#" -ge 3 ] || refuse "--route takes two lines"
        route1="$2" route2="$3" has_route=true
        shift 3
        ;;
      --by)
        [ "$#" -ge 2 ] || refuse "--by takes a value"
        by="$2" has_by=true
        shift 2
        ;;
      --answer-risk) answer=true; shift ;;
      --in-worktree)
        [ "$#" -ge 4 ] || refuse "--in-worktree is the command's own"
        in_wt=true wt="$2" branch="$3" base="$4"
        shift 4
        ;;
      -*) refuse "unknown option '$1'; usage: mise run release-bump <version> [--route <line 1> <line 2>] [--by <agent> on <model>]" ;;
      *)
        [ -z "$version" ] || refuse "one version only"
        version="$1"
        shift
        ;;
    esac
  done
}

cr="$(printf '\r')"
nl='
'
check_inputs() {
  valid_version "$version" || refuse "the version '$version' is not x.y.z without leading zeros"
  branch_want="change/release-$version"
  for v in "$route1" "$route2" "$by"; do
    case "$v" in
      *"$cr"* | *"$nl"*)
        if [ "$v" = "$by" ] && [ "$has_by" = true ]; then
          refuse "the --by value holds a newline or carriage return"
        fi
        refuse "the route holds a newline or carriage return"
        ;;
    esac
  done
  if [ "$has_route" = true ] && [ "$has_by" = false ]; then
    refuse "a route without --by: the body would say the owner ran it"
  fi
  if [ "$has_by" = true ]; then
    [ "${#by}" -le 100 ] || refuse "the --by value is longer than 100 bytes"
    printf '%s\n' "$by" | LC_ALL=C grep -Eqx '[A-Za-z0-9 .:_-]+ on [A-Za-z0-9 .:_-]+' ||
      refuse "the --by value '$by' is not '<agent> on <model>' in A-Z a-z 0-9 space . : _ -"
  fi
  if [ "$has_route" = true ]; then
    [ "$route1" = "/change release-$version chore Record: none" ] ||
      refuse "the route's first line is not '/change release-$version chore Record: none'"
    case "$route2" in
      "Rule 20.2: "?*) ;;
      *) refuse "the route's second line is not of the form 'Rule 20.2: ...'" ;;
    esac
  fi
}

# Hooks switched off through the environment (INV-005). A GIT_CONFIG_COUNT
# that only sets credential keys, as pap claude's agent shell does, stays.
check_env() {
  for v in GIT_CONFIG_PARAMETERS GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM GIT_DIR GIT_WORK_TREE; do
    if env | grep -q "^$v="; then
      refuse "$v is set; it can change what git runs" "unset $v"
    fi
  done
  if env | grep -q '^GIT_CONFIG_COUNT='; then
    key="$(awk 'BEGIN {
      n = ENVIRON["GIT_CONFIG_COUNT"]
      if (n !~ /^[0-9]+$/) { print "(not a number)"; exit }
      for (i = 0; i < n; i++) {
        k = ENVIRON["GIT_CONFIG_KEY_" i]
        if (tolower(k) !~ /^credential\./) { print k; exit }
      } }')"
    [ -z "$key" ] || refuse "GIT_CONFIG_COUNT is set with '$key', which can change what git runs" "unset GIT_CONFIG_COUNT"
  fi
}

check_hooks() {
  common="$(git rev-parse --path-format=absolute --git-common-dir)" || refuse "not in a git repository"
  hooks="$(git rev-parse --path-format=absolute --git-path hooks)"
  [ "$hooks" = "$common/hooks" ] ||
    refuse "core.hooksPath points at $hooks, not the repository's own hooks"
}

prompt_re='github:blairforce1/pap\[asset_pattern=pap-\*\.tar\.gz\]@'

# places <rev>: set p_plugin, p_market, p_install and p_print, the four
# version places at <rev>; a place that cannot be read is empty.
places() {
  p_plugin="$(git show "$1:plugins/pap/.claude-plugin/plugin.json" 2>/dev/null | jq -r '.version // ""' 2>/dev/null)"
  p_market="$(git show "$1:.claude-plugin/marketplace.json" 2>/dev/null |
    jq -r '[.plugins[] | select(.name == "pap") | .version][0] // ""' 2>/dev/null)"
  line="$(git show "$1:docs/agent-onboarding.md" 2>/dev/null | grep -E "${prompt_re}[0-9]" | head -n 1)"
  p_install="$(printf '%s\n' "$line" | sed -n "s#.*${prompt_re}\([0-9][0-9.]*[0-9]\).*#\1#p")"
  p_print="$(printf '%s\n' "$line" | sed -n 's/.*which must print \([0-9][0-9.]*[0-9]\).*/\1/p')"
}

# unreleased_lines <file>: the lines of the unreleased section under
# "## pap" that are not blank; "none" when there is no such heading.
unreleased_lines() {
  awk '
    /^## / { pap = ($0 == "## pap"); inside = 0 }
    pap && $0 == "### [Unreleased]" { inside = 1; seen = 1; next }
    inside && /^###? / { inside = 0 }
    inside && NF { n++ }
    END { if (!seen) print "none"; else print n + 0 }' "$1"
}

refusals() {
  check_inputs
  check_env
  check_hooks
  main="$(dirname "$common")"
  wt="$(dirname "$main")/$(basename "$main")-release-$version"
  run="$(mktemp -d)"
  if ! with_timeout 10 "$run/fetch" git fetch -q origin main; then
    refuse "the fetch of origin/main failed: $(tail -n 3 "$run/fetch" | tr '\n' ' ')"
  fi
  base="$(git rev-parse --verify -q origin/main)" || refuse "the fetch of origin/main left no origin/main"
  say "fetched origin/main at $(echo "$base" | cut -c1-7)"

  places "$base"
  current="$p_plugin"
  if [ -z "$current" ] || [ "$p_market" != "$current" ] || [ "$p_install" != "$current" ] || [ "$p_print" != "$current" ]; then
    refuse "the version places disagree at origin/main: plugin.json names ${p_plugin:-none}, marketplace.json names ${p_market:-none}, the install prompt installs ${p_install:-none} and prints ${p_print:-none}"
  fi
  valid_version "$current" || refuse "the version places name '$current', not x.y.z"
  above "$version" "$current" || refuse "the version $version is not above $current"

  git show "$base:CHANGELOG.md" >"$run/changelog" 2>/dev/null || refuse "origin/main has no CHANGELOG.md"
  case "$(unreleased_lines "$run/changelog")" in
    none) refuse "CHANGELOG.md has no '### [Unreleased]' heading under '## pap'" ;;
    0) refuse "the unreleased section under '## pap' is empty: write its lines before the bump" ;;
  esac

  open="$(git worktree list --porcelain | awk -v b="refs/heads/$branch_want" '
    /^worktree / { w = substr($0, 10) }
    $0 == "branch " b { print w; exit }')"
  [ -z "$open" ] || refuse "a work tree for $branch_want is open at $open" "git worktree remove $open"
  if git rev-parse -q --verify "refs/heads/$branch_want" >/dev/null; then
    refuse "the branch $branch_want exists locally" "git branch -D $branch_want"
  fi
  with_timeout "$net_timeout" "$run/ls-remote" git ls-remote --heads origin "refs/heads/$branch_want"
  st=$?
  [ "$st" = 0 ] || refuse "ls-remote of origin failed: $(tail -n 3 "$run/ls-remote" | tr '\n' ' ')"
  [ ! -s "$run/ls-remote" ] ||
    refuse "the branch $branch_want exists on origin; close its pull request, or delete it" "gh pr close $branch_want --delete-branch"
  [ ! -e "$wt" ] && [ ! -L "$wt" ] || refuse "a directory is at the work tree's path, $wt" "rm -r $wt"
  say "checked: $current to $version"
}

parse "$@"
cd "$(dirname "$0")/.." || exit 1
refusals
: "$risk_wait" "$answer" "$in_wt" "${branch:-}" # used by the steps still to come
refuse "the bump itself is not built yet"
