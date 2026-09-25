#!/bin/sh
# measure.test.sh: tests for bin/pap measure (decisions 0001, 0002, 0004).
#
# Usage: sh tests/measure.test.sh
#
# Builds a repository in a temporary directory with records to measure, and
# runs pap measure with a stub gh on PATH that prints change pull requests
# from a fixture, as the real command's --jq filter would: number, state,
# created, merged, closed and last ready_for_review in epoch seconds, class
# label, reviews, changes requested, failed pr-checks runs, title and body
# with its newlines escaped. Prints one TAP-style line per case and exits 1
# if any case fails. Needs git; touches nothing outside the temporary
# directory.
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

# record <id> <introduced in> <revisit>
record() {
  cat > "$T/repo/decisions/$1-case.md" <<REC
# $1. A case

- **Status:** accepted
- **Introduced in:** $2
- **Revisit:** $3

## Context
REC
}

mkdir -p "$T/repo/decisions" "$T/stub"
git init -q -b main "$T/repo"
record 0001 unreleased "after 10 change PRs from #5: counted from a pull request"
record 0002 v1.0.0 "after 10 change PRs: counted from the tag"
record 0003 unreleased "when something outside happens"
record 0004 unreleased "after 10 change PRs from #99: never merged"
g -C "$T/repo" add -A
GIT_COMMITTER_DATE="@100000 +0000" g -C "$T/repo" commit -qm records
g -C "$T/repo" tag v1.0.0

cat > "$T/stub/gh" <<STUB
#!/bin/sh
[ -f "$T/gh-fails" ] && { echo "not logged in" >&2; exit 4; }
cat "$T/prs"
STUB
chmod +x "$T/stub/gh"

tab="$(printf '\t')"
# pr <number> <state> <created> <merged> <closed> <ready> <class> <reviews>
#    <changes> <fails> <title> <body>: one fixture line, times in minutes.
pr() {
  s() { [ -z "$1" ] || printf '%s' "$(($1 * 60))"; }
  printf '%s\n' "$1$tab$2$tab$(s "$3")$tab$(s "$4")$tab$(s "$5")$tab$(s "$6")$tab$7$tab$8$tab$9$tab${10}$tab${11}$tab${12}"
}
ok_body='## Checks\n- [x] Verification\n- [x] Generated content carries provenance\n\nProvenance: a model'

# Four before #5, the start; twelve after it, of which ten count. #6 was a
# draft for 3 minutes; #7 never was, left a box unexplained and has no
# Provenance line; #8 explains its box; #9 has no Checks section and no
# class label. Closed: #30 a scratch scope, #31 "do not merge", #32 a real
# rejection, #33 outside the span.
{
  for i in 1 2 3 4; do pr "$i" MERGED $((i * 100)) $((i * 100 + 2)) $((i * 100 + 2)) $((i * 100 + 1)) chore 0 0 "" "chore: $i" "$ok_body"; done
  pr 5 MERGED 500 505 505 504 infra 0 0 0 "process: the start" "$ok_body"
  pr 6 MERGED 600 610 610 603 feature 2 1 0 "feat: six" "$ok_body"
  pr 7 MERGED 700 704 704 "" bugfix 0 0 2 "fix: seven" '## Checks\n- [ ] Verification\n\n- [x] Generated content carries provenance\n<!-- - [ ] a box in a comment -->\n## After'
  pr 8 MERGED 800 801 801 800 docs 0 0 1 "docs: eight" '## Checks\n- [ ] Verification\n      no mise here\n- [x] Generated content carries provenance\nProvenance: a model'
  pr 9 MERGED 900 901 901 900 "" 0 0 "" "feat(cli)!: nine" 'no template'
  for i in 10 11 12 13 14 15 16 17; do pr "$i" MERGED $((i * 100)) $((i * 100 + 1)) $((i * 100 + 1)) $((i * 100)) chore 0 0 0 "chore: $i" "$ok_body"; done
  pr 30 CLOSED 1000 "" 1002 "" chore 0 0 "" "chore(scratch): preview" ""
  pr 31 CLOSED 1100 "" 1102 "" spike 0 0 "" "chore: preview" 'Do not merge.'
  pr 32 CLOSED 1200 "" 1202 "" feature 0 0 "" "feat: turned down" "$ok_body"
  pr 33 CLOSED 5000 "" 5002 "" feature 0 0 "" "feat: long after" "$ok_body"
} > "$T/prs"

