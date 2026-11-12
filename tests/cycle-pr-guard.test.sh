#!/bin/sh
# cycle-pr-guard.test.sh: the scenarios of features/cycle-pr-guard.feature,
# bound by ID, for rules 27.1 and 27.2 (changes/cycle-pr-guard/spec.md,
# decision 0027): the pull request and the branch switch the guard refuses
# an agent of a PM session, the refusal log's lines, and the reading of the
# main checkout at a PM session's start. pap doctor's item (scenarios 10
# and 11) is in tests/pap.test.sh.
#
# Usage: sh tests/cycle-pr-guard.test.sh
#
# Never touches the network, the real home or pap's real state directory.
# The hooks run from a copy of plugins/pap and are fed the JSON Claude Code
# sends, in the world of tests/guard-route.test.sh: a session pap claude
# started, with the gh shim first on PATH, so rule 23.4 passes.
#
#   A    adopts PAP, origin https://github.com/olive/trial.git, its main
#        checkout on main; the PM session's own repository
#   W    a linked work tree of A on change/add-thing
#   W2   a second linked work tree of A, on change/second
#   U    does not adopt PAP, on main
#   X    a directory in no repository
#
# A hook only judges a call, so "the main checkout is on main" is shown by
# a stand-in for the tool: tool_bash runs the guard and then, unless it
# exits 2, the command, as Claude Code does.
#
# The spec's process rows are counted by a stand-in git, first on PATH,
# that logs each start and runs the real one. The baselines are constants,
# measured with the guard as it stood at the commit before this change.
#
# Prints one TAP-style line per case and exits 1 if any case fails. Needs
# git and jq.
#
# SC2319: each case passes the exit status of its condition on purpose.
# SC2016: commands are given to the guard as written, unexpanded.
# shellcheck disable=SC2319,SC2016

set -u
# shellcheck disable=SC1091 # tests/clean-env.sh, sourced from this directory
. "$(dirname "$0")/clean-env.sh"

here="$(cd "$(dirname "$0")/.." && pwd)"

for tool in git jq; do
  command -v "$tool" >/dev/null 2>&1 || { printf 'Bail out! %s not found\n' "$tool"; exit 1; }
done

# pwd -P: macOS's temporary directory is under a symlink (/var to
# /private/var), and git and pwd report the resolved path.
T="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$T"' EXIT INT TERM
mkdir -p "$T/home" "$T/xdg/gh-agent" "$T/realgh" "$T/count" "$T/X"
export HOME="$T/home" XDG_STATE_HOME="$T/state" XDG_CONFIG_HOME="$T/xdg" \
  GIT_CONFIG_GLOBAL="$T/gitconfig" GIT_CONFIG_NOSYSTEM=1 GIT_CEILING_DIRECTORIES="$T"
unset CLAUDE_PROJECT_DIR CLAUDE_PLUGIN_ROOT REMOTE_CONTAINERS PAP_MODE 2>/dev/null || true
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

cp -R "$here/plugins/pap" "$T/plugin"
plugin="$T/plugin"

# A session pap claude started: the shim first for gh, a real gh that is no
# shim behind it (tests/guard-route.test.sh has the same world).
I="$T/install"
mkdir -p "$I/bin" "$I/scripts/shim" "$I/templates/base"
cp "$here/scripts/shim/gh" "$I/scripts/shim/gh"
printf '#!/bin/sh\nexit 1\n' > "$I/bin/pap"
printf '#!/bin/sh\n# PAP_SHIM_CHECK\nexit 0\n' > "$T/realgh/gh"
chmod +x "$I/scripts/shim/gh" "$I/bin/pap" "$T/realgh/gh"
chmod 700 "$T/xdg/gh-agent"

# The stand-in git: one line a start in $GIT_COUNT, then the real git.
realgit="$(command -v git)"
cat > "$T/count/git" <<EOF
#!/bin/sh
[ -z "\${GIT_COUNT:-}" ] || printf '%s\n' "\$*" >> "\$GIT_COUNT"
exec "$realgit" "\$@"
EOF
chmod +x "$T/count/git"

mkrepo() { # mkrepo <dir>: one commit on main
  git init -q -b main "$1"
  git -C "$1" config user.name test
  git -C "$1" config user.email test@example.invalid
  git -C "$1" config commit.gpgsign false
  mkdir -p "$1/docs"
  printf 'seed\n' > "$1/README.md"
  printf 'seed\n' > "$1/docs/guide.md"
}
A="$T/A" W="$T/A-add-thing" W2="$T/A-second" U="$T/U"
mkrepo "$A"
mkdir -p "$A/scripts"
cp "$here/scripts/guard-branch.sh" "$A/scripts/guard-branch.sh"
git -C "$A" add -A
git -C "$A" commit -q -m init
git -C "$A" remote add origin https://github.com/olive/trial.git
git -C "$A" worktree add -q -b change/add-thing "$W"
git -C "$A" worktree add -q -b change/second "$W2"
mkrepo "$U"
git -C "$U" add -A
git -C "$U" commit -q -m init

