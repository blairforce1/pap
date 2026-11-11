#!/bin/sh
# plan-step.test.sh: the scenarios of features/plan-step.feature that a
# script check on files, logs and exit codes can bind, by ID, for the plan
# step (changes/plan-step/spec.md, decision 0026): /pap:plan's script, the
# launch's plan check in /pap:pm's, the role the session-start hook gives
# and /spec's hand-on. The spec's unit and integration rows are here too.
# The scenarios that say what a session or a sub-agent does are bound by an
# eval, by hand until H-010, and stay pending.
#
# Usage: sh tests/plan-step.test.sh
#
# Never touches the network, the real home, ~/.claude or pap's real state
# directory: HOME, XDG_STATE_HOME, XDG_CONFIG_HOME and CLAUDE_CONFIG_DIR are
# under a temporary directory. Every case builds its own repository:
#
#   A        adopts PAP, origin https://github.com/olive/trial.git, on main
#   A-trial  a work tree of A on change/trial, where the plan is committed
#
# Where a scenario's last step is the model's (starting a planner, a plan
# review, a cycle; asking the owner), the case binds the script's half and
# the skill's text, and its label says so.
#
# Prints one TAP-style line per case and exits 1 if any case fails. Needs
# git and jq.
#
# SC2319: each case passes the exit status of its condition on purpose.
# SC2016: the skills' own text is matched as written.
# SC2034, SC2154: pl_dir, pl_ref and pl_slug are read, and pl_state is set,
# by plan-lib.sh's functions.
# shellcheck disable=SC2319,SC2016,SC2034,SC2154

set -u
# shellcheck disable=SC1091 # tests/clean-env.sh, sourced from this directory
. "$(dirname "$0")/clean-env.sh"

here="$(cd "$(dirname "$0")/.." && pwd)"
for tool in git jq; do
  command -v "$tool" >/dev/null 2>&1 || { printf 'Bail out! %s not found\n' "$tool"; exit 1; }
done

T="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$T"' EXIT INT TERM
mkdir -p "$T/home/.claude/plugins" "$T/xdg/pap" "$T/stub"
export HOME="$T/home" XDG_STATE_HOME="$T/state" XDG_CONFIG_HOME="$T/xdg" \
  CLAUDE_CONFIG_DIR="$T/home/.claude" GIT_CONFIG_GLOBAL="$T/gitconfig" \
  GIT_CONFIG_NOSYSTEM=1 GIT_CEILING_DIRECTORIES="$T"
unset CLAUDE_PROJECT_DIR CLAUDE_PLUGIN_ROOT PAP_MODE 2>/dev/null || true
printf '[init]\n\tdefaultBranch = main\n' > "$GIT_CONFIG_GLOBAL"
printf '#!/bin/sh\ncase "${1:-}" in --version) echo "2.1.322 (Claude Code)" ;; esac\nexit 0\n' > "$T/stub/claude"
printf '#!/bin/sh\nexit 0\n' > "$T/stub/gh"
chmod +x "$T/stub/claude" "$T/stub/gh"
PATH="$T/stub:$PATH"
export PATH

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

# The plugin as installed: a copy, as Claude Code runs it.
cp -R "$here/plugins/pap" "$T/plugin"
plugin="$T/plugin"
planskill="$plugin/skills/plan/SKILL.md"
jq -n --arg k "pap@$(jq -r .name "$here/.claude-plugin/marketplace.json")" --arg p "$plugin" \
  '{version: 2, plugins: {($k): [{installPath: $p}]}}' > "$CLAUDE_CONFIG_DIR/plugins/installed_plugins.json"

case "$(date +%s%N 2>/dev/null)" in
  *N | "") now() { perl -MTime::HiRes=time -e 'printf "%d\n", time * 1e9'; } ;;
  *) now() { date +%s%N; } ;;
esac

# --- The repository -------------------------------------------------------------