run() { (cd "$T/repo" && PATH="$T/stub:$PATH" sh "$pap" measure "$@" 2>&1); }
out="$(run 0001)"; rc=$?
row() { printf '%s\n' "$out" | awk -F '\t' -v p="$1" '$1 == p'; }
col() { row "$1" | cut -f"$2"; }

[ "$rc" = 0 ] && [ "$(printf '%s\n' "$out" | head -n 1)" = "pr${tab}window${tab}class${tab}open_min${tab}draft_min${tab}reviews${tab}changes_requested${tab}checks_unticked_unexplained${tab}provenance_declared${tab}pr_checks_failures" ]
result $? "a header row, exit 0" "$out"
[ "$(printf '%s\n' "$out" | awk -F '\t' '$2 == "before" { print $1 }' | tr '\n' ' ')" = "1 2 3 4 " ] &&
  printf '%s\n' "$out" | grep -qx '# before: 4 of 10, short'
result $? "a short before window is named short and not padded" "$out"
[ "$(printf '%s\n' "$out" | awk -F '\t' '$2 == "after" { print $1 }' | tr '\n' ' ')" = "6 7 8 9 10 11 12 13 14 15 " ] &&
  printf '%s\n' "$out" | grep -qx '# after: 10 of 10' && [ -z "$(row 5)" ]
result $? "after is the first ten, the start in neither window" "$out"
[ "$(col 6 4)" = "10.0" ] && [ "$(col 6 5)" = "3.0" ] && [ "$(col 7 4)" = "4.0" ] && [ "$(col 7 5)" = "" ]
result $? "open_min from created to merged; draft_min only for a draft" "$(row 6; row 7)"
[ "$(col 6 6)" = 2 ] && [ "$(col 6 7)" = 1 ] && [ "$(col 7 10)" = 2 ] && [ "$(col 1 10)" = "" ]
result $? "reviews, changes requested and pr-checks failures pass through; no runs is empty" "$(row 6; row 7; row 1)"
[ "$(col 7 8)" = 1 ] && [ "$(col 8 8)" = 0 ] && [ "$(col 6 8)" = 0 ] && [ "$(col 9 8)" = "" ]
result $? "an unticked box with no reason counts, one with a reason does not, no Checks is empty" "$(row 6; row 7; row 8; row 9)"
[ "$(col 6 9)" = 1 ] && [ "$(col 7 9)" = 0 ]
result $? "provenance_declared reads the Provenance line" "$(row 6; row 7)"
[ "$(col 9 3)" = "none (feat)" ] && [ "$(col 6 3)" = feature ]
result $? "class: the label, else the title type in brackets" "$(row 9)"
[ "$(printf '%s\n' "$out" | tail -n 1)" = "# closed unmerged in the span, scratch excluded: #32" ]
result $? "rejections: scratch scope and do-not-merge excluded, outside the span not counted" "$(printf '%s\n' "$out" | tail -n 1)"

out="$(run 0002)"
[ "$(printf '%s\n' "$out" | awk -F '\t' '$2 == "before" { print $1 }' | tr '\n' ' ')" = "7 8 9 10 11 12 13 14 15 16 " ] &&
  [ "$(printf '%s\n' "$out" | awk -F '\t' '$2 == "after" { print $1 }')" = 17 ] &&
  printf '%s\n' "$out" | grep -qx '# after: 1 of 10, short'
