#!/bin/sh
# assemble.test.sh: tests for scripts/assemble.sh.
#
# Usage: sh tests/assemble.test.sh
#
# Assembles the real layers into temporary directories, and a synthetic pair
# of colliding layers in a copy of the script beside its own templates/.
# Prints one TAP-style line per case and exits 1 if any case fails. Touches
# nothing outside the temporary directory.
#
# SC2319: each case passes the exit status of its condition on purpose.
# shellcheck disable=SC2319

set -u

here="$(cd "$(dirname "$0")/.." && pwd)"
asm="$here/scripts/assemble.sh"

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

# Base only.
out="$(sh "$asm" base "$T/b" 2>&1)"; rc=$?
result "$rc" "base: exits 0" "$out"
[ -f "$T/b/.editorconfig" ] && [ -f "$T/b/lefthook.yml" ]
result $? "base: files copied to the target root"
[ -f "$T/b/scripts/guard-branch.sh" ] && [ ! -L "$T/b/scripts/guard-branch.sh" ] &&
  cmp -s "$T/b/scripts/guard-branch.sh" "$here/scripts/guard-branch.sh"
result $? "base: symlinked scripts are dereferenced to their content"
[ -x "$T/b/scripts/guard-branch.sh" ]
result $? "base: executable bit kept"
[ ! -e "$T/b/README.md" ]
result $? "base: the layer README is not copied"
expected="$(cd "$here/templates/base" && find . \( -type f -o -type l \) ! -path ./README.md | sed 's|^\./||' | sort)"
[ "$out" = "$expected" ]
result $? "base: prints every file written, one per line" "$out"

# Base, dotnet and go together.
out="$(sh "$asm" base dotnet go "$T/bdg" 2>&1)"; rc=$?
result "$rc" "base+dotnet+go: no collision, exits 0" "$out"
[ -f "$T/bdg/global.json" ] && [ -f "$T/bdg/.golangci.yml" ] &&
  [ -f "$T/bdg/.config/mise/conf.d/base.toml" ] &&
  [ -f "$T/bdg/.config/mise/conf.d/dotnet.toml" ] &&
  [ -f "$T/bdg/.config/mise/conf.d/go.toml" ]
result $? "base+dotnet+go: every layer's files present"
[ "$(printf '%s\n' "$out" | wc -l)" -eq "$(find "$T/bdg" -type f | wc -l)" ]
result $? "base+dotnet+go: printed list matches the files on disk"

# --- every required check has a provider in the base layer -------------------

# The ruleset pap applies requires these checks on every pull request.
# 0.5.0 and 0.6.0 required `tests` and `pr-checks / checks` and shipped no
# workflow for either, so the first pull request after `pap init` could not
# merge. "a / b" is job b of the reusable workflow that job a calls; a bare
# name is a job of that name.
unprovided=""
for context in $(sed -n 's/.*"context": *"\([^"]*\)".*/\1/p' "$here/.github/rulesets/main.json" | tr ' ' '_'); do
  context="$(printf '%s' "$context" | tr '_' ' ')"
  found=""
  for w in "$T/b/.github/workflows/"*.yml; do
    case "$context" in
      *" / "*)
        # A job with that key which calls a reusable workflow.
        awk -v job="  ${context%% / *}:" '
          $0 == job { j = 1; next }
          /^  [^ ]/ { j = 0 }
          j && /^    uses: / { ok = 1 }
          END { exit !ok }' "$w" && found="$w"
        ;;
      *) grep -qx "    name: $context" "$w" && found="$w" ;;
    esac
  done
  [ -n "$found" ] || unprovided="$unprovided '$context'"
done
[ -z "$unprovided" ] && [ -n "$context" ]
result $? "base: every check the ruleset requires has a workflow that provides it" "no provider for:$unprovided"
cmp -s "$T/b/.github/workflows/pr-checks.yml" "$here/.github/workflows/pr-checks.yml"
result $? "base: the pr-checks caller is the one pap itself runs"

# --- the test task and each layer's part of it --------------------------------

