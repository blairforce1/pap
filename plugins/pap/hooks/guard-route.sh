#!/bin/sh
# guard-route.sh: Claude Code PreToolUse hook for decisions 0002
# (decisions/0002-skills-stop-at-draft-pr.md) and 0005
# (decisions/0005-agent-sessions-do-not-bypass-hooks.md).
#
# Reads the tool-call JSON on stdin. For every git command in a Bash command,
# works out the directory it runs in: the session's cwd, then any `cd <dir>`
# earlier in the same command, then any `git -C <dir>`. A repository adopts
# PAP when it has an executable scripts/guard-branch.sh. Exits 2 to block the
# call, 0 otherwise. In an adopting repository:
#
#   0002  a `git commit` or `git push` runs guard-branch.sh's branch check.
#   0005  a hook bypass is refused: LEFTHOOK or LEFTHOOK_EXCLUDE set anywhere
#         in the command (as a prefix, through env or export, or earlier in
#         a sequence), `git commit --no-verify` or `-n`, `git push
#         --no-verify`, and core.hooksPath through `git config`, `-c` or
#         `--config-env`. `git push -n` is --dry-run and passes.
#
# The rules live here and in each repository's guard-branch.sh; this script
# decides which repository a command targets, so a session in one repository
# neither blocks commits to another nor lets a commit to a guarded one through.
# Humans are unaffected: the hook runs only on an agent's Bash tool calls.
#
# Parsing is deliberately simple. It follows cd and git -C across &&, ||, ;,
# |, newlines and subshell parentheses, skips git's -c and other global
# options, and reads quoted words as one, so a commit message that mentions
# --no-verify passes. It does not follow bash -c, eval, GIT_DIR, --git-dir or
# GIT_CONFIG_* variables; the pre-push hook and the repository ruleset remain
# the backstop for main, and nothing yet backs up pre-commit.

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
  | reduce .[] as $seg ({dir: $cwd, lefthook: null, out: []};
      . as $st
      | ($seg | gsub("^\\s+|\\s+$"; "")) as $s
      | if ($s | test("^cd(\\s|$)")) then
          .dir = ((($s | capture("^cd\\s+(?<a>" + arg + ")")? | .a) // "~") | resolve($st.dir))
        else
          # [...][0] turns a failed match into null; an empty update would
          # reset the reduce state and lose the directory tracked so far.
          ([$s | capture("^(env(\\s+-[^\\s]+)*\\s+)?([A-Za-z_][A-Za-z0-9_]*=[^\\s]*\\s+)*git(?<opts>(\\s+-[Cc]\\s+" + arg
                         + "|\\s+--?[A-Za-z][A-Za-z0-9-]*(=[^\\s]+)?)*)\\s+(?<sub>[^\\s]+)(?<rest>.*)$")?][0]) as $m
          # A LEFTHOOK assignment sticks for the rest of the command, as
          # export would; over-refusing a prefix assignment is harmless.
          | ([$s | scan(arg) | .[0] | select(test("^(LEFTHOOK|LEFTHOOK_EXCLUDE)="))][0] // .lefthook) as $lh
          | .lefthook = $lh
          | if $m == null then
              if $lh != null then .out += ["bypass\t\($st.dir)\t\($lh)"] else . end
            else
              (reduce ([$m.opts | scan("-C\\s+" + arg)] | map(.[0]))[] as $c
                 ($st.dir; . as $d | $c | resolve($d))) as $t
              | ([$m.rest | scan(arg) | .[0]]) as $args
              | (if $m.sub == "commit" or $m.sub == "push" then .out += ["branch\t\($t)"] else . end)
              | (if $lh != null then .out += ["bypass\t\($t)\t\($lh)"] else . end)
              | (if ($m.opts | test("core\\.hookspath"; "i"))
                    or ($m.sub == "config" and ($m.rest | test("core\\.hookspath"; "i")))
                 then .out += ["bypass\t\($t)\tcore.hooksPath"] else . end)
              | (if ($m.sub == "commit" or $m.sub == "push")
                    and ($args | any(test("^--no-veri(fy?)?$")))
                 then .out += ["bypass\t\($t)\t--no-verify"] else . end)
              | (if $m.sub == "commit" and ($args | any(test("^-[^-mFCctuS]*n")))
                 then .out += ["bypass\t\($t)\tcommit -n"] else . end)
            end
        end)
  | .out | unique | .[]
')" || exit 0

[ -n "$targets" ] || exit 0

tab="$(printf '\t')"
status=0
while IFS="$tab" read -r kind target reason; do
  root="$(git -C "$target" rev-parse --show-toplevel 2>/dev/null)" || continue
  guard="$root/scripts/guard-branch.sh"
  [ -x "$guard" ] || continue
  case "$kind" in
    branch)
      (cd "$root" && "$guard" branch) || status=2
      ;;
    bypass)
      printf 'guard-route: refusing %s in %s\n' "$reason" "$root" >&2
      printf 'guard-route: decision 0005: agent sessions may not bypass git hooks; fix what the hook reports, or ask the human.\n' >&2
      status=2
      ;;
  esac
done <<EOF
$targets
EOF
exit "$status"