A="$T/A" W="$T/A-trial"
dir="changes/trial"
# repo: A, one commit on main, and its work tree W on change/trial.
repo() {
  rm -rf "$A" "$W"
  git init -q -b main "$A"
  git -C "$A" config user.name test
  git -C "$A" config user.email test@example.invalid
  git -C "$A" config commit.gpgsign false
  mkdir -p "$A/scripts" "$A/product" "$A/src"
  cp "$here/scripts/guard-branch.sh" "$A/scripts/guard-branch.sh"
  printf 'seed\n' > "$A/README.md"
  printf 'seed\n' > "$A/product/vision.md"
  printf 'seed\n' > "$A/src/main.c"
  git -C "$A" add -A
  git -C "$A" commit -q -m init
  git -C "$A" remote add origin https://github.com/olive/trial.git
  git -C "$A" worktree add -q -b change/trial "$W"
  mkdir -p "$W/$dir"
}
cm() { git -C "$W" add -A && git -C "$W" commit -q -m "$1"; }
head_of() { git -C "$W" rev-parse HEAD; }
clean() { [ -z "$(git -C "$W" status --porcelain --untracked-files=all)" ]; }
# doc <file> <title> <class> [by] [on]: an intent or a spec; accepted unless by is "-".
doc() {
  d_by="${4-@olive}" d_on="${5-2026-11-10}"
  [ "$d_by" != - ] || d_by="" d_on=""
  printf '%s\n' "# $2: trial" "" '```text' "id:                 trial" "class:              $3" \
    "accepted-by:        $d_by" "accepted-on:        $d_on" '```' "" "## Body" "" "Text." > "$W/$dir/$1"
}
# base <class>: a change branch with an accepted intent and an accepted spec.
base() {
  repo
  doc intent.md Intent "$1"; cm "intent(trial): a trial"
  doc spec.md Spec "$1"; cm "spec(trial): a trial"
}
code() { printf '%s\n' "$1" >> "$W/src/main.c"; cm "feat(trial): $1"; }
# plan <words> [by] [on] [file]: a plan of exactly that many words by wc -w,
# a draft unless by and on are given.
plan() {
  p_f="${4:-$W/$dir/plan.md}"
  {
    printf '%s\n' "# Plan: trial" "" '```text' "id:                 trial" "class:              feature" \
      "spec:               changes/trial/spec.md" "accepted-by:        ${2:-}" "accepted-on:        ${3:-}" \
      "generated-by:       a model via Claude Code" "reviewed-by:" "skills:             pap:plan 0.0.0" \
      "prompt:             /pap:plan trial" '```' "" "## Increments" "" "- One: the gate, trial-1." "" \
      "## Design" "" "PAD" "" "## Fit" "" "none" "" "## Tests" "" "- trial-1: integration, the suite passes." "" \
      "## Observation" "" "none"
  } > "$p_f"
  p_have="$(wc -w < "$p_f" | tr -d ' ')"
  p_pad="$(awk -v k="$(($1 - p_have + 1))" 'BEGIN { for (i = 0; i < k; i++) printf "w%s", (i % 12 == 11 ? "\n" : " "); print "" }')"
  PAD="$p_pad" awk '$0 == "PAD" { print ENVIRON["PAD"]; next } { print }' "$p_f" > "$p_f.new" && mv "$p_f.new" "$p_f"
}
# reviewed: the main session's line in the plan's header, after its review.
reviewed() { sed 's/^reviewed-by:$/reviewed-by:        another model/' "$W/$dir/plan.md" > "$W/$dir/plan.new" && mv "$W/$dir/plan.new" "$W/$dir/plan.md"; }
# register [disposition of PR-1] [disposition of PR-2]: PR-2 is a return to the spec.
register() {
  mkdir -p "$W/$dir/reviews"
  printf '%s\n' "# Plan review: trial" "" "planner: 90000 tokens, 6 minutes" "plan-reviewer: 40000 tokens, 3 minutes" \
    "told: 2026-11-10T10:00:00Z" "" "- PR-1 | design | Major | Fit names no seam | disposition:${1:+ $1}" \
    ${2+"- PR-2 | conformance | Major | return: spec. The spec names no undo | disposition:${2:+ $2}"} \
    "- verification | no findings" > "$W/$dir/reviews/plan-review.md"
}
# accepted_plan: on top of base, a plan the owner said yes to, committed.
accepted_plan() {
  plan 300; reviewed; register "fixed: Fit"
  pp accept trial --by olive --what "build the trial"
}
script="$plugin/skills/plan/pap-plan.sh"
# pp <command> [argument]...: /pap:plan's script in W. Sets out and rc.
pp() {
  out="$(cd "$W" && PAP_PM_NOW=2026-11-11T09:00:00Z sh "$script" "$@" 2>&1)"
  rc=$?
}
said() { printf '%s\n' "$out" | grep -qF -- "$1"; }
hdr() { awk -v k="$2" '/^```/ { if (o) exit; o = 1; next } o && index($0, k ":") == 1 { v = substr($0, length(k) + 2); gsub(/^[ \t]+|[ \t]+$/, "", v); print v }' "$1"; }

# --- /pap:plan: which changes get a plan ------------------------------------------

for state in absent "a draft"; do
  repo
  doc intent.md Intent feature; cm "intent(trial): a trial"
  [ "$state" = absent ] || { doc spec.md Spec feature -; cm "spec(trial): draft, paused"; }
  h0="$(head_of)"
  pp state trial
  [ "$rc" = 10 ] && said "/spec trial comes first" && said "the spec of \"trial\" is $state"
  result $? "plan-step-2: with a spec that is $state, /pap:plan stops, saying /spec comes first" "exit $rc; $out"
  said "no planner starts" && [ "$(head_of)" = "$h0" ] && clean && [ ! -e "$W/$dir/plan.md" ]
  result $? "plan-step-2: with a spec that is $state, the script names no planner to start and nothing is written" "$out; $(git -C "$W" status --porcelain)"
done
grep -q '^- \*\*Exit 10\.\*\* No accepted spec\. Say `/spec <slug>` comes first\. Start nothing and write nothing\.$' "$planskill"
result $? "plan-step-2: the skill text says: on exit 10 say /spec comes first, start nothing and write nothing" ""

none() { # none <label> <reason said> <next said>
  h0="$(head_of)"
  pp state trial
  [ "$rc" = 11 ] && said "$2" && said "$3"
  result $? "plan-step-3: a change that needs no plan because $1: /pap:plan stops, naming the reason and what is next" "exit $rc; $out"
  [ "$(head_of)" = "$h0" ] && clean && [ ! -e "$W/$dir/plan.md" ] && ! said "start one planner"
  result $? "plan-step-3: because $1: no planner is named to start and nothing is written" "$out; $(git -C "$W" status --porcelain)"
}
for class in bugfix chore docs; do
  base "$class"
  none "its class is $class" "its class is $class" "the build is launched with /pap:pm launch trial, or /change trial $class when solo"