# script_of <file> <task>: the multi-line run script of a mise task, as
# mise hands it to `sh -c`.
script_of() {
  awk -v h="[tasks.$2]" -v q="'''" '
    $0 == h { t = 1; next }
    /^\[/ { t = 0 }
    t && $0 == "run = " q { r = 1; next }
    r && $0 == q { exit }
    r' "$1"
}
# Stub mise, dotnet and go: each logs its arguments and exits as told. mise
# answers `tasks ls --json` from a fixture.
mkdir "$T/req-stub" "$T/req-app"
for tool in mise dotnet go; do
  cat > "$T/req-stub/$tool" <<'EOF'
#!/bin/sh
if [ "$(basename "$0") $*" = "mise tasks ls --json" ]; then cat "$REQ_TASKS"; exit 0; fi
echo "$(basename "$0") $*" >> "$REQ_LOG"
exit "${REQ_EXIT:-0}"
EOF
  chmod +x "$T/req-stub/$tool"
done
export REQ_LOG="$T/req.log" REQ_TASKS="$T/req-tasks.json"
git init -q -b main "$T/req-app"
# run_in_app <file> <task>: runs the script in $T/req-app; sets $out and $rc.
run_in_app() {
  : > "$REQ_LOG"
  out="$(cd "$T/req-app" && PATH="$T/req-stub:$PATH" sh -c "$(script_of "$1" "$2")" 2>&1)"; rc=$?
}
base_toml="$T/bdg/.config/mise/conf.d/base.toml"
dotnet_toml="$T/bdg/.config/mise/conf.d/dotnet.toml"
go_toml="$T/bdg/.config/mise/conf.d/go.toml"

[ -n "$(script_of "$base_toml" test)" ] && [ -n "$(script_of "$dotnet_toml" '"test:dotnet"')" ] &&
  [ -n "$(script_of "$go_toml" '"test:go"')" ]
result $? "test: the base task and each language layer's test:<lang> are read from the assembled layers"

# `mise run 'test:*'` with nothing to match exits 1, which would fail the
# required check in a repository with no language layer.
printf '[\n  {\n    "name": "check:dprint"\n  },\n  {\n    "name": "test"\n  }\n]\n' > "$REQ_TASKS"
run_in_app "$base_toml" test
[ "$rc" = 0 ] && [ ! -s "$REQ_LOG" ] && [ "$out" = 'test: no test:* task is defined; nothing to test' ]
result $? "test, no test:* task: passes, says so, runs nothing" "exit $rc; $out; $(cat "$REQ_LOG")"
printf '[{"name":"test"},{"name":"test:dotnet"}]\n' > "$REQ_TASKS"
run_in_app "$base_toml" test
[ "$rc" = 0 ] && [ "$(cat "$REQ_LOG")" = 'mise run --continue-on-error test:*' ]
result $? "test, a test:* task: runs every one, going on after a failure" "exit $rc; $out; $(cat "$REQ_LOG")"
REQ_EXIT=3 run_in_app "$base_toml" test
[ "$rc" = 3 ]
result $? "test: a failing test:* task fails it" "exit $rc; $out"

run_in_app "$dotnet_toml" '"test:dotnet"'
[ "$rc" = 0 ] && [ ! -s "$REQ_LOG" ] && printf '%s\n' "$out" | grep -q '^test:dotnet: no solution or project in the repository'
result $? "test:dotnet, no solution or project: passes, says so, dotnet not run" "exit $rc; $out; $(cat "$REQ_LOG")"
printf '<Solution>\n</Solution>\n' > "$T/req-app/App.slnx"
run_in_app "$dotnet_toml" '"test:dotnet"'
[ "$rc" = 0 ] && [ "$(cat "$REQ_LOG")" = 'dotnet test' ]
result $? "test:dotnet, a solution: runs dotnet test" "exit $rc; $out; $(cat "$REQ_LOG")"
REQ_EXIT=1 run_in_app "$dotnet_toml" '"test:dotnet"'
[ "$rc" = 1 ]
result $? "test:dotnet: dotnet test's exit status is the task's" "exit $rc; $out"
rm "$T/req-app/App.slnx"

run_in_app "$go_toml" '"test:go"'
[ "$rc" = 0 ] && [ ! -s "$REQ_LOG" ] && printf '%s\n' "$out" | grep -q '^test:go: no go.mod in the repository'
result $? "test:go, no go.mod: passes, says so, go not run" "exit $rc; $out; $(cat "$REQ_LOG")"
mkdir -p "$T/req-app/svc" && printf 'module example.invalid/svc\n' > "$T/req-app/svc/go.mod"
REQ_EXIT=1 run_in_app "$go_toml" '"test:go"'
[ "$rc" = 1 ] && [ "$(cat "$REQ_LOG")" = 'go test ./...' ]
result $? "test:go, a go.mod at any depth: runs go test ./... and its failure stands" "exit $rc; $out; $(cat "$REQ_LOG")"

# A synthetic collision.
mkdir -p "$T/fake/scripts" "$T/fake/templates/one/.config" "$T/fake/templates/two/.config"
cp "$asm" "$T/fake/scripts/"
echo one > "$T/fake/templates/one/.config/shared.toml"
echo two > "$T/fake/templates/two/.config/shared.toml"
echo a > "$T/fake/templates/one/only-one"
out="$(sh "$T/fake/scripts/assemble.sh" one two "$T/c" 2>&1)"; rc=$?
[ "$rc" = 1 ]
result $? "collision: exits 1" "$out"
printf '%s\n' "$out" | grep -q 'collision: .config/shared.toml is in layers: one two'
result $? "collision: names the path and both layers" "$out"
[ ! -e "$T/c" ]
result $? "collision: writes nothing"

# Refusals.
out="$(sh "$asm" base nosuch "$T/n" 2>&1)"; rc=$?
[ "$rc" = 1 ] && printf '%s\n' "$out" | grep -q 'no such layer: templates/nosuch' && [ ! -e "$T/n" ]
result $? "unknown layer: refused, nothing written" "$out"
mkdir "$T/full" && touch "$T/full/x"
out="$(sh "$asm" base "$T/full" 2>&1)"; rc=$?
[ "$rc" = 1 ] && printf '%s\n' "$out" | grep -q 'is not empty'
result $? "non-empty target: refused" "$out"
out="$(sh "$asm" "$T/only" 2>&1)"; rc=$?
[ "$rc" = 1 ] && printf '%s\n' "$out" | grep -q usage
result $? "no layer: usage" "$out"

printf '1..%d\n' "$n"
[ "$failed" = 0 ]
