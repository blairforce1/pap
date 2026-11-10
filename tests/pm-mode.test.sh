#!/bin/sh
# pm-mode.test.sh: the scenarios of features/pm-mode.feature, bound by ID,
# for PM mode (changes/pm-mode/spec.md, decision 0025): pap claude's mode,
# the role the session-start hook gives, the PM paths guard, the commit
# check, and /pap:pm's script and tracker. The spec's size, shell and zero
# rows are here too; its timing rows are in tests/pm-mode-timing.test.sh.
#
# Usage: sh tests/pm-mode.test.sh
#
# Never touches the network, the real home, ~/.claude or pap's real state
# directory: HOME, XDG_STATE_HOME, XDG_CONFIG_HOME and CLAUDE_CONFIG_DIR are
# under a temporary directory, and most cases take a state directory of
# their own (fresh). The hooks run from a copy of plugins/pap, as Claude
# Code runs them from an installed plugin's directory, and are fed the JSON
# Claude Code sends: session_id, cwd, tool_name, tool_input, and agent_id
# and agent_type only on a sub-agent's call.
#
#   A        adopts PAP, origin https://github.com/olive/trial.git, on main,
#            with a product layer; the PM session's own repository
#   A-trial  a work tree of A on change/trial, where commits are judged
#   B        a second adopting repository, not pap, on change/b
#   P        a second adopting repository whose origin is blairforce1/pap
#   N        adopts PAP, no product layer
#   S        adopts PAP, an SSH origin
#   K        adopts PAP, no origin; K-wt is a work tree of it
#   U        does not adopt PAP
#
# A hook only judges a call, so "the write is made" and "the file is
# unchanged" are shown by a stand-in for the tool: edit and tool_bash run
# the guard and then, unless it exits 2, make the write or run the command,
# as Claude Code does. pap claude runs against a claude on PATH that
# records its arguments and environment. Where a scenario's last step is
# the model's (starting the cycle, writing the pull request body), the case
# binds the script's half and the skill's text, and its label says so.
#
# Prints one TAP-style line per case and exits 1 if any case fails. Needs
# git and jq; shellcheck for one case, skipped without it.
#
# SC2319: each case passes the exit status of its condition on purpose.
# SC2016: the skills' and hooks.json's own text is matched as written.
# shellcheck disable=SC2319,SC2016

set -u
# shellcheck disable=SC1091 # tests/clean-env.sh, sourced from this directory
. "$(dirname "$0")/clean-env.sh"

here="$(cd "$(dirname "$0")/.." && pwd)"
pap="$here/bin/pap"

for tool in git jq; do
  command -v "$tool" >/dev/null 2>&1 || { printf 'Bail out! %s not found\n' "$tool"; exit 1; }
done

# pwd -P: macOS's temporary directory is under a symlink (/var to
# /private/var), and git and pwd report the resolved path.
T="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$T"' EXIT INT TERM
mkdir -p "$T/home/.claude/plugins" "$T/xdg/pap" "$T/stub" "$T/realgh" "$T/scratch"
export HOME="$T/home" XDG_STATE_HOME="$T/state" XDG_CONFIG_HOME="$T/xdg" \
  CLAUDE_CONFIG_DIR="$T/home/.claude" GIT_CONFIG_GLOBAL="$T/gitconfig" \
  GIT_CONFIG_NOSYSTEM=1 GIT_CEILING_DIRECTORIES="$T"
unset CLAUDE_PROJECT_DIR CLAUDE_PLUGIN_ROOT REMOTE_CONTAINERS 2>/dev/null || true
# No user in the machine's git config: the tracker commits all the same.
printf '[init]\n\tdefaultBranch = main\n' > "$GIT_CONFIG_GLOBAL"

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
skip() { n=$((n + 1)); printf 'ok %d - %s # SKIP %s\n' "$n" "$1" "$2"; }

# The plugin as installed: a copy, outside Claude Code's own plugins folder,
# so the directory the plugin runs from is judged by itself.
cp -R "$here/plugins/pap" "$T/plugin"
plugin="$T/plugin"
market="$(jq -r .name "$here/.claude-plugin/marketplace.json")"
plugin_on() {
  jq -n --arg k "pap@$market" --arg p "$plugin" '{version: 2, plugins: {($k): [{installPath: $p}]}}' \
    > "$CLAUDE_CONFIG_DIR/plugins/installed_plugins.json"
}
plugin_off() {
  jq -n '{version: 2, plugins: {"other@elsewhere": [{installPath: "/nowhere"}]}}' \
    > "$CLAUDE_CONFIG_DIR/plugins/installed_plugins.json"
}
plugin_on

# claude: records its arguments, directory and environment in $STUB_OUT.
# gh: a plain gh, first on PATH, so the suite's own shell is no agent shell
# even when it runs inside a pap claude session.
cat > "$T/stub/claude" <<'EOF'
#!/bin/sh
case "${1:-}" in --version) echo "2.1.322 (Claude Code)"; exit 0 ;; esac
[ -n "${STUB_OUT:-}" ] || exit 0
for a in "$@"; do printf '%s\n' "$a"; done > "$STUB_OUT/claude.args"
printf '%s\n' "$#" > "$STUB_OUT/claude.argc"
env > "$STUB_OUT/claude.env"
command -v gh > "$STUB_OUT/claude.gh"
pwd -P > "$STUB_OUT/claude.pwd"
EOF
printf '#!/bin/sh\nexit 0\n' > "$T/stub/gh"
# Behind the shim, for the sessions guard-route.sh judges: a real gh that is
# no shim (tests/guard-route.test.sh has the same world).
I="$T/install"
mkdir -p "$I/bin" "$I/scripts/shim" "$I/templates/base" "$T/xdg/gh-agent"
cp "$here/scripts/shim/gh" "$I/scripts/shim/gh"
printf '#!/bin/sh\nexit 1\n' > "$I/bin/pap"
printf '#!/bin/sh\n# PAP_SHIM_CHECK\nexit 0\n' > "$T/realgh/gh"
chmod +x "$T/stub/claude" "$T/stub/gh" "$I/scripts/shim/gh" "$I/bin/pap" "$T/realgh/gh"
chmod 700 "$T/xdg/gh-agent"
PATH="$T/stub:$PATH"
export PATH

# --- The repositories ---------------------------------------------------------

seed() { # seed <repository> <path>...
  s_r="$1"
  shift
  for s_f in "$@"; do
    mkdir -p "$(dirname "$s_r/$s_f")"
    printf 'seed of %s\n' "$s_f" > "$s_r/$s_f"
  done
}
mkrepo() { # mkrepo <dir> [path]...: an adopting repository, one commit on main
  m_r="$1"
  shift
  git init -q -b main "$m_r"
  git -C "$m_r" config user.name test
  git -C "$m_r" config user.email test@example.invalid
  git -C "$m_r" config commit.gpgsign false
  mkdir -p "$m_r/scripts"
  cp "$here/scripts/guard-branch.sh" "$m_r/scripts/guard-branch.sh"
  seed "$m_r" README.md "$@"
  git -C "$m_r" add -A
  git -C "$m_r" commit -q -m init
}
A="$T/A" W="$T/A-trial" B="$T/B" P="$T/P" N="$T/N" S="$T/S" K="$T/K" U="$T/U"
# A holds bin/pap and plugins/pap and still is not pap: its origin says so.
mkrepo "$A" bin/pap rules.md CLAUDE.md CHANGELOG.md decisions/0001-first.md \
  plugins/pap/hooks/guard-route.sh tests/guard-route.test.sh docs/run-a-project.md \
  docs/analysis.ipynb features/README.md features/trial.feature \
  changes/trial/intent.md changes/trial/spec.md \
  product/vision.md product/domain.md product/backlog.md
git -C "$A" remote add origin https://github.com/olive/trial.git
git -C "$A" worktree add -q -b change/trial "$W"
mkrepo "$B" bin/pap changes/trial/intent.md product/vision.md
git -C "$B" remote add origin https://github.com/olive/other.git
git -C "$B" switch -q -c change/b
mkrepo "$P" bin/pap changes/trial/intent.md product/vision.md
git -C "$P" remote add origin https://github.com/blairforce1/pap.git
mkrepo "$N" src/main.c
git -C "$N" remote add origin https://github.com/olive/fresh.git
mkrepo "$S" product/vision.md
git -C "$S" remote add origin git@github.com:olive/ssh-repo.git
mkrepo "$K" product/vision.md
git -C "$K" worktree add -q -b change/k "$T/K-wt"
git init -q -b main "$U"
seed "$U" notes.md

S1=0f6b2c1e-1a2b-4c3d-8e4f-5a6b7c8d9e01
S2=7d2e9a40-0b1c-4d2e-9f3a-4b5c6d7e8f02
R="$T/record"
k=0
# fresh: a state directory of its own for what follows.
fresh() {
  k=$((k + 1))
  XDG_STATE_HOME="$T/state$k"
  export XDG_STATE_HOME
  pmd="$XDG_STATE_HOME/pap/pm"
  rl="$pmd/refusals.log" sl="$pmd/sessions.log" ml="$pmd/messages.log" ll="$pmd/launches.log"
  trk="$pmd/trackers/olive/trial"
}
lines() { if [ -f "$1" ]; then wc -l < "$1" | tr -d ' '; else echo 0; fi; }
field() { tail -n 1 "$1" 2>/dev/null | cut -f "$2"; } # field <log> <n>: of its last line
sig() { if [ -e "$1" ]; then cksum < "$1"; else echo absent; fi; }
has() { printf '%s\n' "$err" | grep -qF -- "$1"; }
menv() { m=""; case "$1" in pm | solo) m="PAP_MODE=$1" ;; esac; }

# --- The drivers ---------------------------------------------------------------

# pc <dir> [argument]...: pap claude in <dir>, with $penv, one assignment,
# added to its environment. Sets rc and err (stderr); the claude it started left its
# record in $R, or nothing if none started.
penv=""
pc() {
  pc_d="$1"
  shift
  rm -rf "$R"
  mkdir -p "$R"
  err="$(cd "$pc_d" && env ${penv:+"$penv"} STUB_OUT="$R" sh "$pap" claude "$@" 2>&1 >/dev/null)"
  rc=$?
}
started() { [ -f "$R/claude.args" ]; }
stub_mode() { v="$(sed -n 's/^PAP_MODE=//p' "$R/claude.env" 2>/dev/null)"; printf '%s\n' "${v:-none}"; }

# ss <mode> <dir> <source> [agent id]: the SessionStart hook. Sets raw (its
# stdout), ctx (the context it gives) and rc.
ss() {
  menv "$1"
  ss_in="$(jq -nc --arg s "$S1" --arg d "$2" --arg src "$3" --arg a "${4:-}" \
    '{session_id: $s, transcript_path: "/x/t.jsonl", cwd: $d, hook_event_name: "SessionStart", source: $src}
     + (if $a == "" then {} else {agent_id: $a, agent_type: "general-purpose"} end)')"
  raw="$(printf '%s' "$ss_in" | env ${m:+"$m"} CLAUDE_PROJECT_DIR="$2" CLAUDE_PLUGIN_ROOT="$plugin" "$plugin/hooks/session-start.sh" 2>/dev/null)"
  rc=$?
  ctx="$(printf '%s' "$raw" | jq -r 'select(.hookSpecificOutput.hookEventName == "SessionStart") | .hookSpecificOutput.additionalContext // empty' 2>/dev/null)"
}
# part <name>: the lines of the role's part [pap-pm:<name>], up to the next marker.
part() {
  printf '%s\n' "$ctx" | awk -v m="[pap-pm:$1]" '$0 == m { on = 1; next } /^\[pap-pm:[a-z-]*\]$/ { on = 0 } on'
}
in_part() { part "$1" | grep -qF -- "$2"; }
markers() { printf '%s\n' "$ctx" | grep -c '^\[pap-pm:[a-z-]*\]$'; }

# edit <mode> <project> <tool> <path> [agent id] [agent type]: one Edit,
# Write or NotebookEdit call: the guard, then, unless it exits 2, the write
# (a line appended). Sets rc and err.
mark="WRITTEN-BY-THE-TOOL"
edit() {
  menv "$1"
  e_k=file_path
  [ "$3" != NotebookEdit ] || e_k=notebook_path
  e_in="$(jq -nc --arg s "$S1" --arg d "$2" --arg t "$3" --arg k "$e_k" --arg p "$4" --arg a "${5:-}" --arg at "${6:-}" \
    '{session_id: $s, transcript_path: "/x/t.jsonl", cwd: $d, permission_mode: "default", hook_event_name: "PreToolUse",
      tool_name: $t, tool_input: {($k): $p, content: "x"}}
     + (if $a == "" then {} else {agent_id: $a, agent_type: $at} end)')"
  err="$(printf '%s' "$e_in" | env ${m:+"$m"} CLAUDE_PROJECT_DIR="$2" CLAUDE_PLUGIN_ROOT="$plugin" "$plugin/hooks/guard-pm.sh" 2>&1 >/dev/null)"
  rc=$?
  [ "$rc" = 2 ] || { mkdir -p "$(dirname "$4")" && printf '%s\n' "$mark" >> "$4"; } 2>/dev/null
}
made() { [ "$rc" = 0 ] && [ "$(tail -n 1 "$1" 2>/dev/null)" = "$mark" ]; }
sub_calls=0 sub_refused=0

