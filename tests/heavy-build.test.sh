#!/bin/sh
# heavy-build.test.sh: tests for templates/dotnet/scripts/heavy-build.sh
# (decision 0015, rule 15.1).
#
# Usage: sh tests/heavy-build.test.sh
#
# Runs the script with a stub dotnet on PATH that logs its arguments, a
# fake power-supply directory for each power state, and a lock file in a
# temporary directory. Prints one TAP-style line per case and exits 1 if
# any case fails. Needs flock; touches nothing outside the temporary
# directory.
#
# SC2319: each case passes the exit status of its condition on purpose.
# shellcheck disable=SC2319

set -u

here="$(cd "$(dirname "$0")/.." && pwd)"
hb="$here/templates/dotnet/scripts/heavy-build.sh"

command -v flock >/dev/null 2>&1 || { printf 'Bail out! flock not found\n'; exit 1; }

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

# A stub dotnet: logs its arguments, sleeps or leaves a child behind when
# told, exits as told.
mkdir "$T/stub"
cat > "$T/stub/dotnet" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$STUB_LOG"
[ -z "${STUB_SLEEP:-}" ] || sleep "$STUB_SLEEP"
[ -z "${STUB_LINGER:-}" ] || { sleep "$STUB_LINGER" </dev/null >/dev/null 2>&1 & }
exit "${STUB_EXIT:-0}"
EOF
chmod +x "$T/stub/dotnet"
export STUB_LOG="$T/dotnet.log" PAP_HEAVY_LOCK="$T/lock" PAP_POWER_SUPPLY="$T/ps"
PATH="$T/stub:$PATH"
export PATH

# supply <name> <type> [online]: one entry in the fake power-supply directory.
supply() {
  mkdir -p "$T/ps/$1"
  printf '%s\n' "$2" > "$T/ps/$1/type"
  [ $# -lt 3 ] || printf '%s\n' "$3" > "$T/ps/$1/online"
}
# run <args>: the script with a fresh log; sets $out, $rc and $logged.
run() {
  : > "$STUB_LOG"
  out="$(sh "$hb" "$@" 2>&1)"; rc=$?
  logged="$(cat "$STUB_LOG")"
}

# --- power state ---------------------------------------------------------------

# On mains: the adapter's name varies by machine; its type is always Mains.
# A USB source that is online is not an adapter.
supply ACAD Mains 1; supply BAT1 Battery; supply ucsi-source-psy-USBC000:001 USB 1
run -f net10.0-android -c Release
[ "$rc" = 0 ] && [ "$logged" = "build -f net10.0-android -c Release" ] && [ -z "$out" ]
result $? "mains: dotnet build runs as given, quietly" "exit $rc; log '$logged'; out '$out'"

rm -r "$T/ps"; supply ADP1 Mains 0; supply BAT0 Battery; supply ucsi-source-psy-USBC000:001 USB 1
run -f net10.0-android -c Release
[ "$rc" = 0 ] && [ "$logged" = "build -f net10.0-android -c Release -m:2" ] &&
  printf '%s\n' "$out" | grep -q 'on battery'
result $? "battery (Mains present, none online): -m:2 added and said" "exit $rc; log '$logged'; out '$out'"

run -c Release -m:1
[ "$logged" = "build -c Release -m:1" ]
result $? "battery: a node count already given is kept" "log '$logged'"
run -c Release --max-cpu-count 3
[ "$logged" = "build -c Release --max-cpu-count 3" ]
result $? "battery: --max-cpu-count is a node count too" "log '$logged'"

rm -r "$T/ps"; supply BAT0 Battery
run -c Release
[ "$logged" = "build -c Release" ]
result $? "no Mains entry: cannot tell, so mains is assumed" "log '$logged'"

rm -r "$T/ps"
run -c Release
[ "$logged" = "build -c Release" ]
result $? "no power-supply directory: mains is assumed" "log '$logged'"

# --- the verb --------------------------------------------------------------------

run publish -f net10.0-ios -c Release
[ "$logged" = "publish -f net10.0-ios -c Release" ]
result $? "an explicit verb is passed through" "log '$logged'"
run App/App.csproj -c Release
[ "$logged" = "build App/App.csproj -c Release" ]
result $? "a first argument that is not a verb belongs to a build" "log '$logged'"
STUB_EXIT=3 run -c Release
[ "$rc" = 3 ]
result $? "dotnet's exit status is the script's" "exit $rc"

# --- the lock --------------------------------------------------------------------

# Two builds at once: the second says it is waiting and runs after the first.
: > "$STUB_LOG"
STUB_SLEEP=2 sh "$hb" -c Release -p:First=true >/dev/null 2>&1 &
first=$!
sleep 0.5
t0="$(date +%s%N)"
out="$(sh "$hb" -c Release -p:Second=true 2>&1)"; rc=$?
t1="$(date +%s%N)"
wait "$first"
waited=$(( (t1 - t0) / 1000000 ))
[ "$rc" = 0 ] && printf '%s\n' "$out" | grep -q 'waiting for' && [ "$waited" -ge 1000 ] &&
  [ "$(sed -n 1p "$STUB_LOG")" = "build -c Release -p:First=true" ] &&
  [ "$(sed -n 2p "$STUB_LOG")" = "build -c Release -p:Second=true" ]
result $? "a second build waits for the first and says so" "exit $rc; waited ${waited} ms; out '$out'; log: $(tr '\n' '|' < "$STUB_LOG")"

# A process the build leaves behind (an MSBuild worker node, VBCSCompiler)
# must not keep the lock: the next build would wait on a finished one.
STUB_LINGER=3 run -c Release
flock -n "$T/lock" true
result $? "the lock is free after the build although a child of dotnet lingers" "exit $rc"

# Without flock the build runs unlocked and says so.
mkdir "$T/bin"
ln -s "$(command -v cat)" "$T/bin/cat"
: > "$STUB_LOG"
out="$(PATH="$T/stub:$T/bin" "$(command -v sh)" "$hb" -c Release 2>&1)"; rc=$?
[ "$rc" = 0 ] && printf '%s\n' "$out" | grep -q 'flock not found' && [ "$(cat "$STUB_LOG")" = "build -c Release" ]
result $? "no flock: the build runs unlocked and says so" "exit $rc; out '$out'"

printf '1..%d\n' "$n"
[ "$failed" = 0 ]
