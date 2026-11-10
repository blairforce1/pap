#!/bin/sh
# pap-pm.sh: the checks and the tracker writes of /pap:pm (decision 0025,
# changes/pm-mode/spec.md; decision 0018's tracker). The skill runs it in
# the main session, PM or solo; guard-route.sh refuses it from a sub-agent.
#
# Usage: pap-pm.sh start --session <id>
#        pap-pm.sh launch <slug> --session <id>
#        pap-pm.sh commit --session <id>
#        pap-pm.sh discard [--confirm] --session <id>
#
# Run in the adopting repository the tracker is for. The tracker is a git
# repository of its own under pap's state directory, or the directory the
# line tracker.<owner>/<name>=<path> in pap's machine config names, inside
# a clone of the owner's companion repository (pm-lib.sh has the layout):
#
#   events.tsv   append-only, one tab-separated line an event: UTC time,
#                event, slug or -, one line of text. Events: start, restate,
#                yes, launch, report, message, pause, resume, merge, decision
#   state.md     three headings: In flight, Waiting on the owner, Next. In
#                flight is rewritten here from the event log, never by hand:
#                a slug is in flight from its launch event until a report,
#                pause or merge event for it, or a decision event whose text
#                starts "abandoned"
#   briefs/<slug>.md
#                line 1 the route, line 2 the item of rule 20.2, and a
#                Budget: line; "Mechanical: yes" picks pap:cycle-mechanical
#
# One PM session holds a tracker at a time, by a lock every command takes;
# a lock whose session has ended is taken over, and that is said. Every
# commit is pushed when the tracker has a remote: never prompting, for at
# most 30 seconds; a failed push is said and the commit stands.
#
# start    Starts the tracker when it is absent. On an uncommitted tracker
#          it shows the change file by file and exits 4: the owner commits
#          (commit) or discards (discard, then discard --confirm). Otherwise
#          rewrites In flight and prints the state file. Launches nothing.
# launch   The checks before a cycle starts; the skill starts the cycle only
#          on exit 0. It refuses, changing nothing, with:
#            10  the owner did not type /pap:pm launch <slug> (rule 18.2);
#                pm-log.sh records the typed command, and one record serves
#                one launch
#            11  the event log has no restate event for the slug (rule 18.2)
#            12  the brief is missing or its first line names no route
#                (rule 18.8)
#            13  its second line names no item of rule 20.2
#            14  it has no budget (rule 18.7)
#            15  the slug is in flight
#            16  a line of the event log cannot be read
#            17  another session holds the tracker
#            18  the tracker could not be committed
#            19  the tracker is not started
#          Then it writes the yes and launch events, rewrites In flight and
#          commits, and prints the agent type and the brief's path.
# commit   Commits the tracker as it stands, and pushes.
# discard  Loses the tracker's uncommitted change: the first call changes
#          nothing and asks for the owner's second yes; --confirm, if the
#          change is still the one shown, restores the last commit.
#
# Exits 2 for a misuse: no repository, not an adopting one, a bad slug.

# SC2154: pm_top, pm_common and pm_companion are set by pm-lib.sh's functions.
# SC2015: each `a && b || die` here dies when either fails, on purpose.
# shellcheck disable=SC2154,SC2015

set -u
here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091 # pm-lib.sh, beside the hooks
. "$here/../../hooks/pm-lib.sh"

say() { printf '%s\n' "$@"; }
die() { # die <code> <line>...
  d_c="$1"
  shift
  for d_l in "$@"; do printf 'pap-pm: %s\n' "$d_l" >&2; done
  exit "$d_c"
}

cmd="${1:-}"
[ $# -eq 0 ] || shift
session="" slug="" confirm=false
while [ $# -gt 0 ]; do
  case "$1" in
    --session) [ $# -ge 2 ] || die 2 "--session needs a value"; session="$2"; shift 2 ;;
    --session=*) session="${1#--session=}"; shift ;;
    --confirm) confirm=true; shift ;;
    -*) die 2 "unknown option $1" ;;
    *) [ -z "$slug" ] || die 2 "one slug, not two"; slug="$1"; shift ;;
  esac
