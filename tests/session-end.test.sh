#!/bin/sh
# session-end.test.sh: tests for plugins/pap/hooks/session-end.sh (decision
# 0015).
#
# Usage: sh tests/session-end.test.sh
#
# Feeds the hook synthetic SessionEnd input with stub dotnet, mise, pgrep
# and ps on PATH that log what they are asked and answer from fixtures:
# which claude processes exist, whether the repository defines a
# session-end task. The hook detaches its cleanup, so each case waits for
# the stubs' log to settle. Prints one TAP-style line per case and exits 1
# if any case fails. Needs jq; touches nothing outside the temporary
# directory.
#
# SC2319: each case passes the exit status of its condition on purpose.
# shellcheck disable=SC2319

set -u

here="$(cd "$(dirname "$0")/.." && pwd)"
hook="$here/plugins/pap/hooks/session-end.sh"

command -v jq >/dev/null 2>&1 || { printf 'Bail out! jq not found\n'; exit 1; }

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

mkdir "$T/stub" "$T/repo" "$T/other"
cat > "$T/stub/dotnet" <<'EOF'
#!/bin/sh
echo "dotnet $*" >> "$STUB_LOG"
[ -z "${STUB_SLEEP:-}" ] || sleep "$STUB_SLEEP"
EOF
# The task exists where the directory holds a .session-end marker.
cat > "$T/stub/mise" <<'EOF'
#!/bin/sh
case "$*" in
  "tasks info session-end") [ -e .session-end ] ;;
  *) echo "mise $* in $PWD" >> "$STUB_LOG" ;;
esac
EOF
cat > "$T/stub/pgrep" <<'EOF'
#!/bin/sh
[ "$*" = "-x claude" ] && cut -d' ' -f1 "$STUB_PS"
exit 0
EOF
cat > "$T/stub/ps" <<'EOF'
#!/bin/sh
for a in "$@"; do p="$a"; done
awk -v p="$p" '$1 == p { $1 = ""; print substr($0, 2) }' "$STUB_PS"
EOF
chmod +x "$T/stub"/*
export STUB_LOG="$T/stub.log" STUB_PS="$T/ps.txt"
PATH="$T/stub:$PATH"
export PATH

# session <cwd>: the hook's stdin for a session ending in <cwd>.
session() { jq -nc --arg d "$1" '{session_id: "abc", hook_event_name: "SessionEnd", reason: "other", cwd: $d}'; }
# run <stdin>: the hook; sets $out, $rc, $ms.
run() {
  : > "$STUB_LOG"
  t0="$(date +%s%N)"
  out="$(printf '%s' "$1" | "$hook" 2>&1)"; rc=$?
  ms=$(( ($(date +%s%N) - t0) / 1000000 ))
}
# settle <pattern>: wait up to five seconds for the log to carry it.
settle() {
  i=0
  while [ "$i" -lt 50 ]; do
    grep -q "$1" "$STUB_LOG" 2>/dev/null && return 0
    sleep 0.1; i=$((i + 1))
  done
  return 1
}
# quiet: a second for anything to arrive, then the log as it stands.
quiet() { sleep 1; cat "$STUB_LOG"; }

# One claude process: this session's own.
printf '%s\n' "4242 claude" > "$STUB_PS"
: > "$T/repo/.session-end"

# The hook returns before the cleanup is done, with nothing on stdout.
STUB_SLEEP=3 run "$(session "$T/repo")"
[ "$rc" = 0 ] && [ -z "$out" ] && [ "$ms" -lt 1000 ]
result $? "exits 0 at once and prints nothing while the cleanup runs on" "exit $rc in $ms ms; out '$out'"
settle 'mise run session-end'
result $? "the cleanup still runs after the hook has returned" "$(cat "$STUB_LOG")"
unset STUB_SLEEP

# The last session on the machine: build servers down, the task run in cwd.
run "$(session "$T/repo")"
settle 'mise run session-end' && grep -qx 'dotnet build-server shutdown' "$STUB_LOG" &&
  grep -qx "mise run session-end in $T/repo" "$STUB_LOG"
result $? "last session: dotnet build-server shutdown, then mise run session-end in the session's cwd" "$(cat "$STUB_LOG")"

# Another session is running: its build servers are left for it.
printf '%s\n' "4242 claude" "4300 claude --resume abc" > "$STUB_PS"
run "$(session "$T/repo")"
settle 'mise run session-end' && ! grep -q 'build-server' "$STUB_LOG"
result $? "another claude session running: no build-server shutdown; the task still runs" "$(cat "$STUB_LOG")"

# The Chrome native host is a claude process and not a session.
printf '%s\n' "4242 claude" "4301 /home/me/.local/bin/claude --chrome-native-host" > "$STUB_PS"
run "$(session "$T/repo")"
settle 'build-server shutdown'
result $? "the Chrome native host does not count as a session" "$(cat "$STUB_LOG")"

# No session-end task: mise run is not called.
printf '%s\n' "4242 claude" > "$STUB_PS"
run "$(session "$T/other")"
settle 'build-server shutdown' && ! grep -q 'mise run' "$(printf '%s' "$STUB_LOG")"
result $? "no session-end task: mise run is not called" "$(cat "$STUB_LOG")"

# A cwd that does not exist: nothing runs, nothing fails.
run "$(session "$T/gone")"
[ "$rc" = 0 ] && [ -z "$(quiet)" ]
result $? "a cwd that does not exist: exit 0, nothing run" "exit $rc; $(cat "$STUB_LOG")"

# Empty stdin: CLAUDE_PROJECT_DIR stands in for cwd.
: > "$STUB_LOG"
out="$(CLAUDE_PROJECT_DIR="$T/repo" "$hook" </dev/null 2>&1)"; rc=$?
[ "$rc" = 0 ] && settle "mise run session-end in $T/repo"
result $? "no stdin: the cleanup runs in CLAUDE_PROJECT_DIR" "exit $rc; $(cat "$STUB_LOG")"

# No dotnet on PATH: the shutdown is skipped, the task still runs. PATH is
# only the stubs and the system tools the hook and stubs call, so a dotnet
# the machine has (a CI runner's /usr/bin/dotnet) cannot stand in.
mkdir "$T/nodotnet"
for b in mise pgrep ps; do ln -s "$T/stub/$b" "$T/nodotnet/$b"; done
for b in sh jq setsid nohup timeout cut awk sleep; do
  p="$(command -v "$b")" && ln -s "$p" "$T/nodotnet/$b"
done
: > "$STUB_LOG"
out="$(printf '%s' "$(session "$T/repo")" | PATH="$T/nodotnet" "$hook" 2>&1)"; rc=$?
[ "$rc" = 0 ] && settle 'mise run session-end' && ! grep -q dotnet "$STUB_LOG"
result $? "no dotnet: skipped; the task still runs" "exit $rc; $(cat "$STUB_LOG")"

printf '1..%d\n' "$n"
[ "$failed" = 0 ]
