#!/bin/sh
# pm-mode-timing.test.sh: the timing rows of the Non-functional table in
# changes/pm-mode/spec.md (decision 0025). tests/pm-mode.test.sh has the
# scenarios and the other rows.
#
# Usage: sh tests/pm-mode-timing.test.sh
#        PAP_TRIAL_REPO=<path> sh tests/pm-mode-timing.test.sh
#
# Each row is measured as the spec says: in pap's own repository, this
# checkout, with a warm file cache, as the difference between a run with
# the guard and a run without, at the 95th percentile over the row's number
# of runs. A run with the guard is the hook, fed the JSON Claude Code sends
# and started as Claude Code starts it; a run without is nothing at all, so
# the hook's whole cost is counted, its shell and its jq included. For pap
# claude the two runs are pap claude in front of a stand-in claude, and
# that claude alone. The pairs alternate, after three warm-up pairs.
#
# The commit row is also run in the trial repository when PAP_TRIAL_REPO
# names its checkout, and skipped for it otherwise. The hooks only read the
# repositories; their logs and the tracker go to a temporary directory, as
# do HOME, XDG_STATE_HOME, XDG_CONFIG_HOME and CLAUDE_CONFIG_DIR. The
# claude the session-start hook asks for its version is the stand-in (the
# real one answers --version in about 10 ms).
#
# Prints one TAP-style line per row, with the measured value, and exits 1
# if any is over its threshold. A threshold is the spec's and is not to be
# loosened here: a row that fails is a finding. Needs git, jq and a clock
# with nanoseconds (GNU date, or perl); without one every row is skipped.

set -u
# shellcheck disable=SC1091 # tests/clean-env.sh, sourced from this directory
. "$(dirname "$0")/clean-env.sh"

here="$(cd "$(dirname "$0")/.." && pwd)"
pap="$here/bin/pap"
hooks="$here/plugins/pap/hooks"

for tool in git jq; do
  command -v "$tool" >/dev/null 2>&1 || { printf 'Bail out! %s not found\n' "$tool"; exit 1; }
done

T="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$T"' EXIT INT TERM
mkdir -p "$T/home/.claude/plugins" "$T/xdg" "$T/stub"
export HOME="$T/home" XDG_STATE_HOME="$T/state" XDG_CONFIG_HOME="$T/xdg" \
  CLAUDE_CONFIG_DIR="$T/home/.claude" GIT_CONFIG_GLOBAL="$T/gitconfig" GIT_CONFIG_NOSYSTEM=1
unset CLAUDE_PROJECT_DIR CLAUDE_PLUGIN_ROOT 2>/dev/null || true
: > "$GIT_CONFIG_GLOBAL"
cat > "$T/stub/claude" <<'EOF'
#!/bin/sh
case "${1:-}" in --version) echo "2.1.322 (Claude Code)" ;; esac
exit 0
EOF
printf '#!/bin/sh\nexit 0\n' > "$T/stub/gh"
chmod +x "$T/stub/claude" "$T/stub/gh"
PATH="$T/stub:$PATH"
export PATH
jq -n --arg k "pap@$(jq -r .name "$here/.claude-plugin/marketplace.json")" --arg p "$here/plugins/pap" \
  '{version: 2, plugins: {($k): [{installPath: $p}]}}' > "$CLAUDE_CONFIG_DIR/plugins/installed_plugins.json"

n=0
failed=0
result() { # result <ok 0|1> <label>
  n=$((n + 1))
  if [ "$1" = 0 ]; then printf 'ok %d - %s\n' "$n" "$2"; else printf 'not ok %d - %s\n' "$n" "$2"; failed=$((failed + 1)); fi
}
skip() { n=$((n + 1)); printf 'ok %d - %s # SKIP %s\n' "$n" "$1" "$2"; }

case "$(date +%s%N 2>/dev/null)" in
  "" | *[!0-9]*)
    if perl -MTime::HiRes -e 1 2>/dev/null; then now() { perl -MTime::HiRes=time -e 'printf "%d\n", time * 1e9'; }
    else now() { echo; }; fi ;;
  *) now() { date +%s%N; } ;;
esac

# p95 <runs> <with> <without>: prints the 95th percentile, in ms, of what
# the function <with> took over the function <without>.
p95() {
  i=-3
  : > "$T/samples"
  while [ "$i" -lt "$1" ]; do
    t0="$(now)"; "$2"; t1="$(now)"; "$3"; t2="$(now)"
    [ "$i" -lt 0 ] || echo $(((t1 - t0 - (t2 - t1)) / 1000000)) >> "$T/samples"
    i=$((i + 1))
  done
  sort -n "$T/samples" | sed -n "$((($1 * 95 + 99) / 100))p"
}
# row <threshold ms> <runs> <with> <without> <label>
row() {
  ms="$(p95 "$2" "$3" "$4")"
  [ -n "$ms" ] && [ "$ms" -le "$1" ]
  result $? "$5: $ms ms at the 95th percentile over $2 (at most $1 ms)"
}
nothing() { :; }

S1=0f6b2c1e-1a2b-4c3d-8e4f-5a6b7c8d9e01
call() { # call <tool> <path or command> [agent id]: the JSON of one tool call here
  jq -nc --arg s "$S1" --arg d "$here" --arg t "$1" --arg p "$2" --arg a "${3:-}" \
    '{session_id: $s, transcript_path: "/x/t.jsonl", cwd: $d, permission_mode: "default", hook_event_name: "PreToolUse", tool_name: $t,
      tool_input: (if $t == "Bash" then {command: $p} else {file_path: $p} end)}
     + (if $a == "" then {} else {agent_id: $a, agent_type: "pap:cycle"} end)'
}
in_refused="$(call Edit "$here/bin/pap")"
in_made="$(call Write "$here/changes/pm-mode/notes.md")"
in_sub="$(call Edit "$here/bin/pap" a3f9c2e17b5d4)"
in_commit="$(call Bash 'git commit -m x')"
in_start="$(jq -nc --arg s "$S1" --arg d "$here" '{session_id: $s, transcript_path: "/x/t.jsonl", cwd: $d, hook_event_name: "SessionStart", source: "startup"}')"