done
case "$cmd" in start | launch | commit | discard) ;; *) die 2 "usage: pap-pm.sh start|launch <slug>|commit|discard [--confirm] --session <id>" ;; esac
case "$session" in
  "") die 2 "no session id; /pap:pm passes it as --session" ;;
  *[!A-Za-z0-9_-]*) die 2 "the session id '$session' is not one Claude Code gives" ;;
esac

pm_repo . || die 2 "not in a git repository; run /pap:pm in the repository the tracker is for"
pm_adopts "$pm_top" || die 2 "$pm_top does not adopt PAP (no executable scripts/guard-branch.sh)"
common="$pm_common"
key="$(pm_key "$pm_top")"
trk="$(pm_tracker "$key" "$common")"
pm_tracker_note "$key" "$common"
pmd="$(pm_dir)"
mkdir -p "$pmd/locks" "$pmd/live" && chmod 700 "$(pm_state)" "$pmd" 2>/dev/null ||
  die 2 "cannot write pap's state directory, $pmd"
lockf="$pmd/locks/$(pm_keyfile "${pm_tracker_was:-$key}")"
events="$trk/events.tsv"
statef="$trk/state.md"

# --- The lock ---------------------------------------------------------------

alive() { # alive <session>: noted as running, and its Claude Code still is
  [ -f "$pmd/live/$1" ] || return 1
  a_p="$(cat "$pmd/live/$1" 2>/dev/null)"
  case "$a_p" in "" | *[!0-9]*) return 0 ;; esac
  kill -0 "$a_p" 2>/dev/null
}
take_lock() {
  [ -f "$pmd/live/$session" ] || : > "$pmd/live/$session"
  holder="$(cat "$lockf" 2>/dev/null)" || holder=""
  if [ -n "$holder" ] && [ "$holder" != "$session" ]; then
    if alive "$holder"; then
      die 17 "session $holder holds the tracker at $trk; this session writes nothing to it" \
        "one PM session writes a tracker at a time. If that session is gone, remove $lockf and run the command again."
    fi
    say "pap-pm: took over the tracker from session $holder, which has ended"
  fi
  printf '%s\n' "$session" > "$lockf"
}

# --- The tracker's git ------------------------------------------------------

tgit() { git -C "$trk" "$@"; }
dirty() { [ -n "$(tgit status --porcelain -- . 2>/dev/null)" ]; }
tcommit() { # tcommit <message>: commits everything in the tracker; 1 if git refuses
  tgit add -A -- . 2> "$pmd/commit.err" || return 1
  dirty || return 0
  if [ "$pm_companion" = true ]; then
    tgit commit -q -m "$1" -- . > "$pmd/commit.err" 2>&1
  elif [ -n "$(tgit config user.email 2>/dev/null)" ]; then
    tgit -c commit.gpgsign=false commit -q -m "$1" > "$pmd/commit.err" 2>&1
  else
    tgit -c commit.gpgsign=false -c user.name=pap-pm -c user.email=pap-pm@localhost commit -q -m "$1" > "$pmd/commit.err" 2>&1
  fi
}
limit30() {
  if command -v timeout >/dev/null 2>&1; then timeout 30 "$@"; return $?; fi
  "$@" &
  l_p=$!
  (sleep 30; kill "$l_p" 2>/dev/null) >/dev/null 2>&1 &
  l_w=$!
  wait "$l_p"
  l_rc=$?
  kill "$l_w" 2>/dev/null
  [ "$l_rc" -lt 128 ] || l_rc=124
  return "$l_rc"
}
tpush() { # after a commit: push where there is a remote; never fails its caller
  p_r="$(tgit remote 2>/dev/null | sed -n 1p)"
  [ -n "$p_r" ] || return 0
  if tgit rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
    p_out="$(GIT_TERMINAL_PROMPT=0 limit30 git -C "$trk" push -q 2>&1)"
  else
    p_out="$(GIT_TERMINAL_PROMPT=0 limit30 git -C "$trk" push -q -u "$p_r" HEAD 2>&1)"
  fi
  p_rc=$?
  [ "$p_rc" != 0 ] || return 0
  if [ "$p_rc" = 124 ]; then p_why="the push ran over 30 seconds"
  else p_why="$(printf '%s\n' "$p_out" | grep -v '^$' | tail -n 1)"; fi
  say "pap-pm: the tracker is committed but not pushed: ${p_why:-git push failed}" \
    "pap-pm: the next commit's push carries both."
}