done
base spike
none "its class is spike" "its class is spike" "a spike has no spec and no plan"
repo
printf 'notes\n' > "$W/$dir/notes.md"; cm "chore(trial): notes"
none "its change branch carries no intent" "its change branch carries no accepted intent" "it is exempt under rule 20.2, or /intent trial <class> comes first"
base feature
code "the first of it"
none "it started unplanned" "it started unplanned" "the build goes on without a plan"
grep -q '^- \*\*Exit 11\.\*\* The change needs no plan\. Say the reason and what is next, as printed\. Start nothing and write nothing\.$' "$planskill"
result $? "plan-step-3: the skill text says: on exit 11 say the reason and what is next, start nothing and write nothing" ""

base feature
pp state trial
[ "$rc" = 0 ] && said "state: absent" && said "start one planner in the background"
result $? "state: a feature change with an accepted spec, no code and no plan is the one a planner is started for" "exit $rc; $out"
plan 300
sig0="$(cksum < "$W/$dir/plan.md")"
pp state trial
[ "$rc" = 12 ] && said "$dir/plan.md" && said "resume it, or start again?"
result $? "plan-step-8: a plan draft in the work tree and not committed: the owner is shown it and asked, resume it or start again" "exit $rc; $out"
said "Overwrite nothing until the owner answers" && [ "$(cksum < "$W/$dir/plan.md")" = "$sig0" ] && ! said "state:"
result $? "plan-step-8: nothing is overwritten, and the script names no next step, before the owner answers" "$out"
grep -q 'Show them and ask: resume, or start again? Overwrite nothing until the owner answers\.' "$planskill"
result $? "plan-step-8: the skill text says: show them, ask resume or start again, overwrite nothing until the owner answers" ""

# --- The plan: its header, its sections, its length --------------------------------

base feature
plan 300
pp check trial
[ "$rc" = 0 ] && said "words: 300"
result $? "plan-step-9: a plan draft with the header's nine lines and the five sections in order, each with content or \"none\", passes" "exit $rc; $out"
[ -z "$(hdr "$W/$dir/plan.md" accepted-by)$(hdr "$W/$dir/plan.md" accepted-on)" ]
result $? "plan-step-9: and it carries no acceptance" ""
for k in id class spec accepted-by accepted-on generated-by reviewed-by skills prompt; do
  plan 300
  grep -v "^$k:" "$W/$dir/plan.md" > "$T/p" && cp "$T/p" "$W/$dir/plan.md"
  pp check trial
  [ "$rc" = 13 ] && said "the header lacks the line $k:"
  result $? "plan-step-9: a plan draft whose header lacks $k: is not a plan draft" "exit $rc; $out"
done
for k in id class spec generated-by skills prompt; do
  plan 300
  sed "s/^$k:.*/$k:/" "$W/$dir/plan.md" > "$T/p" && cp "$T/p" "$W/$dir/plan.md"
  pp check trial
  [ "$rc" = 13 ] && said "the header line $k: is empty"
  result $? "plan-step-9: a plan draft whose header does not name its $k is not a plan draft" "exit $rc; $out"
done
for s in Increments Design Fit Tests Observation; do
  plan 300
  grep -v "^## $s\$" "$W/$dir/plan.md" > "$T/p" && cp "$T/p" "$W/$dir/plan.md"
  pp check trial
  [ "$rc" = 13 ] && said "in that order"
  result $? "plan-step-9: a plan draft with no section $s is not a plan draft" "exit $rc; $out"
done
plan 300
awk '$0 == "## Fit" { print "## Tests"; next } $0 == "## Tests" { print "## Fit"; next } { print }' "$W/$dir/plan.md" > "$T/p" && cp "$T/p" "$W/$dir/plan.md"
pp check trial
[ "$rc" = 13 ] && said "in that order"
result $? "plan-step-9: sections out of order are not a plan draft" "exit $rc; $out"
plan 300
awk '$0 == "none" && !d { d = 1; next } { print }' "$W/$dir/plan.md" > "$T/p" && cp "$T/p" "$W/$dir/plan.md"
pp check trial
[ "$rc" = 13 ] && said "the section Fit is empty"
result $? "plan-step-9: a section with neither content nor \"none\" is not a plan draft" "exit $rc; $out"
plan 300 @olive 2026-11-11
pp check trial
[ "$rc" = 13 ] && said "a plan draft carries no acceptance"
result $? "plan-step-9: a draft that arrives with acceptance filled is not a plan draft" "exit $rc; $out"
printf 'The plan is to build it well.\n' > "$T/report"
pp check trial --file "$T/report"
[ "$rc" = 13 ] && said "the planner has failed" && said "write nothing"
result $? "plan-step-9: a report with no header is a failed planner: write nothing" "exit $rc; $out"

