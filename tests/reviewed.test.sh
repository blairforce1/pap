#!/bin/sh
# reviewed.test.sh: tests for plugins/pap/skills/reviewed/reviewed.sh, the
# script behind /pap:reviewed (decision 0016, rule 16.1).
#
# Usage: sh tests/reviewed.test.sh
#
# Puts a fake gh on PATH that answers `repo view` and `pr view` from
# fixtures (state, head, labels), applies the --jq filter with the real jq,
# records every `pr edit` and adds the label it is given, so the read-back
# sees it. Covers each refusal and the success paths. Prints one TAP-style
# line per case and exits 1 if any case fails. Needs jq; touches nothing
# outside the temporary directory.
#
# SC2319: each case passes the exit status of its condition on purpose.
# shellcheck disable=SC2319

set -u
# shellcheck source=tests/clean-env.sh
. "$(dirname "$0")/clean-env.sh"

here="$(cd "$(dirname "$0")/.." && pwd)"
script="$here/plugins/pap/skills/reviewed/reviewed.sh"

command -v jq >/dev/null 2>&1 || { printf 'Bail out! jq not found\n'; exit 1; }

# pwd -P: macOS's temporary directory is under a symlink (/var to
# /private/var), and git and pwd report the resolved path.
T="$(cd "$(mktemp -d)" && pwd -P)"
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
cat > "$T/stub/gh" <<'EOF'
#!/bin/sh
# Fake gh. FAKE_STATE, FAKE_HEAD and the labels file FAKE_LABELS (one per
# line) describe the one pull request; FAKE_FAIL names a subcommand to fail.
echo "gh $*" >> "$FAKE_LOG"
echo "GH_CONFIG_DIR=${GH_CONFIG_DIR-<unset>} GH_TOKEN=${GH_TOKEN-<unset>} GITHUB_TOKEN=${GITHUB_TOKEN-<unset>} CLAUDECODE=${CLAUDECODE-<unset>}" >> "$FAKE_ENV"
[ "${FAKE_FAIL:-}" != "$1 $2" ] || { echo "fake gh: $1 $2 failed" >&2; exit 1; }
filter=''
for a in "$@"; do
  if [ "${want:-}" = 1 ]; then filter="$a"; want=0; fi
  [ "$a" = "--jq" ] && want=1
done
case "$1 $2" in
  "repo view") printf '{"nameWithOwner":"example/repo"}' | jq -r "$filter" ;;
  "pr view")
    labels="$(jq -R . "$FAKE_LABELS" | jq -s 'map({name: .})')"
    jq -nc --arg s "$FAKE_STATE" --arg h "$FAKE_HEAD" --argjson l "$labels" \
      '{state: $s, headRefOid: $h, labels: $l}' | jq -r "$filter" ;;
  "pr edit")
    [ "${FAKE_EDIT_NOOP:-}" = 1 ] || { shift 3; [ "$1" = "--add-label" ] && printf '%s\n' "$2" >> "$FAKE_LABELS"; } ;;
  *) echo "fake gh: unexpected $*" >&2; exit 1 ;;
esac
EOF
chmod +x "$T/stub/gh"
export FAKE_LOG="$T/gh.log" FAKE_LABELS="$T/labels.txt" FAKE_ENV="$T/gh.env"
PATH="$T/stub:$PATH"
export PATH
# Rule 23.4: the owner's gh directory, gh's default under XDG_CONFIG_HOME;
# and the environment of an agent shell, which the script must
# not pass on to gh.
export XDG_CONFIG_HOME="$T/xdg"
mkdir -p "$T/xdg/gh"
export CLAUDECODE=1 GH_TOKEN=ghs_agent_token GITHUB_TOKEN=ghs_agent_token2

HEAD=3a7b521f07c2c0c74f197989ceb5fe64c34a8660

# fixture <state> <labels, comma separated>: the pull request as gh sees it.
fixture() {
  export FAKE_STATE="$1" FAKE_HEAD="$HEAD"
  printf '%s\n' "$2" | tr ',' '\n' | grep . > "$FAKE_LABELS" || : > "$FAKE_LABELS"
  : > "$FAKE_LOG"
  : > "$FAKE_ENV"
  unset FAKE_FAIL FAKE_EDIT_NOOP
}
# run <args...>: the script; sets $out and $rc.
run() { out="$(sh "$script" "$@" 2>&1)"; rc=$?; }
edits() { grep -c '^gh pr edit' "$FAKE_LOG"; }

# Argument checks, before any gh call.
fixture OPEN 'class:infra,risk:high'
run
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q '^refused: usage' && [ ! -s "$FAKE_LOG" ]
result $? "no arguments: usage, gh not called" "exit $rc; $out"
run 7x
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q "'7x' is not a pull request number" && [ ! -s "$FAKE_LOG" ]
result $? "a pull request number that is not digits is refused" "exit $rc; $out"
run 7 3a7b52
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q "'3a7b52' is not 7 to 40 hex" && [ ! -s "$FAKE_LOG" ]
result $? "a 6-character SHA is refused" "exit $rc; $out"
run 7 '3a7b521;id'
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q "is not 7 to 40 hex" && [ ! -s "$FAKE_LOG" ]
result $? "a SHA with a non-hex character is refused before any gh call" "exit $rc; $out"
run 7 3a7b521 extra
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q '^refused: usage' && [ ! -s "$FAKE_LOG" ]
result $? "a third argument is refused" "exit $rc; $out"