# --- The event log and the state file ----------------------------------------

log_bad() { # prints the number of the first line that cannot be read
  [ -f "$events" ] || return 0
  awk -F '\t' '
    BEGIN { n = split("start restate yes launch report message pause resume merge decision", e, " "); for (i = 1; i <= n; i++) ok[e[i]] = 1 }
    NF != 4 || $1 !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z$/ ||
      !($2 in ok) || ($3 != "-" && $3 !~ /^[A-Za-z0-9][A-Za-z0-9._-]*$/) { print NR; exit }' "$events"
}
inflight() { # slug, launch time, launch text; one line a slug in flight
  awk -F '\t' '
    $2 == "launch" { f[$3] = $1 "\t" $4 }
    $2 == "report" || $2 == "pause" || $2 == "merge" { delete f[$3] }
    $2 == "decision" && $4 ~ /^abandoned/ { delete f[$3] }
    END { for (s in f) print s "\t" f[s] }' "$events" | sort
}
new_state() {
  say "# Tracker: $key" "" "## In flight" "" "- none" "" "## Waiting on the owner" "" "- nothing" "" "## Next" "" "- nothing"
}
rewrite_state() {
  [ -f "$statef" ] || new_state > "$statef"
  s_body="$(inflight | awk -F '\t' '{ print "- " $1 ": launched " $2 ", " $3 }')"
  [ -n "$s_body" ] || s_body="- none"
  BODY="$s_body" awk '
    /^## In flight[ \t]*$/ { print; print ""; print ENVIRON["BODY"]; print ""; skip = 1; found = 1; next }
    /^## / { skip = 0 }
    !skip { print }
    END { if (!found) { print ""; print "## In flight"; print ""; print ENVIRON["BODY"] } }' "$statef" > "$statef.new" &&
    mv "$statef.new" "$statef"
}
# change_id: the uncommitted change as one number, an untracked file's
# content included, so a discard confirms the change that was shown.
change_id() {
  {
    tgit status --porcelain --untracked-files=all -- .
    tgit diff HEAD -- . 2>/dev/null
    (cd "$trk" && git ls-files -z --others --exclude-standard -- . | xargs -0 cksum 2>/dev/null)
  } | cksum
}

# --- The commands ------------------------------------------------------------

