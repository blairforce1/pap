#!/bin/sh
# release-bump.test.sh: tests for scripts/release-bump.sh, the scenarios of
# features/release-bump.feature (changes/release-bump/spec.md).
#
# Usage: sh tests/release-bump.test.sh
#
# Every case builds a fixture in a temporary directory: a bare origin, a
# checkout named pap carrying the command, release.sh and the four version
# places at 0.19.1, and stubs of gh, mise and date first on PATH. The gh
# stub keeps one pull request in a state directory; nothing touches the
# network or this repository's origin. Prints one TAP-style line per case
# and exits 1 if any case fails. Needs git and jq.
#
# SC2319: each case passes the exit status of its condition on purpose.
# shellcheck disable=SC2319

set -u
# shellcheck disable=SC1091 # tests/clean-env.sh, sourced from this directory
. "$(dirname "$0")/clean-env.sh"
unset GIT_EDITOR GIT_DIR GIT_WORK_TREE GIT_CONFIG_SYSTEM

here="$(cd "$(dirname "$0")/.." && pwd)"
for tool in git jq; do
  command -v "$tool" >/dev/null 2>&1 || { printf 'Bail out! %s not found\n' "$tool"; exit 1; }
done
real_date="$(command -v date)"
real_git="$(command -v git)"

T="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$T"' EXIT INT TERM
export GIT_CEILING_DIRECTORIES="$T"

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

# The stubs, written once. Each reads its state directory from W, the
# current fixture.
mkdir -p "$T/bin" "$T/hang"
cat >"$T/bin/date" <<STUB
#!/bin/sh
# 2026-11-13T23:30:00Z: the UTC date, and a local date a zone ahead.
case "\$*" in
  '-u +%F') echo 2026-11-13 ;;
  '+%F') echo 2026-11-14 ;;
  *) exec "$real_date" "\$@" ;;
esac
STUB
cat >"$T/bin/mise" <<'STUB'
#!/bin/sh
printf '%s in %s\n' "$*" "$(pwd -P)" >>"$W/mise.log"
case "$*" in
  'run check') echo "check: all good"; exit "$(cat "$W/check-exit" 2>/dev/null || echo 0)" ;;
  'run test')
    printf 'ok 1 - one\nok 2 - two\nok 3 - three\n'
    if [ -e "$W/test-fails" ]; then printf 'not ok 4 - four\n# the last line of the failure\n'; exit 1; fi
    ;;
  *) echo "mise stub: $*" >&2; exit 2 ;;
esac
STUB
cat >"$T/bin/gh" <<'STUB'
#!/bin/sh
# One pull request, its state in $W/gh.
S="$W/gh"
mkdir -p "$S"
printf '%s\n' "$*" >>"$S/log"
env | grep -q '^GH_TOKEN=' && echo "GH_TOKEN set" >>"$S/log"
url=https://github.com/blairforce1/pap/pull/150
labels() { cat "$S/labels" 2>/dev/null; cat "$S/risk" 2>/dev/null; }
case "$1 $2" in
  'pr create')
    if [ -e "$S/create-hang" ]; then
      echo "$$" >"$S/create-pid"
      : >"$S/create-ready"
      if [ -p "$S/fifo" ]; then read -r _ <"$S/fifo"; else sleep 30; fi
      exit 1
    fi
    if [ -e "$S/create-fail" ]; then
      if [ -e "$S/create-move" ]; then
        git -C "$W/origin.git" update-ref "refs/heads/$(cat "$S/create-move")" "$(git -C "$W/origin.git" rev-parse main)"
      fi
      echo "could not create the pull request" >&2
      exit 1
    fi
    shift 2
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --body-file) cp "$2" "$S/body"; shift ;;
        --label) [ -e "$S/drop-label" ] || printf '%s\n' "$2" >>"$S/labels"; shift ;;
        --head) printf '%s\n' "$2" >"$S/head"; shift ;;
        --title) printf '%s\n' "$2" >"$S/title"; printf '%s\n' "$2" >"$S/commits"; shift ;;
        --draft) : >"$S/draft" ;;
        --base) shift ;;
      esac
      shift
    done
    echo "$url"
    ;;
  'pr view')
    [ -e "$S/head" ] || { echo "no pull requests found" >&2; exit 1; }
    case "$3" in "$url" | "$(cat "$S/head")") ;; *) echo "no pull requests found for $3" >&2; exit 1 ;; esac
    jq -n --arg url "$url" --arg head "$(cat "$S/head")" --arg body "$(cat "$S/body")" \
      --argjson draft "$([ -e "$S/draft" ] && echo true || echo false)" \
      --arg labels "$(labels)" --arg commits "$(cat "$S/commits")" \
      '{url: $url, headRefName: $head, isDraft: $draft, state: "OPEN", body: $body,
        labels: [$labels | split("\n")[] | select(. != "") | {name: .}],
        commits: [$commits | split("\n")[] | select(. != "") | {messageHeadline: .}]}'
    ;;
  'pr edit')
    case "$4" in
      --add-label) [ ! -e "$S/edit-label-fail" ] || exit 1; printf '%s\n' "$5" >>"$S/labels" ;;
      --body-file) cp "$5" "$S/body" ;;
    esac
    ;;