S1=0f6b2c1e-1a2b-4c3d-8e4f-5a6b7c8d9e01
sub=a1b2c3d4
k=0
# fresh: a state directory of its own for what follows.
fresh() {
  k=$((k + 1))
  XDG_STATE_HOME="$T/state$k"
  export XDG_STATE_HOME
  rl="$XDG_STATE_HOME/pap/pm/refusals.log"
}
lines() { if [ -f "$1" ]; then wc -l < "$1" | tr -d ' '; else echo 0; fi; }
field() { tail -n 1 "$1" 2>/dev/null | cut -f "$2"; } # field <log> <n>: of its last line
has() { printf '%s\n' "$err" | grep -qF -- "$1"; }
PAP_PM_NOW=2026-11-12T10:00:00Z
export PAP_PM_NOW

# route <mode> <project> <cwd> <command> [agent id]: one Bash call, judged
# by guard-route.sh. Sets rc and err. An agent id makes it a sub-agent's.
route() {
  m=""
  case "$1" in pm | solo) m="PAP_MODE=$1" ;; esac
  r_in="$(jq -nc --arg s "$S1" --arg d "$3" --arg c "$4" --arg a "${5:-}" \
    '{session_id: $s, transcript_path: "/x/t.jsonl", cwd: $d, permission_mode: "default", hook_event_name: "PreToolUse",
      tool_name: "Bash", tool_input: {command: $c}}
     + (if $a == "" then {} else {agent_id: $a, agent_type: "pap:cycle"} end)')"
  err="$(printf '%s' "$r_in" | env ${m:+"$m"} CLAUDE_PROJECT_DIR="$2" CLAUDE_PLUGIN_ROOT="$plugin" \
    GH_CONFIG_DIR="$T/xdg/gh-agent" PATH="$T/count:$I/scripts/shim:$T/realgh:$PATH" \
    "$plugin/hooks/guard-route.sh" 2>&1 >/dev/null)"
  rc=$?
}
tool_bash() {
  route "$@"
  [ "$rc" = 2 ] || (cd "$3" && sh -c "$4") >/dev/null 2>&1 </dev/null
}
on_main() { [ "$(git -C "$A" symbolic-ref -q --short HEAD)" = main ]; }
# refused <first line> <second line>: the call was blocked with both lines.
refused() { [ "$rc" = 2 ] && has "$1" && has "$2"; }
# passed: let through, and nothing said under rule 27.
passed() { [ "$rc" = 0 ] && ! has 'rule 27.'; }

sw1="guard-route: refusing to switch the branch of the main checkout, "
sw2='guard-route: rule 27.2: parallel sessions share it; work in a worktree on change/<id>, made by /change. To restore a path: git checkout -- <path>.'
un2_272='guard-route: rule 27.2: run it as its own command, from the worktree made by /change.'

# --- Rule 27.2: the branch of the main checkout --------------------------------

fresh
while IFS='|' read -r who cmd; do
  a="$sub"
  [ "$who" = sub ] || a=""
  tool_bash pm "$A" "$A" "$cmd" "$a"
  refused "$sw1$A" "$sw2" && on_main
  result $? "cycle-pr-guard-4: refused in the main checkout, which stays on main ($who): $cmd" "exit $rc; $err"
done <<'EOF'
sub|git switch change/add-thing
sub|git switch -c change/other
sub|git checkout change/add-thing
sub|git checkout -b change/other
sub|git checkout --detach
sub|git checkout origin/main
main|git switch change/add-thing
sub|git checkout change/add-thing --
sub|git checkout -b change/other --
sub|git checkout README.md
sub|git checkout .
sub|git checkout -
sub|git switch -
sub|git switch --detach main
sub|git switch --det main
sub|git checkout -d main
sub|git switch -qc change/other
sub|git -c advice.detachedHead=false checkout --detach
sub|git switch change/other 2>/dev/null
EOF
tool_bash pm "$A" "$W" "git -C $A switch change/add-thing" "$sub"
refused "$sw1$A" "$sw2" && on_main
result $? "cycle-pr-guard-4: git -C <the main checkout> switch, run from the linked work tree, is refused" "exit $rc; $err"
tool_bash pm "$A" "$W" "cd $A/docs && git switch -c change/other" "$sub"
refused "$sw1$A/docs" "$sw2" && on_main
result $? "cycle-pr-guard-4: a switch in a directory under the main checkout is refused" "exit $rc; $err"
tool_bash pm "$A" "$A" "git status && git switch -c change/other | cat" "$sub"
refused "$sw1$A" "$sw2" && on_main
result $? "cycle-pr-guard-4: a switch later in a sequence, and in a pipeline, is refused" "exit $rc; $err"

