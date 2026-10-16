#!/bin/sh
# heavy-build.sh: run one heavy .NET build under the machine's heavy-build
# lock, rule 15.1 of decision 0015
# (decisions/0015-agent-sessions-share-one-machines-power-and-cores.md).
#
# Usage: scripts/heavy-build.sh [build|publish|pack|test] <dotnet arguments>
#        scripts/heavy-build.sh -f net10.0-android -c Release      # a build
#        scripts/heavy-build.sh publish -f net10.0-ios -c Release
#
# A heavy build (an Android, iOS or Mac Catalyst target, a Release
# configuration, AOT) takes minutes and every core. Agent sessions on one
# machine do not know of each other, so two can start one each and contend
# for the same cores. This script takes the one lock the machine has,
# ${XDG_RUNTIME_DIR:-/tmp}/pap-heavy-build.lock, runs
# `dotnet <verb> <arguments>` and releases it when dotnet exits. A second
# build says it is waiting and waits. On battery it adds -m:2, two MSBuild
# nodes instead of one per core, unless the arguments already set a count.
# A light build needs none of this and runs `dotnet build` directly.
#
# The verb defaults to build, so arguments alone are a build. The lock is
# held by this shell, not by dotnet: MSBuild worker nodes and VBCSCompiler
# outlive the build (node reuse), and a lock they inherited would never be
# released, so dotnet runs with the lock's descriptor closed.
#
# Battery: any /sys/class/power_supply/* whose type is Mains is an adapter,
# whatever its name (ACAD, AC, ADP1); the machine is on battery when it has
# one and none is online. On macOS, `pmset -g batt` reports "Battery
# Power". Where neither answers, mains is assumed. flock is util-linux;
# without it (macOS ships none; `brew install flock`) the build runs
# unlocked and says so. PAP_HEAVY_LOCK and PAP_POWER_SUPPLY override the
# lock path and the sysfs directory, for tests.

set -u

lock="${PAP_HEAVY_LOCK:-${XDG_RUNTIME_DIR:-/tmp}/pap-heavy-build.lock}"
supplies="${PAP_POWER_SUPPLY:-/sys/class/power_supply}"

say() { printf 'heavy-build: %s\n' "$*" >&2; }

on_battery() {
  if [ -d "$supplies" ]; then
    adapters=0
    for d in "$supplies"/*/; do
      [ -r "${d}type" ] || continue
      [ "$(cat "${d}type")" = Mains ] || continue
      adapters=$((adapters + 1))
      [ "$(cat "${d}online" 2>/dev/null)" = 1 ] && return 1
    done
    [ "$adapters" -gt 0 ] && return 0
    return 1
  fi
  if command -v pmset >/dev/null 2>&1; then
    case "$(pmset -g batt 2>/dev/null)" in *"Battery Power"*) return 0 ;; esac
  fi
  return 1
}

case "${1:-}" in
  build | publish | pack | test) verb="$1"; shift ;;
  *) verb=build ;;
esac

cap=""
if on_battery; then
  case " $* " in
    *" -m"* | *" /m"* | *" --max-cpu-count"*) ;;
    *) cap="-m:2"; say "on battery: MSBuild capped at two nodes (-m:2)" ;;
  esac
fi

if ! command -v flock >/dev/null 2>&1; then
  say "flock not found; running without the machine lock"
elif ! ( : >>"$lock" ) 2>/dev/null; then
  say "cannot open $lock; running without the machine lock"
else
  exec 9>>"$lock"
  if ! flock -n 9; then
    say "waiting for $lock, held by another heavy build on this machine"
    flock 9
  fi
fi

# shellcheck disable=SC2086 # $cap is one word or nothing
dotnet "$verb" "$@" $cap 9>&-
