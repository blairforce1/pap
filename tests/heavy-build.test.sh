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
# shellcheck disable=SC1091 # tests/clean-env.sh, sourced from this directory
. "$(dirname "$0")/clean-env.sh"

here="$(cd "$(dirname "$0")/.." && pwd)"
hb="$here/templates/dotnet/scripts/heavy-build.sh"

command -v flock >/dev/null 2>&1 || { printf 'Bail out! flock not found\n'; exit 1; }

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
# Every build logs under the state directory: keep it in the temp dir.
export HOME="$T/home" XDG_STATE_HOME="$T/state"
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
export STUB_EXIT=3; run -c Release; unset STUB_EXIT
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
export STUB_LINGER=3; run -c Release; unset STUB_LINGER
flock -n "$T/lock" true
result $? "the lock is free after the build although a child of dotnet lingers" "exit $rc"

# Without flock the build runs unlocked and says so.
mkdir "$T/bin"
ln -s "$(command -v cat)" "$T/bin/cat"
: > "$STUB_LOG"
out="$(PATH="$T/stub:$T/bin" "$(command -v sh)" "$hb" -c Release 2>&1)"; rc=$?
[ "$rc" = 0 ] && printf '%s\n' "$out" | grep -q 'flock not found' && [ "$(cat "$STUB_LOG")" = "build -c Release" ]
result $? "no flock: the build runs unlocked and says so" "exit $rc; out '$out'"

# --- the log ---------------------------------------------------------------------

# Each build appends one tab-separated line (UTC start, command, power,
# seconds) under the user's state directory, and nothing in the repository
# it ran from.
git init -q "$T/repo"
rm -rf "$T/ps" "$T/state"; supply ADP1 Mains 0; supply BAT0 Battery
log="$T/state/pap/heavy-builds.log"
(cd "$T/repo" && STUB_SLEEP=1 sh "$hb" publish -f net10.0-ios -c Release >/dev/null 2>&1)
line="$(cat "$log" 2>/dev/null)"
tab="$(printf '\t')"
printf '%s\n' "$line" | grep -Eq "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z${tab}dotnet publish -f net10.0-ios -c Release -m:2${tab}battery${tab}[1-9][0-9]*s\$" &&
  [ "$(wc -l < "$log")" -eq 1 ] && [ -z "$(git -C "$T/repo" status --porcelain)" ]
result $? "a build appends time, command, power and duration to the state log, not the repo" "log '$line'; repo: $(git -C "$T/repo" status --porcelain | tr '\n' ' ')"

rm -r "$T/ps"; supply ACAD Mains 1
(cd "$T/repo" && sh "$hb" -c Release >/dev/null 2>&1)
[ "$(wc -l < "$log")" -eq 2 ] && tail -n 1 "$log" | grep -q "${tab}dotnet build -c Release${tab}mains${tab}"
result $? "a second build appends a second line, on mains" "log: $(tr '\n' '|' < "$log")"

unset XDG_STATE_HOME
(cd "$T/repo" && sh "$hb" -c Release >/dev/null 2>&1)
grep -q "${tab}dotnet build -c Release${tab}" "$T/home/.local/state/pap/heavy-builds.log" 2>/dev/null
result $? "without XDG_STATE_HOME the log is under HOME/.local/state" ""

export XDG_STATE_HOME=state
(cd "$T/repo" && sh "$hb" -c Release >/dev/null 2>&1)
[ ! -e "$T/repo/state" ] && [ "$(wc -l < "$T/home/.local/state/pap/heavy-builds.log")" -eq 2 ] &&
  [ -z "$(git -C "$T/repo" status --porcelain)" ]
result $? "a relative XDG_STATE_HOME is ignored, so nothing lands in the repo" "repo: $(find "$T/repo" -maxdepth 1 ! -name .git | tr '\n' ' ')"

export XDG_STATE_HOME="$T/state"
chmod a-w "$T/state/pap/heavy-builds.log"
export STUB_EXIT=4
out="$(cd "$T/repo" && sh "$hb" -c Release 2>&1)"; rc=$?
unset STUB_EXIT
chmod u+w "$T/state/pap/heavy-builds.log"
[ "$rc" = 4 ] && printf '%s\n' "$out" | grep -q 'not logged'
result $? "a log it cannot write never changes the build's status, and says so" "exit $rc; out '$out'"

printf '1..%d\n' "$n"
[ "$failed" = 0 ]