esac
exit 0
STUB
# A git that hangs on fetch when $W/hang-fetch exists.
cat >"$T/hang/git" <<STUB
#!/bin/sh
if [ "\$1" = fetch ] && [ -e "\$W/hang-fetch" ]; then echo \$\$ >"\$W/fetch-pid"; exec sleep 60; fi
exec "$real_git" "\$@"
STUB
chmod +x "$T/bin/"* "$T/hang/git"
PATH="$T/bin:$PATH"
export PATH

# fixture [current version]: a fresh origin and checkout at W, the version
# places agreeing on <current> (0.19.1) and the unreleased section holding
# a line.
fixture() {
  W="$T/w$n"
  export W
  rm -rf "$W"
  mkdir -p "$W"
  fv="${1:-0.19.1}"
  git init -q --bare -b main "$W/origin.git"
  git init -q -b main "$W/pap"
  r="$W/pap"
  git -C "$r" config user.name test
  git -C "$r" config user.email test@example.invalid
  git -C "$r" config commit.gpgsign false
  git -C "$r" remote add origin "$W/origin.git"
  mkdir -p "$r/scripts" "$r/plugins/pap/.claude-plugin" "$r/.claude-plugin" "$r/docs"
  cp "$here/scripts/release-bump.sh" "$here/scripts/release.sh" "$r/scripts/"
  [ ! -e "$here/scripts/release-bump-body.txt" ] || cp "$here/scripts/release-bump-body.txt" "$r/scripts/"
  cat >"$r/plugins/pap/.claude-plugin/plugin.json" <<JSON
{
  "name": "pap",
  "version": "$fv",
  "description": "Personal Agentic Process"
}
JSON
  cat >"$r/.claude-plugin/marketplace.json" <<JSON
{
  "name": "blairforce1-pap",
  "plugins": [
    {
      "name": "spec-review",
      "version": "$fv"
    },
    {
      "name": "pap",
      "source": "./plugins/pap",
      "version": "$fv"
    }
  ]
}
JSON
  # shellcheck disable=SC2016 # the prompt's own backticks
  printf 'The install prompt names %s:\n\nInstall pap for me: run `mise use -g %sgithub:blairforce1/pap[asset_pattern=pap-*.tar.gz]@%s%s`, then `pap version`, which must print %s. Then stop.\n\nPinned at %s in another place.\n' \
    "$fv" "'" "$fv" "'" "$fv" "$fv" >"$r/docs/agent-onboarding.md"
  cat >"$r/CHANGELOG.md" <<LOG
# Changelog

## pm-console

### [Unreleased]

### [$fv] - 2026-01-01

## spec-review

### [Unreleased]

- A spec-review line.

## pap

### [Unreleased]

#### Added

- A line for the next release.

### [$fv] - 2026-11-11

- The last release.
LOG
  printf 'other\n' >"$r/README"
  git -C "$r" add -A
  git -C "$r" commit -q -m "the fixture"
  git -C "$r" push -q origin main
  git -C "$r" fetch -q origin
}
B=change/release-0.20.0