# route <mode> <project> <cwd> <command> [agent id] [agent type]: one Bash
# call, judged by guard-route.sh in a session pap claude started. Sets rc
# and err. tool_bash then runs the command unless it was refused.
route() {
  menv "$1"
  r_in="$(jq -nc --arg s "$S1" --arg d "$3" --arg c "$4" --arg a "${5:-}" --arg at "${6:-}" \
    '{session_id: $s, transcript_path: "/x/t.jsonl", cwd: $d, permission_mode: "default", hook_event_name: "PreToolUse",
      tool_name: "Bash", tool_input: {command: $c}}
     + (if $a == "" then {} else {agent_id: $a, agent_type: $at} end)')"
  err="$(printf '%s' "$r_in" | env ${m:+"$m"} CLAUDE_PROJECT_DIR="$2" CLAUDE_PLUGIN_ROOT="$plugin" \
    GH_CONFIG_DIR="$T/xdg/gh-agent" PATH="$I/scripts/shim:$T/realgh:$PATH" "$plugin/hooks/guard-route.sh" 2>&1 >/dev/null)"
  rc=$?
}
tool_bash() {
  route "$@"
  [ "$rc" = 2 ] || (cd "$3" && sh -c "$4") >/dev/null 2>&1 </dev/null
}

# pm <dir> <argument>...: /pap:pm's script, as the skill runs it in <dir>.
# Sets out (stdout and stderr) and rc. at <hh:mm:ss> sets the time of what
# follows; tevent appends one event line, as the PM does.
script="$plugin/skills/pm/pap-pm.sh"
pm() {
  p_d="$1"
  shift
  out="$(cd "$p_d" && sh "$script" "$@" 2>&1)"
  rc=$?
}
at() { PAP_PM_NOW="2026-11-10T$1Z"; export PAP_PM_NOW; }
tevent() { printf '%s\t%s\t%s\t%s\n' "$PAP_PM_NOW" "$1" "$2" "$3" >> "$trk/events.tsv"; }
brief() { # brief <slug> [a line more]
  mkdir -p "$trk/briefs"
  printf '%s\n' "/change $1 bugfix" "Rule 20.2: exempt: a bugfix with a failing test" "" \
    "Fix the thing." "Budget: 200000 tokens" ${2:+"$2"} > "$trk/briefs/$1.md"
}
# typed <dir> <session> <prompt> [agent id]: the UserPromptSubmit hook.
typed() {
  jq -nc --arg s "$2" --arg d "$1" --arg p "$3" --arg a "${4:-}" \
    '{session_id: $s, transcript_path: "/x/t.jsonl", cwd: $d, permission_mode: "default", hook_event_name: "UserPromptSubmit", prompt: $p}
     + (if $a == "" then {} else {agent_id: $a, agent_type: "pap:cycle"} end)' |
    env PAP_MODE=pm CLAUDE_PROJECT_DIR="$1" CLAUDE_PLUGIN_ROOT="$plugin" "$plugin/hooks/pm-log.sh" prompt
}
# ready <slug> [a brief line more]: a started tracker, the ask restated, a
# complete brief, both committed, and the launch the owner typed. Each test
# of a refusal takes one of these away.
ready() {
  fresh
  at 10:00:00; pm "$A" start --session "$S1"
  at 10:01:00; tevent restate "$1" "fix the thing the owner named"
  brief "$@"
  pm "$A" commit --session "$S1"
  at 10:02:00; typed "$A" "$S1" "/pap:pm launch $1"
  at 10:03:00
}
thead() { git -C "$trk" rev-parse HEAD 2>/dev/null; }
tclean() { [ -z "$(git -C "$trk" status --porcelain 2>/dev/null)" ]; }
events() { grep -c "$(printf '\t')$1$(printf '\t')" "$trk/events.tsv"; } # events <event>: how many
# no_cycle: the script refused and named no agent, so the skill starts none.
# as_was: the tracker is there, and is what $ev0 and $h0 recorded of it.
no_cycle() { [ "$rc" != 0 ] && [ -n "$out" ] && ! printf '%s\n' "$out" | grep -q '^agent:'; }
as_was() { [ -n "$h0" ] && [ "$(thead)" = "$h0" ] && [ "$ev0" != absent ] && [ "$(sig "$trk/events.tsv")" = "$ev0" ]; }
said() { printf '%s\n' "$out" | grep -qF -- "$1"; }

# --- pap claude sets the mode ---------------------------------------------------

fresh
pc "$A"
mode="$(stub_mode)"
[ "$rc" = 0 ] && started && [ "$mode" = pm ] && [ "$(cat "$R/claude.pwd")" = "$A" ]
result $? "pm-mode-1: pap claude in an adopting repository starts Claude Code there with PAP_MODE=pm" "exit $rc, mode $mode; $err"
[ "$(lines "$sl")" = 1 ] && [ "$(field "$sl" 3)" = pm ] && [ "$(field "$sl" 4)" = olive/trial ] && [ "$(field "$sl" 6)" = start ] &&
  field "$sl" 1 | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'
result $? "pm-mode-1: the start is one line in the session log naming pm and the repository" "$(cat "$sl" 2>&1)"
grep -qx "GH_CONFIG_DIR=$T/xdg/gh-agent" "$R/claude.env" && [ "$(cat "$R/claude.gh")" = "$here/scripts/shim/gh" ] &&
  ! grep -q -e '^GH_TOKEN=' -e '^GITHUB_TOKEN=' "$R/claude.env" &&
  grep -q '^GIT_CONFIG_VALUE_[0-9]*=!gh auth git-credential$' "$R/claude.env"
result $? "pm-mode-1: gh in the session acts as the agent installation: the agent's gh directory, pap's gh first, no token" "$(grep -e '^GH' -e '^GIT_CONFIG' "$R/claude.env"; cat "$R/claude.gh")"
ss "$mode" "$A" startup
[ "$rc" = 0 ] && [ "$(printf '%s\n' "$ctx" | sed -n 1p)" = '[pap-pm:role]' ] &&
  in_part role 'You are the project manager' && in_part role 'You open, approve and merge nothing' && in_part role 'rule 18.1' &&
  in_part routing '/intent <slug> <class>' && in_part routing 'a cycle through /pap:pm launch' &&
  in_part paths 'changes/<slug>/**, features/<slug>.feature, product/** and the tracker'
result $? "pm-mode-1: the session is given the role: project manager, the routes, the PM paths, and that it opens, approves and merges nothing" "$ctx"
[ "$(lines "$sl")" = 2 ] && [ "$(field "$sl" 2)" = "$S1" ] && [ "$(field "$sl" 3)" = pm ] && [ "$(field "$sl" 4)" = olive/trial ] &&
  [ "$(field "$sl" 5)" = 2.1.322 ] && [ "$(field "$sl" 6)" = role:startup ]
result $? "pm-mode-1: the role given at the start is a second line, naming pm, the repository and the Claude Code version" "$(cat "$sl" 2>&1)"
for pt in role first-line routing no-route paths blocked-commit launch tracker; do
  [ -n "$(part "$pt")" ] || break
done
[ -n "$(part "$pt")" ] && [ "$pt" = tracker ] && [ "$(markers)" = 8 ]
result $? "pm-mode-1: each of the role's eight parts opens with its marker line, and no warning part is given" "stopped at $pt; $(markers) markers"

fresh
pc "$A/docs"
[ "$(stub_mode)" = pm ] && [ "$(field "$sl" 4)" = olive/trial ]
result $? "pm-mode-1: from a directory inside the repository the session is a PM session too" "mode $(stub_mode); $(cat "$sl" 2>&1)"
pc "$W"
[ "$(stub_mode)" = pm ] && [ "$(field "$sl" 4)" = olive/trial ]
result $? "pm-mode-1: from a work tree of the repository the session is a PM session of that repository" "mode $(stub_mode); $(cat "$sl" 2>&1)"
rm -rf "$R"; mkdir -p "$R"
helptext="$(cd "$A" && STUB_OUT="$R" sh "$pap" claude --help 2>&1)"
printf '%s\n' "$helptext" | grep -q 'By default, in a repository that adopts PAP' &&
  printf '%s\n' "$helptext" | grep -q 'the session is the project manager' &&
  printf '%s\n' "$helptext" | grep -q -- '--solo  starts a session without the mode' &&
  [ "$(cat "$R/claude.args")" = --help ]
result $? "pm-mode-1: pap claude --help says what the default is and what --solo does, before Claude Code's own help" "$helptext"

fresh
penv="PAP_MODE=pm"
pc "$U"
penv=""
mode="$(stub_mode)"
[ "$rc" = 0 ] && started && [ "$mode" = none ] && [ "$(lines "$sl")" = 1 ] && [ "$(field "$sl" 3)" = none ] && [ "$(field "$sl" 4)" = - ]
result $? "pm-mode-6: outside an adopting repository pap claude starts a session with no mode, even with PAP_MODE=pm in its own environment" "mode $mode; $(cat "$sl" 2>&1)"
ss "$mode" "$U" startup
[ "$rc" = 0 ] && [ -z "$raw" ] && [ "$(lines "$sl")" = 1 ]
result $? "pm-mode-6: that session is given no role: the hook prints nothing and logs nothing" "$raw"
before="$(lines "$rl")"
edit "$mode" "$U" Edit "$U/notes.md"
made "$U/notes.md" && [ "$(lines "$rl")" = "$before" ]
result $? "pm-mode-6: in that session no write is refused as outside the PM paths" "exit $rc; $err"