# Refusals from the pull request's state.
fixture MERGED 'class:infra,risk:high'
run 7
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q 'example/repo#7 is MERGED, not open' && [ "$(edits)" = 0 ]
result $? "a pull request that is not open is refused, no label added" "exit $rc; $out"
fixture OPEN 'class:infra,risk:high'
run 7 deadbeef
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q 'deadbeef is not a prefix of the head 3a7b521' && [ "$(edits)" = 0 ]
result $? "a SHA that is not a prefix of the head is refused" "exit $rc; $out"
fixture OPEN 'class:infra,risk:low'
run 7
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q 'risk:low needs no owner-reviewed' && [ "$(edits)" = 0 ]
result $? "risk:low needs no owner-reviewed" "exit $rc; $out"
fixture OPEN 'class:infra,risk:medium'
run 7
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q 'risk:medium needs no owner-reviewed' && [ "$(edits)" = 0 ]
result $? "risk:medium needs no owner-reviewed" "exit $rc; $out"
fixture OPEN 'class:infra'
run 7
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q 'no risk label yet' && [ "$(edits)" = 0 ]
result $? "no risk label yet: refused, wait for pr-checks" "exit $rc; $out"
fixture OPEN 'class:infra,risk:high,owner-reviewed'
run 7
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q 'already has owner-reviewed at head 3a7b521' && [ "$(edits)" = 0 ]
result $? "already labelled: says so, adds nothing" "exit $rc; $out"

# Success.
fixture OPEN 'class:infra,risk:high'
run 7
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q '^owner-reviewed added to example/repo#7 at head 3a7b521\. Labels: class:infra,risk:high,owner-reviewed\.' \
  && [ "$(edits)" = 1 ] && grep -qx 'gh pr edit 7 --add-label owner-reviewed' "$FAKE_LOG"
result $? "risk:high, open, no SHA: labelled once, head and labels printed" "exit $rc; $out; $(cat "$FAKE_LOG")"
fixture OPEN 'class:infra,risk:high'
run 7 3A7B521F07
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q '^owner-reviewed added to example/repo#7 at head 3a7b521' && [ "$(edits)" = 1 ]
result $? "a SHA prefix in upper case matches the head" "exit $rc; $out"
fixture OPEN 'class:infra,risk:high'
run "7 $HEAD"
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q '^owner-reviewed added to example/repo#7 at head 3a7b521' && [ "$(edits)" = 1 ]
result $? "one word holding number and full SHA, as a skill may pass it" "exit $rc; $out"
fixture OPEN 'class:infra,risk:high'
run 7 ''
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q '^owner-reviewed added' && [ "$(edits)" = 1 ]
result $? "an empty second argument is no SHA" "exit $rc; $out"

# Rule 23.4: every gh call runs as the owner, from the owner's directory.
fixture OPEN 'class:infra,risk:high'
run 7
[ "$rc" = 0 ] && [ "$(edits)" = 1 ] && [ "$(wc -l < "$FAKE_ENV" | tr -d ' ')" -ge 4 ] &&
  [ "$(sort -u "$FAKE_ENV")" = "GH_CONFIG_DIR=$T/xdg/gh GH_TOKEN=<unset> GITHUB_TOKEN=<unset> CLAUDECODE=<unset>" ]
result $? "every gh call has GH_CONFIG_DIR the owner's, GH_TOKEN, GITHUB_TOKEN and CLAUDECODE unset" "exit $rc; $(cat "$FAKE_ENV")"
fixture OPEN 'class:infra,risk:high'
mv "$T/xdg/gh" "$T/gh.away"
run 7
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q '^refused: gh has no default directory at .*gh auth login' && [ ! -s "$FAKE_LOG" ]
result $? "no gh default directory: refused naming gh auth login, gh not called" "exit $rc; $out"
mv "$T/gh.away" "$T/xdg/gh"
# Without XDG_CONFIG_HOME, gh's default is ~/.config/gh, on macOS too.
fixture OPEN 'class:infra,risk:high'
mkdir -p "$T/home/.config/gh"
out="$(env -u XDG_CONFIG_HOME HOME="$T/home" sh "$script" 7 2>&1)"; rc=$?
[ "$rc" = 0 ] && [ "$(edits)" = 1 ] && [ "$(sort -u "$FAKE_ENV" | cut -d' ' -f1)" = "GH_CONFIG_DIR=$T/home/.config/gh" ]
result $? "without XDG_CONFIG_HOME the owner directory is ~/.config/gh" "exit $rc; $out; $(cat "$FAKE_ENV")"

# Failures: gh itself, or a label that did not land.
fixture OPEN 'class:infra,risk:high'
export FAKE_FAIL='pr view'
run 7
[ "$rc" = 1 ] && printf '%s' "$out" | grep -q 'gh could not read pull request #7' && [ "$(edits)" = 0 ]
result $? "gh failing to read the pull request exits 1, no label added" "exit $rc; $out"
fixture OPEN 'class:infra,risk:high'
export FAKE_FAIL='pr edit'
run 7
[ "$rc" = 1 ] && printf '%s' "$out" | grep -q 'gh could not add owner-reviewed'
result $? "gh failing to add the label exits 1" "exit $rc; $out"
fixture OPEN 'class:infra,risk:high'
export FAKE_EDIT_NOOP=1
run 7
[ "$rc" = 1 ] && printf '%s' "$out" | grep -q 'is not on example/repo#7 after adding it'
result $? "a label that is not there on read-back exits 1" "exit $rc; $out"

printf '1..%d\n' "$n"
[ "$failed" = 0 ]
