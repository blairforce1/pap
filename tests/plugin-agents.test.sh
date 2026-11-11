#!/bin/sh
# plugin-agents.test.sh: the pap plugin's agent definitions parse
# (decision 0024).
#
# Usage: sh tests/plugin-agents.test.sh
#
# For each expected file in plugins/pap/agents/, checks the frontmatter
# opens on line 1 and closes, carries `name` matching the file name,
# `tools` and `model`, that the reviewer, the planner and the plan reviewer
# (decision 0026) have no Edit, Write, NotebookEdit or Agent, and that the
# reviewer and /change step 5 give /code-review the same args and the same
# fixed first lines, that both cycle definitions say in the same fixed words
# to carry the change with /change and stay out of the main checkout, and
# that /change reports a failed required check by its error lines, and the
# scenarios of features/spec-board-keeps-tools.feature: the spec reviewer's
# tool list, the spec-review skills' withheld tools against the list pinned
# here, and the five sentences /spec step 6 carries word for word.
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

for a in cycle cycle-mechanical reviewer planner plan-reviewer spec-reviewer; do
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

# Read-only by the tool list: no tool that edits, writes or starts an agent.
for a in reviewer planner plan-reviewer; do
  tools=$(field "$dir/$a.md" tools)
  case ", $tools," in
    *", Edit,"* | *", Write,"* | *", NotebookEdit,"* | *", Agent,"*) result 1 "$a: no Edit, Write, NotebookEdit or Agent" ;;
    *) [ -n "$tools" ]; result $? "$a: no Edit, Write, NotebookEdit or Agent" ;;
  esac
done

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

# A cycle carries its change with /change, in a worktree (decisions 0018
# and 0024). Both definitions say so in the same fixed words.
for a in cycle cycle-mechanical; do
  f="$dir/$a.md"
  has "$f" 'Your first act after that `cd` is to invoke the `/change` skill with the brief'"'"'s first line.'
  result $? "$a: the first act after cd is the /change skill with the brief's first line"
  has "$f" 'Do no step of a change by hand: no branch, commit or pull request outside the skill.'
  result $? "$a: no step of a change by hand"
  has "$f" 'If the skill is not available, end with `ASK:`.'
  result $? "$a: ends with ASK: when the skill is not available"
  has "$f" 'Never work in, or change the branch of, the repository'"'"'s main checkout.'
  result $? "$a: never works in, or changes the branch of, the main checkout"
done

# /change reports a failed required check by its error lines, all of them,
# and does not wait for one still running.
has "$skill" 'read the result of each required check that has finished'
result $? "SKILL.md: the report reads each finished required check"
has "$skill" 'Do not wait for one still running'
result $? "SKILL.md: the report does not wait for a running check"
has "$skill" 'quote every error line in Verification and name each in the chat report'
result $? "SKILL.md: a failed check's error lines are quoted and named"
has "$skill" 'A failure is expected only when every one of its error lines is'
result $? "SKILL.md: a failure is expected only when every error line is"
has "$skill" 'Failed required checks:'
result $? "SKILL.md: the chat report has a line for failed required checks"

[ "$(field "$dir/cycle-mechanical.md" model)" = haiku ]
result $? "cycle-mechanical: model is haiku"

# The plan reviewer is pinned to sonnet, as the reviewer is; the planner
# inherits.
[ "$(field "$dir/plan-reviewer.md" model)" = sonnet ]
result $? "plan-reviewer: model is sonnet"
[ "$(field "$dir/planner.md" model)" = inherit ]
result $? "planner: model is inherit"

# /spec runs its spec review in read-only sub-agents and keeps its own
# tools (features/spec-board-keeps-tools.feature). Scenarios 3 and 4 are
# structure. Scenarios 1, 2 and 5 to 8 are what a session does, and pap has
# no harness to run one in (backlog H-010): they are bound to five sentences
# step 6 carries word for word.
spec="$here/plugins/pap/skills/spec/SKILL.md"
# step6: step 6 of /spec on one line, line breaks read as spaces.
step6() { awk '/^## 6\. /{ f = 1 } /^## 7\. /{ f = 0 } f' "$spec" | tr '\n' ' ' | tr -s ' '; }
has6() { step6 | grep -qF -- "$1"; }