fresh
pc "$A" --resume 0f6b2c1e -p "two words here" --model opus --append-system-prompt "a
two-line value"
[ "$(stub_mode)" = pm ] && [ "$(cat "$R/claude.argc")" = 8 ] &&
  [ "$(cat "$R/claude.args")" = "--resume
0f6b2c1e
-p
two words here
--model
opus
--append-system-prompt
a
two-line value" ]
result $? "pm-mode-7: arguments that are not pap's own reach Claude Code unchanged, in order, in a PM session" "$(cat "$R/claude.args" 2>&1)"
pc "$A" -p x -- --solo
[ "$(stub_mode)" = pm ] && [ "$(tr '\n' ' ' < "$R/claude.args")" = "-p x -- --solo " ]
result $? "pm-mode-7: a --solo after -- is Claude Code's argument and is passed on, in a PM session" "mode $(stub_mode); $(cat "$R/claude.args" 2>&1)"

fresh
plugin_off
pc "$A"
plugin_on
mode="$(stub_mode)"
has 'PM mode needs the pap plugin' && has 'claude plugin install pap --marketplace blairforce1/pap'
result $? "pm-mode-50: without the pap plugin, pap claude says PM mode needs it and gives the command that installs it" "$err"
[ "$rc" = 0 ] && started && [ "$mode" = none ]
result $? "pm-mode-50: a session still starts, and it is not a PM session" "exit $rc, mode $mode"
[ "$(lines "$sl")" = 1 ] && [ "$(field "$sl" 3)" = none ] && [ "$(field "$sl" 4)" = olive/trial ] && [ "$(field "$sl" 6)" = no-plugin ]
result $? "pm-mode-50: the session log gains one line naming no mode and the missing plugin" "$(cat "$sl" 2>&1)"
rm -f "$CLAUDE_CONFIG_DIR/plugins/installed_plugins.json"
pc "$A"
plugin_on
[ "$(stub_mode)" = none ] && has 'PM mode needs the pap plugin'
result $? "pm-mode-50: a machine with no installed-plugins file at all is the same: no mode, and it says why" "mode $(stub_mode); $err"

# --- A solo session is the owner's ------------------------------------------------

fresh
pc "$A" --solo -p hi
mode="$(stub_mode)"
[ "$rc" = 0 ] && [ "$mode" = solo ] && [ "$(tr '\n' ' ' < "$R/claude.args")" = "-p hi " ]
result $? "pm-mode-8: pap claude --solo in an adopting repository starts a solo session, and --solo is taken out of the arguments" "mode $mode; $(cat "$R/claude.args" 2>&1)"
[ "$(lines "$sl")" = 1 ] && [ "$(field "$sl" 3)" = solo ] && [ "$(field "$sl" 4)" = olive/trial ]
result $? "pm-mode-8: the session log gains one line naming solo and the repository" "$(cat "$sl" 2>&1)"
ss "$mode" "$A" startup
[ "$(printf '%s\n' "$ctx" | wc -l | tr -d ' ')" = 1 ] && printf '%s\n' "$ctx" | grep -q 'This is a solo session' &&
  [ "$(markers)" = 0 ] && ! printf '%s\n' "$ctx" | grep -q 'You are the project manager'
result $? "pm-mode-8: the solo session is given one line saying it is solo, and no project-manager role" "$ctx"
[ "$(field "$sl" 3)" = solo ] && [ "$(field "$sl" 6)" = solo:startup ] && [ "$(field "$sl" 5)" = 2.1.322 ]
result $? "pm-mode-8: that line is logged as solo, with the Claude Code version" "$(cat "$sl" 2>&1)"
before="$(sig "$A/bin/pap")"
edit "$mode" "$A" Edit "$A/bin/pap"
made "$A/bin/pap" && [ "$(sig "$A/bin/pap")" != "$before" ] && [ "$(lines "$rl")" = 0 ]
result $? "pm-mode-8: in the solo session a write to bin/pap is made, and nothing is in the refusal log" "exit $rc; $err"
git -C "$A" checkout -q -- bin/pap

fresh
pc "$U" --solo
[ "$rc" = 0 ] && started && [ "$(stub_mode)" = solo ] && [ "$(cat "$R/claude.argc")" = 0 ]
result $? "pm-mode-48: pap claude --solo outside every adopting repository starts a solo session" "exit $rc, mode $(stub_mode); $err"
[ "$(lines "$sl")" = 1 ] && [ "$(field "$sl" 3)" = solo ] && [ "$(field "$sl" 4)" = - ]
result $? "pm-mode-48: the session log gains one line naming solo, and no repository" "$(cat "$sl" 2>&1)"

# The mode is this start's: what the earlier start left in the environment
# is the plausible wrong answer, so each row starts with it set.
fresh
penv="PAP_MODE=solo"
pc "$A" --resume
penv=""
mode="$(stub_mode)"
ss "$mode" "$A" resume
[ "$mode" = pm ] && [ "$(cat "$R/claude.args")" = --resume ] && in_part role 'You are the project manager' && [ "$(field "$sl" 6)" = role:resume ]
result $? "pm-mode-49: a conversation begun solo, resumed with pap claude --resume, is a PM session and is given the role" "mode $mode; $(cat "$R/claude.args" 2>&1)"
penv="PAP_MODE=pm"
pc "$A" --solo --resume
penv=""
mode="$(stub_mode)"
ss "$mode" "$A" resume
[ "$mode" = solo ] && [ "$(cat "$R/claude.args")" = --resume ] && [ "$(markers)" = 0 ] && [ "$(field "$sl" 6)" = solo:resume ]
result $? "pm-mode-49: a conversation begun PM, resumed with pap claude --solo --resume, is a solo session and is given no role" "mode $mode; $(cat "$R/claude.args" 2>&1)"

for row in "the session marker Claude Code sets|CLAUDECODE=1|the session marker CLAUDECODE is set" \
  "the agent's gh directory in use|GH_CONFIG_DIR=$T/xdg/gh-agent|GH_CONFIG_DIR is the agent's gh directory" \
  "the agent's gh first on the path|PATH=$here/scripts/shim:$PATH|the agent's gh, $here/scripts/shim/gh, is first on PATH"; do
  name="${row%%|*}" rest="${row#*|}"
  fresh
  penv="${rest%%|*}"
  pc "$A" --solo
  [ "$rc" = 1 ] && has "${rest#*|}" && has 'from your own terminal, run: pap claude --solo' && ! started && [ "$(lines "$sl")" = 0 ]
  result $? "pm-mode-9: --solo in an agent shell known by $name is refused, naming the signal and the command; no session starts" "exit $rc; $err"
  pc "$A"
  [ "$rc" = 0 ] && started && [ "$(stub_mode)" = pm ]
  result $? "pm-mode-9: the same shell without --solo starts a PM session, so it is the flag that is refused" "exit $rc, mode $(stub_mode); $err"
  penv=""
done

# pm-mode-34 is bound through pap claude, not through a run of pap new: the
# welcome session is the same cmd_claude, handed the welcome as its one
# argument (tests/pap-new.test.sh binds what the run did and the listing).
fresh
welcome="In one line, welcome the owner to the Personal Agentic Process (PAP).
What happened: pap new made the first commit.
<installed>
skills:
</installed>"
pc "$N" "$welcome"
mode="$(stub_mode)"
[ "$mode" = pm ] && [ "$(cat "$R/claude.pwd")" = "$N" ] && [ "$(cat "$R/claude.argc")" = 1 ] && [ "$(cat "$R/claude.args")" = "$welcome" ]
result $? "pm-mode-34: (through pap claude in a fresh adopting clone, as pap new starts it) the welcome session is a PM session in the clone, given the welcome unchanged" "mode $mode; $(cat "$R/claude.args" 2>&1)"
ss "$mode" "$N" startup
in_part routing '/envision, first' && in_part tracker 'Launch and resume nothing until the owner says'
result $? "pm-mode-34: (same) its role says /envision is the route to propose first, and to launch nothing until the owner says" "$ctx"
sed -n '/^cmd_new() {/,/^}/p' "$pap" | grep -q '^  cmd_claude "\$prompt"$' &&
  grep -q 'Start none of it yourself: run no skill and no command until the owner answers' "$pap" &&
  grep -q 'What happened: pap new \$did' "$pap"
result $? "pm-mode-34: (the text of bin/pap) pap new ends in cmd_claude with the welcome: what the run did, and start nothing until the owner answers" ""

# One key, two programs: bin/pap's c_key writes the start's line, pm-lib.sh's
# pm_key the role's. A work tree of a repository with no origin tells the
# main work tree's path from the work tree's own.
for row in "an HTTPS origin|$A|olive/trial" "an SSH origin|$S|olive/ssh-repo" \
  "no origin|$K|_path/$(printf '%s' "$K" | tr '/' '%')" "no origin, from a work tree|$T/K-wt|_path/$(printf '%s' "$K" | tr '/' '%')"; do
  name="${row%%|*}" rest="${row#*|}"
  fresh
  pc "${rest%%|*}"
  k1="$(field "$sl" 4)"
  ss pm "${rest%%|*}" startup
  k2="$(field "$sl" 4)"
  [ "$(lines "$sl")" = 2 ] && [ "$k1" = "${rest#*|}" ] && [ "$k2" = "$k1" ]
  result $? "key: bin/pap (c_key) and pm-lib.sh (pm_key) give a repository with $name the same key, ${rest#*|}" "c_key '$k1', pm_key '$k2'"
done

# --- The role ---------------------------------------------------------------------

fresh
ss pm "$N" startup
in_part routing '/envision, first: this repository has no product layer' && in_part tracker 'and after /envision'
result $? "pm-mode-2: with no product layer the session is told /envision is the route to propose first" "$(part routing)"

ss pm "$A" startup
in_part routing 'is answered. Launch nothing.' && ! in_part routing '/envision'
result $? "pm-mode-3: with a product layer the session is told to answer a question and launch nothing, and /envision is not proposed" "$(part routing)"
in_part routing '/intent <slug> <class>, then /spec <slug>, when rule 20.2 says the change needs an intent' &&
  in_part routing 'a cycle through /pap:pm launch for any other ripe ask'
result $? "pm-mode-3: it is told to propose /intent for a ripe ask rule 20.2 says needs one, and a cycle for any other ripe ask" "$(part routing)"
in_part routing 'An ask that is not yet ripe is talked through. Propose a route only once the ask is ripe' &&
  in_part routing 'A ripe ask gets one proposed route'
result $? "pm-mode-3: it is told to propose a route only once the ask is ripe" "$(part routing)"
in_part routing 'A skill the owner invokes runs as invoked; propose no route in its place.'
result $? "pm-mode-4: it is told a skill the owner invokes runs as invoked, with no route proposed in its place" "$(part routing)"

ss pm "$P" startup
in_part no-route 'An ask no route covers stops' && in_part no-route 'propose an /intent for the missing route' &&
  ! in_part no-route 'text of an issue'
result $? "pm-mode-5: in pap itself the session is told an ask with no route stops, and that it then proposes an /intent for the missing route" "$(part no-route)"
in_part no-route 'File nothing yourself.'
result $? "pm-mode-5: in pap itself it is told to file nothing itself" "$(part no-route)"
ss pm "$A" startup
in_part no-route 'An ask no route covers stops' && in_part no-route 'Give the owner the text of an issue for blairforce1/pap, for the owner to file.' &&
  in_part no-route 'carries nothing from this repository' && ! in_part no-route 'propose an /intent for the missing route'
result $? "pm-mode-5: in a repository that is not pap it is told an ask with no route stops, and that it then gives the owner the text of an issue for blairforce1/pap, for the owner to file" "$(part no-route)"
in_part no-route 'File nothing yourself.'
result $? "pm-mode-5: in a repository that is not pap it is told to file nothing itself" "$(part no-route)"

in_part first-line 'Open your first reply of this session with one line to the owner' && in_part first-line 'this is a PM session' &&
  in_part first-line 'it writes only the PM paths' && in_part first-line 'pap claude --solo starts a session without the mode'
result $? "pm-mode-47: the session is told to open with one line to the owner: a PM session, it writes only the PM paths, pap claude --solo is the way out" "$(part first-line)"
in_part blocked-commit 'Then report the files to the owner and stop.'
result $? "pm-mode-54: the session is told that on a refused commit it reports the files and stops" "$(part blocked-commit)"
in_part blocked-commit 'Never stash, clean, check out or delete a file to clear the block'
result $? "pm-mode-54: it is told never to stash, clean, check out or delete a file to clear the block" "$(part blocked-commit)"

fresh
ss pm "$A" startup sub-agent-id-0a1b2c
[ "$(printf '%s\n' "$ctx" | sed -n 1p)" = '[pap-pm:warning]' ] && in_part warning 'the PM paths are NOT enforced in this session' &&
  [ "$(printf '%s\n' "$ctx" | grep -n '^\[pap-pm:role\]$' | cut -d: -f1)" -gt 1 ]
result $? "pm-mode-35: when the main session's own call carries an agent id, the role opens with a warning that the PM paths are not enforced" "$(printf '%s\n' "$ctx" | sed -n 1,4p)"
in_part warning 'Say so to the owner in your first line' && in_part warning '2.1.322'
result $? "pm-mode-35: the session is told to say so to the owner in its first line, with the Claude Code version" "$(part warning)"
[ "$(lines "$sl")" = 1 ] && [ "$(field "$sl" 6)" = role:startup:unbound ] && [ "$(field "$sl" 5)" = 2.1.322 ] && [ "$(field "$sl" 2)" = "$S1" ]
result $? "pm-mode-35: the session log gains one line recording it, with the Claude Code version" "$(cat "$sl" 2>&1)"

fresh
ss pm "$A" startup
in_part tracker 'The tracker is not started. /pap:pm start, which the owner types, comes before the first launch' &&
  ! in_part tracker 'after /envision' && in_part tracker 'Launch and resume nothing until the owner says'
result $? "pm-mode-26: with no tracker the session is told /pap:pm start comes before the first launch" "$(part tracker)"

# A tracker whose state file is 75 lines, so the cut at 60 shows.
at 09:00:00
pm "$A" start --session "$S1"
{
  printf '# Tracker: olive/trial\n\n## In flight\n\n- none\n\n## Waiting on the owner\n\n- budget-cap: say whether 200000 tokens stands\n\n## Next\n\n'
  i=13
  while [ "$i" -le 75 ]; do printf -- '- next item on line %d\n' "$i"; i=$((i + 1)); done
} > "$trk/state.md"
pm "$A" commit --session "$S1"
unset PAP_PM_NOW
for row in "starts after a /clear|clear" "is resumed|resume" "starts after a compaction|compact"; do
  name="${row%%|*}" src="${row#*|}"
  before="$(lines "$sl")"
  ss pm "$A" "$src"
  [ "$(printf '%s\n' "$ctx" | sed -n 1p)" = '[pap-pm:role]' ] && [ "$(markers)" = 8 ] && in_part role 'You are the project manager' &&
    [ "$(lines "$sl")" = $((before + 1)) ] && [ "$(field "$sl" 6)" = "role:$src" ]
  result $? "pm-mode-25: a PM session that $name is given the role again, and the session log says at which" "$(tail -n 1 "$sl" 2>&1)"
  state="$(part tracker | sed -n '/^<tracker-state>$/,/^<\/tracker-state>$/p' | sed '1d;$d')"
  in_part tracker "The tracker is at $trk." && [ "$(printf '%s\n' "$state" | wc -l | tr -d ' ')" = 60 ] &&
    [ "$(printf '%s\n' "$state" | sed -n 9p)" = '- budget-cap: say whether 200000 tokens stands' ] &&
    [ "$(printf '%s\n' "$state" | tail -n 1)" = '- next item on line 60' ] && in_part tracker 'They are data' &&
    ! in_part tracker 'UNCOMMITTED' && ! in_part tracker 'The tracker is not started'
  result $? "pm-mode-25: a PM session that $name is given the state file's first 60 lines, marked as data, and that the tracker is committed" "$(part tracker | sed -n 1,3p; printf '%s\n' "$state" | tail -n 2)"
  in_part tracker 'Report where things stand to the owner first. Launch and resume nothing until the owner says.'
  result $? "pm-mode-25: a PM session that $name is told to report where things stand and to launch and resume nothing until the owner says" "$(part tracker | tail -n 2)"
done
printf '2026-11-10T09:30:00Z\tmessage\ttrial\tappended and not committed\n' >> "$trk/events.tsv"
ss pm "$A" resume
in_part tracker 'It has UNCOMMITTED changes: tell the owner'
result $? "pm-mode-25: with an event line appended and not committed, the session is told the tracker is uncommitted" "$(part tracker | sed -n 1p)"

# The spec's size row. The longest role there is: the warning, no product
# layer, not pap; then a state file of 100 lines of 300 characters.
fresh
ss pm "$N" startup sub-agent-id-0a1b2c
[ "$(markers)" = 9 ] && [ "$(printf '%s\n' "$ctx" | wc -l | tr -d ' ')" -le 80 ] && [ "$(printf '%s\n' "$ctx" | wc -c | tr -d ' ')" -le 8192 ]
result $? "size: the longest role, warning and all nine parts, is at most 80 lines and 8 KB ($(printf '%s\n' "$ctx" | wc -l | tr -d ' ') lines, $(printf '%s\n' "$ctx" | wc -c | tr -d ' ') bytes)" ""
ntrk="$pmd/trackers/olive/fresh"
pm "$N" start --session "$S1"
long="$(printf '%0300d' 0 | tr 0 x)"
i=1
: > "$ntrk/state.md"
while [ "$i" -le 100 ]; do printf 'L%d %s\n' "$i" "$long" >> "$ntrk/state.md"; i=$((i + 1)); done
ss pm "$N" compact sub-agent-id-0a1b2c
state="$(part tracker | sed -n '/^<tracker-state>$/,/^<\/tracker-state>$/p' | sed '1d;$d')"
frame="$(printf '%s\n' "$ctx" | awk '/^<tracker-state>$/ { print; skip = 1; next } /^<\/tracker-state>$/ { skip = 0 } !skip')"
sl_n="$(printf '%s\n' "$state" | wc -l | tr -d ' ')"
[ "$sl_n" -ge 1 ] && [ "$sl_n" -le 60 ] && [ "$(printf '%s\n' "$state" | sed -n 1p | cut -c1-3)" = 'L1 ' ] && ! printf '%s\n' "$state" | grep -q '^L61 ' &&
  [ "$(printf '%s\n' "$frame" | wc -l | tr -d ' ')" -le 80 ] && [ "$(printf '%s\n' "$frame" | wc -c | tr -d ' ')" -le 8192 ]
result $? "size: with a 100-line state file the role stays at most 80 lines and 8 KB, plus at most 60 lines of the state file ($(printf '%s\n' "$frame" | wc -l | tr -d ' ') lines, $(printf '%s\n' "$frame" | wc -c | tr -d ' ') bytes, $sl_n state lines)" ""
[ "${#ctx}" -lt 10000 ] && [ "${#raw}" -gt "${#ctx}" ]
result $? "size: the whole context, role and state, is under Claude Code's 10,000 characters (${#ctx})" ""

# --- The PM session writes only the PM paths -------------------------------------

fresh
at 09:00:00
pm "$A" start --session "$S1"
unset PAP_PM_NOW
for row in "changes/trial/intent.md|Write" "changes/trial/spec.md|Edit" "changes/trial/reviews/spec-review.md|Write" \
  "features/trial.feature|Write" "product/domain.md|Edit" "product/backlog.md|Edit" \
  "the tracker's state file|Write|$trk/state.md" "the tracker's event log|Edit|$trk/events.tsv" \
  "changes/trial/reviews/deep/notes.md|Write" "features/a.b-c_d.feature|Write"; do
  name="${row%%|*}" rest="${row#*|}"
  tool="${rest%%|*}" p="$A/$name"
  case "$rest" in *"|"*) p="${rest#*|}" ;; esac
  before="$(sig "$p")"
  edit pm "$A" "$tool" "$p"
  made "$p" && [ "$(sig "$p")" != "$before" ] && [ "$(lines "$rl")" = 0 ]
  result $? "pm-mode-10: the PM session writes $name with $tool, and the write is made" "exit $rc; $err"
