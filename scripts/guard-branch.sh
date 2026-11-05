#!/bin/sh
# guard-branch.sh: client-side enforcement for decision 0002
# (decisions/0002-skills-stop-at-draft-pr.md). Nothing reaches main except
# by pull request; work happens on change/<id>.
#
# Usage: guard-branch.sh <mode>
#
#   branch  Exit 1 unless the current branch matches change/<id>.
#   push    Run the branch check, then read the git pre-push ref list from
#           stdin (<local ref> <local sha> <remote ref> <remote sha> per
#           line) and exit 1 if any ref targets refs/heads/main.
#   push-args
#           Decision 0022: refuse a force push. The remaining arguments are
#           the words after `git push`, as the Claude Code hook
#           (plugins/pap/hooks/guard-route.sh) reads them from an agent's
#           tool call. Exit 1 if any is --force, -f (alone or bundled, as in
#           -uf), --force-with-lease[=...], --force-if-includes, or a refspec
#           starting with `+`. Not run by git: a person at a terminal is
#           unaffected, and the GitHub ruleset all-branches is the backstop.
#   hook    Deprecated: the pap plugin's PreToolUse hook before 0.2.0.
#           Reads the tool-call JSON from stdin and runs the branch check in
#           the session's repository when the command contains `git commit`
#           or `git push`. From 0.2.0 the plugin routes each command to the
#           repository it targets (plugins/pap/hooks/guard-route.sh), which
#           calls `branch` mode there. Kept until installed plugins update.
#
# Outside a git work tree every mode exits 0: there is nothing to guard.

set -eu

mode="${1:-}"
id_pattern='^change/[A-Za-z0-9][A-Za-z0-9._-]*$'

refuse() {
  printf 'guard-branch: %s\n' "$1" >&2
  printf 'guard-branch: decision 0002: work on change/<id> and open a draft PR; main changes only by PR.\n' >&2
  exit "${2:-1}"
}

in_work_tree() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1
}

current_branch() {
  git symbolic-ref --quiet --short HEAD 2>/dev/null || printf 'HEAD (detached)'
}

check_branch() {
  branch="$(current_branch)"
  if ! printf '%s\n' "$branch" | grep -Eq "$id_pattern"; then
    refuse "refusing on branch '$branch'; expected change/<id>" "$1"
  fi
}

check_push_refs() {
  # stdin is the ref list only when git (or lefthook with use_stdin) pipes
  # it in; a terminal means a manual run with nothing to read.
  [ -t 0 ] && return 0
  while read -r local_ref _ remote_ref _; do
    [ -n "${remote_ref:-}" ] || continue
    if [ "$remote_ref" = "refs/heads/main" ]; then
      refuse "refusing to push $local_ref to $remote_ref" "$1"
    fi
  done
}

# check_push_args <word>...: refuse the first force form among the words.
check_push_args() {
  for word in "$@"; do
    case "$word" in
      --force | --force-with-lease | --force-with-lease=* | --force-if-includes) form="$word" ;;
      --*) continue ;;
      -[uqvnd46]*f* | -f*) form="$word" ;;
      +*) form="refspec $word" ;;
      *) continue ;;
    esac
    printf 'guard-branch: refusing a force push (%s)\n' "$form" >&2
    printf 'guard-branch: rule 22.1, decision 0022: no branch takes a force push; merge main into the branch instead of rebasing.\n' >&2
    printf 'guard-branch: the override is deliberate and the human'"'"'s: they push from their own terminal, after disabling the all-branches ruleset on GitHub, then run pap repo apply to restore it.\n' >&2
    exit 1
  done
}

case "$mode" in
  push-args)
    shift
    check_push_args "$@"
    ;;
  branch)
    in_work_tree || exit 0
    check_branch 1
    ;;
  push)
    in_work_tree || exit 0
    check_branch 1
    check_push_refs 1
    ;;
  hook)
    command -v jq >/dev/null 2>&1 || {
      printf 'guard-branch: jq not found; hook mode cannot parse tool input\n' >&2
      exit 1
    }
    input="$(cat)"
    tool="$(printf '%s' "$input" | jq -r '.tool_name // empty')"
    [ "$tool" = "Bash" ] || exit 0
    cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
    printf '%s\n' "$cmd" \
      | grep -Eq 'git([[:space:]]+-[^[:space:]]+)*[[:space:]]+(commit|push)([[:space:]]|$)' \
      || exit 0
    in_work_tree || exit 0
    check_branch 2
    ;;
  *)
    printf 'usage: %s branch|push|push-args|hook\n' "$0" >&2
    exit 64
    ;;
esac