c=0
# A PM session's write: one refused (bin/pap), then one made (a PM path).
pm_write() {
  c=$((c + 1))
  if [ $((c % 2)) = 0 ]; then w_in="$in_refused"; else w_in="$in_made"; fi
  printf '%s' "$w_in" | PAP_MODE=pm CLAUDE_PROJECT_DIR="$here" CLAUDE_PLUGIN_ROOT="$here/plugins/pap" "$hooks/guard-pm.sh" >/dev/null 2>&1
}
# The callers the guard does not bind, in turn: a sub-agent of a PM
# session, a solo session, a session with no mode.
unbound() {
  c=$((c + 1))
  case $((c % 3)) in
    0) printf '%s' "$in_sub" | PAP_MODE=pm CLAUDE_PROJECT_DIR="$here" "$hooks/guard-pm.sh" >/dev/null 2>&1 ;;
    1) printf '%s' "$in_refused" | PAP_MODE=solo CLAUDE_PROJECT_DIR="$here" "$hooks/guard-pm.sh" >/dev/null 2>&1 ;;
    2) printf '%s' "$in_refused" | CLAUDE_PROJECT_DIR="$here" "$hooks/guard-pm.sh" >/dev/null 2>&1 ;;
  esac
}
role() {
  printf '%s' "$in_start" | PAP_MODE=pm CLAUDE_PROJECT_DIR="$here" CLAUDE_PLUGIN_ROOT="$here/plugins/pap" "$hooks/session-start.sh" >/dev/null 2>&1
}
with_pap() { (cd "$here" && sh "$pap" claude -p hi) >/dev/null 2>&1; }
claude_alone() { (cd "$here" && claude -p hi) >/dev/null 2>&1; }
repo="$here"
pm_commit() {
  printf '%s' "$in_commit" | PAP_MODE=pm CLAUDE_PROJECT_DIR="$repo" CLAUDE_PLUGIN_ROOT="$here/plugins/pap" "$hooks/guard-route.sh" >/dev/null 2>&1
}

if [ -z "$(now)" ]; then
  for r in "a PM session's Edit or Write" "a sub-agent's, a solo session's or a no-mode session's call" "the role at a session start" \
    "pap claude before Claude Code starts" "a PM session's git commit, in pap" "a PM session's git commit, in the trial repository"; do
    skip "timing: the guard adds to $r" "no clock with nanoseconds (GNU date or perl)"
  done
  printf '1..%d\n' "$n"
  exit 0
fi

# The rows only mean something if the hook did its work: the write it
# refuses is refused, the one it makes is made, the role is given.
printf '%s' "$in_refused" | PAP_MODE=pm CLAUDE_PROJECT_DIR="$here" "$hooks/guard-pm.sh" >/dev/null 2>&1
r1=$?
printf '%s' "$in_made" | PAP_MODE=pm CLAUDE_PROJECT_DIR="$here" "$hooks/guard-pm.sh" >/dev/null 2>&1
r2=$?
printf '%s' "$in_sub" | PAP_MODE=pm CLAUDE_PROJECT_DIR="$here" "$hooks/guard-pm.sh" >/dev/null 2>&1
r3=$?
[ "$r1" = 2 ] && [ "$r2" = 0 ] && [ "$r3" = 0 ] &&
  printf '%s' "$in_start" | PAP_MODE=pm CLAUDE_PROJECT_DIR="$here" "$hooks/session-start.sh" 2>/dev/null | grep -q 'pap-pm:role'
result $? "timing: what is timed works here: bin/pap refused ($r1), a PM path made ($r2), a sub-agent passed ($r3), the role given"

row 150 100 pm_write nothing "timing: the guard adds to one Edit or Write of a PM session, in pap"
row 30 100 unbound nothing "timing: the guard adds to one call of a sub-agent, a solo session or a session with no mode"

# The role with a tracker to read: started here, in the temporary state.
(cd "$here" && sh "$here/plugins/pap/skills/pm/pap-pm.sh" start --session "$S1") >/dev/null 2>&1
row 300 20 role nothing "timing: the session-start hook gives the role, tracker read"
row 200 20 with_pap claude_alone "timing: pap claude adds before Claude Code starts, a stand-in for claude"
row 500 50 pm_commit nothing "timing: the guard adds to one git commit of a PM session, work-tree scan included, in pap"
if [ -n "${PAP_TRIAL_REPO:-}" ] && [ -x "$PAP_TRIAL_REPO/scripts/guard-branch.sh" ]; then
  repo="$(cd "$PAP_TRIAL_REPO" && pwd -P)"
  in_commit="$(call Bash "git -C $repo commit -m x")"
  row 500 50 pm_commit nothing "timing: the guard adds to one git commit of a PM session, in the trial repository"
else
  skip "timing: the guard adds to one git commit of a PM session, in the trial repository" "PAP_TRIAL_REPO names no adopting checkout"
fi

printf '1..%d\n' "$n"
[ "$failed" = 0 ] || { printf '# %d of %d failed\n' "$failed" "$n"; exit 1; }