plan 1000
pp check trial
[ "$rc" = 0 ] && said "words: 1000" && [ "$(wc -w < "$W/$dir/plan.md" | tr -d ' ')" = 1000 ]
result $? "plan-step-11: a plan draft of 1000 words by wc -w, header included, passes: the plan review starts (unit row: at most 1000 words)" "exit $rc; $out"
plan 1001
pp check trial
[ "$rc" = 14 ] && said "1001 words, over 1000" && said "goes back to the planner once" && [ "$(wc -w < "$W/$dir/plan.md" | tr -d ' ')" = 1001 ]
result $? "plan-step-11: a plan draft of 1001 words does not: it goes back to the planner once" "exit $rc; $out"
grep -q '^- \*\*Exit 0\.\*\* Write the report, unchanged, to `changes/<slug>/plan.md`\. Go to step 3\.$' "$planskill" &&
  grep -q '^- \*\*Exit 14\*\*, over 1000 words\. Send the planner back once with the count, to shorten\.' "$planskill"
result $? "plan-step-11: the skill text says: on exit 0 write it and go to the review; on exit 14 send the planner back once" ""
plan 1000; reviewed
pp check trial --reviewed
[ "$rc" = 0 ] && said "words: 1000"
result $? "words: the header values the main session fills are not counted, so a reviewed 1000-word draft is still 1000" "exit $rc; $out"

h0="$(head_of)"
plan 1001; reviewed
pp keep trial --what "over 1000 words"
[ "$rc" = 0 ] && [ "$(git -C "$W" rev-list --count "$h0..HEAD")" = 1 ] && clean &&
  [ -z "$(git -C "$W" show "HEAD:$dir/plan.md" | hdr /dev/stdin accepted-by)$(git -C "$W" show "HEAD:$dir/plan.md" | hdr /dev/stdin accepted-on)" ] &&
  git -C "$W" log -n 1 --format=%s | grep -q '^plan(trial): draft, over 1000 words$'
result $? "plan-step-12: a plan draft still over 1000 words is committed with no acceptance" "exit $rc; $out; $(git -C "$W" log --oneline -n 2)"
said "1001 words, over 1000" && said "run /pap:plan trial again or narrow the spec"
result $? "plan-step-12: the owner is told the word count and to run /pap:plan again or narrow the spec" "$out"
said "it is not put to the owner for a yes"
result $? "plan-step-12: the script says it is not put to the owner for a yes" "$out"
register "fixed: Fit"
pp accept trial --by olive --what "build the trial"
[ "$rc" = 14 ] && [ -z "$(hdr "$W/$dir/plan.md" accepted-by)" ] && [ "$(git -C "$W" rev-list --count "$h0..HEAD")" = 1 ]
result $? "plan-step-12: and a yes to it is not taken: the plan stays a draft and nothing more is committed" "exit $rc; $out"

# --- The yes -----------------------------------------------------------------------

base feature
git init -q --bare "$T/origin.git"
git -C "$A" remote set-url origin "$T/origin.git"
git -C "$A" push -q origin main
plan 300; reviewed; register "fixed: Fit"
h0="$(head_of)"
pp accept trial --by olive --what "build the trial"
[ "$rc" = 0 ] && [ "$(hdr "$W/$dir/plan.md" accepted-by)" = "@olive" ] && [ "$(hdr "$W/$dir/plan.md" accepted-on)" = 2026-11-11 ] &&
  [ "$(git -C "$W" show "HEAD:$dir/plan.md" | hdr /dev/stdin accepted-by)" = "@olive" ]
result $? "plan-step-22: on the owner's yes the plan records who said yes and when" "exit $rc; $out"
[ "$(git -C "$W" rev-list --count "$h0..HEAD")" = 1 ] && clean &&
  [ "$(git -C "$W" show --format= --name-only HEAD | sort | tr '\n' ' ')" = "$dir/plan.md $dir/reviews/plan-review.md " ] &&
  git -C "$W" log -n 1 --format=%s | grep -q '^plan(trial): build the trial$'
result $? "plan-step-22: the plan and the plan review register are committed in one commit whose message starts \"plan(trial): \"" "$(git -C "$W" show --stat --format=%s HEAD)"
[ -z "$(git -C "$A" ls-remote origin 'refs/heads/change/*' 'refs/pull/*')" ] && [ -z "$(git -C "$A" for-each-ref refs/remotes/origin/change)" ]
result $? "plan-step-22: nothing is pushed and no pull request is opened: the remote has no change branch" "$(git -C "$A" ls-remote origin)"
said "nothing was pushed and no pull request is open" && said "a launch from another clone needs change/trial there first" &&
  said "the build is launched by the owner typing /pap:pm launch trial in a PM session, or /change trial feature in a solo session"
result $? "plan-step-22: the owner is told nothing was pushed, that a launch from another clone needs the branch there first, and what launches the build" "$out"
pp status trial
[ "$out" = accepted ]
result $? "plan-step-22: the plan is then accepted, as /change and the launch read it" "$out"

# The yes is not taken where the script can tell it should not be.
base feature
plan 300; reviewed; register ""
h0="$(head_of)"
pp accept trial --by olive --what "build the trial"
[ "$rc" = 15 ] && said "these findings wait for a disposition: PR-1" && [ "$(head_of)" = "$h0" ] && [ -z "$(hdr "$W/$dir/plan.md" accepted-by)" ]
result $? "accept: with a finding waiting, the yes is not taken and the finding is named" "exit $rc; $out"
rm -rf "$W/$dir/reviews"
pp accept trial --by olive --what "build the trial"
[ "$rc" = 15 ] && [ "$(head_of)" = "$h0" ]
result $? "accept: with no register, the plan has not been reviewed and the yes is not taken" "exit $rc; $out"
register "accepted" "accepted"
pp accept trial --by olive --what "build the trial"
[ "$rc" = 16 ] && said "/spec trial" && [ "$(head_of)" = "$h0" ]
result $? "accept: an accepted return to the spec is no yes: keep, then /spec" "exit $rc; $out"
register "accepted" "fixed: Tests"
pp accept trial --by olive --what "build the trial"
[ "$rc" = 15 ] && said "a return to the spec is accepted, or rejected with a reason"
result $? "accept: a return to the spec marked fixed cannot be read as a disposition" "exit $rc; $out"
register "deferred: build" "rejected: the undo is in the spec's Operations"
pp accept trial --by olive --what "build the trial"
[ "$rc" = 0 ]
result $? "accept: deferred to a phase, and a return to the spec rejected with a reason, are dispositions" "exit $rc; $out"