# bump [args]: run the command from the checkout, as mise run release-bump
# does; out holds its output, status its exit.
bump() {
  out="$(cd "$W/pap" && RELEASE_BUMP_RISK_WAIT="${RISK_WAIT:-0}" sh scripts/release-bump.sh "$@" 2>&1)"
  status=$?
}
# nothing_made: no work tree, no branch locally or on origin, no pull request.
nothing_made() {
  [ ! -e "$W/pap-release-0.20.0" ] &&
    ! git -C "$W/pap" rev-parse -q --verify "refs/heads/$B" >/dev/null &&
    [ -z "$(git -C "$W/origin.git" for-each-ref "refs/heads/$B")" ] &&
    ! grep -q 'pr create' "$W/gh/log" 2>/dev/null &&
    [ "$(git -C "$W/pap" worktree list | wc -l | tr -d ' ')" = 1 ]
}
refused() { # refused <label> <text the refusal names>
  [ "$status" = 1 ] && printf '%s' "$out" | grep -q -- "$2" && nothing_made
  result $? "$1" "exit $status: $out"
}

ROUTE1="/change release-0.20.0 chore Record: none"
ROUTE2="Rule 20.2: exempt: version bump"
BY="pap:cycle-mechanical on Claude Haiku 5.5"

# release-bump-9: refusals, nothing made.
for v in 0.20 v0.20.0 0.020.0; do
  fixture
  bump "$v"
  refused "release-bump-9: $v is refused as not x.y.z" "is not x.y.z"
done
for v in 0.19.1 0.9.0; do
  fixture
  bump "$v"
  refused "release-bump-9: $v is refused as not above 0.19.1" "is not above 0.19.1"
done
fixture
git -C "$W/pap" remote set-url origin "$W/no-such-origin.git"
bump 0.20.0
refused "release-bump-9: an origin that cannot be fetched is refused" "the fetch of origin/main"
fixture
sed 's/"version": "0.19.1"$/"version": "0.19.0"/' "$W/pap/.claude-plugin/marketplace.json" >"$W/m" &&
  mv "$W/m" "$W/pap/.claude-plugin/marketplace.json"
git -C "$W/pap" commit -qam "marketplace at 0.19.0" && git -C "$W/pap" push -q origin main
bump 0.20.0
refused "release-bump-9: version places that disagree are refused, naming each" \
  "plugin.json names 0.19.1, marketplace.json names 0.19.0, the install prompt installs 0.19.1 and prints 0.19.1"
fixture
awk '/^## pap/ { p = 1 } p && /^#### Added/ { skip = 1 } p && /^### \[0.19.1\]/ { skip = 0 } !skip' \
  "$W/pap/CHANGELOG.md" >"$W/c" && mv "$W/c" "$W/pap/CHANGELOG.md"
git -C "$W/pap" commit -qam "empty unreleased" && git -C "$W/pap" push -q origin main
bump 0.20.0
refused "release-bump-9: an empty unreleased section is refused" "unreleased section under '## pap' is empty"
fixture
git -C "$W/pap" push -q origin "main:refs/heads/$B"
bump 0.20.0
[ "$status" = 1 ] && printf '%s' "$out" | grep -q "$B exists on origin" &&
  [ ! -e "$W/pap-release-0.20.0" ] && ! grep -q 'pr create' "$W/gh/log" 2>/dev/null
result $? "release-bump-9: a branch on origin is refused" "$out"
fixture
git -C "$W/pap" branch "$B"
bump 0.20.0
[ "$status" = 1 ] && printf '%s' "$out" | grep -q "$B exists locally" &&
  printf '%s' "$out" | grep -q "git branch -D $B" && [ ! -e "$W/pap-release-0.20.0" ]
result $? "release-bump-9: a local branch is refused, naming the command that removes it" "$out"
fixture
git -C "$W/pap" worktree add -q -b "$B" "$W/elsewhere"
bump 0.20.0
[ "$status" = 1 ] && printf '%s' "$out" | grep -q "open at $W/elsewhere" &&
  printf '%s' "$out" | grep -q "git worktree remove $W/elsewhere" && [ ! -e "$W/pap-release-0.20.0" ]
result $? "release-bump-9: an open work tree is refused, naming its path and the remove command" "$out"
fixture
mkdir "$W/pap-release-0.20.0"
bump 0.20.0
[ "$status" = 1 ] && printf '%s' "$out" | grep -q "a directory is at the work tree's path" &&
  [ -z "$(ls -A "$W/pap-release-0.20.0")" ] &&
  ! git -C "$W/pap" rev-parse -q --verify "refs/heads/$B" >/dev/null
