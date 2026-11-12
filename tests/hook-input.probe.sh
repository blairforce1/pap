#!/bin/sh
# hook-input.probe.sh: the probe behind decision 0025's guard
# (changes/pm-mode/spec.md, Security and "Consumed"). pap does not control
# Claude Code's hook input; this asks a live Claude Code what it sends.
#
# Usage: sh tests/hook-input.probe.sh
#
# Not part of `mise run test`: it starts three real `claude -p` sessions (the
# small model, a few thousand tokens), so it needs the claude CLI signed in
# and the network. Run it by hand on a new Claude Code release, and when
# the session log shows a role given as `:unbound`.
#
# It loads a throwaway plugin whose hooks write every input they get to a
# file, then checks the facts the guard and `/pap:pm sync` rest on:
#
#   1  a main session's tool call carries no agent_id
#   2  a sub-agent's tool call carries agent_id and agent_type
#   3  a hook sees PAP_MODE as Claude Code was started with it
#   4  UserPromptSubmit gets a typed slash command as its raw line
#   5  the Bash tool's shell has the hooks' session_id as
#      CLAUDE_CODE_SESSION_ID (changes/pm-sync/spec.md, "The PM session")
#
# Prints one TAP-style line per fact and exits 1 if any fails. First passed
# on Claude Code 2.1.322, 2026-11-10; fact 5 on 2.1.322, 2026-11-12. Touches nothing outside a temporary
# directory.

set -u
for tool in claude jq git; do
  command -v "$tool" >/dev/null 2>&1 || { printf 'Bail out! %s not found\n' "$tool"; exit 1; }
done

T="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$T"' EXIT INT TERM
mkdir -p "$T/plugin/.claude-plugin" "$T/plugin/hooks" "$T/plugin/skills/pm" "$T/work"
printf '{"name":"probe","version":"0.0.1","description":"hook input probe"}\n' > "$T/plugin/.claude-plugin/plugin.json"
cat > "$T/plugin/hooks/log.sh" <<'EOF'
#!/bin/sh
jq -c --arg m "${PAP_MODE:-unset}" '{mode: $m, event: .hook_event_name, tool: (.tool_name // ""),
  agent_id: (.agent_id // ""), agent_type: (.agent_type // ""), session_id: (.session_id // ""), prompt: (.prompt // "" | .[0:80])}' >> "$PROBE_LOG"
exit 0
EOF
chmod +x "$T/plugin/hooks/log.sh"
cat > "$T/plugin/hooks/hooks.json" <<'EOF'
{"hooks": {
  "PreToolUse": [{"matcher": "*", "hooks": [{"type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/log.sh\""}]}],
  "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/log.sh\""}]}]
}}
EOF
# shellcheck disable=SC2016 # $ARGUMENTS is for Claude Code to fill
printf -- '---\nname: pm\ndescription: Probe skill. Use only when the user types /probe:pm.\n---\nReply with exactly: ran $ARGUMENTS\n' \
  > "$T/plugin/skills/pm/SKILL.md"
git init -q "$T/work"
# The shell's side of fact 5: the Bash tool runs this, and it logs what the
# shell has beside what the hooks were sent.
cat > "$T/work/sid.sh" <<'EOF'
#!/bin/sh
jq -cn --arg s "${CLAUDE_CODE_SESSION_ID:-}" '{event: "Shell", shell_session_id: $s}' >> "$PROBE_LOG"
EOF

PROBE_LOG="$T/events.jsonl"
export PROBE_LOG
: > "$PROBE_LOG"
# The mode is set here as pap claude sets it: in Claude Code's environment.
(cd "$T/work" && env PAP_MODE=pm claude -p "Do exactly two things, then stop. 1) With the Write tool, write the file main.txt containing a. 2) Spawn one general-purpose sub-agent whose whole task is: with the Write tool, write the file sub.txt containing b." \
  --plugin-dir "$T/plugin" --allowedTools "Write,Agent,Task" --model haiku </dev/null >/dev/null 2>&1)
(cd "$T/work" && claude -p "/probe:pm launch trial" --plugin-dir "$T/plugin" --model haiku </dev/null >/dev/null 2>&1)
(cd "$T/work" && claude -p "With the Bash tool, run exactly this command and nothing else, then stop: sh sid.sh" \
  --plugin-dir "$T/plugin" --allowedTools "Bash(sh sid.sh)" --model haiku </dev/null >/dev/null 2>&1)

n=0
failed=0
fact() { # fact <jq filter over the slurped log> <label>
  n=$((n + 1))
  if jq -es "$1" "$PROBE_LOG" >/dev/null 2>&1; then
    printf 'ok %d - %s\n' "$n" "$2"
  else
    printf 'not ok %d - %s\n' "$n" "$2"
    failed=$((failed + 1))
  fi
}
fact 'map(select(.event == "PreToolUse" and .tool == "Write" and .agent_id == "")) | length >= 1' \
  "a main session's Write carries no agent_id"
fact 'map(select(.event == "PreToolUse" and .tool == "Write" and .agent_id != "" and .agent_type != "")) | length >= 1' \
  "a sub-agent's Write carries agent_id and agent_type"
fact 'map(select(.event == "PreToolUse" and .tool == "Write")) | length >= 2 and all(.mode == "pm")' \
  "the hooks of both see PAP_MODE=pm from Claude Code's environment"
fact 'map(select(.event == "UserPromptSubmit" and (.prompt | startswith("/probe:pm launch trial")))) | length == 1' \
  "UserPromptSubmit gets the typed /probe:pm launch trial as its raw line"
# shellcheck disable=SC2016 # $s is jq's
fact '(map(select(.event == "Shell")) | first | .shell_session_id) as $s
  | ($s | length) > 0
    and (map(select(.event == "PreToolUse" and .tool == "Bash" and .agent_id == ""))
      | length >= 1 and all(.session_id == $s))' \
  "the Bash tool's shell has the hooks' session_id as CLAUDE_CODE_SESSION_ID"
printf '1..%d\n' "$n"
printf '# Claude Code %s\n' "$(claude --version 2>/dev/null)"
[ "$failed" = 0 ] || { printf '# %d of %d failed\n' "$failed" "$n"; sed 's/^/# /' "$PROBE_LOG"; exit 1; }
