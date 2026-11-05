#!/bin/sh
# accept.test.sh: tests for plugins/pap/skills/accept/accept.sh, the script
# behind /pap:accept.
#
# Usage: sh tests/accept.test.sh
#
# Builds a bare origin and a clone in a temporary directory, with decision
# records on main and one only on a local branch, and puts a fake gh on
# PATH that answers `api user` and records `pr create`. Covers each
# refusal (nothing written, no branch), and acceptance: only the Status
# line changes, on a new change/accept-<ids> branch pushed to origin, with
# a draft class:docs pull request. Prints one TAP-style line per case and
# exits 1 if any case fails. Needs git; no network; touches nothing outside
# the temporary directory.
#
# SC2319: each case passes the exit status of its condition on purpose.
# shellcheck disable=SC2319

set -u

here="$(cd "$(dirname "$0")/.." && pwd)"
script="$here/plugins/pap/skills/accept/accept.sh"

command -v git > /dev/null 2>&1 || { printf 'Bail out! git not found\n'; exit 1; }

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

mkdir "$T/stub"
cat > "$T/stub/gh" << 'EOF'
#!/bin/sh
echo "gh $*" >> "$FAKE_LOG"
case "$1 $2" in
  "api user") echo example-lead ;;
  "pr create")
    while [ $# -gt 0 ]; do
      [ "$1" = --body-file ] && cp "$2" "$FAKE_BODY"
      shift
    done
    echo https://github.com/example/repo/pull/9 ;;
  *) echo "fake gh: unexpected $*" >&2; exit 1 ;;
esac
EOF
chmod +x "$T/stub/gh"
export FAKE_LOG="$T/gh.log" FAKE_BODY="$T/body.md"
PATH="$T/stub:$PATH"
export PATH
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

# record <id> <status>: a decision record in the shape PAP's take.
record() {
  cat > "decisions/$1-example-$1.md" << EOF
# $1. An example decision

- **Status:** $2
- **Date:** 2026-01-01
- **Revisit:** when it is wrong

## Context

Nothing proposed here is real.

## Decision

1. **The first rule holds.** It says what it
   means, over two lines.
2. **The second
   rule wraps.** And so on.

## Consequences

- **Status:** proposed is quoted here and must not change.
EOF
}

git init -q --bare -b main "$T/origin.git"
git clone -q "$T/origin.git" "$T/repo" 2> /dev/null
cd "$T/repo" || exit 1
git config user.name test
git config user.email test@example.invalid
git config commit.gpgsign false
mkdir decisions .github
echo '/decisions/** @example-lead' > .github/CODEOWNERS
record 0001 proposed
record 0002 proposed
record 0003 accepted
record 0004 'measured:confirmed (2026-02-01)'
git add decisions .github
git commit -q -m records
git push -q origin main
# 0005 exists only on a branch that has not merged.
git checkout -q -b change/new-record
record 0005 proposed
git add decisions
git commit -q -m 'a new record'
git checkout -q main

run() { : > "$FAKE_LOG"; out="$(sh "$script" "$@" 2>&1)"; rc=$?; }
branches() { git for-each-ref --format='%(refname:short)' 'refs/heads/change/accept-*' 'refs/remotes/origin/change/accept-*'; }
clean() { [ -z "$(branches)" ] && [ ! -s "$FAKE_LOG" ] && [ -z "$(git status --porcelain)" ]; }

run
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q '^refused: usage' && clean
result $? "no ids: usage, nothing written" "exit $rc; $out"
run 18
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q "'18' is not a four-digit record number" && clean
result $? "an id that is not four digits is refused" "exit $rc; $out"
run '0001;id'
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q 'is not a four-digit record number' && clean
result $? "an id with a shell character is refused before any use" "exit $rc; $out"
run 0099
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q '^refused: no decision record 0099' && clean
result $? "an unknown id is refused, nothing written" "exit $rc; $out"
run 0003
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q "^refused: decision 0003 is 'accepted', not proposed" && clean
result $? "an accepted record is refused, nothing written" "exit $rc; $out"
run 0004
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q "decision 0004 is 'measured:confirmed (2026-02-01)', not proposed" && clean
result $? "a measured record is refused" "exit $rc; $out"
run 0005
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q '^refused: decision 0005 is not on main yet' && clean
result $? "a record not on the default branch is refused" "exit $rc; $out"
run 0001 0003
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q 'decision 0003' && clean
result $? "one bad id among several: none is accepted" "exit $rc; $out"