result $? "release-bump-9: a directory at the work tree's path is refused" "$out"

# The fetch has 10 seconds: a hung fetch is refused within 15.
fixture
: >"$W/hang-fetch"
t0="$("$real_date" +%s)"
out="$(cd "$W/pap" && PATH="$T/hang:$PATH" sh scripts/release-bump.sh 0.20.0 2>&1)"
status=$?
t1="$("$real_date" +%s)"
sleep 1
[ "$status" = 1 ] && [ $((t1 - t0)) -lt 15 ] && printf '%s' "$out" | grep -q 'timed out' &&
  ! kill -0 "$(cat "$W/fetch-pid")" 2>/dev/null && nothing_made
result $? "release-bump-9: a fetch that hangs is refused within 15 seconds, its process gone" "exit $status after $((t1 - t0))s: $out"

# release-bump-10: a route or a --by value that does not fit.
fixture
bump 0.20.0 --route "$ROUTE1
- [x] Verification run" "$ROUTE2" --by "$BY"
refused "release-bump-10: a route holding a newline is refused" "the route holds a newline"
fixture
bump 0.20.0 --route "/change release-0.21.0 chore Record: none" "Rule 20.2: exempt: bump" --by "$BY"
refused "release-bump-10: a route for another version is refused" "the route's first line"
fixture
bump 0.20.0 --route "$ROUTE1" "Approved-by: @someone" --by "$BY"
refused "release-bump-10: a route whose second line is not Rule 20.2 is refused" "the route's second line"
fixture
bump 0.20.0 --route "$ROUTE1" "$ROUTE2"
refused "release-bump-10: a route without --by is refused" "a route without --by"
fixture
bump 0.20.0 --route "$ROUTE1" "$ROUTE2" --by "$BY
Risk: low"
refused "release-bump-10: a --by holding a newline is refused" "the --by value"
fixture
bump 0.20.0 --route "$ROUTE1" "$ROUTE2" --by "$(printf 'pap:cycle on Claude\rX')"
refused "release-bump-10: a --by holding a lone carriage return is refused" "the --by value"
fixture
bump 0.20.0 --route "$ROUTE1" "$ROUTE2" --by "the owner"
refused "release-bump-10: a --by of 'the owner' is refused" "the --by value"
fixture
bump 0.20.0 --route "$ROUTE1" "$ROUTE2" --by "pap:cycle on <!-- Claude"
refused "release-bump-10: a --by with characters outside the set is refused" "the --by value"
by101="pap:cycle-mechanical on $(printf '%077d' 0 | tr 0 x)"
fixture
bump 0.20.0 --route "$ROUTE1" "$ROUTE2" --by "$by101"
[ "${#by101}" = 101 ]
refused "release-bump-10: a --by of 101 bytes is refused" "longer than 100 bytes"

# release-bump-11: hooks switched off through the environment.
fixture
out="$(cd "$W/pap" && GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hookspath GIT_CONFIG_VALUE_0=/dev/null \
  sh scripts/release-bump.sh 0.20.0 2>&1)"
status=$?
refused "release-bump-11: GIT_CONFIG_COUNT with core.hooksPath is refused" "GIT_CONFIG_COUNT"
fixture
out="$(cd "$W/pap" && GIT_CONFIG_PARAMETERS="'core.hookspath'='/dev/null'" sh scripts/release-bump.sh 0.20.0 2>&1)"
status=$?
refused "release-bump-11: GIT_CONFIG_PARAMETERS is refused" "GIT_CONFIG_PARAMETERS"
fixture
out="$(cd "$W/pap" && GIT_DIR="$W/pap/.git" sh scripts/release-bump.sh 0.20.0 2>&1)"
status=$?
refused "release-bump-11: GIT_DIR is refused" "GIT_DIR"
fixture
git -C "$W/pap" config core.hooksPath "$W/other-hooks"
bump 0.20.0
refused "release-bump-11: a hooks path other than the repository's own is refused" "not the repository's own hooks"

