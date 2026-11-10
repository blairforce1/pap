#!/bin/sh
# guard-pm.sh: Claude Code PreToolUse hook for decision 0025, rule 25.2
# (changes/pm-mode/spec.md): a PM session writes only the PM paths.
#
# Runs before Edit, Write and NotebookEdit; these three are the tools it
# matches, and any other tool that writes a file (an MCP server's, for one)
# is a limit of the rule. Reads the tool-call JSON on stdin. Exits 2 to
# refuse the call, 0 to let it through, 1 (reported, not blocking) when it
# could not read the call.
#
# It binds one caller: the main session of a session pap claude started in
# PM mode (PAP_MODE=pm in Claude Code's own environment, which no command
# the session runs can change). Any other mode exits before reading
# anything. A call that carries an agent id is a sub-agent's and exits
# before any path or git work: a cycle is never refused a path (the H-003
# lesson). Claude Code puts the id on a sub-agent's calls and none on the
# main session's (probed on 2.1.322; session-start.sh checks it live).
#
# The path is judged where it resolves, after .. and symbolic links, from
# its deepest existing parent when it does not exist yet (pm-lib.sh):
#
#   made     changes/<slug>/**, features/<slug>.feature and product/** in the
#            session's own repository and its work trees; the tracker; any
#            file in no adopting repository (a scratch directory, memory)
#   refused  anything else in its own repository, naming the routes; every
#            path in another adopting repository, naming that repository's
#            own PM session, or for pap the text of an issue; the guard's own
#            files (Claude Code's settings, the installed plugins, pap's
#            state and config apart from the tracker), and a path that
#            cannot be resolved, naming no route
#
# Each refusal adds a line to the refusal log. A shell command that changes
# a file is not seen here; guard-route.sh judges the commit.

set -u
[ "${PAP_MODE:-}" = pm ] || exit 0

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=plugins/pap/hooks/pm-lib.sh
. "$here/pm-lib.sh"

input="$(cat)"
us="$(printf '\037')"
unread() { # unread <session> <what>
  printf 'guard-pm: could not read the tool call (%s); the PM paths were not checked for it\n' "$2" >&2
  pm_log refusals.log "$(pm_now)" "${1:--}" pm unknown - - unread
  exit 1
}
command -v jq >/dev/null 2>&1 || unread "" "jq not found"
fields="$(printf '%s' "$input" | jq -r '[.agent_id // "", .agent_type // "", .session_id // "",
  (.tool_input.file_path // .tool_input.notebook_path // ""), .cwd // "", "end"] | map(tostring) | join("\u001f")' 2>/dev/null)" ||
  unread "" "not the JSON a tool call carries"
IFS="$us" read -r agent _type session path cwd _end <<EOF
$fields
EOF
[ -z "$agent" ] || exit 0
[ -n "$path" ] || unread "$session" "no file path in it"

case "$path" in
  /*) ;;
  \~/*) path="$HOME/${path#??}" ;;
  *) path="${cwd:-${CLAUDE_PROJECT_DIR:-$PWD}}/$path" ;;
esac
pm_session "${CLAUDE_PROJECT_DIR:-${cwd:-.}}"

refuse() { # refuse <shown path> <repository> <reason> <instead>
  printf 'guard-pm: refusing a write to %s: %s\n' "$1" "$3" >&2
  printf 'guard-pm: rule 25.2: a PM session writes only changes/<slug>/**, features/<slug>.feature, product/** and the tracker. %s Do not retry.\n' "$4" >&2
  pm_log refusals.log "$(pm_now)" "${session:--}" pm main "$1" "${2:--}" write
  exit 2
}

resolved="$(pm_resolve "$path")" ||
  refuse "$path" "$pm_own_key" "the path could not be resolved, so it is refused and not passed" \
    "No route changes that; tell the owner what you were writing."
pm_judge "$resolved"
case "$pm_verdict" in
  ok) exit 0 ;;
  route)
    refuse "$resolved" "$pm_own_key" "it is outside the PM paths" \
      "Bring the route to the owner instead: a cycle through /pap:pm launch <slug>, or /intent <slug> <class> for a change that needs one (rule 20.2)." ;;
  other)
    refuse "$resolved" "$pm_jrepo" "it is in another adopting repository, $pm_jrepo, where this session writes nothing" \
      "The change belongs to that repository's own PM session; tell the owner." ;;
  otherpap)
    refuse "$resolved" "$pm_jrepo" "it is in pap, $pm_jrepo, where this session writes nothing" \
      "Give the owner the text of an issue for blairforce1/pap, for the owner to file (rule 25.4)." ;;
  *)
    refuse "$resolved" "$pm_own_key" "the file belongs to the guard: Claude Code's settings, an installed plugin, or pap's state or config" \
      "No route changes it from a PM session; tell the owner." ;;
esac