# Acceptance, ids passed as one word as the skill passes them.
day="$(date +%Y-%m-%d)"
run "0002 0001"
wt="$T/repo-accept-0001-0002"
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q '^Opened https://github.com/example/repo/pull/9 (draft) from change/accept-0001-0002'
result $? "accepts: prints the pull request URL" "exit $rc; $out"
printf '%s' "$out" | grep -q '^  0001\. An example decision' &&
  printf '%s' "$out" | grep -q '^    - The first rule holds\.' &&
  printf '%s' "$out" | grep -q '^    - The second rule wraps\.'
result $? "shows each title and the Decision items' leads" "$out"
[ "$(git -C "$wt" branch --show-current)" = change/accept-0001-0002 ] &&
  git ls-remote --exit-code "$T/origin.git" refs/heads/change/accept-0001-0002 > /dev/null
result $? "commits on change/accept-0001-0002, pushed to origin"
diff="$(git -C "$wt" diff -U0 origin/main HEAD -- decisions | grep '^[-+]' | grep -v '^\(---\|+++\) ')"
expect="$(printf -- '-- **Status:** proposed\n+- **Status:** accepted (example-lead, %s)\n' "$day")"
[ "$diff" = "$(printf '%s\n%s' "$expect" "$expect")" ] &&
  [ "$(git -C "$wt" diff --name-only origin/main HEAD | sort | tr '\n' ' ')" = "decisions/0001-example-0001.md decisions/0002-example-0002.md " ]
result $? "rewrites only the Status line of each record" "$diff"
grep -q '^- \*\*Status:\*\* proposed is quoted here' "$wt/decisions/0001-example-0001.md"
result $? "a later line that starts like the Status line is untouched"
[ "$(git -C "$wt" log -1 --format=%s)" = "docs(decisions): accept 0001, 0002" ]
result $? "commit subject names the ids" "$(git -C "$wt" log -1 --format=%s)"
grep -q -- '--draft --title docs(decisions): accept 0001, 0002 --body-file .* --label class:docs$' "$FAKE_LOG" &&
  ! grep -q 'owner-reviewed\|merge\|pr ready' "$FAKE_LOG"
result $? "opens a draft class:docs pull request, adds no other label, merges nothing" "$(cat "$FAKE_LOG")"
grep -q '^Change: none$' "$FAKE_BODY" && grep -q '^Record: none$' "$FAKE_BODY" &&
  grep -q '^- \[ \] No protected path touched' "$FAKE_BODY" && grep -q '^Head to approve: [0-9a-f]\{7\}$' "$FAKE_BODY" &&
  ! grep -q '^Approved-by:' "$FAKE_BODY"
result $? "body: protected-path box unticked with the head to approve, no Approved-by line" "$(cat "$FAKE_BODY")"

# The branch now exists: a second run for the same ids is refused.
git -C "$wt" checkout -q --detach
run 0001 0002
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q '^refused: change/accept-0001-0002 already exists' && [ ! -s "$FAKE_LOG" ]
result $? "an existing accept branch is refused" "exit $rc; $out"

# Risk mode: decisions/** is fixed high, so the box says so.
cd "$T/repo" || exit 1
printf 'default: low\n' > .github/risk.yml
git add .github/risk.yml
git commit -q -m 'risk mode'
git push -q origin main
run 0001
[ "$rc" = 0 ] && grep -q '^Risk: high; the owner adds owner-reviewed after review$' "$FAKE_BODY" &&
  ! grep -q '^Head to approve' "$FAKE_BODY"
result $? "risk mode: box unticked with Risk: high" "exit $rc; $out; $(cat "$FAKE_BODY")"

printf '1..%d\n' "$n"
[ "$failed" = 0 ]