# plan-step-25: later, and no.
base feature
plan 300; reviewed; register "accepted"
h0="$(head_of)"
pp keep trial --what "the owner said later"
pl_dir="$W" pl_ref=refs/heads/change/trial pl_slug=trial
# shellcheck disable=SC1091 # the plan library, from the plugin copy
. "$plugin/skills/plan/plan-lib.sh"
still() { git -C "$W" show "HEAD:$dir/intent.md" | plan_filled && git -C "$W" show "HEAD:$dir/spec.md" | plan_filled; }
plan_state
[ "$rc" = 0 ] && [ "$(git -C "$W" rev-list --count "$h0..HEAD")" = 1 ] && clean && [ "$pl_state" = draft ] &&
  [ "$(git -C "$W" show --format= --name-only HEAD | sort | tr '\n' ' ')" = "$dir/plan.md $dir/reviews/plan-review.md " ] && still
result $? "plan-step-25: the plan was absent and the owner answers later: the draft and its register are committed with no acceptance; intent and spec are still accepted" "exit $rc; $out; state $pl_state"
base feature
plan 300; reviewed; register "accepted"
h0="$(head_of)"
pp drop trial
[ "$rc" = 0 ] && said "the draft and the review are lost" && said "nothing is committed" && [ "$(head_of)" = "$h0" ] && clean &&
  [ ! -e "$W/$dir/plan.md" ] && [ ! -e "$W/$dir/reviews/plan-review.md" ] && still
result $? "plan-step-25: the plan was absent and the owner answers no: told the draft and the review are lost, nothing committed, no plan and no register in the work tree" "exit $rc; $out; $(git -C "$W" status --porcelain)"
base feature
plan 300; reviewed; register "accepted"
pp keep trial --what "paused"
h0="$(head_of)"
sig0="$(cksum < "$W/$dir/plan.md")"
plan 400; reviewed; register ""
pp drop trial
[ "$rc" = 0 ] && said "the new draft and its review are lost" && said "nothing is committed" && [ "$(head_of)" = "$h0" ] && clean &&
  [ "$(cksum < "$W/$dir/plan.md")" = "$sig0" ] && still
result $? "plan-step-25: the plan was a draft and the owner answers no: told the new draft and review are lost, nothing committed, the work tree holds the draft as committed" "exit $rc; $out; $(git -C "$W" status --porcelain)"

# plan-step-26: a committed draft is resumed.
pp state trial
[ "$rc" = 0 ] && said "state: draft" && said "show it and its register, with the dispositions already given, and ask for the yes" &&
  grep -q 'disposition: accepted$' "$W/$dir/reviews/plan-review.md"
result $? "plan-step-26: a committed draft whose spec has no later commit: show the draft and the register with the dispositions given, and ask for a yes" "exit $rc; $out"
printf 'More.\n' >> "$W/$dir/spec.md"; cm "spec(trial): one more scenario"
pp state trial
[ "$rc" = 0 ] && said "state: redraft" && said "a planner redrafts against the spec as it is now, and the plan review runs again"
result $? "plan-step-26: a committed draft whose spec has a later commit: a planner redrafts and a plan review runs again" "exit $rc; $out"
grep -q '^- \*\*`state: draft`\.\*\* A committed draft whose spec has not changed\. Go to step 5 with the dispositions already given\.$' "$planskill" &&
  grep -q 'Say so, then step 2: redraft against the spec as it is now and review again\.' "$planskill"
result $? "plan-step-26: the skill text sends a draft to the yes and a redraft to a planner and a review" ""

# plan-step-27: an edit to an accepted plan.
base feature
accepted_plan
by0="$(hdr "$W/$dir/plan.md" accepted-by)" on0="$(hdr "$W/$dir/plan.md" accepted-on)"
sed 's/^- One: the gate, trial-1\.$/- One: the launch gate, trial-1./' "$W/$dir/plan.md" > "$T/p" && cp "$T/p" "$W/$dir/plan.md"
h0="$(head_of)"
pp status trial
[ "$out" = accepted ] && [ "$(head_of)" = "$h0" ] && ! git -C "$W" show "HEAD:$dir/plan.md" | grep -q 'launch gate'
result $? "plan-step-27: an edit not yet committed changes nothing the launch reads: it reads the last committed plan" "$out"
pp amend trial --what "name the launch gate"
[ "$rc" = 0 ] && [ "$(git -C "$W" rev-list --count "$h0..HEAD")" = 1 ] && clean &&
  [ "$(hdr "$W/$dir/plan.md" accepted-by)" = "$by0" ] && [ "$(hdr "$W/$dir/plan.md" accepted-on)" = "$on0" ] &&
  grep -q '^Edited 2026-11-11 after the yes: name the launch gate$' "$W/$dir/plan.md" &&
  git -C "$W" log -n 1 --format=%s | grep -q '^plan(trial): name the launch gate$'
