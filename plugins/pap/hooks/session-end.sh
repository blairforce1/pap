#!/bin/sh
# session-end.sh: Claude Code SessionEnd hook for decision 0015
# (decisions/0015-agent-sessions-share-one-machines-power-and-cores.md).
#
# Reads the hook JSON on stdin for the session's cwd, starts the cleanup
# below as a detached process and exits 0 at once. SessionEnd hooks share
# a 1.5 s budget that a plugin's own timeout cannot raise, cannot block the
# exit, and have their stdout discarded, so nothing here waits, prints or
# fails: a session's exit is never delayed by its cleanup.
#
# The cleanup, in the session's cwd, each step capped at five minutes
# where `timeout` exists and skipped where its tool is missing:
#
#   (a) `dotnet build-server shutdown`, only when no other Claude Code
#       session runs on this machine. Measured on SDK 10.0.401: the command
#       cannot break a parallel build (a busy MSBuild worker node is left
#       alone and finishes; an in-flight VBCSCompiler compile is waited for,
#       15.6 s on a 17 MB source file, then the server exits), but it costs
#       a live session a cold server on its next build. So the last session
#       out shuts the servers down and an earlier one leaves them for the
#       sessions still running. Another session is a process named claude
#       other than this one; the Chrome native host is a claude process too
#       and is not a session. The shutdown reaches the servers of the SDK
#       the session's `dotnet` resolves; another SDK's servers stay.
#   (b) `mise run session-end`, when the repository defines that task: the
#       place for a project's own cleanup, such as stopping an emulator a
#       script of its own started. mise refuses an untrusted directory
#       without prompting when stdin is not a terminal, so this cannot hang.
#
# A process that outlives the session: setsid (util-linux) puts it in its
# own session so Claude Code's teardown does not take it; without setsid,
# nohup. stdin, stdout and stderr are /dev/null, so the hook's pipes close
# and nothing reaches the terminal.

set -u

if [ "${1:-}" = --cleanup ]; then
  cd "${2:-.}" 2>/dev/null || exit 0
  limit() { if command -v timeout >/dev/null 2>&1; then timeout 300 "$@"; else "$@"; fi; }
  others=0
  for p in $(pgrep -x claude 2>/dev/null); do
    case "$(ps -o args= -p "$p" 2>/dev/null)" in *chrome-native-host*) ;; *) others=$((others + 1)) ;; esac
  done
  # This session's own process is still alive and counted.
  if command -v dotnet >/dev/null 2>&1 && [ "$others" -le 1 ]; then
    limit dotnet build-server shutdown
  fi
  if command -v mise >/dev/null 2>&1 && mise tasks info session-end >/dev/null 2>&1; then
    limit mise run session-end
  fi
  exit 0
fi

cwd=""
if command -v jq >/dev/null 2>&1; then
  cwd="$(jq -r '.cwd // empty' 2>/dev/null)"
fi
[ -n "$cwd" ] || cwd="${CLAUDE_PROJECT_DIR:-.}"

if command -v setsid >/dev/null 2>&1; then
  setsid sh "$0" --cleanup "$cwd" </dev/null >/dev/null 2>&1 &
else
  nohup sh "$0" --cleanup "$cwd" </dev/null >/dev/null 2>&1 &
fi
exit 0