done
edit pm "$A" Write "$W/changes/trial/plan.md"
made "$W/changes/trial/plan.md"
result $? "pm-mode-10: a PM path in a work tree of the session's repository is written too" "exit $rc; $err"
rm -f "$W/changes/trial/plan.md"
(cd "$A" && git checkout -q -- . && git clean -qfd)

for row in "bin/pap|Edit" "rules.md|Edit" "decisions/0025-a-new-record.md|Write" "plugins/pap/hooks/guard-route.sh|Edit" \
  "tests/guard-route.test.sh|Write" "CLAUDE.md|Edit" "README.md|Write" "features/README.md|Write" "changes/notes.md|Write" \
  "docs/analysis.ipynb|NotebookEdit" "features/sub/trial.feature|Write" "features/trial.txt|Write" "changes/-bad/intent.md|Write"; do
  name="${row%%|*}" tool="${row#*|}" p="$A/${row%%|*}"
  before="$(sig "$p")" logged="$(lines "$rl")"
  edit pm "$A" "$tool" "$p"
  [ "$rc" = 2 ] && [ "$(sig "$p")" = "$before" ]
  result $? "pm-mode-11: the PM session's $tool of $name is refused and the file is unchanged" "exit $rc; $err"
  has 'rule 25.2' && has "$p" && has 'a cycle through /pap:pm launch <slug>' && has '/intent <slug> <class> for a change that needs one' && has 'Do not retry'
  result $? "pm-mode-11: the refusal of $name names rule 25.2, the path and the routes: a cycle through /pap:pm launch, or /intent" "$err"
  [ "$(lines "$rl")" = $((logged + 1)) ] && [ "$(field "$rl" 2)" = "$S1" ] && [ "$(field "$rl" 3)" = pm ] && [ "$(field "$rl" 4)" = main ] &&
    [ "$(field "$rl" 5)" = "$p" ] && [ "$(field "$rl" 6)" = olive/trial ] && [ "$(field "$rl" 7)" = write ]
  result $? "pm-mode-11: the refusal log gains one line naming the session, pm, the main session and $name" "$(tail -n 2 "$rl" 2>&1)"
done
before="$(sig "$W/bin/pap")"
edit pm "$A" Edit "$W/bin/pap"
[ "$rc" = 2 ] && [ "$(sig "$W/bin/pap")" = "$before" ] && has 'outside the PM paths'
result $? "pm-mode-11: bin/pap in a work tree of the session's repository is refused too" "exit $rc; $err"
before="$(sig "$A/bin/pap")"
e_rel="$(cd "$A" && jq -nc --arg s "$S1" --arg d "$A" '{session_id: $s, cwd: $d, hook_event_name: "PreToolUse", tool_name: "Edit", tool_input: {file_path: "bin/pap"}}' |
  env PAP_MODE=pm CLAUDE_PROJECT_DIR="$A" "$plugin/hooks/guard-pm.sh" 2>&1)"
[ $? = 2 ] && printf '%s\n' "$e_rel" | grep -qF "refusing a write to $A/bin/pap" && [ "$(sig "$A/bin/pap")" = "$before" ]
result $? "pm-mode-11: a path given relative to the session's directory is judged from there, and refused" "$e_rel"

mkdir -p "$A/changes/trial"
ln -s ../../bin "$A/changes/trial/tools"
ln -s ../../product "$A/changes/trial/layer"
for row in "starts under changes/trial/ and climbs out with ..|$A/changes/trial/../../bin/pap" \
  "goes through a symbolic link under changes/trial/|$A/changes/trial/tools/pap"; do
  name="${row%%|*}" p="${row#*|}"
  before="$(sig "$A/bin/pap")"
  edit pm "$A" Write "$p"
  [ "$rc" = 2 ] && [ "$(sig "$A/bin/pap")" = "$before" ] && has "refusing a write to $A/bin/pap" && has 'outside the PM paths'
  result $? "pm-mode-12: a path that $name and resolves to bin/pap is refused" "exit $rc; $err"
done
edit pm "$A" Write "$A/bin/../changes/trial/via-dots.md"
made "$A/changes/trial/via-dots.md"
result $? "pm-mode-12: a path that starts under bin/ and resolves inside changes/trial/ is made: the judgement is of where it resolves" "exit $rc; $err"
edit pm "$A" Write "$A/changes/trial/layer/glossary.md"
made "$A/product/glossary.md"
result $? "pm-mode-12: a path through a symbolic link that resolves inside product/ is made" "exit $rc; $err"
rm -f "$A/changes/trial/tools" "$A/changes/trial/layer"

logged="$(lines "$rl")"
mem="$CLAUDE_CONFIG_DIR/projects/-tmp-A/memory/MEMORY.md"
edit pm "$A" Write "$T/scratch/notes.md"
made "$T/scratch/notes.md"
result $? "pm-mode-13: the PM session writes a file in a scratch directory, in no adopting repository, and the write is made" "exit $rc; $err"
edit pm "$A" Write "$mem"
made "$mem" && [ "$(lines "$rl")" = "$logged" ]
result $? "pm-mode-13: it writes the session's memory, and the write is made; nothing is added to the refusal log" "exit $rc; $err"
edit pm "$A" Write "$U/notes.md"
made "$U/notes.md"
result $? "pm-mode-13: it writes a file in a repository that does not adopt PAP, and the write is made" "exit $rc; $err"

# The guard's own files. The refusal log gains the guard's own line, so
# there "unchanged" is that the tool's line is not in it.
printf '{}\n' > "$CLAUDE_CONFIG_DIR/settings.json"
seed "$A" .claude/settings.json .claude/settings.local.json
printf 'client_id=Iv1.test\n' > "$XDG_CONFIG_HOME/pap/agent.conf"
for row in "Claude Code's user settings file|$CLAUDE_CONFIG_DIR/settings.json|Edit" \
  "the project's Claude Code settings file|$A/.claude/settings.json|Write" \
  "the project's local Claude Code settings file|$A/.claude/settings.local.json|Edit" \
  "a hook in the directory the pap plugin runs from|$plugin/hooks/guard-pm.sh|Edit" \
  "a file under Claude Code's installed plugins|$CLAUDE_CONFIG_DIR/plugins/installed_plugins.json|Write" \
  "the refusal log|$rl|Write" "the session log|$sl|Edit" "the launch record|$ll|Write" \
  "pap's machine config|$XDG_CONFIG_HOME/pap/agent.conf|Edit"; do
  name="${row%%|*}" rest="${row#*|}"
  p="${rest%%|*}" tool="${rest#*|}"
  before="$(sig "$p")"
  edit pm "$A" "$tool" "$p"
  [ "$rc" = 2 ] && ! grep -qF "$mark" "$p" 2>/dev/null && { [ "$p" = "$rl" ] || [ "$(sig "$p")" = "$before" ]; }
  result $? "pm-mode-36: the PM session's $tool of $name is refused and the file is unchanged" "exit $rc; $err"
  has 'the file belongs to the guard' && has 'No route changes it' && ! has '/pap:pm launch' && ! has '/intent'
  result $? "pm-mode-36: the refusal of $name says the file belongs to the guard and names no route" "$err"
done
rm -rf "$A/.claude" "$XDG_CONFIG_HOME/pap/agent.conf"
edit pm "$A" Edit "$trk/events.tsv"
made "$trk/events.tsv"
result $? "pm-mode-36: the tracker, alone under pap's state directory, is still the PM's to write" "exit $rc; $err"

absent="$(sig "$A/changes/newslug")"
edit pm "$A" Write "$A/changes/newslug/intent.md"
[ "$absent" = absent ] && made "$A/changes/newslug/intent.md"
result $? "pm-mode-38: a first write into changes/newslug/, which did not exist, is made" "exit $rc; $err"
edit pm "$A" Write "$A/newdir/deep/intent.md"
[ "$rc" = 2 ] && [ ! -e "$A/newdir" ] && has 'outside the PM paths'
result $? "pm-mode-38: a first write into a new folder outside the PM paths is judged from its deepest existing parent, and refused" "exit $rc; $err"

ln -s "$T/nowhere/at-all" "$A/changes/trial/gone"
edit pm "$A" Write "$A/changes/trial/gone/notes.md"
[ "$rc" = 2 ] && has 'the path could not be resolved' && [ ! -e "$T/nowhere" ] && ! has '/pap:pm launch'
result $? "pm-mode-39: a write through a symbolic link pointing at nothing is refused, saying the path could not be resolved" "exit $rc; $err"
[ "$(field "$rl" 5)" = "$A/changes/trial/gone/notes.md" ] && [ "$(field "$rl" 7)" = write ]
result $? "pm-mode-39: that refusal is a line in the refusal log, with the path as given" "$(tail -n 1 "$rl" 2>&1)"
rm -f "$A/changes/trial/gone"
(cd "$A" && git checkout -q -- . && git clean -qfd)

before="$(sig "$B/bin/pap")"
edit pm "$A" Edit "$B/bin/pap"
[ "$rc" = 2 ] && [ "$(sig "$B/bin/pap")" = "$before" ]
result $? "pm-mode-14: the PM session's write of bin/pap in a second adopting repository is refused" "exit $rc; $err"
has "that repository's own PM session" && has "$B" && ! has '/pap:pm launch'
result $? "pm-mode-14: the refusal says the change belongs to that repository's own PM session, and names no /pap:pm launch" "$err"
[ "$(field "$rl" 5)" = "$B/bin/pap" ] && [ "$(field "$rl" 6)" = "$B" ]
result $? "pm-mode-14: the refusal log's line names the second repository" "$(tail -n 1 "$rl" 2>&1)"

before="$(sig "$P/changes/trial/intent.md")"
edit pm "$A" Write "$P/changes/trial/intent.md"
[ "$rc" = 2 ] && [ "$(sig "$P/changes/trial/intent.md")" = "$before" ] &&
  has 'the text of an issue for blairforce1/pap, for the owner to file' && has 'rule 25.4' && ! has '/pap:pm launch'
result $? "pm-mode-52: a PM path in pap itself, a second repository, is refused, naming the text of an issue for blairforce1/pap, for the owner to file" "exit $rc; $err"
before="$(sig "$B/changes/trial/intent.md")"
edit pm "$A" Write "$B/changes/trial/intent.md"
[ "$rc" = 2 ] && [ "$(sig "$B/changes/trial/intent.md")" = "$before" ] && has "that repository's own PM session" && ! has 'blairforce1/pap'
result $? "pm-mode-52: a PM path in a second repository that is not pap is refused, naming that repository's own PM session" "exit $rc; $err"
edit pm "$B" Write "$B/changes/trial/intent.md"
made "$B/changes/trial/intent.md"
result $? "pm-mode-52: the same file is written by that repository's own PM session" "exit $rc; $err"
git -C "$B" checkout -q -- .

fresh
edit none "$A" Edit "$A/bin/pap"
made "$A/bin/pap" && [ "$(lines "$rl")" = 0 ]
result $? "pm-mode-57: a session with no mode, started without pap claude, writes bin/pap with Edit: made, and nothing is logged" "exit $rc; $err"
git -C "$A" checkout -q -- bin/pap
before="$(sig "$A/bin/pap")"
edit pm "$A" Edit "$A/bin/pap"
[ "$rc" = 2 ] && [ "$(sig "$A/bin/pap")" = "$before" ] && [ "$(lines "$rl")" = 1 ]
result $? "pm-mode-57: the same write in a PM session is refused, so it is the mode that binds" "exit $rc; $err"

# --- A sub-agent is not bound ---------------------------------------------------