result $? "plan-step-27: with no code, the edit is committed with the acceptance kept and the edit noted in the plan, in a commit that starts \"plan(trial): \"" "exit $rc; $out"
pp status trial
[ "$out" = accepted ]
result $? "plan-step-27: the plan is still accepted after the edit" "$out"
code "the gate"
sed 's/^- trial-1: integration, the suite passes\.$/- trial-1: integration and unit, the suite passes./' "$W/$dir/plan.md" > "$T/p" && cp "$T/p" "$W/$dir/plan.md"
h0="$(head_of)"
pp amend trial --what "a unit tier"
[ "$rc" = 17 ] && said "plan rework" && [ "$(head_of)" = "$h0" ]
result $? "plan-step-27: once the branch carries code, an edit that does not say what the code surfaced is not committed" "exit $rc; $out"
pp amend trial --rework "the gate needs a unit tier"
[ "$rc" = 0 ] && [ "$(hdr "$W/$dir/plan.md" accepted-by)" = "$by0" ] &&
  git -C "$W" log -n 1 --format=%s | grep -q '^plan(trial): rework, the gate needs a unit tier$' &&
  grep -q '^Edited 2026-11-11 after the yes: the gate needs a unit tier$' "$W/$dir/plan.md"
result $? "plan-step-27: with code, the commit's message says it is plan rework and what the code surfaced" "exit $rc; $(git -C "$W" log -n 1 --format=%s)"
sed 's/^accepted-by:.*/accepted-by:        @mallory/' "$W/$dir/plan.md" > "$T/p" && cp "$T/p" "$W/$dir/plan.md"
pp amend trial --rework "a new name"
[ "$rc" = 17 ] && said "the acceptance is kept"
result $? "plan-step-27: an edit that changes the acceptance is not committed" "exit $rc; $out"
grep -q 'Wording only: no review\. More than wording: start one `pap:plan-reviewer` on the part the edit bears on' "$planskill" &&
  grep -q 'Commit only on the owner.s yes:' "$planskill"
result $? "plan-step-27: the skill text says: wording only, no review; more than wording, the plan reviewer re-reads the part the edit bears on; commit only on the owner's yes" ""

# plan-step-28: a spec changed after the yes.
base feature
accepted_plan
pp status trial
was="$out"
printf 'More.\n' >> "$W/$dir/spec.md"; cm "spec(trial): one more scenario"
pp status trial
[ "$was" = accepted ] && [ "$out" = "draft: the spec changed after the plan's yes" ]
result $? "plan-step-28: a spec commit later than the commit that accepted the plan makes the plan a draft" "$was; $out"
pp state trial
[ "$rc" = 0 ] && said "state: spec-changed" && said "the owner says yes a second time"
result $? "plan-step-28: /pap:plan then redrafts, reviews again and asks for a second yes" "exit $rc; $out"
grep -q 'the plan is a draft again; tell the owner to run `/pap:plan <slug>` before the build' "$plugin/skills/spec/SKILL.md"
result $? "plan-step-28: /spec's text says its reply to that commit tells the owner to run /pap:plan before the build" ""
# An edit after the yes does not move the commit that accepted the plan.
base feature
accepted_plan
printf 'More.\n' >> "$W/$dir/spec.md"; cm "spec(trial): one more scenario"
git -C "$W" show "HEAD~1:$dir/plan.md" | sed 's/the gate/the launch gate/' > "$W/$dir/plan.md"; cm "plan(trial): by hand"
pp status trial
[ "$out" = "draft: the spec changed after the plan's yes" ]
result $? "plan-step-28: a later commit to the plan that keeps the acceptance does not hide the spec's change" "$out"

# --- The launch -------------------------------------------------------------------

S1=0f6b2c1e-1a2b-4c3d-8e4f-5a6b7c8d9e01
pmscript="$plugin/skills/pm/pap-pm.sh"
k=0
pm() {
  out="$(cd "$A" && sh "$pmscript" "$@" --session "$S1" 2>&1)"
  rc=$?
}
at() { PAP_PM_NOW="2026-11-10T$1Z"; export PAP_PM_NOW; }
typed() {
  jq -nc --arg s "$S1" --arg d "$A" --arg p "/pap:pm launch trial" \
    '{session_id: $s, transcript_path: "/x/t.jsonl", cwd: $d, permission_mode: "default", hook_event_name: "UserPromptSubmit", prompt: $p}' |
    env PAP_MODE=pm CLAUDE_PROJECT_DIR="$A" CLAUDE_PLUGIN_ROOT="$plugin" "$plugin/hooks/pm-log.sh" prompt
}
# ready <first line> <second line> [no-restate]: a started tracker of its
# own, the ask restated, a complete brief, both committed, and the launch
# the owner typed.
ready() {
  k=$((k + 1))
  XDG_STATE_HOME="$T/state$k"
  export XDG_STATE_HOME
  pmd="$XDG_STATE_HOME/pap/pm"
  trk="$pmd/trackers/olive/trial" ll="$pmd/launches.log"
  at 10:00:00; pm start
  at 10:01:00
  [ -n "${3:-}" ] || printf '%s\t%s\t%s\t%s\n' "$PAP_PM_NOW" restate trial "build the thing the owner named" >> "$trk/events.tsv"
  mkdir -p "$trk/briefs"
  printf '%s\n' "$1" "$2" "" "Done: the draft pull request." "Budget: 200000 tokens" > "$trk/briefs/trial.md"
  pm commit
  at 10:02:00; typed
  at 10:03:00
}
events() { grep -c "$(printf '\t')$1$(printf '\t')trial$(printf '\t')" "$trk/events.tsv"; }
tclean() { [ -z "$(git -C "$trk" status --porcelain 2>/dev/null)" ]; }