while IFS= read -r cmd; do
  route pm "$A" "$A" "$cmd" "$sub"
  passed
  result $? "cycle-pr-guard-5: let through in the main checkout: $cmd" "exit $rc; $err"
done <<'EOF'
git switch main
git checkout main
git switch -q main
git checkout
git checkout -- README.md
git checkout HEAD -- README.md
git fetch origin
git pull
git worktree add ../x -b change/x origin/main
git worktree remove ../x
git branch -D change/x
git status
git worktree prune
git fetch --prune
git fetch --quiet --tags origin main
git switch --force main
git switch main 2>/dev/null
git log --oneline -- checkout
echo "x; git switch y"
git log --grep 'git switch change/x' | cat
EOF

route pm "$A" "$W" 'git switch -c change/other' "$sub"
passed
result $? "cycle-pr-guard-6: a branch switched in a linked work tree is let through" "exit $rc; $err"
route pm "$A" "$A" "git -C $W checkout change/other" "$sub"
passed
result $? "cycle-pr-guard-6: so is one that reaches the linked work tree by git -C from the main checkout" "exit $rc; $err"

for mode in solo none; do
  route "$mode" "$A" "$A" 'git switch change/x' "$sub"
  passed
  result $? "cycle-pr-guard-7: a session of mode $mode switches the main checkout's branch unrefused" "exit $rc; $err"
  route "$mode" "$A" "$W" 'cd "$somewhere" && git switch change/x' "$sub"
  passed
  result $? "cycle-pr-guard-7: a session of mode $mode is not refused a directory the guard cannot place" "exit $rc; $err"
done
route pm "$U" "$U" 'git switch change/x' "$sub"
passed
result $? "cycle-pr-guard-7: a PM session in a repository that does not adopt PAP switches its branch unrefused" "exit $rc; $err"
route pm "$U" "$U" 'cd "$somewhere" && git switch change/x' "$sub"
passed
result $? "cycle-pr-guard-7: and is not refused a directory the guard cannot place" "exit $rc; $err"
route pm "$A" "$A" "git -C $U switch change/x" "$sub"
passed
result $? "cycle-pr-guard-7: a PM session of an adopting repository switches a branch in one that does not adopt" "exit $rc; $err"

# What the guard refused before, under PAP_MODE=pm, beside the suites that
# run unchanged (tests/guard-route.test.sh, tests/pm-mode.test.sh).
route pm "$A" "$W" 'git commit --no-verify -m x' "$sub"
[ "$rc" = 2 ] && has 'decision 0005'
result $? "cycle-pr-guard-8: a hook bypass is refused still in a PM session" "exit $rc; $err"
route pm "$A" "$W" 'git push --force origin change/add-thing' "$sub"
[ "$rc" = 2 ]
result $? "cycle-pr-guard-8: a force push is refused still in a PM session" "exit $rc; $err"
route pm "$A" "$W" 'gh pr merge 7 --squash' "$sub"
[ "$rc" = 2 ] && has 'decision 0016'
result $? "cycle-pr-guard-8: a merge is refused still in a PM session" "exit $rc; $err"

# --- The refusal log -----------------------------------------------------------

fresh
route pm "$A" "$A" 'git switch -c change/secret-zzz' "$sub"
[ "$rc" = 2 ] && [ "$(lines "$rl")" = 1 ] &&
  [ "$(cat "$rl")" = "$(printf '%s\t%s\tpm\t%s pap:cycle\t%s\tolive/trial\tbranch-switch\tgit switch -c <word>' "$PAP_PM_NOW" "$S1" "$sub" "$A")" ]
result $? "cycle-pr-guard-9: a refused switch leaves one line: the time, the session, the mode, the caller, the directory, the repository, branch-switch and the form" "$(cat "$rl" 2>&1)"
[ -f "$rl" ] && ! grep -q 'secret-zzz' "$rl"
result $? "cycle-pr-guard-9: the line never carries the command's own words" "$(cat "$rl" 2>&1)"
route pm "$A" "$A" 'git checkout README.md'
[ "$rc" = 2 ] && [ "$(lines "$rl")" = 2 ] && [ "$(field "$rl" 7)" = path-without-dashes ] &&
  [ "$(field "$rl" 8)" = 'git checkout <word>' ] && [ "$(field "$rl" 4)" = main ]
result $? "cycle-pr-guard-9: git checkout README.md by the main session leaves one line of kind path-without-dashes, caller main" "$(cat "$rl" 2>&1)"
route pm "$A" "$W" 'cd "$somewhere" && git switch change/add-thing' "$sub"
[ "$rc" = 2 ] && [ "$(lines "$rl")" = 3 ] && [ "$(field "$rl" 7)" = unplaced ] &&
  [ "$(field "$rl" 5)" = '"$somewhere"' ] && [ "$(field "$rl" 8)" = 'git switch <word>' ] && [ "$(field "$rl" 6)" = olive/trial ]