for row in "pap:cycle|bin/pap" "pap:cycle|plugins/pap/hooks/guard-route.sh" "pap:cycle|rules.md" "pap:cycle|tests/guard-route.test.sh" \
  "pap:cycle-mechanical|CHANGELOG.md" "general-purpose|docs/run-a-project.md"; do
  type="${row%%|*}" p="$A/${row#*|}"
  before="$(sig "$p")" logged="$(lines "$rl")"
  edit pm "$A" Write "$p" a3f9c2e17b5d4 "$type"
  sub_calls=$((sub_calls + 1))
  [ "$rc" = 0 ] || sub_refused=$((sub_refused + 1))
  made "$p" && [ "$(sig "$p")" != "$before" ] && [ "$(lines "$rl")" = "$logged" ]
  result $? "pm-mode-18: a sub-agent of type $type writes ${row#*|}, and the write is made" "exit $rc; $err"
done
for p in "$CLAUDE_CONFIG_DIR/settings.json" "$B/bin/pap"; do
  edit pm "$A" Write "$p" a3f9c2e17b5d4 pap:cycle
  sub_calls=$((sub_calls + 1))
  [ "$rc" = 0 ] || sub_refused=$((sub_refused + 1))
  made "$p"
  result $? "pm-mode-18: a sub-agent is not judged against the PM paths even for ${p#"$T"/}" "exit $rc; $err"
done
(cd "$A" && git checkout -q -- . && git clean -qfd)
git -C "$B" checkout -q -- .

fresh
menv pm
err="$(printf 'this is not the JSON a tool call carries' | env ${m:+"$m"} CLAUDE_PROJECT_DIR="$A" "$plugin/hooks/guard-pm.sh" 2>&1 >/dev/null)"
rc=$?
[ "$rc" = 1 ] && has 'could not read the tool call'
result $? "pm-mode-21: a call the guard cannot read: the guard says so, and exits 1, which reports and does not block" "exit $rc; $err"
[ "$(lines "$rl")" = 1 ] && [ "$(field "$rl" 7)" = unread ] && [ "$(field "$rl" 3)" = pm ]
result $? "pm-mode-21: the refusal log gains one line of the unread kind" "$(cat "$rl" 2>&1)"
err="$(jq -nc --arg s "$S1" --arg d "$A" '{session_id: $s, cwd: $d, tool_name: "Edit", tool_input: {path: "bin/pap"}}' |
  env ${m:+"$m"} CLAUDE_PROJECT_DIR="$A" "$plugin/hooks/guard-pm.sh" 2>&1 >/dev/null)"
rc=$?
[ "$rc" = 1 ] && has 'could not read the tool call' && [ "$(lines "$rl")" = 2 ] && [ "$(field "$rl" 7)" = unread ] && [ "$(field "$rl" 2)" = "$S1" ]
result $? "pm-mode-21: a call with no file path in it is unread too, logged with its session, and not blocked" "exit $rc; $err"
err="$(printf '{"tool_name": "Bash", "tool_input": {"command": 7' | env ${m:+"$m"} CLAUDE_PROJECT_DIR="$A" "$plugin/hooks/guard-route.sh" 2>&1 >/dev/null)"
rc=$?
[ "$rc" != 2 ] && has 'could not read the tool call' && [ "$(lines "$rl")" = 3 ] && [ "$(field "$rl" 7)" = unread ]
result $? "pm-mode-21: a Bash call the guard cannot read is said, logged as unread, and not blocked" "exit $rc; $err"
err="$(printf '{"tool_name": "Bash", "tool_input": {"command": 7' | env CLAUDE_PROJECT_DIR="$A" "$plugin/hooks/guard-route.sh" 2>&1 >/dev/null)"
[ $? != 2 ] && [ "$(lines "$rl")" = 3 ]
result $? "pm-mode-21: outside a PM session an unread Bash call is let through as before, with nothing logged" "$err"

# --- Commits and commands, judged by guard-route.sh --------------------------------

# What was refused before is still refused, in a clean work tree on a change
# branch, so only the named rule can refuse and rule 25.2 has nothing to say.
fresh
for row in "PM session|pm||git commit --no-verify|decision 0005" "PM session|pm||gh pr merge 1|the owner merges" \
  "PM session|pm||gh pr edit 1 --add-label owner-reviewed|the owner-reviewed label" "PM session|pm||git push --force|decision 0022" \
  "solo session|solo||git commit --no-verify|decision 0005" "solo session|solo||gh pr merge 1|the owner merges" \
  "sub-agent of a PM session|pm|a3f9c2e17b5d4|git commit --no-verify|decision 0005" \
  "sub-agent of a PM session|pm|a3f9c2e17b5d4|gh pr merge 1|the owner merges" \
  "sub-agent of a PM session|pm|a3f9c2e17b5d4|git push --force|decision 0022"; do
  who="${row%%|*}" rest="${row#*|}"
  mode="${rest%%|*}" rest="${rest#*|}"
  agent="${rest%%|*}" rest="${rest#*|}"
  cmd="${rest%%|*}" why="${rest#*|}"
  route "$mode" "$A" "$W" "$cmd" "$agent" pap:cycle
  [ "$rc" = 2 ] && has "$why" && ! has 'rule 25' && ! has 'rule 23.4' && [ "$(lines "$rl")" = 0 ]
  result $? "pm-mode-20: a $who's $cmd is refused as it was before pm-mode ($why)" "exit $rc; $err"
done
route pm "$A" "$W" 'git status && gh pr view 1'
[ "$rc" = 0 ]
result $? "pm-mode-20: and what passed before still passes: git status, gh pr view in a PM session" "exit $rc; $err"

# The work tree on change/trial, with changes under the PM paths only: one
# staged, one unstaged, one untracked, and an ignored file outside them.
printf 'more\n' >> "$W/changes/trial/intent.md"
git -C "$W" add changes/trial/intent.md
printf 'more\n' >> "$W/product/domain.md"
seed "$W" features/second.feature changes/second/intent.md
printf 'scratch.log\n' >> "$(git -C "$W" rev-parse --git-path info/exclude)"
seed "$W" scratch.log
route pm "$A" "$W" 'git commit -m "intent(trial): sharpen"'
[ "$rc" = 0 ] && [ "$(lines "$rl")" = 0 ]
result $? "pm-mode-15: a commit in a work tree whose only changes are under the PM paths is not refused" "exit $rc; $err"

head0="$(git -C "$W" rev-parse HEAD)"
seed "$W" notes.md
tool_bash pm "$A" "$W" 'git add -A && git commit -m x'
[ "$rc" = 2 ] && has 'the whole work tree is judged' && has 'notes.md' && [ "$(git -C "$W" rev-parse HEAD)" = "$head0" ]
result $? "pm-mode-17: an untracked file notes.md, not ignored, stops the commit, saying the whole work tree is judged and naming notes.md" "exit $rc; $err"
! has 'scratch.log' && [ "$(lines "$rl")" = 1 ] && [ "$(field "$rl" 5)" = notes.md ]
result $? "pm-mode-17: the ignored file beside it is not named: one file refused, one line logged" "$err"
rm "$W/notes.md"

for row in "a staged change|git commit -m x" "an unstaged change|git commit -am x"; do
  name="${row%%|*}" cmd="${row#*|}"
  printf 'changed\n' >> "$W/bin/pap"
  [ "$name" != "a staged change" ] || git -C "$W" add bin/pap
  logged="$(lines "$rl")"
  tool_bash pm "$A" "$W" "$cmd"
  [ "$rc" = 2 ] && has 'the whole work tree is judged' && has 'outside the PM paths: bin/pap'
  result $? "pm-mode-16: with $name to bin/pap the commit is refused, saying the whole work tree is judged and naming bin/pap" "exit $rc; $err"
  has "Commit from the change's own work tree" && has 'have whoever owns each file move it' && has 'rule 25.2' && ! has '/pap:pm launch' && ! has '/intent'
  result $? "pm-mode-16: with $name, the refusal names committing from the change's own work tree, or the owner of the file moving it, and no route" "$err"
  [ "$(git -C "$W" rev-parse HEAD)" = "$head0" ]
  result $? "pm-mode-16: with $name, nothing is committed" "$(git -C "$W" log --oneline | head -n 3)"
  [ "$(lines "$rl")" = $((logged + 1)) ] && [ "$(field "$rl" 2)" = "$S1" ] && [ "$(field "$rl" 4)" = main ] && [ "$(field "$rl" 5)" = bin/pap ] &&
    [ "$(field "$rl" 6)" = olive/trial ] && [ "$(field "$rl" 7)" = commit ]
  result $? "pm-mode-16: with $name, the refusal log gains one line naming the session and bin/pap" "$(tail -n 2 "$rl" 2>&1)"
  if [ "$name" = "a staged change" ]; then
    logged="$(lines "$rl")"
    route pm "$A" "$W" 'git commit -m x' a3f9c2e17b5d4 pap:cycle
    [ "$rc" = 0 ] && [ "$(lines "$rl")" = "$logged" ]
    result $? "pm-mode-19: a pap:cycle sub-agent's commit in that work tree, bin/pap staged, is not refused as outside the PM paths" "exit $rc; $err"
    for c in 'git merge main' 'git cherry-pick abc1234' 'git revert abc1234' 'git rebase main'; do
      route pm "$A" "$W" "$c"
      [ "$rc" = 0 ] && [ "$(lines "$rl")" = "$logged" ]
      result $? "pm-mode-37: $c in that work tree, where a commit is refused, is not judged against the PM paths" "exit $rc; $err"
    done
    for mode in solo none; do
      route "$mode" "$A" "$W" 'git commit -m x'
      [ "$rc" = 0 ] && [ "$(lines "$rl")" = "$logged" ]
      result $? "pm-mode-$([ "$mode" = solo ] && echo 8 || echo 57): a session with mode $mode commits in that work tree and is not refused as outside the PM paths" "exit $rc; $err"
    done
  fi
  git -C "$W" reset -q -- bin/pap
  git -C "$W" checkout -q -- bin/pap
done
tool_bash pm "$A" "$W" 'git add -A && git commit -m "intent(trial): sharpen"'
[ "$rc" = 0 ] && [ "$(git -C "$W" rev-parse HEAD)" != "$head0" ] && [ -z "$(git -C "$W" status --porcelain)" ]
result $? "pm-mode-15: with bin/pap restored, the commit of the PM paths is made" "exit $rc; $err"
seed "$B" changes/trial/plan.md
route pm "$A" "$B" 'git commit -m x'
[ "$rc" = 2 ] && has 'rule 25.2' && has 'changes/trial/plan.md'
result $? "pm-mode-52: a commit of a PM path in a second adopting repository is refused too" "exit $rc; $err"
rm "$B/changes/trial/plan.md"

for c in 'PAP_MODE=solo claude -p hi' 'env -u PAP_MODE claude -p hi' 'export PAP_MODE=solo' 'unset PAP_MODE'; do
  route pm "$A" "$A" "$c"
  [ "$rc" = 2 ] && has 'rule 25.1: the mode is set by pap claude and stays so'
  result $? "pm-mode-55: $c is refused, saying the mode is set by pap claude and stays so" "exit $rc; $err"
done
route pm "$A" "$A" 'echo "PAP_MODE=solo is refused" && printenv PAP_MODE'
[ "$rc" = 0 ]
result $? "pm-mode-55: a command that only names PAP_MODE, and does not set it, passes" "exit $rc; $err"
route pm "$A" "$A" 'unset PAP_MODE' a3f9c2e17b5d4 pap:cycle
[ "$rc" = 2 ]
result $? "pm-mode-55: a sub-agent's unset PAP_MODE is refused as well" "exit $rc; $err"

# --- /pap:pm start and the tracker ---------------------------------------------

fresh
at 10:00:00
status0="$(git -C "$A" status --porcelain)"
pm "$A" start --session "$S1"
[ "$rc" = 0 ] && [ -f "$trk/state.md" ] && [ -f "$trk/events.tsv" ] && said "tracker started at $trk, outside the repository" &&
  [ "$(git -C "$A" status --porcelain)" = "$status0" ] && [ -z "$(find "$A" -name events.tsv)" ] &&
  [ "$(grep -c -e '^## In flight$' -e '^## Waiting on the owner$' -e '^## Next$' "$trk/state.md")" = 3 ]
result $? "pm-mode-22: /pap:pm start starts the tracker outside the repository, with a state file of three headings and an event log" "exit $rc; $out"
[ "$(lines "$trk/events.tsv")" = 1 ] && [ "$(sed -n 1p "$trk/events.tsv" | cut -f 1-3)" = "2026-11-10T10:00:00Z$(printf '\t')start$(printf '\t')-" ]
result $? "pm-mode-22: the event log's first line is a start event" "$(cat "$trk/events.tsv" 2>&1)"
[ "$(git -C "$trk" rev-list --count HEAD)" = 1 ] && tclean && [ "$(git -C "$trk" ls-files | sort | tr '\n' ' ')" = "events.tsv state.md " ]
result $? "pm-mode-22: the tracker is committed" "$(git -C "$trk" status --porcelain 2>&1; git -C "$trk" log --oneline 2>&1)"

# A clean tracker with one cycle in flight and hand-written entries.
at 10:01:00; tevent restate trial "fix the thing the owner named"
brief trial
awk '/^## Waiting on the owner$/ { print; print ""; print "- budget-cap: say whether 200000 tokens stands"; skip = 1; next }
     /^## Next$/ { print ""; print; print ""; print "- write the adopter guide"; skip = 1; next }
     /^## / { skip = 0 } !skip { print }' "$trk/state.md" > "$trk/state.new" && mv "$trk/state.new" "$trk/state.md"
