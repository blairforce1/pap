#!/bin/sh
# pm-lib.sh: what the PM-mode hooks and /pap:pm share (decision 0025,
# changes/pm-mode/spec.md). Sourced, never run: guard-pm.sh, guard-route.sh,
# session-start.sh, pm-log.sh and skills/pm/pap-pm.sh.
#
# Where things live, under pap's state directory
# (${XDG_STATE_HOME:-~/.local/state}/pap), mode 700:
#
#   pm/sessions.log   one line a start and one a role given: UTC time,
#                     session id, mode, repository, Claude Code version, what;
#                     and, for a PM start with the main checkout off main,
#                     main-checkout:<branch> or main-checkout:detached
#   pm/refusals.log   one line a refusal: UTC time, session id, mode, caller
#                     (main, or a sub-agent's id and type), path, repository,
#                     kind (write, commit, unread; and, by decision 0027,
#                     pr-main-checkout, pr-label, branch-switch,
#                     path-without-dashes, unplaced, whose path is the
#                     directory the command ran in and which carry an eighth
#                     field, the form refused: gh pr create, or git switch
#                     or git checkout with its options, never the command)
#   pm/messages.log   UTC time, session id, message or stop, the sub-agent's
#                     id, its type
#   pm/launches.log   one line for each /pap:pm launch <slug> the owner
#                     typed: UTC time, session id, repository, slug
#   pm/keys.tsv       repository key, then the git directory it was first
#                     started for, so a changed key finds its tracker
#   pm/live/<id>      a running session, with Claude Code's process id
#   pm/locks/<key>    the session that holds a tracker
#   pm/trackers/<key> the tracker, a git repository of its own, unless the
#                     owner's config points it at a companion clone
#
# A repository's key is the owner and name of its origin, or, with none,
# _path/ and the path of its main work tree with / written as %. Each log
# line carries it, so the logs are one file each and read by that column.
# bin/pap computes the same key (c_key) for the line pap claude writes.
#
# Everything here is POSIX sh; nothing prints unless it says so.
# SC2034: the variables a function sets are read by the scripts that source this.
# shellcheck shell=sh disable=SC2034

pm_tab="$(printf '\t')"

pm_now() { if [ -n "${PAP_PM_NOW:-}" ]; then printf '%s\n' "$PAP_PM_NOW"; else date -u +%Y-%m-%dT%H:%M:%SZ; fi; }
pm_state() { printf '%s/pap\n' "${XDG_STATE_HOME:-$HOME/.local/state}"; }
pm_dir() { printf '%s/pm\n' "$(pm_state)"; }
# pm_confdir: the directory of pap's machine config, as bin/pap's a_config.
pm_confdir() {
  if [ "$(uname -s 2>/dev/null)" = Darwin ] && [ -z "${XDG_CONFIG_HOME:-}" ]; then
    printf '%s/Library/Application Support/pap\n' "$HOME"
  else
    printf '%s/pap\n' "${XDG_CONFIG_HOME:-$HOME/.config}"
  fi
}
# pm_conf_get <key>: the last value of <key> in agent.conf, or nothing.
pm_conf_get() {
  [ -f "$(pm_confdir)/agent.conf" ] || return 0
  awk -v k="$1" 'index($0, k "=") == 1 { v = substr($0, length(k) + 2) } END { if (v != "") print v }' \
    "$(pm_confdir)/agent.conf"
}

# pm_log <file> <field>...: one tab-separated line appended to pm/<file>;
# tabs and newlines inside a field become spaces. Never fails its caller:
# pm_logged is false when the line could not be written.
pm_log() {
  l_f="$1"
  shift
  l_d="$(pm_dir)"
  pm_logged=true
  [ -d "$l_d" ] || { mkdir -p "$l_d" 2>/dev/null && chmod 700 "$(pm_state)" "$l_d" 2>/dev/null; } || {
    pm_logged=false
    return 0
  }
  l_line=""
  l_first=true
  for l_x in "$@"; do
    l_x="$(printf '%s' "$l_x" | tr '\t\n\r' '   ')"
    if [ "$l_first" = true ]; then l_line="$l_x"; l_first=false; else l_line="$l_line$pm_tab$l_x"; fi
  done
  { printf '%s\n' "$l_line" >> "$l_d/$l_f"; } 2>/dev/null || pm_logged=false
  return 0
}