# A run that goes through. WT is the work tree it makes.
WT_NAME=pap-release-0.20.0
fixture
bump 0.20.0
WT="$W/$WT_NAME"
base="$(git -C "$W/pap" rev-parse origin/main)"
[ "$status" = 0 ] && [ -d "$WT" ]
result $? "a run for 0.20.0 exits 0 and makes its work tree" "exit $status: $out"

# release-bump-2: exactly the release bump's lines.
names="$(git -C "$WT" diff --name-only "$base" HEAD | tr '\n' ' ')"
[ "$names" = ".claude-plugin/marketplace.json CHANGELOG.md docs/agent-onboarding.md plugins/pap/.claude-plugin/plugin.json " ]
result $? "release-bump-2: the bump changes the four files and no other" "$names"
git -C "$WT" diff -U0 "$base" HEAD | grep -E '^[-+]' | grep -vE '^(\+\+\+|---) ' >"$W/lines"
want_lines() {
  printf '%s\n' '-      "version": "0.19.1"' '+      "version": "0.20.0"' '-  "version": "0.19.1",' '+  "version": "0.20.0",'
  # shellcheck disable=SC2016 # the prompt's own backticks
  printf -- "-Install pap for me: run \`mise use -g 'github:blairforce1/pap[asset_pattern=pap-*.tar.gz]@0.19.1'\`, then \`pap version\`, which must print 0.19.1. Then stop.\n"
  # shellcheck disable=SC2016
  printf -- "+Install pap for me: run \`mise use -g 'github:blairforce1/pap[asset_pattern=pap-*.tar.gz]@0.20.0'\`, then \`pap version\`, which must print 0.20.0. Then stop.\n"
  printf '%s\n' '+### [0.20.0] - 2026-11-13' '+'
}
[ "$(want_lines | LC_ALL=C sort)" = "$(LC_ALL=C sort "$W/lines")" ]
result $? "release-bump-2: the diff is the version places at 0.20.0, the dated heading and one blank line" "$(cat "$W/lines")"
git -C "$WT" show HEAD:.claude-plugin/marketplace.json | jq -e '.plugins[] | select(.name == "spec-review") | .version == "0.19.1"' >/dev/null &&
  git -C "$WT" show HEAD:docs/agent-onboarding.md | grep -q 'Pinned at 0.19.1 in another place.'
result $? "release-bump-2: no other version string has changed"

# release-bump-3: dated in UTC, under "## pap" only.
section() { git -C "$WT" show "$1:CHANGELOG.md" | awk -v s="$2" '/^## / { p = ($0 == s) } p'; }
[ "$(section HEAD '## pap')" = "## pap

### [Unreleased]

### [0.20.0] - 2026-11-13

#### Added

- A line for the next release.

### [0.19.1] - 2026-11-11

- The last release." ]
result $? "release-bump-3: the unreleased section is dated 2026-11-13, the UTC date, under an empty one" "$(section HEAD '## pap')"
[ "$(section HEAD '## pm-console')" = "$(section "$base" '## pm-console')" ] &&
  [ "$(section HEAD '## spec-review')" = "$(section "$base" '## spec-review')" ]
result $? "release-bump-3: the pm-console and spec-review sections are unchanged"

# release-bump-4: the head passes release.sh's four conditions.
o="$(cd "$WT" && sh scripts/release.sh --places-at HEAD 0.20.0 2>&1)"
result $? "release-bump-4: release.sh --places-at HEAD 0.20.0 passes in the work tree" "$o"

# release-bump-20: compared number by number.
for row in 0.19.1:0.19.10 0.19.1:0.100.0 0.19.1:1.0.0 0.9.9:0.10.0; do
  cur="${row%%:*}" new="${row#*:}"
  fixture "$cur"
  bump "$new"
  o="$(cd "$W/pap-release-$new" 2>/dev/null && sh scripts/release.sh --places-at HEAD "$new" 2>&1)"
  [ "$status" = 0 ] && [ -n "$o" ] && [ "$(git -C "$W/pap-release-$new" show HEAD:docs/agent-onboarding.md | grep -c "must print $new")" = 1 ]
  result $? "release-bump-20: from $cur, $new is taken and the version places agree on it" "exit $status: $out $o"
done

printf '1..%d\n' "$n"
[ "$failed" = 0 ]