pm "$A" commit --session "$S1"
at 10:02:00; typed "$A" "$S1" "/pap:pm launch trial"
at 10:03:00; pm "$A" launch trial --session "$S1"
for mode in pm solo; do
  ev0="$(lines "$trk/events.tsv")" h0="$(thead)"
  at 10:05:00
  [ "$mode" = pm ] || { PAP_MODE=solo; export PAP_MODE; }
  pm "$A" start --session "$S1"
  unset PAP_MODE
  id=23
  [ "$mode" = pm ] || id=51
  [ "$rc" = 0 ] && said '- trial: launched 2026-11-10T10:03:00Z' && said '- budget-cap: say whether 200000 tokens stands' && said '- write the adopter guide' &&
    [ "$(printf '%s\n' "$out" | grep -n -e '^## In flight' -e '^- trial: launched' -e '^## Waiting on the owner' -e '^- budget-cap' -e '^## Next' -e '^- write the adopter' | sed 's/^[0-9]*://' | cut -c1-9 | tr '\n' ',')" = "## In fli,- trial: ,## Waitin,- budget-,## Next,- write t," ]
  result $? "pm-mode-$id: in a $mode session /pap:pm start reports what is in flight, what waits on the owner and what is next, from the state file" "exit $rc; $out"
  if [ "$mode" = pm ]; then
    [ "$(lines "$trk/events.tsv")" = "$ev0" ] && [ -n "$h0" ] && [ "$(thead)" = "$h0" ] && ! printf '%s\n' "$out" | grep -q '^agent:' && said 'Launch and resume nothing until the owner says'
    result $? "pm-mode-23: nothing is launched: no event is added, no agent is named, and it says to launch nothing" "$out"
  else
    route solo "$A" "$A" "sh \"$script\" start --session \"$S1\""
    [ "$rc" = 0 ]
    result $? "pm-mode-51: the guard lets a solo session's main call run the /pap:pm script" "exit $rc; $err"
  fi
done

# In flight is from the event log: an abandoned decision clears it, and a
# decision that only mentions the word does not.
at 10:06:00; tevent decision trial "the cycle may be abandoned if it stays silent"
pm "$A" commit --session "$S1"
pm "$A" start --session "$S1"
grep -q '^- trial: launched' "$trk/state.md"
result $? "pm-mode-43: a decision whose text does not start \"abandoned\" leaves \"trial\" in flight" "$(cat "$trk/state.md")"
at 10:07:00; typed "$A" "$S1" "/pap:pm launch trial"
ev0="$(sig "$trk/events.tsv")" h0="$(thead)"
at 10:08:00; pm "$A" launch trial --session "$S1"
[ "$rc" = 15 ] && said '"trial" is in flight'
result $? "pm-mode-31: a second launch of \"trial\", in flight, is refused, saying \"trial\" is in flight" "exit $rc; $out"
no_cycle && as_was && [ "$(events launch)" = 1 ]
result $? "pm-mode-31: no cycle starts: no agent is named and the event log and the tracker are as they were" "$out"
at 10:09:00; tevent decision trial "abandoned: the session that ran it was lost"
pm "$A" commit --session "$S1"
at 10:10:00; pm "$A" start --session "$S1"
[ "$rc" = 0 ] && ! grep -q '^- trial' "$trk/state.md" && [ "$(sed -n '/^## In flight$/,/^## Waiting/p' "$trk/state.md" | grep -c '^- ')" = 1 ] &&
  sed -n '/^## In flight$/,/^## Waiting/p' "$trk/state.md" | grep -qx -- '- none' && grep -q '^- budget-cap' "$trk/state.md" && tclean
result $? "pm-mode-43: after a decision whose text starts \"abandoned\", /pap:pm start rewrites the state file and \"trial\" is not in flight" "$(cat "$trk/state.md")"
# The typed line of 10:07 was used up by the refusal: a launch run again
# without the owner typing it is not the owner's yes.
at 10:11:00; pm "$A" launch trial --session "$S1"
[ "$rc" = 10 ] && [ "$(events launch)" = 1 ]
result $? "pm-mode-40: a refused launch uses up the typed line; run again untyped once the cause is gone, it is refused" "exit $rc; $out"
at 10:12:00; typed "$A" "$S1" "/pap:pm launch trial"
at 10:13:00; pm "$A" launch trial --session "$S1"
[ "$rc" = 0 ] && [ "$(events launch)" = 2 ]
result $? "pm-mode-43: and the launch the owner typed for it then goes through: the way out for a dead cycle" "exit $rc; $out"

# An uncommitted tracker: an event line appended, and a brief in a folder
# git has not seen.
fresh
at 10:00:00; pm "$A" start --session "$S1"
at 10:01:00; tevent restate trial "fix the thing the owner named"
pm "$A" commit --session "$S1"
at 10:02:00; tevent message second "told the cycle to stop at the draft"
mkdir -p "$trk/briefs"
printf '/change second docs\nRule 20.2: exempt: docs\n' > "$trk/briefs/second.md"
dirty0="$(sig "$trk/events.tsv") $(git -C "$trk" status --porcelain --untracked-files=all)" h0="$(thead)"
at 10:03:00; pm "$A" start --session "$S1"
[ "$rc" = 4 ] && said '--- events.tsv ( M)' && said "+2026-11-10T10:02:00Z$(printf '\t')message$(printf '\t')second$(printf '\t')told the cycle to stop at the draft" &&
  said '--- briefs/second.md (??)' && said '+/change second docs' &&
  said 'likely cause: an event line appended and not committed, or a session that ended mid-event'
result $? "pm-mode-24: on an uncommitted tracker /pap:pm start shows the change as a diff, file by file, with its likely cause" "exit $rc; $out"
said 'ask the owner: commit it, or discard it?'
result $? "pm-mode-24: it asks the owner whether to commit or discard it" "$out"
said 'Do nothing else until the owner answers' && [ "$(sig "$trk/events.tsv") $(git -C "$trk" status --porcelain --untracked-files=all)" = "$dirty0" ] &&
  [ "$(thead)" = "$h0" ] && ! said '## In flight'
result $? "pm-mode-24: nothing else is done until the owner answers: the tracker is as it was and no state is reported" "$out"

pm "$A" discard --confirm --session "$S1"
[ "$rc" != 0 ] && said 'nothing is discarded' && [ "$(sig "$trk/events.tsv") $(git -C "$trk" status --porcelain --untracked-files=all)" = "$dirty0" ]
result $? "pm-mode-53: a confirmation with no first answer discards nothing" "exit $rc; $out"
pm "$A" discard --session "$S1"
[ "$rc" = 0 ] && said 'nothing is discarded yet, and the tracker is unchanged' && said 'confirm a second time' &&
  [ "$(sig "$trk/events.tsv") $(git -C "$trk" status --porcelain --untracked-files=all)" = "$dirty0" ] && [ -f "$trk/briefs/second.md" ]
result $? "pm-mode-53: after the owner's first discard the tracker is unchanged, and a second yes is asked for" "exit $rc; $out"
pm "$A" discard --confirm --session "$S1"
[ "$rc" = 0 ] && tclean && [ "$(thead)" = "$h0" ] && ! grep -q 'told the cycle' "$trk/events.tsv" && [ ! -e "$trk/briefs/second.md" ] &&
  [ "$(lines "$trk/events.tsv")" = 2 ]
result $? "pm-mode-53: on the confirmation the tracker is clean and the uncommitted change is gone" "exit $rc; $out; $(git -C "$trk" status --porcelain 2>&1)"
at 10:04:00; tevent message second "a first change"
pm "$A" discard --session "$S1"
at 10:05:00; tevent message second "a second change, made after the first answer"
pm "$A" discard --confirm --session "$S1"
[ "$rc" != 0 ] && grep -q 'a second change' "$trk/events.tsv"
result $? "pm-mode-53: a confirmation after the change has changed discards nothing: the yes was for the change shown" "exit $rc; $out"
pm "$A" commit --session "$S1"
[ "$rc" = 0 ] && tclean && grep -q 'a second change' "$trk/events.tsv" &&
  git -C "$trk" show HEAD:events.tsv | grep -q 'a second change'
result $? "pm-mode-24: the other answer, commit, commits the change as it stands" "exit $rc; $out"

# The key changes when an origin is added; the tracker does not move.
fresh
kkey="_path/$(printf '%s' "$K" | tr '/' '%')"
at 10:00:00; pm "$K" start --session "$S1"
[ "$rc" = 0 ] && [ -f "$pmd/trackers/$kkey/events.tsv" ]
result $? "pm-mode-56: (the given) a repository with no origin has its tracker under the key of its path" "exit $rc; $out"
git -C "$K" remote add origin https://github.com/olive/later.git
at 10:05:00; pm "$K" start --session "$S1"
[ "$rc" = 0 ] && said "the tracker is under the repository's earlier key, $kkey" && said "tracker at $pmd/trackers/$kkey, committed"
result $? "pm-mode-56: after an origin is added, /pap:pm start says the tracker is under the repository's earlier key, and uses it" "exit $rc; $out"
[ ! -e "$pmd/trackers/olive/later" ] && [ "$(lines "$pmd/trackers/$kkey/events.tsv")" = 1 ] &&
  [ "$(sed -n 1p "$pmd/trackers/$kkey/events.tsv" | cut -f 1,2)" = "2026-11-10T10:00:00Z$(printf '\t')start" ]
result $? "pm-mode-56: no second tracker is started: none under the new key, and the event log still opens with the first start" "$(ls "$pmd/trackers" 2>&1)"
unset PAP_PM_NOW
ss pm "$K" resume
in_part tracker "The tracker is at $pmd/trackers/$kkey."
result $? "pm-mode-56: the role names the same tracker" "$(part tracker | sed -n 1p)"
git -C "$K" remote remove origin

# A companion clone: the tracker is a folder in it, and every commit is pushed.
for row in "accepts pushes" "rejects pushes"; do
  fresh
  rm -rf "$T/companion.git" "$T/companion"
  git init -q --bare -b main "$T/companion.git"
  git clone -q "$T/companion.git" "$T/companion" 2>/dev/null
  git -C "$T/companion" config user.name olive
  git -C "$T/companion" config user.email olive@example.invalid
  mkdir "$T/companion/pm"
  printf 'client_id=Iv1.test\ntracker.olive/other=%s\ntracker.olive/trial=%s\n' "$T/elsewhere" "$T/companion/pm" > "$XDG_CONFIG_HOME/pap/agent.conf"
  ctrk="$T/companion/pm"
  if [ "$row" = "accepts pushes" ]; then
    at 10:00:00; pm "$A" start --session "$S1"
    [ "$rc" = 0 ] && [ -f "$ctrk/events.tsv" ] && [ ! -e "$trk" ] && ! said 'not pushed' &&
      [ "$(git -C "$T/companion.git" rev-parse main 2>/dev/null)" = "$(git -C "$T/companion" rev-parse HEAD)" ] &&
      git -C "$T/companion.git" show main:pm/events.tsv | grep -q "$(printf '\t')start$(printf '\t')"
    result $? "pm-mode-27: with the tracker pointed at a companion clone whose remote accepts pushes, the commit is on the companion's remote" "exit $rc; $out"
    at 10:01:00; printf '%s\trestate\ttrial\tfix the thing\n' "$PAP_PM_NOW" >> "$ctrk/events.tsv"
    pm "$A" commit --session "$S1"
    [ "$rc" = 0 ] && [ "$(git -C "$T/companion.git" rev-list --count main)" = 2 ] && git -C "$T/companion.git" show main:pm/events.tsv | grep -q 'fix the thing'
    result $? "pm-mode-27: and so is the next commit: every commit is pushed" "exit $rc; $out"
    edit pm "$A" Write "$ctrk/briefs/trial.md"
    made "$ctrk/briefs/trial.md"
    result $? "pm-mode-10: the tracker in a companion clone is the PM's to write" "exit $rc; $err"
  else
    printf '#!/bin/sh\necho "the companion refuses this push" >&2\nexit 1\n' > "$T/companion.git/hooks/pre-receive"
    chmod +x "$T/companion.git/hooks/pre-receive"
    at 10:00:00; pm "$A" start --session "$S1"
    why="$(printf '%s\n' "$out" | sed -n 's/^pap-pm: the tracker is committed but not pushed: //p')"
    [ "$rc" = 0 ] && [ -n "$why" ] && [ "$(git -C "$T/companion" rev-list --count HEAD)" = 1 ] && [ -z "$(git -C "$T/companion" status --porcelain)" ] &&
      ! git -C "$T/companion.git" rev-parse -q --verify main >/dev/null
    result $? "pm-mode-27: with a remote that rejects pushes, the session is told the tracker is committed but not pushed, and why ($why)" "exit $rc; $out"
    rm "$T/companion.git/hooks/pre-receive"
    at 10:01:00; printf '%s\trestate\ttrial\tfix the thing\n' "$PAP_PM_NOW" >> "$ctrk/events.tsv"
    pm "$A" commit --session "$S1"
    [ "$rc" = 0 ] && ! said 'not pushed' && [ "$(git -C "$T/companion.git" rev-list --count main 2>/dev/null)" = 2 ]
    result $? "pm-mode-27: the next commit's push carries both" "exit $rc; $out"
    git -C "$T/companion" remote set-url origin "$T/no-such-remote.git"
    at 10:02:00; printf '%s\tmessage\ttrial\tone more\n' "$PAP_PM_NOW" >> "$ctrk/events.tsv"
    pm "$A" commit --session "$S1"
    [ "$rc" = 0 ] && said 'the tracker is committed but not pushed: ' && [ "$(git -C "$T/companion" rev-list --count HEAD)" = 3 ]
    result $? "pm-mode-27: a remote that is not there is said the same way, and the commit stands" "exit $rc; $out"
  fi
  rm -f "$XDG_CONFIG_HOME/pap/agent.conf"