# pm_repo <dir>: sets pm_top (the work tree's root) and pm_common (the git
# directory every work tree of the repository shares); 1 outside a work tree.
pm_repo() {
  pm_top="" pm_common=""
  r_out="$(git -C "$1" rev-parse --path-format=absolute --show-toplevel --git-common-dir 2>/dev/null)" || return 1
  pm_top="$(printf '%s\n' "$r_out" | sed -n 1p)"
  pm_common="$(printf '%s\n' "$r_out" | sed -n 2p)"
  [ -n "$pm_top" ] && [ -n "$pm_common" ]
}
pm_adopts() { [ -x "$1/scripts/guard-branch.sh" ]; }
# pm_is_pap <root>: pap itself, by its origin or, with none, by what it holds.
pm_is_pap() {
  p_u="$(git -C "$1" remote get-url origin 2>/dev/null | tr '[:upper:]' '[:lower:]')" || p_u=""
  case "$p_u" in
    *github.com[:/]blairforce1/pap | *github.com[:/]blairforce1/pap.git | *github.com[:/]blairforce1/pap/) return 0 ;;
    "") [ -f "$1/bin/pap" ] && [ -d "$1/plugins/pap" ] ;;
    *) return 1 ;;
  esac
}
# pm_slug <word>: what a change branch allows after change/.
pm_slug() {
  case "$1" in "" | [!A-Za-z0-9]* | *[!A-Za-z0-9._-]*) return 1 ;; esac
  return 0
}

# pm_key <dir in the repository>: prints the repository's key. Needs pm_repo
# to have run for it (pm_top, pm_common).
pm_key() {
  k_u="$(git -C "$1" remote get-url origin 2>/dev/null)" || k_u=""
  k_u="${k_u%/}"
  k_u="${k_u%.git}"
  k_name="${k_u##*/}"
  k_rest="${k_u%/*}"
  k_owner="${k_rest##*[/:]}"
  if [ -n "$k_u" ] && [ "$k_rest" != "$k_u" ] && pm_slug "$k_name" && pm_slug "$k_owner"; then
    printf '%s/%s\n' "$k_owner" "$k_name"
  else
    printf '_path/%s\n' "$(printf '%s' "${pm_common%/.git}" | tr '/' '%')"
  fi
}
# pm_keyfile <key>: the key as one file name.
pm_keyfile() { printf '%s\n' "$1" | tr '/' '%'; }

# pm_tracker <key> <common dir>: prints the tracker's directory, started or
# not. Sets pm_tracker_was to an earlier key when the tracker was started
# under one (an origin added or renamed since), and pm_companion to true
# when the owner's config points the tracker at a clone of their own.
pm_tracker() {
  pm_tracker_was="" pm_companion=false
  t_c="$(pm_conf_get "tracker.$1")"
  if [ -n "$t_c" ]; then pm_companion=true; printf '%s\n' "$t_c"; return 0; fi
  t_d="$(pm_dir)"
  if [ ! -d "$t_d/trackers/$1" ] && [ -f "$t_d/keys.tsv" ]; then
    t_old="$(awk -F '\t' -v c="$2" -v k="$1" '$2 == c && $1 != k { o = $1 } END { if (o != "") print o }' "$t_d/keys.tsv")"
    if [ -n "$t_old" ] && [ -d "$t_d/trackers/$t_old" ]; then
      pm_tracker_was="$t_old"
      printf '%s\n' "$t_d/trackers/$t_old"
      return 0
    fi
  fi
  printf '%s\n' "$t_d/trackers/$1"
}
# The call above runs in a command substitution, which loses what it sets;
# pm_tracker_note <key> <common dir> sets the two again in the caller's shell.
pm_tracker_note() {
  pm_tracker_was="" pm_companion=false
  [ -z "$(pm_conf_get "tracker.$1")" ] || { pm_companion=true; return 0; }
  t_d="$(pm_dir)"
  if [ ! -d "$t_d/trackers/$1" ] && [ -f "$t_d/keys.tsv" ]; then
    t_old="$(awk -F '\t' -v c="$2" -v k="$1" '$2 == c && $1 != k { o = $1 } END { if (o != "") print o }' "$t_d/keys.tsv")"
    if [ -n "$t_old" ] && [ -d "$t_d/trackers/$t_old" ]; then pm_tracker_was="$t_old"; fi
  fi
  return 0
}