# refused <class> <state, as the scenario words it> <said>: the branch is built by the caller.
refused() {
  ready "/change trial $1" "Rule 20.2: item ${4:-1}"
  h0="$(git -C "$trk" rev-parse HEAD)"
  pm launch trial
  [ "$rc" = 20 ] && said "$3" && said "/pap:plan trial" && said "rule 26.2" && said "/change in a solo session"
  result $? "plan-step-29: class $1, $2: the launch is refused with exit 20, saying $3, naming /pap:plan trial, its rule and /change in a solo session" "exit $rc; $out"
  [ "$(events yes)" = 0 ] && [ "$(events launch)" = 0 ] && [ "$(git -C "$trk" rev-parse HEAD)" = "$h0" ] && tclean
  result $? "plan-step-29: class $1, $2: the event log gains no yes event and no launch event" "$(cat "$trk/events.tsv")"
  ! printf '%s\n' "$out" | grep -q -e '^agent:' -e '^brief:'
  result $? "plan-step-29: class $1, $2: no cycle starts: the script names no agent and no brief" "$out"
  line="$(grep "refused-20" "$ll" | tail -n 1)"
  [ "$(printf '%s\n' "$line" | cut -f 4,5,6)" = "trial$(printf '\t')refused-20$(printf '\t')$3" ]
  result $? "plan-step-29: class $1, $2: a line beside the launch record names \"trial\" and the reason" "$(cat "$ll" 2>&1)"
  at 10:04:00; pm launch trial
  [ "$rc" = 10 ]
  result $? "plan-step-29: class $1, $2: the launch record is used up: run again untyped, the launch is refused as not typed" "exit $rc; $out"
}
for class in feature infra security-sensitive; do
  base "$class"
  refused "$class" "the plan of \"trial\" is absent" "the plan is absent"
done
base feature
plan 300; reviewed; register "accepted"; pp keep trial
refused feature "the change branch carries a plan with no acceptance" "the plan is a draft" 2
base feature
plan 300 @olive ""; cm "plan(trial): by hand"
refused feature "the change branch carries a plan whose acceptance names who but not when" "the plan is a draft"
base feature
plan 300; reviewed; register "accepted"; pp keep trial
plan 300 @olive 2026-11-11
refused feature "the plan is accepted in the work tree and that is not committed" "the plan is a draft"
base feature
accepted_plan
printf 'More.\n' >> "$W/$dir/spec.md"; cm "spec(trial): one more scenario"
refused feature "the plan was accepted and the spec has a later commit" "the spec changed after the plan's yes"
base infra
plan 300; cm "plan(trial): draft, by hand"
code "the first of it"
refused infra "the change branch carries code and a plan with no acceptance" "the plan is a draft"
base feature
git -C "$A" worktree remove --force "$W" && git -C "$A" branch -q -D change/trial
refused feature "this clone has no change branch for \"trial\"" "the change branch cannot be read"
base feature
printf 'A plan with no header.\n' > "$W/$dir/plan.md"; cm "plan(trial): by hand"
refused feature "the plan's header cannot be read" "the plan cannot be read"

base feature
ready "/change trial feature" "Rule 20.2: item 1" no-restate
pm launch trial
[ "$rc" = 11 ] && said "the ask is restated first"
result $? "plan-step-30: with no restate event and the plan absent, the launch is refused, saying the ask is restated first" "exit $rc; $out"
! printf '%s\n' "$out" | grep -qi 'plan' && ! grep -q refused-20 "$ll"
result $? "plan-step-30: nothing is said of the plan, and no plan refusal is logged" "$out; $(cat "$ll")"
# The plan is checked after every other check: each refuses first.
base feature
ready "/change trial feature" "Rule 20.2: item 1"
grep -v '^Budget:' "$trk/briefs/trial.md" > "$T/b" && cp "$T/b" "$trk/briefs/trial.md"
pm launch trial
[ "$rc" = 14 ] && ! printf '%s\n' "$out" | grep -qi 'plan'
result $? "plan-step-30: a brief with no budget and no plan is refused for its budget, and nothing is said of the plan" "exit $rc; $out"