done

# One writer. A session is running while its note is in pm/live and the
# process it names, if any, is alive.
fresh
at 10:00:00; pm "$A" start --session "$S1"
snap() { printf '%s %s %s' "$(thead)" "$(sig "$trk/events.tsv")" "$(git -C "$trk" status --porcelain | cksum)"; }
t0="$(snap)"
at 10:01:00; pm "$A" start --session "$S2"
[ "$rc" = 17 ] && said "session $S1 holds the tracker"
result $? "pm-mode-41: /pap:pm start in a second PM session is told which session holds the tracker" "exit $rc; $out"
[ "$(snap)" = "$t0" ] && [ "$(cat "$pmd/locks/olive%trial")" = "$S1" ] && ! said '## In flight'
result $? "pm-mode-41: the tracker is unchanged, and the lock is still the first session's" "$(cat "$pmd/locks/olive%trial" 2>&1)"
tevent restate trial "fix the thing"; brief trial
pm "$A" commit --session "$S1"
t0="$(snap)"
typed "$A" "$S2" "/pap:pm launch trial"
at 10:02:00; pm "$A" launch trial --session "$S2"
[ "$rc" = 17 ] && [ "$(snap)" = "$t0" ] && no_cycle
result $? "pm-mode-41: a launch from the second session is refused the same way, and no cycle starts" "exit $rc; $out"
printf '%s\n' "$$" > "$pmd/live/$S1"
pm "$A" start --session "$S2"
[ "$rc" = 17 ]
result $? "pm-mode-41: a holder whose Claude Code process is alive holds the tracker" "exit $rc; $out"

# The session ends: session-end.sh takes its note away. PATH is only what
# the hook needs, so its detached cleanup finds no dotnet and no mise.
mkdir "$T/endbin"
for b in sh jq rm nohup; do bp="$(command -v "$b")" && ln -s "$bp" "$T/endbin/$b"; done
printf '#!/bin/sh\nexit 0\n' > "$T/endbin/pgrep"
chmod +x "$T/endbin/pgrep"
if "$T/endbin/jq" --version >/dev/null 2>&1; then
  jq -nc --arg s "$S1" --arg d "$A" '{session_id: $s, hook_event_name: "SessionEnd", reason: "other", cwd: $d}' |
    PATH="$T/endbin" "$T/endbin/sh" "$plugin/hooks/session-end.sh" >/dev/null 2>&1
  [ ! -e "$pmd/live/$S1" ] && [ -e "$pmd/live/$S2" ]
  result $? "pm-mode-42: when a session ends, the session-end hook removes its running note and no other" "$(ls "$pmd/live" 2>&1)"
else
  skip "pm-mode-42: when a session ends, the session-end hook removes its running note" "jq cannot run from a bare PATH here"
  rm -f "$pmd/live/$S1"
fi
at 10:03:00; pm "$A" start --session "$S2"
[ "$rc" = 0 ] && said "took over the tracker from session $S1, which has ended" && [ "$(cat "$pmd/locks/olive%trial")" = "$S2" ]
result $? "pm-mode-42: /pap:pm start then takes the lock left by the ended session and says it took it over" "exit $rc; $out"
said '## In flight' && said '## Waiting on the owner' && said '## Next'
result $? "pm-mode-42: and the session reports where things stand" "$out"
sh -c 'exit 0' &
gone=$!
wait "$gone"
printf '%s\n' "$gone" > "$pmd/live/$S2"
at 10:04:00; pm "$A" start --session "$S1"
[ "$rc" = 0 ] && said "took over the tracker from session $S2, which has ended"
result $? "pm-mode-42: a lock whose session's Claude Code process is gone is taken over too" "exit $rc; $out"

# --- The launch ----------------------------------------------------------------

ready trial
ev0="$(sig "$trk/events.tsv")" h0="$(thead)"
pm "$A" launch trial --session "$S1"
[ "$rc" = 0 ] && [ "$(sig "$trk/events.tsv")" != "$ev0" ]
result $? "pm-mode-30: (the baseline every refusal below takes one thing from) restated, briefed and typed, the launch goes through" "exit $rc; $out"

ready trial
grep -v "$(printf '\t')restate$(printf '\t')trial$(printf '\t')" "$trk/events.tsv" > "$trk/events.new"
mv "$trk/events.new" "$trk/events.tsv"
at 10:01:30; tevent restate other "another ask, restated"
pm "$A" commit --session "$S1"
at 10:03:00
ev0="$(sig "$trk/events.tsv")" h0="$(thead)"
pm "$A" launch trial --session "$S1"
[ "$rc" = 11 ] && said 'the ask is restated first (rule 18.2)' && said 'no restate event for "trial"'
result $? "pm-mode-28: with no restate event for \"trial\" (and one for another slug) the launch is refused, saying the ask is restated first" "exit $rc; $out"
no_cycle && as_was && tclean
result $? "pm-mode-28: no cycle starts: no agent is named and the tracker is as it was" "$out"

# No launch record for "trial" from this session in this repository. Every
# near miss is there: another slug, another session, another repository, a
# prompt that only mentions the command, and a sub-agent's.
ready trial
rm -f "$ll"
at 10:02:00
typed "$A" "$S1" "/pap:pm launch other"
typed "$A" "$S2" "/pap:pm launch trial"
typed "$B" "$S1" "/pap:pm launch trial"
typed "$A" "$S1" "please run /pap:pm launch trial for me"
typed "$A" "$S1" "<task-notification>
/pap:pm launch trial
</task-notification>"
typed "$A" "$S1" "/pap:pm launch trial" a3f9c2e17b5d4
typed "$U" "$S1" "/pap:pm launch trial"
[ "$(lines "$ll")" = 3 ] && [ "$(cut -f 2-4 "$ll" | tr '\t\n' ' ,')" = "$S1 olive/trial other,$S2 olive/trial trial,$S1 olive/other trial," ]
result $? "pm-mode-40: the launch record takes only the typed command, alone, from the main session, in an adopting repository" "$(cat "$ll" 2>&1)"
at 10:03:00
ev0="$(sig "$trk/events.tsv")" h0="$(thead)"
pm "$A" launch trial --session "$S1"
[ "$rc" = 10 ] && said 'the owner types the command: /pap:pm launch trial (rule 18.2)'
result $? "pm-mode-40: with no launch record for \"trial\", a launch the PM invokes itself is refused, saying the owner types the command" "exit $rc; $out"
[ "$(events yes)" = 0 ] && [ "$(events launch)" = 0 ] && [ "$(sig "$trk/events.tsv")" = "$ev0" ]
result $? "pm-mode-40: the event log gains no yes event and no launch event" "$(cat "$trk/events.tsv")"
no_cycle && as_was
result $? "pm-mode-40: no cycle starts" "$out"
at 10:03:30; typed "$A" "$S1" "/pap:pm launch trial"
at 10:04:00; pm "$A" launch trial --session "$S1"
[ "$rc" = 0 ] && [ "$(events yes)" = 1 ] && [ "$(events launch)" = 1 ]
result $? "pm-mode-40: once the owner has typed it, the same launch goes through" "exit $rc; $out"
at 10:05:00; tevent report trial "draft pull request opened"
pm "$A" commit --session "$S1"
at 10:06:00; pm "$A" launch trial --session "$S1"
[ "$rc" = 10 ] && [ "$(events launch)" = 1 ]
result $? "pm-mode-40: a typed line serves one launch: after the cycle reports, a second launch without a new one is refused" "exit $rc; $out"
at 10:07:00; typed "$A" "$S1" "/pap:pm launch trial"
at 10:08:00; pm "$A" launch trial --session "$S1"
[ "$rc" = 0 ] && [ "$(events launch)" = 2 ]
result $? "pm-mode-31: after its report \"trial\" is not in flight, and the owner's next typed launch goes through" "exit $rc; $out"

for row in "a first line naming its route|12|rule 18.8|first line naming its route" \
  "a second line naming the item of rule 20.2|13|rule 20.2|second line naming the item of rule 20.2" \
  "a budget in tokens or wall time|14|rule 18.7|budget in tokens or wall time"; do
  name="${row%%|*}" rest="${row#*|}"
  code="${rest%%|*}" rest="${rest#*|}"
  rule="${rest%%|*}" words="${rest#*|}"
  ready trial
  case "$code" in
    12) printf '%s\n' "Fix the thing in trial." "Rule 20.2: exempt: a bugfix" "Budget: 200000 tokens" > "$trk/briefs/trial.md" ;;
    13) printf '%s\n' "/change trial bugfix" "Fix the thing; rule 20.2 does not ask for an intent." "Budget: 200000 tokens" > "$trk/briefs/trial.md" ;;
    14) printf '%s\n' "/change trial bugfix" "Rule 20.2: exempt: a bugfix" "Budget: as much as it takes" > "$trk/briefs/trial.md" ;;
  esac
  pm "$A" commit --session "$S1"
  ev0="$(sig "$trk/events.tsv")" h0="$(thead)"
  pm "$A" launch trial --session "$S1"
  [ "$rc" = "$code" ] && said "$words" && said "$rule"
  result $? "pm-mode-29: a brief that lacks $name is refused, naming the part and $rule" "exit $rc; $out"
  no_cycle && as_was
  result $? "pm-mode-29: with no $name, no cycle starts" "$out"
done
ready trial
rm "$trk/briefs/trial.md"
pm "$A" launch trial --session "$S1"
[ "$rc" = 12 ] && said 'rule 18.8' && no_cycle
result $? "pm-mode-29: no brief at all is refused as one with no route" "exit $rc; $out"
ready trial
printf '%s\n' "/change other bugfix" "Rule 20.2: exempt: a bugfix" "Budget: 200000 tokens" > "$trk/briefs/trial.md"
pm "$A" launch trial --session "$S1"
[ "$rc" = 12 ] && no_cycle
result $? "pm-mode-29: a first line whose route names another slug is no route for this one" "exit $rc; $out"

for row in "not mechanical|pap:cycle|" "mechanical|pap:cycle-mechanical|Mechanical: yes"; do
  kind="${row%%|*}" rest="${row#*|}"
  type="${rest%%|*}"
  ready trial "${rest#*|}"
  ev0="$(lines "$trk/events.tsv")" h0="$(thead)"
  pm "$A" launch trial --session "$S1"
  tabc="$(printf '\t')"
  [ "$rc" = 0 ] && [ "$(lines "$trk/events.tsv")" = $((ev0 + 2)) ] &&
    [ "$(tail -n 2 "$trk/events.tsv" | sed -n 1p | cut -f 1-3)" = "2026-11-10T10:03:00Z${tabc}yes${tabc}trial" ] &&
    [ "$(tail -n 1 "$trk/events.tsv" | cut -f 1-3)" = "2026-11-10T10:03:00Z${tabc}launch${tabc}trial" ] &&
    tail -n 1 "$trk/events.tsv" | cut -f 4 | grep -q '^/change trial bugfix; Rule 20.2: exempt: a bugfix with a failing test; '
  result $? "pm-mode-30: a $kind launch adds a yes event and then a launch event for \"trial\", naming the route" "exit $rc; $(tail -n 2 "$trk/events.tsv")"
  sed -n '/^## In flight$/,/^## Waiting/p' "$trk/state.md" | grep -q '^- trial: launched 2026-11-10T10:03:00Z, /change trial bugfix'
  result $? "pm-mode-30: a $kind launch: the state file lists \"trial\" as in flight" "$(cat "$trk/state.md")"
  tclean && [ "$(thead)" != "$h0" ] && [ "$(git -C "$trk" log -1 --format=%s)" = "tracker: launch trial" ] &&
    git -C "$trk" show HEAD:events.tsv | tail -n 1 | grep -q "${tabc}launch${tabc}trial${tabc}" && git -C "$trk" show HEAD:state.md | grep -q '^- trial: launched'
  result $? "pm-mode-30: a $kind launch: the tracker is committed, events and state both, when the script exits 0" "$(git -C "$trk" status --porcelain; git -C "$trk" log --oneline | head -n 2)"
  [ "$(printf '%s\n' "$out" | grep -c '^agent: ')" = 1 ] && said "agent: $type" && said "brief: $trk/briefs/trial.md" &&
    [ "$(printf '%s\n' "$out" | grep -n 'the tracker is committed' | cut -d: -f1)" -lt "$(printf '%s\n' "$out" | grep -n '^agent: ' | cut -d: -f1)" ] &&
    [ "$(printf '%s\n' "$out" | sed -n 's/^agent: //p')" = "$type" ] && tail -n 1 "$trk/events.tsv" | cut -f 4 | grep -q "; $type\$"
  result $? "pm-mode-30: a $kind launch: only then the script names one agent, $type, and the brief, for the skill to start" "$out"
done
skill="$here/plugins/pap/skills/pm/SKILL.md"
grep -q 'Now start exactly one cycle with the Agent tool' "$skill" && grep -q '`subagent_type` the `agent:` line it printed' "$skill" &&
  grep -q '`run_in_background` true' "$skill" && grep -q 'as the prompt the contents of the file on its `brief:` line and nothing else' "$skill" &&
  grep -q '\*\*Not 0.\*\* The launch is refused and no cycle starts' "$skill" && grep -q '^disable-model-invocation: true$' "$skill"
result $? "pm-mode-30: the skill text says: on exit 0 start exactly one cycle, of the printed agent type, in the background, with the brief and nothing else; on any other exit none" ""
grep -q 'append a `decision` event for the slug with the text `abandoned: did not start`' "$skill"
result $? "pm-mode-43: the skill text says a cycle that fails to start is logged as a decision, abandoned: did not start" ""