case "$cmd" in
  start)
    take_lock
    [ -z "$pm_tracker_was" ] ||
      say "pap-pm: the tracker is under the repository's earlier key, $pm_tracker_was, at $trk; using it, and starting no second one"
    if [ ! -f "$events" ]; then
      if [ "$pm_companion" = true ]; then
        [ -d "$trk" ] && tgit rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
          die 2 "the config points the tracker at $trk, which is not a directory in a git clone"
      else
        mkdir -p "$trk" && { [ -d "$trk/.git" ] || git init -q -b main "$trk"; } || die 2 "cannot start a tracker at $trk"
        printf '%s\t%s\n' "$key" "$common" >> "$pmd/keys.tsv"
      fi
      new_state > "$statef"
      printf '%s\tstart\t-\ttracker started for %s\n' "$(pm_now)" "$key" > "$events"
      tcommit "tracker: start" || die 18 "the tracker could not be committed: $(tail -n 1 "$pmd/commit.err")"
      tpush
      say "pap-pm: tracker started at $trk, outside the repository" ""
      cat "$statef"
      exit 0
    fi
    if dirty; then
      say "pap-pm: the tracker at $trk has uncommitted changes, shown below file by file." \
        "pap-pm: likely cause: an event line appended and not committed, or a session that ended mid-event." ""
      tgit status --porcelain --untracked-files=all -- . | while IFS= read -r l; do
        f="${l#???}"
        say "--- $f (${l%"${l#??}"})"
        case "$l" in
          "??"*) sed -n '1,40p' "$trk/$f" 2>/dev/null | sed 's/^/+/' ;;
          *) tgit diff HEAD -- "$f" 2>/dev/null | sed -n '5,60p' ;;
        esac
      done
      say "" "pap-pm: ask the owner: commit it, or discard it? Do nothing else until the owner answers." \
        "pap-pm: commit: pap-pm.sh commit. Discard loses the change and takes a second yes: pap-pm.sh discard, then discard --confirm."
      exit 4
    fi
    bad="$(log_bad)"
    if [ -n "$bad" ]; then
      say "pap-pm: line $bad of $events cannot be read, so In flight was not rewritten; a launch is refused until it is fixed"
    else
      rewrite_state
      if dirty; then
        tcommit "tracker: rewrite in flight" || die 18 "the tracker could not be committed: $(tail -n 1 "$pmd/commit.err")"
        tpush
      fi
    fi
    say "pap-pm: tracker at $trk, committed. Launch and resume nothing until the owner says." ""
    cat "$statef"
    ;;

  commit)
    take_lock
    [ -f "$events" ] || die 19 "the tracker is not started; the owner types /pap:pm start"
    rm -f "$pmd/discard-$(pm_keyfile "$key")"
    if dirty; then
      last="$(tail -n 1 "$events" | cut -f 2,3 | tr '\t' ' ')"
      tcommit "tracker: ${last:-event}" || die 18 "the tracker could not be committed: $(tail -n 1 "$pmd/commit.err")"
      say "pap-pm: tracker committed"
    else
      say "pap-pm: nothing to commit"
    fi
    tpush
    ;;

  discard)
    take_lock
    [ -f "$events" ] || die 19 "the tracker is not started; the owner types /pap:pm start"
    mark="$pmd/discard-$(pm_keyfile "$key")"
    dirty || { rm -f "$mark"; say "pap-pm: the tracker is clean; nothing to discard"; exit 0; }
    if [ "$confirm" = false ]; then
      change_id > "$mark"
      say "pap-pm: nothing is discarded yet, and the tracker is unchanged." \
        "pap-pm: discarding loses the uncommitted change for good. Ask the owner to confirm a second time; only on that yes run: pap-pm.sh discard --confirm"
      exit 0
    fi
    [ -f "$mark" ] && [ "$(cat "$mark")" = "$(change_id)" ] || {
      rm -f "$mark"
      die 2 "no discard is waiting for this change (it was never asked, or the tracker changed since); nothing is discarded" \
        "show the change again with start, and ask the owner again."
    }
    tgit checkout -q HEAD -- . 2>/dev/null
    tgit clean -qfd -- . 2>/dev/null
    rm -f "$mark"
    dirty && die 18 "the tracker could not be restored to its last commit"
    say "pap-pm: the uncommitted change is discarded; the tracker is clean"
    ;;

  launch)
    pm_slug "$slug" || die 2 "launch needs a slug: letters, digits, . _ and -, starting with a letter or digit"
    take_lock
    [ -f "$events" ] || die 19 "the tracker is not started; the owner types /pap:pm start before the first launch"
    bad="$(log_bad)"
    [ -z "$bad" ] ||
      die 16 "line $bad of the event log, $events, cannot be read: $(sed -n "${bad}p" "$events" | cut -c1-120)" \
        "the format is four tab-separated fields: UTC time (2026-01-31T12:00:00Z), event, slug or -, one line of text; fix the line, commit, and the owner types the launch again."
    last="$(awk -F '\t' -v s="$slug" '$2 == "launch" && $3 == s { t = $1 } END { print t }' "$events")"
    [ -f "$pmd/launches.log" ] &&
      awk -F '\t' -v ses="$session" -v k="$key" -v s="$slug" -v t="$last" \
        '$2 == ses && $3 == k && $4 == s && ($1 "") > (t "") { f = 1 } END { exit !f }' "$pmd/launches.log" ||
      die 10 "the owner types the command: /pap:pm launch $slug (rule 18.2). That typed line is the owner's yes, and this launch has none" \
        "give the owner the command and stop; do not invoke it yourself."
    awk -F '\t' -v s="$slug" '$2 == "restate" && $3 == s { f = 1 } END { exit !f }' "$events" ||
      die 11 "the ask is restated first (rule 18.2): the event log has no restate event for \"$slug\"" \
        "restate the ask in one line, log the restate event, commit, and the owner types the launch again."
    brief="$trk/briefs/$slug.md"
    [ -f "$brief" ] || die 12 "there is no brief at $brief, so no first line naming its route (rule 18.8)"
    l1="$(sed -n 1p "$brief" | tr '\t' ' ')"
    l2="$(sed -n 2p "$brief" | tr '\t' ' ')"
    re="$(printf '%s' "$slug" | sed 's/\./\\./g')"
    printf '%s\n' "$l1" | grep -Eq "^/(pap:)?(intent|change) +$re +(feature|infra|security-sensitive|bugfix|spike|chore|docs)( |\$)" ||
      die 12 "the brief lacks a first line naming its route (rule 18.8): /intent $slug <class> or /change $slug <class> [Record: NNNN]"
    printf '%s\n' "$l2" | grep -Eq '^Rule 20\.2: (item [12]|exempt: .+)' ||
      die 13 "the brief lacks a second line naming the item of rule 20.2 that decided the route: \"Rule 20.2: item 1\", \"Rule 20.2: item 2\" or \"Rule 20.2: exempt: <which>\""
    grep -Ei '^Budget:.*[0-9]' "$brief" | grep -Eiq 'token|minute|hour|min|wall' ||
      die 14 "the brief lacks a budget in tokens or wall time (rule 18.7): a line \"Budget: <n> tokens\" or \"Budget: <n> minutes\""
    ! inflight | awk -F '\t' -v s="$slug" '$1 == s { f = 1 } END { exit !f }' ||
      die 15 "\"$slug\" is in flight: launched, with no later report, pause, merge or abandoned decision" \
        "a dead cycle is cleared on the owner's word, by a decision event whose text starts \"abandoned\"."
    agent=pap:cycle
    ! grep -Eq '^Mechanical: *yes' "$brief" || agent=pap:cycle-mechanical
    cp "$events" "$pmd/events.bak" && { [ ! -f "$statef" ] || cp "$statef" "$pmd/state.bak"; } ||
      die 18 "the tracker could not be committed: no room to keep its last state"
    now="$(pm_now)"
    printf '%s\tyes\t%s\tthe owner typed /pap:pm launch %s\n' "$now" "$slug" "$slug" >> "$events"
    printf '%s\tlaunch\t%s\t%s; %s; %s\n' "$now" "$slug" "$l1" "$l2" "$agent" >> "$events"
    rewrite_state
    if ! tcommit "tracker: launch $slug"; then
      cp "$pmd/events.bak" "$events"
      if [ -f "$pmd/state.bak" ]; then cp "$pmd/state.bak" "$statef"; else rm -f "$statef"; fi
      rm -f "$pmd/events.bak" "$pmd/state.bak"
      # tcommit staged the two events; the index goes back with the files.
      tgit reset -q -- . 2>/dev/null
      die 18 "the tracker could not be committed, so no cycle starts: $(tail -n 1 "$pmd/commit.err")" \
        "the yes and launch events were taken back out."
    fi
    rm -f "$pmd/events.bak" "$pmd/state.bak"
    tpush
    say "pap-pm: launch ok: the yes and launch events are logged and the tracker is committed" \
      "agent: $agent" "brief: $brief"
    ;;
esac
exit 0