result $? "cycle-pr-guard-9: a switch in a directory the guard cannot place leaves one line of kind unplaced, the directory as written" "$(cat "$rl" 2>&1)"
route pm "$A" "$A" 'git switch main' "$sub"
route pm "$A" "$W" 'git switch -c change/other' "$sub"
[ "$(lines "$rl")" = 3 ]
result $? "cycle-pr-guard-9: a call let through leaves no line" "$(cat "$rl" 2>&1)"

fresh
mkdir -p "$XDG_STATE_HOME/pap"
: > "$XDG_STATE_HOME/pap/pm"
tool_bash pm "$A" "$A" 'git switch change/add-thing' "$sub"
refused "$sw1$A" "$sw2" && has 'guard-route: the refusal could not be written to the refusal log.' &&
  [ "$(printf '%s\n' "$err" | wc -l | tr -d ' ')" = 3 ] && on_main
result $? "cycle-pr-guard-17: with a refusal log that cannot be written the switch is refused still, and a third line says it was not logged" "exit $rc; $err"

# --- A directory the guard cannot place ----------------------------------------

fresh
check13() { # check13 <as written> <command>
  tool_bash pm "$A" "$W" "$2" "$sub"
  refused "guard-route: refusing a branch switch in a directory the guard cannot place: $1" "$un2_272" && on_main
  result $? "cycle-pr-guard-13: refused under rule 27.2, to run as its own command: $2" "exit $rc; $err"
}
check13 '"$somewhere"' 'cd "$somewhere" && git switch change/add-thing'
check13 "pushd $A" "pushd $A && git checkout change/add-thing"
check13 "GIT_DIR=$A/.git" "GIT_DIR=$A/.git git switch change/add-thing"
check13 "GIT_DIR=$A/.git" "export GIT_DIR=$A/.git; git switch change/add-thing"
check13 "--git-dir=$A/.git" "git --git-dir=$A/.git --work-tree=$A checkout change/add-thing"
check13 '"$main"' 'git -C "$main" switch change/add-thing'
check13 '-' 'cd - && git switch change/add-thing'
check13 '../nowhere' 'cd ../nowhere && git switch change/add-thing'
route pm "$A" "$W" 'cd "$somewhere" && git switch main' "$sub"
passed
result $? "cycle-pr-guard-13: a switch to main is let through wherever it runs" "exit $rc; $err"
route pm "$A" "$W" 'cd "$somewhere" && git status' "$sub"
passed
result $? "cycle-pr-guard-13: a command with none of the verbs is let through in a directory the guard cannot place" "exit $rc; $err"

# --- The spec's process rows ---------------------------------------------------

# count <mode> <cwd> <command>: the git processes the guard starts for it.
count() {
  GIT_COUNT="$T/git.count"
  export GIT_COUNT
  : > "$GIT_COUNT"
  route "$1" "$A" "$2" "$3" "$sub"
  unset GIT_COUNT
  lines "$T/git.count"
}
# The baselines, counted with the guard at the commit before this change.
base_none=0 base_sw=0 base_sw2=0
c="$(count pm "$A" 'git status')"
[ "$c" = "$base_none" ]
result $? "cycle-pr-guard non-functional: a call with none of the verbs starts no more git processes than before ($base_none)" "$c"
for mode in solo none; do
  c="$(count "$mode" "$A" 'git switch change/x')"
  [ "$c" = "$base_sw" ]
  result $? "cycle-pr-guard non-functional: outside a PM session (mode $mode) a switch starts no more git processes than before ($base_sw)" "$c"
done
c="$(count pm "$W" 'git switch -c change/other')"
[ "$rc" = 0 ] && [ "$c" -gt "$base_sw" ] && [ "$c" -le $((base_sw + 2)) ]
result $? "cycle-pr-guard non-functional: a switch placed in one directory starts at most two more git processes than before ($base_sw)" "$c"
c="$(count pm "$W" "git switch -c change/other && git -C $W2 switch -c change/third && git switch -c change/fourth")"
[ "$rc" = 0 ] && [ "$c" -gt "$base_sw2" ] && [ "$c" -le $((base_sw2 + 2)) ]
result $? "cycle-pr-guard non-functional: switches placed in two directories start at most two more git processes than before ($base_sw2)" "$c"
c="$(count pm "$A" 'git switch main')"
[ "$c" = "$base_sw" ]
result $? "cycle-pr-guard non-functional: a form let through in the main checkout is not placed at all ($base_sw)" "$c"

printf '1..%d\n' "$n"
[ "$failed" -eq 0 ] || { printf '# %d of %d cases failed\n' "$failed" "$n"; exit 1; }