ready trial
printf '#!/bin/sh\necho "this tracker takes no commit" >&2\nexit 1\n' > "$trk/.git/hooks/pre-commit"
chmod +x "$trk/.git/hooks/pre-commit"
ev0="$(sig "$trk/events.tsv")" st0="$(sig "$trk/state.md")" h0="$(thead)"
pm "$A" launch trial --session "$S1"
[ "$rc" = 18 ] && said 'the tracker could not be committed, so no cycle starts'
result $? "pm-mode-44: a launch whose tracker commit fails is refused, saying the tracker could not be committed" "exit $rc; $out"
no_cycle && as_was && [ "$(sig "$trk/state.md")" = "$st0" ] &&
  [ "$(events yes)" = 0 ] && [ "$(events launch)" = 0 ] && tclean
result $? "pm-mode-44: no cycle starts: no agent is named, and the yes and launch events are taken back out, leaving the tracker clean" "$out; $(git -C "$trk" status --porcelain 2>&1)"
rm "$trk/.git/hooks/pre-commit"
pm "$A" launch trial --session "$S1"
[ "$rc" = 0 ] && said 'agent: pap:cycle'
result $? "pm-mode-44: once the tracker takes a commit again the same typed launch goes through" "exit $rc; $out"

ready trial
printf '2026-11-10T10:01:40Z\tmessage\ttrial told the cycle to carry on\n' >> "$trk/events.tsv"
pm "$A" commit --session "$S1"
ev0="$(sig "$trk/events.tsv")" h0="$(thead)"
pm "$A" launch trial --session "$S1"
[ "$rc" = 16 ] && said 'line 3 of the event log' && said 'four tab-separated fields' && said 'trial told the cycle to carry on'
result $? "pm-mode-45: an event log line that is not four tab-separated fields stops the launch, naming the line and the format" "exit $rc; $out"
no_cycle && as_was
result $? "pm-mode-45: no cycle starts" "$out"
ready trial
printf '2026-11-10T10:01:40Z\tshipped\ttrial\tan event that is not one of the ten\n' >> "$trk/events.tsv"
pm "$A" commit --session "$S1"
pm "$A" launch trial --session "$S1"
[ "$rc" = 16 ] && said 'line 3' && no_cycle
result $? "pm-mode-45: a line of four fields whose event is not one of the ten is unreadable too" "exit $rc; $out"

change_skill="$here/plugins/pap/skills/change/SKILL.md"
sed -n '/^Body, in the template/,/^Provenance:/p' "$change_skill" | grep -A1 '^Record: ' | grep -q '^Route: <the brief.s route and its rule 20.2 item'
result $? "pm-mode-32: the /change skill's pull request body template carries a Route line, after Record" ""
grep -q 'Copy both, unchanged, onto one line joined by `; `, as in `Route: /change <slug> <class>; Rule 20.2: item 1`' "$change_skill" &&
  grep -q 'Its brief starts with the route' "$change_skill" && grep -q 'its second line names the item of rule 20.2' "$change_skill"
result $? "pm-mode-32: the skill text says to copy the brief's route and its rule 20.2 item onto that line, unchanged" ""
grep -q 'A change with no such brief, one the human invoked directly, has no `Route:` line' "$change_skill"
result $? "pm-mode-32: the skill text says a change with no such brief has no Route line" ""

# A sub-agent runs the /pap:pm script: refused by the guard, so it never runs.
fresh
at 10:00:00
for c in "sh \"$script\" start --session $S1" "$script start --session $S1" "cd $A && sh ../plugin/skills/pm/pap-pm.sh start --session $S1"; do
  tool_bash pm "$A" "$A" "$c" a3f9c2e17b5d4 pap:cycle
  [ "$rc" = 2 ] && has '/pap:pm needs the PM session'
  result $? "pm-mode-33: a sub-agent's $(printf '%s' "$c" | sed "s|$T/||g; s|$S1|<id>|") is refused, saying /pap:pm needs the PM session" "exit $rc; $err"
done
[ ! -e "$trk" ] && [ ! -e "$pmd/locks" ]
result $? "pm-mode-33: the tracker is unchanged: it was not started" "$(ls "$pmd" 2>&1)"
tool_bash pm "$A" "$A" "sh \"$script\" start --session $S1"
[ "$rc" = 0 ] && [ -f "$trk/events.tsv" ]
result $? "pm-mode-33: the same command from the PM session itself runs, and starts the tracker" "exit $rc; $err"

# A message to a cycle, and the cycle's stop, are logged by hooks.
fresh
msg() { # msg <mode> <kind> <json>
  menv "$1"
  printf '%s' "$3" | env ${m:+"$m"} CLAUDE_PROJECT_DIR="$A" CLAUDE_PLUGIN_ROOT="$plugin" "$plugin/hooks/pm-log.sh" "$2"
}
send="$(jq -nc --arg s "$S1" --arg d "$A" '{session_id: $s, cwd: $d, hook_event_name: "PreToolUse", tool_name: "SendMessage",
  tool_input: {to: "a3f9c2e17b5d4", message: "carry on, and keep to the brief: SECRET-WORDS"}}')"
stop="$(jq -nc --arg s "$S1" --arg d "$A" '{session_id: $s, cwd: $d, hook_event_name: "SubagentStop", agent_id: "a3f9c2e17b5d4", agent_type: "pap:cycle"}')"
at 11:00:00; msg pm stop "$stop"
tabc="$(printf '\t')"
[ "$(lines "$ml")" = 1 ] && [ "$(cat "$ml")" = "2026-11-10T11:00:00Z${tabc}$S1${tabc}stop${tabc}a3f9c2e17b5d4${tabc}pap:cycle" ]
result $? "pm-mode-46: a cycle's stop is one line in the message log, with the sub-agent's id and type" "$(cat "$ml" 2>&1)"
at 11:05:00; out="$(msg pm message "$send" 2>&1)"
[ "$(lines "$ml")" = 2 ] && [ "$(tail -n 1 "$ml")" = "2026-11-10T11:05:00Z${tabc}$S1${tabc}message${tabc}a3f9c2e17b5d4${tabc}-" ] && [ -z "$out" ]
result $? "pm-mode-46: when the PM session sends the cycle a message, the message log gains one line naming the session and the cycle's sub-agent" "$(cat "$ml" 2>&1)"
! grep -q 'SECRET-WORDS' "$ml" && [ "$(awk -F '\t' '$4 == "a3f9c2e17b5d4" && $3 == "stop" { s = 1 } s && $3 == "message" && $4 == "a3f9c2e17b5d4" { c++ } END { print c + 0 }' "$ml")" = 1 ]
result $? "pm-mode-46: the line holds no word of the message, and reads as a message after that sub-agent's first stop" "$(cat "$ml" 2>&1)"
before="$(sig "$ml")"
edit pm "$A" Edit "$ml"
[ "$rc" = 2 ] && [ "$(sig "$ml")" = "$before" ] && has 'the file belongs to the guard'
result $? "pm-mode-46: the PM session wrote none of it: the message log is the guard's, and its own Edit of it is refused" "exit $rc; $err"
msg solo message "$send"; msg none message "$send"; msg solo stop "$stop"
msg pm message "$(printf '%s' "$send" | jq -c '. + {agent_id: "b77", agent_type: "pap:cycle"}')"
[ "$(sig "$ml")" = "$before" ]
result $? "pm-mode-46: a solo session, a session with no mode and a sub-agent's own message add nothing to the log" "$(cat "$ml" 2>&1)"
unset PAP_PM_NOW

# --- The wiring, the zero rows and the shell --------------------------------------

hooks="$here/plugins/pap/hooks/hooks.json"
[ "$(jq -r '.hooks.PreToolUse[] | select(.matcher == "Edit|Write|NotebookEdit") | .hooks[].command' "$hooks")" = '"${CLAUDE_PLUGIN_ROOT}/hooks/guard-pm.sh"' ] &&
  [ "$(jq -r '.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[].command' "$hooks")" = '"${CLAUDE_PLUGIN_ROOT}/hooks/guard-route.sh"' ] &&
  [ "$(jq -r '.hooks.PreToolUse[] | select(.matcher == "SendMessage") | .hooks[].command' "$hooks")" = '"${CLAUDE_PLUGIN_ROOT}/hooks/pm-log.sh" message' ] &&
  [ "$(jq -r '.hooks.SessionStart[] | select(has("matcher") | not) | .hooks[].command' "$hooks")" = '"${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh"' ] &&
  [ "$(jq -r '.hooks.UserPromptSubmit[].hooks[].command' "$hooks")" = '"${CLAUDE_PLUGIN_ROOT}/hooks/pm-log.sh" prompt' ] &&
  [ "$(jq -r '.hooks.SubagentStop[].hooks[].command' "$hooks")" = '"${CLAUDE_PLUGIN_ROOT}/hooks/pm-log.sh" stop' ]
result $? "wiring: hooks.json runs the guard before Edit, Write and NotebookEdit, the role at every SessionStart, and the three records" "$(jq -c .hooks "$hooks" 2>&1)"
x=""
for f in guard-pm.sh guard-route.sh session-start.sh pm-log.sh session-end.sh; do [ -x "$here/plugins/pap/hooks/$f" ] || x="$x $f"; done
[ -z "$x" ]
result $? "wiring: every hook hooks.json runs by path is executable" "not executable:$x"

[ "$sub_calls" -ge 8 ] && [ "$sub_refused" = 0 ]
result $? "zero: sub-agent writes refused as outside the PM paths, across the suite: $sub_refused of $sub_calls" ""

# The existing guard suite, unedited, run again in a mode: a copy of the
# suite beside a clean-env.sh that sets the mode, over this tree's hooks.
# Solo changes nothing. In a PM session every case that expected a refusal
# still gets one; the commits rule 25.2 now refuses in its dirty work trees
# are the only difference.
rerun() { # rerun <mode>: prints the suite's output
  rr="$T/rerun-$1"
  mkdir -p "$rr/tests"
  cp "$here/tests/guard-route.test.sh" "$rr/tests/"
  { cat "$here/tests/clean-env.sh"; printf 'PAP_MODE=%s\nexport PAP_MODE\n' "$1"; } > "$rr/tests/clean-env.sh"
  ln -s "$here/plugins" "$rr/plugins"
  ln -s "$here/scripts" "$rr/scripts"
  (cd "$T/scratch" && sh "$rr/tests/guard-route.test.sh" 2>&1)
}
fresh
rerun solo > "$T/rerun-solo.out" &
rerun pm > "$T/rerun-pm.out" &
base="$(sh "$here/tests/guard-route.test.sh" 2>&1)"
wait
total="$(printf '%s\n' "$base" | grep -c '^ok ')"
[ "$total" -ge 300 ] && ! printf '%s\n' "$base" | grep -q '^not ok'
result $? "zero: existing guard expectations changed: $(printf '%s\n' "$base" | grep -c '^not ok') of $total cases of tests/guard-route.test.sh fail" "$(printf '%s\n' "$base" | grep '^not ok')"
[ "$(grep -c '^ok ' "$T/rerun-solo.out")" = "$total" ] && ! grep -q '^not ok' "$T/rerun-solo.out"
result $? "pm-mode-20: in a solo session every one of the $total existing guard cases gives what it gave before" "$(grep '^not ok' "$T/rerun-solo.out" | head -n 20)"
[ "$(grep -c -e '^ok ' -e '^not ok ' "$T/rerun-pm.out")" = "$total" ] && ! grep -q 'expected 2)' "$T/rerun-pm.out" &&
  [ "$(grep -c '^not ok .* git commit .*(exit 2, expected 0)$' "$T/rerun-pm.out")" = "$(grep -c '^not ok' "$T/rerun-pm.out")" ] &&
  [ "$(grep -c '^not ok' "$T/rerun-pm.out")" -ge 1 ]
result $? "pm-mode-20: in a PM session every existing case that was refused is still refused; the only difference is commits in dirty work trees, now refused ($(grep -c '^not ok' "$T/rerun-pm.out"))" "$(grep '^not ok' "$T/rerun-pm.out" | grep -v 'git commit .*(exit 2, expected 0)$' | head -n 20)"

if command -v shellcheck >/dev/null 2>&1; then
  sc="$(cd "$here" && shellcheck -s sh plugins/pap/hooks/pm-lib.sh plugins/pap/hooks/guard-pm.sh plugins/pap/hooks/guard-route.sh \
    plugins/pap/hooks/session-start.sh plugins/pap/hooks/pm-log.sh plugins/pap/hooks/session-end.sh plugins/pap/skills/pm/pap-pm.sh 2>&1)"
  result $? "shell: the hooks and pap-pm.sh are shellcheck -s sh clean" "$sc"
else
  skip "shell: the hooks and pap-pm.sh are shellcheck -s sh clean" "shellcheck is not on PATH"
fi
if command -v dash >/dev/null 2>&1; then
  x=""
  for f in hooks/pm-lib.sh hooks/guard-pm.sh hooks/guard-route.sh hooks/session-start.sh hooks/pm-log.sh hooks/session-end.sh skills/pm/pap-pm.sh; do
    dash -n "$here/plugins/pap/$f" 2>/dev/null || x="$x $f"
  done
  dash -n "$pap" 2>/dev/null || x="$x bin/pap"
  [ -z "$x" ]
  result $? "shell: dash parses the hooks, pap-pm.sh and bin/pap" "dash refuses:$x"
else
  skip "shell: dash parses the hooks, pap-pm.sh and bin/pap" "dash is not on PATH"
fi

printf '1..%d\n' "$n"
[ "$failed" = 0 ] || { printf '# %d of %d failed\n' "$failed" "$n"; exit 1; }