result $? "no from: the Introduced-in tag is the start" "$out"
out="$(run 0001 --from '#12')"
[ "$(printf '%s\n' "$out" | awk -F '\t' '$2 == "after" { print $1 }' | tr '\n' ' ')" = "13 14 15 16 17 " ]
result $? "--from #<pr> overrides the Revisit line's start" "$out"
out="$(run 0003)"; rc=$?
[ "$rc" = 0 ] && [ "$out" = "0003 cannot be measured: its Revisit line does not count change PRs (decision 0010)" ]
result $? "a when trigger cannot be measured, exit 0" "$out"
out="$(run 0004)"; rc=$?
[ "$rc" = 0 ] && [ "$out" = "0004 cannot be measured: #99 is not a merged change pull request" ]
result $? "a start that never merged cannot be measured, exit 0" "$out"
touch "$T/gh-fails"
out="$(run 0001)"; rc=$?
[ "$rc" = 0 ] && [ "$out" = "0001 cannot be measured (gh: not logged in)" ]
result $? "gh failing: says so, exit 0" "$out"
rm "$T/gh-fails"
out="$(run 0001 --verdict open_min down)"; rc=$?
[ "$rc" = 0 ] && [ "$out" = "cannot run (open_min: 4 before and 10 after, 0001 needs ten a side)" ]
result $? "fewer than ten before: cannot run, exit 0" "$out"
(cd "$T/repo" && PATH="$T/stub:$PATH" sh "$pap" measure 0001 --verdict open_min sideways >/dev/null 2>&1); rc=$?
[ "$rc" = 64 ]
result $? "an unknown direction is a usage error" "rc=$rc"

# Ten a side for the verdict: before takes 1 to 10 minutes open, so its 3rd
# and 8th values are 3 and 8; every after pull request takes <a> minutes.
ten() { # ten <a>
  {
    for i in 1 2 3 4 5 6 7 8 9 10; do pr "$i" MERGED $((i * 100)) $((i * 100 + i)) $((i * 100 + i)) "" chore 0 0 "" "chore: $i" "$ok_body"; done
    pr 11 MERGED 1100 1101 1101 "" infra 0 0 "" "process: the start" "$ok_body"
    for i in 12 13 14 15 16 17 18 19 20 21; do pr "$i" MERGED $((i * 100)) $((i * 100 + $1)) $((i * 100 + $1)) "" chore 0 0 "" "chore: $i" "$ok_body"; done
  } > "$T/prs"
}
verdict() { # verdict <after minutes> <direction> <expected word>
  ten "$1"
  out="$(run 0001 --from '#11' --verdict open_min "$2")"; rc=$?
  [ "$rc" = 0 ] && [ "${out%% *}" = "$3" ]
  result $? "verdict $2 at a median of $1 against 3 to 8: $3" "$out"
}
verdict 2 down confirmed
verdict 9 down refuted
verdict 5 down inconclusive
verdict 9 up confirmed
verdict 2 up refuted
verdict 8 up inconclusive
verdict 5 not-up held
verdict 9 not-up broken
verdict 3 not-down held
verdict 2 not-down broken
ten 5
out="$(run 0001 --from '#11' --verdict open_min up)"
[ "$out" = "inconclusive (open_min up: after median 5, before 3rd to 8th 3 to 8)" ]
result $? "the verdict line names the median and the range" "$out"
out="$(run 0001 --from '#11' --verdict draft_min up)"
[ "$out" = "cannot run (draft_min: 0 before and 0 after, 0001 needs ten a side)" ]
result $? "empty cells are not values" "$out"
out="$(run 0001 --from '#11' --verdict class up)"
[ "$out" = "cannot run (class is not a numeric column)" ]
result $? "a column that is not numeric cannot run" "$out"
[ -z "$(git -C "$T/repo" status --porcelain)" ]
result $? "never writes a record" "$(git -C "$T/repo" status --porcelain)"

printf '1..%d\n' "$n"
[ "$failed" -eq 0 ]