# spec-board-keeps-tools-3: an allow-list, so a tool added later fails here
# unless it is one that only reads.
tools=$(field "$dir/spec-reviewer.md" tools 2>/dev/null)
bad=$(printf '%s\n' "$tools" | tr ',' '\n' | sed 's/^ *//; s/ *$//' | grep -vxE 'Read|Grep|Glob')
[ -n "$tools" ] && [ -z "$bad" ]
result $? "spec-board-keeps-tools-3: the spec reviewer holds only Read, Grep and Glob: no tool that edits, writes, runs a shell or starts a sub-agent"
has6 '`subagent_type` `pap:spec-reviewer`' && has6 'One sub-agent for each perspective'
result $? "spec-board-keeps-tools-3: step 6 starts one pap:spec-reviewer sub-agent for each perspective"
has6 'Do not invoke a spec-review skill in this session.' && ! step6 | grep -qE 'invokes? `spec-review-'
result $? "spec-board-keeps-tools-3: step 6 says: Do not invoke a spec-review skill in this session. And it invokes none"

# spec-board-keeps-tools-4: a perspective or the board invoked directly runs
# in the conversation with the same tools withheld. The list is pinned here,
# not read from main. The board is the one skill that may start sub-agents.
withheld='Agent Artifact AskUserQuestion Bash CronCreate CronDelete CronList Edit EnterPlanMode EnterWorktree ExitPlanMode ExitWorktree ListAgents ListMcpResourcesTool LSP Monitor NotebookEdit PowerShell PushNotification ReadMcpResourceTool RemoteTrigger ReportFindings ScheduleWakeup SendMessage SendUserFile ShareOnboardingGuide Skill TaskCreate TaskGet TaskList TaskOutput TaskStop TaskUpdate TodoWrite ToolSearch WaitForMcpServers WebFetch WebSearch Workflow Write'
review="$here/plugins/spec-review/skills"
seen=0
for p in ai-act cost full gdpr iso27001 operations performance qa reliability security soc2 ux; do
  f="$review/spec-review-$p/SKILL.md"
  want="$withheld"
  [ "$p" = full ] && want="${withheld#Agent }"
  got=$(awk 'NR > 1 && $0 == "---" { exit } /^disallowed-tools:/ { f = 1; next } f && /^  - / { printf "%s%s", s, $2; s = " "; next } f { exit }' "$f" 2>/dev/null)
  [ "$got" = "$want" ]
  result $? "spec-board-keeps-tools-4: spec-review-$p withholds the pinned tools, Bash, Edit and Write among them"
  [ -f "$f" ] && [ -z "$(field "$f" context)" ] && [ -z "$(field "$f" agent)" ]
  result $? "spec-board-keeps-tools-4: spec-review-$p runs in the conversation, not in a sub-agent of its own"
  seen=$((seen + 1))
done
[ "$(find "$review" -name SKILL.md -path '*/spec-review-*/*' | wc -l | tr -d ' ')" = "$seen" ]
result $? "spec-board-keeps-tools-4: every spec-review skill is one of the $seen checked"

has6 'Write the register before you ask for any disposition.'
result $? "spec-board-keeps-tools-1, spec-board-keeps-tools-2: step 6 says: Write the register before you ask for any disposition."
has6 'Wait for every perspective before you consolidate.'
result $? "spec-board-keeps-tools-5: step 6 says: Wait for every perspective before you consolidate."
has6 'Start a failed perspective once more.'
result $? "spec-board-keeps-tools-6, spec-board-keeps-tools-7: step 6 says: Start a failed perspective once more."
has6 'Start no sub-agent of another type in its place.'
result $? "spec-board-keeps-tools-8: step 6 says: Start no sub-agent of another type in its place."

printf '1..%d\n' "$n"
[ "$failed" = 0 ]