launched() { # launched <id> <label> <route as the launch event names it>
  h0="$(git -C "$trk" rev-parse HEAD)"
  pm launch trial
  [ "$rc" = 0 ] && [ "$(events yes)" = 1 ] && [ "$(events launch)" = 1 ] &&
    [ "$(tail -n 2 "$trk/events.tsv" | cut -f 2 | tr '\n' ' ')" = "yes launch " ] &&
    tail -n 1 "$trk/events.tsv" | cut -f 4 | grep -qF -- "$3; "
  result $? "plan-step-$1: $2: the event log gains a yes event and a launch event for \"trial\" naming the route" "exit $rc; $out"
  tclean && [ "$(git -C "$trk" rev-parse HEAD)" != "$h0" ]
  result $? "plan-step-$1: $2: the tracker is committed" "$(git -C "$trk" status --porcelain 2>&1)"
  [ "$(printf '%s\n' "$out" | grep -c '^agent: pap:cycle$')" = 1 ] && said "brief: $trk/briefs/trial.md"
  result $? "plan-step-$1: $2: only then the script names one agent and the brief, for the skill to start one cycle with the brief and nothing else" "$out"
  ! grep -q refused-20 "$ll"
  twenty=$((twenty + $?))
}
twenty=0
for class in feature infra security-sensitive; do
  base "$class"
  accepted_plan
  ready "/change trial $class" "Rule 20.2: item 1"
  launched 31 "class $class, the plan accepted, no code" "/change trial $class; Rule 20.2: item 1"
done
# An accepted plan stays accepted once the build's code is on the branch.
base feature
accepted_plan
code "the first of it"
ready "/change trial feature" "Rule 20.2: item 1"
pm launch trial
[ "$rc" = 0 ]
result $? "plan-step-31: an accepted plan with code after it is launched too: a relaunch of the build" "exit $rc; $out"

twenty=0
for class in bugfix chore docs spike; do
  base "$class"
  ready "/change trial $class" "Rule 20.2: item 1"
  launched 32 "the route is /change and the class is $class, the plan absent" "/change trial $class; Rule 20.2: item 1"
done
base feature
ready "/change trial feature" "Rule 20.2: exempt: a fix that restores what the spec states"
launched 32 "the route is /change, the class is feature and the second line names an exemption, the plan absent" "/change trial feature; Rule 20.2: exempt: a fix that restores what the spec states"
repo
ready "/intent trial feature" "Rule 20.2: item 1"
launched 32 "the route is /intent and the class is feature, the plan absent" "/intent trial feature; Rule 20.2: item 1"
base infra
code "the first of it"
ready "/change trial infra" "Rule 20.2: item 2"
launched 32 "the route is /change, the class is infra and the change started unplanned" "/change trial infra; Rule 20.2: item 2"
[ "$twenty" = 0 ]
result $? "plan-step-32: (integration row) launches refused with exit 20 among these cases: 0" "$twenty"

# The plan check's own elapsed time, on a branch with history.
base feature
accepted_plan
i=0
while [ "$i" -lt 30 ]; do i=$((i + 1)); code "increment $i"; done
pl_dir="$A" pl_ref=refs/heads/change/trial pl_slug=trial
t0="$(now)"
plan_state
plan_code && coded=yes || coded=no
t1="$(now)"
ms=$(((t1 - t0) / 1000000))
[ "$pl_state" = accepted ] && [ "$coded" = yes ] && [ "$ms" -lt 1000 ]
result $? "timing: (integration row) the plan check itself, on a local clone with 30 commits of code and no network, takes under 1 second ($ms ms)" "state $pl_state; code $coded"

# --- The PM role and /spec ----------------------------------------------------------

base feature
ctx_of() { # ctx_of [agent id]: the role a PM session in A is given
  jq -nc --arg s "$S1" --arg d "$A" --arg a "${1:-}" \
    '{session_id: $s, transcript_path: "/x/t.jsonl", cwd: $d, hook_event_name: "SessionStart", source: "startup"}
     + (if $a == "" then {} else {agent_id: $a, agent_type: "general-purpose"} end)' |
    env PAP_MODE=pm CLAUDE_PROJECT_DIR="$A" CLAUDE_PLUGIN_ROOT="$plugin" "$plugin/hooks/session-start.sh" 2>/dev/null |
    jq -r '.hookSpecificOutput.additionalContext // empty'
}
XDG_STATE_HOME="$T/state-role"
export XDG_STATE_HOME
ctx="$(ctx_of)"
routing="$(printf '%s\n' "$ctx" | awk '$0 == "[pap-pm:routing]" { on = 1; next } /^\[pap-pm:[a-z-]*\]$/ { on = 0 } on')"
launch="$(printf '%s\n' "$ctx" | awk '$0 == "[pap-pm:launch]" { on = 1; next } /^\[pap-pm:[a-z-]*\]$/ { on = 0 } on')"
printf '%s\n' "$routing" | grep -q 'then /pap:plan <slug> after /spec, for a feature, infra or security-sensitive change'
result $? "plan-step-37: the role a PM session is given names /pap:plan after /spec for feature, infra and security-sensitive changes" "$routing"
printf '%s\n' "$launch" | grep -q 'does not restate the plan'
result $? "plan-step-37: it says the brief of a build with an accepted plan does not restate the plan" "$launch"
ctx="$(ctx_of a3f9c2e17b5d4)"
[ "$(printf '%s\n' "$ctx" | wc -l | tr -d ' ')" -le 80 ] && [ "$(printf '%s\n' "$ctx" | wc -c | tr -d ' ')" -le 8192 ] && printf '%s\n' "$ctx" | grep -q '/pap:plan'
result $? "size: (unit row) the longest role, with the plan lines and the warning, is still at most 80 lines and 8 KB ($(printf '%s\n' "$ctx" | wc -l | tr -d ' ') lines, $(printf '%s\n' "$ctx" | wc -c | tr -d ' ') bytes)" ""

printf '1..%d\n' "$n"
[ "$failed" = 0 ]
