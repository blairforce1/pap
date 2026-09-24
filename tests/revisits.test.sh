#!/bin/sh
# revisits.test.sh: tests for bin/pap revisits (decision 0010).
#
# Usage: sh tests/revisits.test.sh
#
# Builds a repository in a temporary directory with one record per trigger
# form and a tag, and runs pap revisits with a stub gh on PATH that prints
# merged pull requests from a fixture, as the real command's --jq filter
# would: number, head branch, merge time in epoch seconds. Prints one
# TAP-style line per case and exits 1 if any case fails. Needs git; touches
# nothing outside the temporary directory.
#
# SC2319: each case passes the exit status of its condition on purpose.
# shellcheck disable=SC2319

set -u

here="$(cd "$(dirname "$0")/.." && pwd)"
pap="$here/bin/pap"

command -v git >/dev/null 2>&1 || { printf 'Bail out! git not found\n'; exit 1; }

T="$(mktemp -d)"
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
g() { git -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false -c tag.gpgsign=false "$@"; }

# record <id> <status> <introduced in> <revisit>
record() {
  cat > "$T/repo/decisions/$1-case.md" <<REC
# $1. A case

- **Status:** $2
- **Introduced in:** $3
- **Revisit:** $4

## Context
REC
}

mkdir -p "$T/repo/decisions" "$T/stub"
git init -q -b main "$T/repo"
record 0001 accepted unreleased "after 3 change PRs from #10: counted from a pull request"
record 0002 accepted unreleased "after 5 change PRs from #10: not yet"
record 0003 accepted v1.0.0 "after 2 change PRs: counted from the Introduced-in tag"
record 0004 accepted v1.0.0 "when something outside happens"
record 0005 accepted unreleased "on 2000-01-01: long past"
record 0006 accepted unreleased "on 2999-01-01: far off"
record 0007 "measured:refuted (2026-09-24)" unreleased "after 1 change PRs from #10: measured already"
record 0008 accepted unreleased "if something happens, in prose"
record 0009 accepted unreleased "after 1 change PRs: no tag and no start"
record 0010 accepted v9.9.9 "after 1 change PRs: a tag that does not exist"
record 0011 accepted unreleased "after 1 change PRs from #99: not a merged pull request"
g -C "$T/repo" add -A
GIT_COMMITTER_DATE="@2000 +0000" g -C "$T/repo" commit -qm records
g -C "$T/repo" tag v1.0.0

# #10 merges at 1000; the tag's commit is at 2000. Before #10: #9. Between:
# #11, and #12 from a non-change branch. After the tag: #13, #14.
cat > "$T/prs" <<'PRS'
9	change/before	900
10	change/start	1000
11	change/between	1500
12	renovate/deps	1600
13	change/after-tag	2500
14	change/also-after	3000
PRS
cat > "$T/stub/gh" <<STUB
#!/bin/sh
[ -f "$T/gh-fails" ] && { echo "not logged in" >&2; exit 4; }
cat "$T/prs"
STUB
chmod +x "$T/stub/gh"

run() { (cd "$T/repo" && PATH="$T/stub:$PATH" sh "$pap" revisits 2>&1); }
out="$(run)"; rc=$?
line() { printf '%s\n' "$out" | grep "^$1 "; }

[ "$rc" = 0 ] && [ "$(printf '%s\n' "$out" | wc -l)" -eq 11 ]
result $? "one line per record, exit 0" "$out"
[ "$(line 0001)" = "0001 due (3 of 3 change PRs since #10)" ]
result $? "from #<pr>: counts change/ branches merged after it, and is due at n" "$(line 0001)"
[ "$(line 0002)" = "0002 not due (3 of 5 change PRs since #10)" ]
result $? "from #<pr>: not due below n, with the count" "$(line 0002)"
[ "$(line 0003)" = "0003 due (2 of 2 change PRs since v1.0.0)" ]
result $? "no from: counts from the Introduced-in tag" "$(line 0003)"
[ "$(line 0004)" = "0004 manual (when something outside happens)" ]
result $? "when: manual" "$(line 0004)"
[ "$(line 0005)" = "0005 due (on 2000-01-01)" ] && [ "$(line 0006)" = "0006 not due (on 2999-01-01)" ]
result $? "on <date>: due once the date is reached" "$(line 0005; line 0006)"
[ "$(line 0007)" = "0007 closed (measured:refuted (2026-09-24))" ]
result $? "a measured record is closed" "$(line 0007)"
line 0008 | grep -q '^0008 unknown (Revisit is not in the typed form'
result $? "an untyped trigger is reported, not guessed" "$(line 0008)"
line 0009 | grep -q "^0009 unknown (introduced in 'unreleased', not a tag"
result $? "no tag and no from: unknown" "$(line 0009)"
line 0010 | grep -q '^0010 unknown (no tag v9.9.9 here'
result $? "a missing tag: unknown" "$(line 0010)"
[ "$(line 0011)" = "0011 unknown (#99 is not a merged pull request)" ]
result $? "a start that never merged: unknown" "$(line 0011)"

touch "$T/gh-fails"
out="$(run)"; rc=$?
[ "$rc" = 0 ] && [ "$(line 0001)" = "0001 unknown (gh: not logged in)" ] &&
  [ "$(line 0004)" = "0004 manual (when something outside happens)" ]
result $? "gh failing: counted records unknown, the rest still reported, exit 0" "$out"
rm "$T/gh-fails"

long="when $(printf '%070d' 0)"
record 0001 accepted unreleased "$long"
out="$(run)"
[ "$(line 0001)" = "0001 manual (when $(printf '%055d' 0)...)" ]
result $? "a long condition is cut at 60 characters" "$(line 0001)"

out="$(cd "$T" && sh "$pap" revisits 2>&1)"; rc=$?
[ "$rc" = 0 ]
result $? "outside a repository: says so, exit 0" "$out"

printf '1..%d\n' "$n"
[ "$failed" -eq 0 ]
