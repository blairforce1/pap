#!/bin/sh
# guard-route.sh: Claude Code PreToolUse hook for decision 0002
# (decisions/0002-skills-stop-at-draft-pr.md).
#
# Reads the tool-call JSON on stdin. For every `git commit` or `git push` in
# a Bash command, works out the directory it runs in: the session's cwd, then
# any `cd <dir>` earlier in the same command, then any `git -C <dir>`. If the
# repository there adopts decision 0002 (it has an executable
# scripts/guard-branch.sh), runs that script's branch check in it. Exits 2 to
# block the call when a check fails, 0 otherwise.
#
# The rule lives in each repository's guard-branch.sh; this script only
# decides which repository a command targets, so a session in one repository
# neither blocks commits to another nor lets a commit to a guarded one through.
#
# Parsing is deliberately simple. It follows cd and git -C across &&, ||, ;,
# |, newlines and subshell parentheses, and skips git's -c and other global
# options. It does not follow bash -c, eval, GIT_DIR or --git-dir; the
# pre-push hook and the repository ruleset remain the backstop.

set -u

if ! command -v jq >/dev/null 2>&1; then
  # Without jq the command cannot be parsed. Complain only in a session whose
  # own repository is guarded, as the hook did before routing existed.
  [ -x "${CLAUDE_PROJECT_DIR:-.}/scripts/guard-branch.sh" ] || exit 0
  printf 'guard-route: jq not found; cannot parse the tool call\n' >&2
  exit 1
fi

targets="$(jq -r '
  def unquote: if test("^\".*\"$") or test("^'"'"'.*'"'"'$") then .[1:-1] else . end;
  def resolve($base):
    unquote
    | if . == "" or . == "~" then env.HOME
      elif startswith("~/") then env.HOME + .[1:]
      elif startswith("/") then .
      else $base + "/" + . end;
  def arg: "(\"[^\"]*\"|'"'"'[^'"'"']*'"'"'|[^\\s]+)";

  select(.tool_name == "Bash")
  | (.cwd // env.CLAUDE_PROJECT_DIR // ".") as $cwd
  | [(.tool_input.command // "") | splits("&&|\\|\\||;|\\||\\n|\\(|\\)")]
  | reduce .[] as $seg ({dir: $cwd, out: []};
      . as $st
      | ($seg | gsub("^\\s+|\\s+$"; "")) as $s
      | if ($s | test("^cd(\\s|$)")) then
          .dir = ((($s | capture("^cd\\s+(?<a>" + arg + ")")? | .a) // "~") | resolve($st.dir))
        else
          # [...][0] turns a failed match into null; an empty update would
          # reset the reduce state and lose the directory tracked so far.
          ([$s | capture("^([A-Za-z_][A-Za-z0-9_]*=[^\\s]*\\s+)*git(?<opts>(\\s+-[Cc]\\s+" + arg
                         + "|\\s+--?[A-Za-z][A-Za-z0-9-]*(=[^\\s]+)?)*)\\s+(?<sub>[^\\s]+)")?][0]) as $m
          | if $m != null and ($m.sub == "commit" or $m.sub == "push") then
              .out += [reduce ([$m.opts | scan("-C\\s+" + arg)] | map(.[0]))[] as $c
                         ($st.dir; . as $d | $c | resolve($d))]
            else . end
        end)
  | .out | unique | .[]
')" || exit 0

[ -n "$targets" ] || exit 0

status=0
while IFS= read -r target; do
  root="$(git -C "$target" rev-parse --show-toplevel 2>/dev/null)" || continue
  guard="$root/scripts/guard-branch.sh"
  [ -x "$guard" ] || continue
  (cd "$root" && "$guard" branch) || status=2
done <<EOF
$targets
EOF
exit "$status"
