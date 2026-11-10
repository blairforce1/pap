#!/bin/sh
# pm-log.sh: the records a PM session does not write itself (decision 0025,
# changes/pm-mode/spec.md). One Claude Code hook an argument; each reads the
# hook JSON on stdin, appends at most one line under pap's state directory
# (pm-lib.sh has the files), prints nothing and always exits 0.
#
#   prompt   UserPromptSubmit. When the owner's prompt is the typed command
#            /pap:pm launch <slug>, alone on its line, in a session whose
#            directory is in an adopting repository: one line in
#            launches.log. That line is the yes of rule 18.2; pap-pm.sh
#            launch refuses without it. A prompt Claude Code submits for a
#            sub-agent's report or another session's message is wrapped in
#            a tag and never starts with the command, and a skill the model
#            invokes submits no prompt at all (probed on 2.1.322).
#   message  PreToolUse on SendMessage, in a PM session, from the main
#            session: one line in messages.log naming the sub-agent sent to.
#   stop     SubagentStop, in a PM session: one line in messages.log with
#            the sub-agent's id and type. A message to a sub-agent after its
#            first stop is what the messaged-cycles signal counts.

# SC2154: the pm_ variables are set by pm-lib.sh's functions.
# shellcheck disable=SC2154
set -u
kind="${1:-}"
case "$kind" in
  prompt) ;;
  message | stop) [ "${PAP_MODE:-}" = pm ] || exit 0 ;;
  *) exit 0 ;;
esac
command -v jq >/dev/null 2>&1 || exit 0

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091 # pm-lib.sh, beside this script
. "$here/pm-lib.sh"

input="$(cat)"
us="$(printf '\037')"
case "$kind" in
  prompt)
    f="$(printf '%s' "$input" | jq -r '
      select((.agent_id // "") == "")
      | (.prompt // "" | capture("^/pap:pm[ \\t]+launch[ \\t]+(?<s>[A-Za-z0-9][A-Za-z0-9._-]*)([ \\t][^\\n]*)?\\n?$")? | .s) as $s
      | select($s != null) | [.session_id // "-", .cwd // "", $s] | join("\u001f")' 2>/dev/null)" || exit 0
    [ -n "$f" ] || exit 0
    IFS="$us" read -r session cwd slug <<EOF
$f
EOF
    pm_session "${CLAUDE_PROJECT_DIR:-${cwd:-.}}"
    [ -n "$pm_own_key" ] || exit 0
    pm_log launches.log "$(pm_now)" "$session" "$pm_own_key" "$slug" ;;
  message)
    f="$(printf '%s' "$input" | jq -r '
      select((.agent_id // "") == "")
      | [.session_id // "-", (.tool_input.to // .tool_input.agent_id // .tool_input.name // "?" | tostring)] | join("\u001f")' 2>/dev/null)" || exit 0
    [ -n "$f" ] || exit 0
    IFS="$us" read -r session to <<EOF
$f
EOF
    pm_log messages.log "$(pm_now)" "$session" message "$to" - ;;
  stop)
    f="$(printf '%s' "$input" | jq -r '
      select((.agent_id // "") != "" and (.agent_type // "") != "")
      | [.session_id // "-", .agent_id, .agent_type] | join("\u001f")' 2>/dev/null)" || exit 0
    [ -n "$f" ] || exit 0
    IFS="$us" read -r session id type <<EOF
$f
EOF
    pm_log messages.log "$(pm_now)" "$session" stop "$id" "$type" ;;
esac
exit 0