# pm_resolve <absolute path>: prints where the path resolves, after . and ..
# and every symbolic link on the way, whether or not its last parts exist
# yet; 1 when it cannot be resolved (not absolute, a link pointing at
# nothing, a loop of links). No realpath: it is not POSIX.
pm_resolve() {
  r_rest="$1" r_cur="" r_hops=0
  case "$r_rest" in /*) ;; *) return 1 ;; esac
  while [ -n "$r_rest" ]; do
    r_rest="${r_rest#/}"
    case "$r_rest" in "") break ;; /*) continue ;; esac
    r_c="${r_rest%%/*}"
    case "$r_rest" in */*) r_rest="/${r_rest#*/}" ;; *) r_rest="" ;; esac
    case "$r_c" in
      .) continue ;;
      ..) r_cur="${r_cur%/*}"; continue ;;
    esac
    if [ -L "$r_cur/$r_c" ]; then
      r_hops=$((r_hops + 1))
      [ "$r_hops" -le 40 ] && [ -e "$r_cur/$r_c" ] || return 1
      r_t="$(readlink "$r_cur/$r_c")" || return 1
      case "$r_t" in
        /*) r_cur="" r_rest="$r_t$r_rest" ;;
        *) r_rest="/$r_t$r_rest" ;;
      esac
      continue
    fi
    r_cur="$r_cur/$r_c"
  done
  printf '%s\n' "${r_cur:-/}"
}
# pm_under <path> <dir>: the path is the directory or below it.
pm_under() {
  [ -n "$2" ] || return 1
  case "$1" in "$2" | "${2%/}"/*) return 0 ;; esac
  return 1
}
# pm_relok <path relative to a work tree's root>: one of the PM paths.
pm_relok() {
  case "$1" in
    product/?*) return 0 ;;
    changes/*/?*) o_s="${1#changes/}"; pm_slug "${o_s%%/*}" ;;
    features/*/*) return 1 ;;
    features/?*.feature) o_s="${1#features/}"; pm_slug "${o_s%.feature}" ;;
    *) return 1 ;;
  esac
}

# pm_session <dir>: the session's own repository, from the directory it was
# started in. Sets pm_own_top, pm_own_common, pm_own_key (empty when that is
# no adopting repository) and pm_trk, the tracker's directory as it resolves.
pm_session() {
  pm_own_top="" pm_own_common="" pm_own_key="" pm_trk=""
  pm_repo "$1" && pm_adopts "$pm_top" || return 0
  pm_own_top="$pm_top" pm_own_common="$pm_common"
  pm_own_key="$(pm_key "$pm_top")"
  s_t="$(pm_tracker "$pm_own_key" "$pm_own_common")"
  pm_trk="$(pm_resolve "$s_t" 2>/dev/null)" || pm_trk="$s_t"
}

# pm_judge <resolved path>: sets pm_verdict for a write by the PM session
# (pm_session has run):
#   ok        a PM path, the tracker, or a file in no adopting repository
#   route     in its own repository, outside the PM paths
#   other     in another adopting repository
#   otherpap  in another adopting repository, which is pap
#   guard     one of the guard's own files
# and pm_jrepo, the root of the repository the path is in, if any.
pm_judge() {
  pm_verdict=ok pm_jrepo=""
  if pm_under "$1" "$pm_trk"; then return 0; fi
  for j_d in "$(pm_state)" "$(pm_confdir)" "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins" "${CLAUDE_PLUGIN_ROOT:-}"; do
    [ -n "$j_d" ] || continue
    j_r="$(pm_resolve "$j_d" 2>/dev/null)" || j_r="$j_d"
    if pm_under "$1" "$j_r"; then pm_verdict=guard; return 0; fi
  done
  j_c="$(pm_resolve "${CLAUDE_CONFIG_DIR:-$HOME/.claude}" 2>/dev/null)" || j_c="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  case "$1" in
    "$j_c/settings.json" | "$j_c/settings.local.json" | */.claude/settings.json | */.claude/settings.local.json)
      pm_verdict=guard
      return 0 ;;
  esac
  j_d="$1"
  while [ ! -d "$j_d" ]; do
    j_d="${j_d%/*}"
    [ -n "$j_d" ] || j_d=/
  done
  pm_repo "$j_d" && pm_adopts "$pm_top" || return 0
  pm_jrepo="$pm_top"
  if [ -z "$pm_own_common" ] || [ "$pm_common" != "$pm_own_common" ]; then
    if pm_is_pap "$pm_top"; then pm_verdict=otherpap; else pm_verdict=other; fi
    return 0
  fi
  j_top="$(pm_resolve "$pm_top" 2>/dev/null)" || j_top="$pm_top"
  if pm_under "$1" "$j_top" && pm_relok "${1#"$j_top"/}"; then return 0; fi
  pm_verdict=route
}

# pm_commit_outside <dir>: for a git commit by the PM session in <dir>,
# prints each path of that work tree's changes (staged, unstaged, untracked
# and not ignored) that is outside the PM paths, one a line, relative to the
# work tree's root, which it leaves in pm_top. Nothing for a work tree that
# is not an adopting repository's. Run in the caller's shell, output to a
# file, so pm_top survives.
pm_commit_outside() {
  pm_repo "$1" && pm_adopts "$pm_top" || return 0
  c_own=true
  [ -n "$pm_own_common" ] && [ "$pm_common" = "$pm_own_common" ] || c_own=false
  c_skip=false
  git -C "$pm_top" status --porcelain=v1 -z --untracked-files=all 2>/dev/null | tr '\0' '\n' |
    while IFS= read -r c_l; do
      [ -n "$c_l" ] || continue
      # A rename or copy is followed by the path it came from, bare.
      if [ "$c_skip" = true ]; then
        c_skip=false
        [ "$c_own" = true ] && pm_relok "$c_l" || printf '%s\n' "$c_l"
        continue
      fi
      case "$c_l" in R* | C* | ?R* | ?C*) c_skip=true ;; esac
      c_p="${c_l#???}"
      [ "$c_own" = true ] && pm_relok "$c_p" || printf '%s\n' "$c_p"
    done
}
