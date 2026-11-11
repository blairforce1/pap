#!/bin/sh
# plugin-agents.test.sh: the pap plugin's agent definitions parse
# (decision 0024).
#
# Usage: sh tests/plugin-agents.test.sh
#
# For each expected file in plugins/pap/agents/, checks the frontmatter
# opens on line 1 and closes, carries `name` matching the file name,
# `tools` and `model`, that the reviewer has no Edit, Write or Agent, and
# that the reviewer and /change step 5 give /code-review the same args and
# the same fixed first lines.
# Nothing in CI runs `claude plugin validate`, so this is the structure
# check. Prints one TAP-style line per case and exits 1 if any fails. No
# network; touches nothing.

# SC2319: each case passes the exit status of its condition on purpose.
# SC2016: the backticks in the pinned texts are literal markdown.
# shellcheck disable=SC2319,SC2016

set -u
# shellcheck disable=SC1091 # tests/clean-env.sh, sourced from this directory
. "$(dirname "$0")/clean-env.sh"

here="$(cd "$(dirname "$0")/.." && pwd)"
dir="$here/plugins/pap/agents"

n=0
failed=0
result() { # result <ok 0|1> <label>
  n=$((n + 1))
  if [ "$1" = 0 ]; then
    printf 'ok %d - %s\n' "$n" "$2"
  else
    printf 'not ok %d - %s\n' "$n" "$2"
    failed=$((failed + 1))
  fi
}

# field <file> <key>: the key's value from the frontmatter, empty if none.
field() {
  awk -v k="$2" 'NR == 1 && $0 != "---" { exit } NR > 1 && $0 == "---" { exit }
    NR > 1 && index($0, k ": ") == 1 { print substr($0, length(k) + 3); exit }' "$1"
}

for a in cycle cycle-mechanical reviewer; do
  f="$dir/$a.md"
  if [ ! -f "$f" ]; then
    result 1 "$a: file exists"
    continue
  fi
  closes=$(awk 'NR == 1 && $0 == "---" { o = 1; next } o && $0 == "---" { print "y"; exit }' "$f")
  [ "$closes" = y ]
  result $? "$a: frontmatter opens and closes"
  [ "$(field "$f" name)" = "$a" ]
  result $? "$a: name is $a"
  [ -n "$(field "$f" tools)" ]
  result $? "$a: tools present"
  [ -n "$(field "$f" model)" ]
  result $? "$a: model present"
done

tools=$(field "$dir/reviewer.md" tools)
case ", $tools," in
  *", Edit,"* | *", Write,"* | *", Agent,"*) result 1 "reviewer: no Edit, Write or Agent" ;;
  *) [ -n "$tools" ]; result $? "reviewer: no Edit, Write or Agent" ;;
esac

# The reviewer starts in its launcher's directory, where a `cd` does not
# carry and /code-review runs too, so the args must name the worktree's
# diff outright. The agent and /change step 5 give the same args and the
# same fixed first lines; a run that fell back must not read as a review.
skill="$here/plugins/pap/skills/change/SKILL.md"
# has <file> <text>: the text is in the file, line breaks read as spaces.
has() { tr '\n' ' ' <"$1" | tr -s ' ' | grep -qF -- "$2"; }
for f in "$dir/reviewer.md" "$skill"; do
  b=$(basename "$f")
  has "$f" 'args `low git -C <worktree> diff origin/main...HEAD`'
  result $? "$b: /code-review is given the worktree's diff command"
  ! has "$f" 'args `low <worktree>`'
  result $? "$b: /code-review is not given the bare worktree path"
  has "$f" '`/code-review low: reviewed the diff`'
  result $? "$b: fixed first line for a review that saw the diff"
  has "$f" '/code-review FELL BACK:'
  result $? "$b: fixed first line for a fallback"
  for why in 'skill not available' 'no result returned' 'saw an empty diff'; do
    has "$f" "$why"
    result $? "$b: fallback reason '$why'"
  done
done
has "$skill" "Verification gets one row: the review ran, the reviewer's first line word for word"
result $? "SKILL.md: the Verification row carries the reviewer's first line"
has "$dir/reviewer.md" 'or is `(none)` alone, its word for no findings'
result $? "reviewer: a bare (none) from /code-review is a review, not a fallback"
has "$dir/reviewer.md" 'Where it exists, call it'
result $? "reviewer: calls /code-review where it exists"
has "$dir/reviewer.md" 'do not report before the result has arrived'
result $? "reviewer: waits for a /code-review launched in the background"

[ "$(field "$dir/cycle-mechanical.md" model)" = haiku ]
result $? "cycle-mechanical: model is haiku"

printf '1..%d\n' "$n"
[ "$failed" = 0 ]
