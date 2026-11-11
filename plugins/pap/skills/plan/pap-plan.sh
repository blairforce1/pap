#!/bin/sh
# pap-plan.sh: the checks and the commits of /pap:plan (decision 0026,
# changes/plan-step/spec.md). The skill runs it in the main session, in the
# work tree of change/<slug>; /change runs its status command. What a
# session or a sub-agent does (drafting, reviewing, asking) is the skill's;
# what can be read from files and git, and every commit, is here.
#
# Usage: pap-plan.sh state <slug>
#        pap-plan.sh status <slug>
#        pap-plan.sh check <slug> [--file <path>] [--reviewed]
#        pap-plan.sh keep <slug> [--what <text>]
#        pap-plan.sh accept <slug> --by <login> --what <text>
#        pap-plan.sh amend <slug> --what <text> [--rework <text>]
#        pap-plan.sh drop <slug>
#
# The plan is changes/<slug>/plan.md; its register is
# changes/<slug>/reviews/plan-review.md. "Committed" is the work tree's
# HEAD, which is the tip of change/<slug>; plan-lib.sh has the reading of
# accepted, code and started unplanned that the launch shares.
#
# A plan's words are `wc -w` over the file, less the values of the three
# header lines the main session fills (accepted-by, accepted-on,
# reviewed-by): for a draft as the planner returned it that is `wc -w`
# over the file. At most 1000.
#
# The register's first lines are `planner:`, `plan-reviewer:` and `told:`.
# A finding is one line of five fields split by " | ":
#   - <id> | <viewpoint> | <severity> | <finding> | disposition: <value>
# A viewpoint with none is `- <viewpoint> | no findings`. A finding that
# is the spec's fault starts "return: spec". The value is empty while the
# finding waits; else `fixed: <section>` (the planner's), `accepted`,
# `rejected: <reason>` or `deferred: build|code review|findings`.
#
# state    What /pap:plan does next. Exit 0 with a first line
#          `state: absent|draft|redraft|spec-changed|accepted|unreadable`,
#          then `class:`, `code: yes|no` and `words:`. It stops with:
#            10  no accepted spec: /spec comes first
#            11  the change needs no plan, with the reason and what is next
#            12  plan files in the work tree are not committed: the owner
#                chooses, resume or start again; nothing is overwritten
# status   For /change. One line: `accepted`, `none`, or `draft: <why>`.
# check    The shape of a plan draft and its length, of --file or of the
#          work tree's plan. Prints `words: <n>`.
#            13  the header or a section is missing, or a draft carries
#                acceptance: the planner failed
#            14  over 1000 words
#          --reviewed also asks for reviewed-by filled.
# keep     Commits the draft and its register with no acceptance, as
#          `plan(<slug>): draft, <what>`: for "later", for a draft still
#          over 1000 words, and for an accepted return to the spec.
# accept   The owner's yes. Refuses unless the draft passes check
#          --reviewed, the spec is accepted and every finding has a
#          disposition:
#            15  no register, one that cannot be read, or a finding waits
#            16  a `return: spec` finding was accepted: no yes; keep, then
#                /spec
#          Then fills accepted-by and accepted-on and commits the plan and
#          its register in one commit, `plan(<slug>): <what>`. Pushes
#          nothing.
# amend    An edit to an accepted plan, on the owner's yes: keeps the
#          acceptance, notes the edit under the header, and commits. Once
#          the branch carries code it needs --rework, what the code
#          surfaced, and the message is `plan(<slug>): rework, <that>`.
# drop     The owner's no: puts the two files back as committed, or removes
#          them where none was. Commits nothing.
#
# Exits 2 for a misuse, 17 for a command the plan's state does not allow,
# 18 when git refuses the commit (a hook is never bypassed, rule 5.1).

# SC2015: each `a && b || die` here dies when either fails, on purpose.
# SC2034, SC2154: pl_dir, pl_ref and pl_slug are read, and pl_state is set,
# by plan-lib.sh's functions.
# shellcheck disable=SC2015,SC2034,SC2154

set -u
here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091 # plan-lib.sh, beside this script
. "$here/plan-lib.sh"

say() { printf '%s\n' "$@"; }
die() { # die <code> <line>...
  d_c="$1"
  shift
  for d_l in "$@"; do printf 'pap-plan: %s\n' "$d_l" >&2; done
  exit "$d_c"
}

cmd="${1:-}"
[ $# -eq 0 ] || shift
slug="" file="" by="" what="" rework="" reviewed=false
while [ $# -gt 0 ]; do
  case "$1" in
    --file | --by | --what | --rework)
      [ $# -ge 2 ] || die 2 "$1 needs a value"
      case "$1" in --file) file="$2" ;; --by) by="$2" ;; --what) what="$2" ;; --rework) rework="$2" ;; esac
      shift 2 ;;
    --reviewed) reviewed=true; shift ;;
    -*) die 2 "unknown option $1" ;;
    *) [ -z "$slug" ] || die 2 "one slug, not two"; slug="$1"; shift ;;
  esac
done
case "$cmd" in state | status | check | keep | accept | amend | drop) ;; *) die 2 "usage: pap-plan.sh state|status|check|keep|accept|amend|drop <slug>" ;; esac
case "$slug" in "" | [!A-Za-z0-9]* | *[!A-Za-z0-9._-]*) die 2 "$cmd needs a slug: letters, digits, . _ and -, starting with a letter or digit" ;; esac
what="$(printf '%s' "$what" | tr '\n\r\t' '   ')"
rework="$(printf '%s' "$rework" | tr '\n\r\t' '   ')"

# --- The shape and the length of a plan ---------------------------------------

# shape <file> draft|reviewed|accepted: prints one line a fault; fails on any.
shape() {
  awk -v mode="$2" '
    BEGIN {
      n = split("id class spec accepted-by accepted-on generated-by reviewed-by skills prompt", K, " ")
      m = split("Increments Design Fit Tests Observation", S, " ")
    }
    /^```/ && !hdone { if (open) { open = 0; hdone = 1 } else open = 1; next }
    open {
      i = index($0, ":")
      if (i) { v = substr($0, i + 1); gsub(/^[ \t]+|[ \t]+$/, "", v); val[substr($0, 1, i - 1)] = v; has[substr($0, 1, i - 1)] = 1 }
      next
    }
    hdone && /^## / {
      name = substr($0, 4); sub(/[ \t]+$/, "", name); cur = ""
      for (j = 1; j <= m; j++) if (S[j] == name) { order = order " " name; cur = name }
      next
    }
    hdone && cur != "" && NF { body[cur] = 1 }
    function fault(t) { print t; bad = 1 }
    END {
      if (!hdone) fault("the header is missing: no fenced block that opens and closes")
      else {
        for (j = 1; j <= n; j++) if (!(K[j] in has)) fault("the header lacks the line " K[j] ":")
        split("id class spec generated-by skills prompt", F, " ")
        for (j in F) if ((F[j] in has) && val[F[j]] == "") fault("the header line " F[j] ": is empty")
        if (mode != "draft" && ("reviewed-by" in has) && val["reviewed-by"] == "") fault("the header line reviewed-by: is empty: the plan has not been reviewed")
        acc = (val["accepted-by"] != "" || val["accepted-on"] != "")
        if (mode != "accepted" && acc) fault("a plan draft carries no acceptance: accepted-by: and accepted-on: are filled only by the yes")
        if (mode == "accepted" && (val["accepted-by"] == "" || val["accepted-on"] == "")) fault("the acceptance is not kept: accepted-by: and accepted-on: stay as the yes filled them")
      }
      if (order != " Increments Design Fit Tests Observation") fault("the sections are Increments, Design, Fit, Tests and Observation, in that order; found:" (order == "" ? " none" : order))
      for (j = 1; j <= m; j++) if (index(order " ", " " S[j] " ") && !body[S[j]]) fault("the section " S[j] " is empty: content, or \"none\"")
      exit bad
    }' "$1"
}

words() {
  awk '
    /^```/ && !d { if (o) d = 1; o = !o; print; next }
    o && /^(accepted-by|accepted-on|reviewed-by):/ { sub(/:.*/, ":") }
    { print }' "$1" | wc -w | tr -d ' '
}

# fill <file> <key> <value>: writes the header line, aligned as the templates are.
fill() {
  awk -v k="$2" -v v="$3" '
    /^```/ && !d { if (o) d = 1; o = !o; print; next }
    o && index($0, k ":") == 1 { printf "%-20s%s\n", k ":", v; next }
    { print }' "$1" > "$1.new" && mv "$1.new" "$1"
}

# --- The register ---------------------------------------------------------------

# findings <file>: one line a fault: "waiting <id>", "return <id>" (a return
# to the spec the owner accepted) or "unreadable <what>".
findings() {
  awk -F ' [|] ' '
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    /^planner:[ \t]*[^ \t]/ { p = 1 }
    /^plan-reviewer:[ \t]*[^ \t]/ { r = 1 }
    /^told:[ \t]*[^ \t]/ { t = 1 }
    /^- / {
      seen = 1
      if (NF == 2 && trim($2) == "no findings") next
      id = trim(substr($1, 3)); d = trim($NF)
      if (NF < 5 || index(d, "disposition:") != 1) { print "unreadable the line of " id ": five fields split by \" | \", the last starting \"disposition:\""; next }
      d = trim(substr(d, 13)); ret = (index(trim($4), "return: spec") == 1)
      if (d == "") print "waiting " id
      else if (ret && d == "accepted") print "return " id
      else if (ret && d !~ /^rejected: ./) print "unreadable the disposition of " id ": a return to the spec is accepted, or rejected with a reason"
      else if (!ret && d !~ /^(fixed: .+|accepted|rejected: .+|deferred: (build|code review|findings))$/) print "unreadable the disposition of " id ": fixed: <section>, accepted, rejected: <reason>, or deferred: build, code review or findings"
    }
    END {
      if (!p) print "unreadable the first lines: no planner: line with its tokens and minutes"
      if (!r) print "unreadable the first lines: no plan-reviewer: line with its tokens and minutes"
      if (!t) print "unreadable the first lines: no told: line with the time the owner was told"
      if (!seen) print "unreadable the findings: one line a finding, or a viewpoint with \"no findings\""
    }' "$1"
}

# register_ok: dies 15 or 16 unless every finding has a disposition.
register_ok() {
  [ -f "$reg" ] || die 15 "there is no plan review register at $dir/reviews/plan-review.md: the plan has not been reviewed, so there is no yes to take" \
    "run /pap:plan $slug, which runs the plan review."
  r_f="$(findings "$reg")"
  r_x="$(printf '%s\n' "$r_f" | sed -n 's/^unreadable //p')"
  [ -z "$r_x" ] || die 15 "the plan review register cannot be read, so there is no yes to take:" "$r_x"
  r_x="$(printf '%s\n' "$r_f" | sed -n 's/^waiting //p' | tr '\n' ' ')"
  [ -z "$r_x" ] || die 15 "the plan is not accepted: these findings wait for a disposition: $r_x" \
    "ask the owner for each: accepted, rejected with a reason, or deferred to build, code review or findings."
  r_x="$(printf '%s\n' "$r_f" | sed -n 's/^return //p' | tr '\n' ' ')"
  [ -z "$r_x" ] || die 16 "the owner accepted a return to the spec ($r_x), so the plan is not put to a yes" \
    "run: pap-plan.sh keep $slug --what \"return to spec\"; then the owner runs /spec $slug, then /pap:plan $slug."
}

# --- The work tree ----------------------------------------------------------------

top="$(git rev-parse --show-toplevel 2>/dev/null)" || die 2 "not in a git repository; run it in the work tree of change/$slug"
[ "$(git -C "$top" symbolic-ref -q --short HEAD 2>/dev/null)" = "change/$slug" ] ||
  die 2 "$top is not on change/$slug; run it in that branch's work tree (worktree.sh $slug prints it)"
pl_dir="$top" pl_ref=HEAD pl_slug="$slug"
dir="changes/$slug"
plan="$top/$dir/plan.md"
reg="$top/$dir/reviews/plan-review.md"
tgit() { git -C "$top" "$@"; }
today() { if [ -n "${PAP_PM_NOW:-}" ]; then printf '%s\n' "${PAP_PM_NOW%%T*}"; else date +%Y-%m-%d; fi; }
uncommitted() { tgit status --porcelain --untracked-files=all -- "$dir/plan.md" "$dir/reviews/plan-review.md" 2>/dev/null; }

# commit <message>: the plan and its register in one commit, and nothing
# else of the work tree. Fails with 1 when there is nothing to commit.
commit() {
  c_m="$1"
  set -- "$dir/plan.md"
  if [ -f "$reg" ] || tgit cat-file -e "HEAD:$dir/reviews/plan-review.md" 2>/dev/null; then set -- "$@" "$dir/reviews/plan-review.md"; fi
  tgit add -- "$@" 2>/dev/null
  [ -n "$(tgit status --porcelain -- "$@")" ] || return 1
  c_e="$(tgit commit -q -m "$c_m" -- "$@" 2>&1)" || {
    tgit reset -q -- "$@" 2>/dev/null
    undo
    die 18 "git refused the commit, so nothing is committed: $(printf '%s\n' "$c_e" | grep -v '^$' | tail -n 1)" \
      "a hook is fixed or handed to the owner, never bypassed (rule 5.1). If it is a formatter's, format the two files and run the command again."
  }
}
undo() { :; }

spec_accepted() { pl_show spec.md | plan_filled; }

case "$cmd" in
  state)
    intent="$(pl_show intent.md)" && printf '%s\n' "$intent" | plan_filled ||
      die 11 "\"$slug\" needs no plan: its change branch carries no accepted intent" \
        "it is exempt under rule 20.2, or /intent $slug <class> comes first."
    class="$(printf '%s\n' "$intent" | plan_hdr class)" || class=""
    case "$class" in
      feature | infra | security-sensitive) ;;
      bugfix | chore | docs)
        die 11 "\"$slug\" needs no plan: its class is $class" \
          "the build is launched with /pap:pm launch $slug, or /change $slug $class when solo." ;;
      spike) die 11 "\"$slug\" needs no plan: its class is spike" "a spike has no spec and no plan." ;;
      *) die 2 "the intent of \"$slug\" names no class of the seven, so whether it needs a plan cannot be said" ;;
    esac
    plan_state
    code=no
    ! plan_code || code=yes
    [ "$pl_state" != absent ] || [ "$code" = no ] ||
      die 11 "\"$slug\" needs no plan: it started unplanned (its change branch carries code and no plan)" \
        "the build goes on without a plan."
    if ! spec_accepted; then
      s_is="a draft"
      tgit cat-file -e "HEAD:$dir/spec.md" 2>/dev/null || s_is="absent"
      die 10 "/spec $slug comes first: the spec of \"$slug\" is $s_is, and a plan is drafted only from an accepted spec" \
        "no planner starts and nothing is written."
    fi
    left="$(uncommitted)"
    if [ -n "$left" ]; then
      say "pap-plan: plan files of \"$slug\" are in the work tree and not committed, left by a session that ended:"
      printf '%s\n' "$left" | while IFS= read -r l; do
        f="${l#???}"
        say "pap-plan:   $f ($(wc -w < "$top/$f" 2>/dev/null | tr -d ' ') words)"
      done
      say "pap-plan: show them to the owner and ask: resume it, or start again? Overwrite nothing until the owner answers." \
        "pap-plan: resume: go on from these files. Start again: pap-plan.sh drop $slug, then /pap:plan $slug."
      exit 12
    fi
    state="$pl_state"
    if [ "$state" = draft ]; then
      last="$(tgit log -n 1 --format=%H HEAD -- "$dir/plan.md")"
      [ -z "$(tgit rev-list -n 1 "$last..HEAD" -- "$dir/spec.md")" ] || state=redraft
    fi
    say "state: $state" "class: $class" "code: $code"
    ! tgit cat-file -e "HEAD:$dir/plan.md" 2>/dev/null || [ ! -f "$plan" ] || say "words: $(words "$plan")"
    case "$state" in
      absent) say "pap-plan: no plan yet: start one planner in the background." ;;
      draft) say "pap-plan: a plan draft is committed and its spec has not changed since: show it and its register, with the dispositions already given, and ask for the yes." ;;
      redraft) say "pap-plan: a plan draft is committed and the spec has a later commit: a planner redrafts against the spec as it is now, and the plan review runs again." ;;
      spec-changed) say "pap-plan: the plan was accepted and the spec has a later commit, so the plan is a draft again: a planner redrafts, the plan review runs again, and the owner says yes a second time." ;;
      unreadable) say "pap-plan: the committed plan's header cannot be read: show it to the owner; a planner redrafts on their word." ;;
      accepted) say "pap-plan: the plan is accepted. An edit is shown to the owner and committed only on their yes: pap-plan.sh amend." ;;
    esac
    ;;

  status)
    plan_state
    case "$pl_state" in
      accepted) say "accepted" ;;
      absent) say "none" ;;
      draft) say "draft: the owner has not accepted it" ;;
      spec-changed) say "draft: the spec changed after the plan's yes" ;;
      *) say "draft: the plan's header cannot be read" ;;
    esac
    ;;

  check)
    f="${file:-$plan}"
    [ -f "$f" ] || die 13 "there is no plan at $f: the planner returned no report, and has failed"
    mode=draft
    [ "$reviewed" = false ] || mode=reviewed
    faults="$(shape "$f" "$mode")" || {
      printf '%s\n' "$faults" | while IFS= read -r l; do printf 'pap-plan: %s\n' "$l" >&2; done
      die 13 "the report is not a plan draft, so the planner has failed: write nothing, tell the owner why, and stop. /pap:plan $slug starts it again."
    }
    w="$(words "$f")"
    say "words: $w"
    [ "$w" -le 1000 ] || die 14 "the plan draft is $w words, over 1000" \
      "a first draft goes back to the planner once to shorten; one still over, or a revised or edited draft that is over, is kept (pap-plan.sh keep $slug) and not put to the owner."
    ;;

  keep)
    [ -f "$plan" ] || die 17 "there is no plan draft at $dir/plan.md to keep"
    faults="$(shape "$plan" draft)" || die 13 "the plan draft is not kept as it is:" "$faults"
    w="$(words "$plan")"
    if commit "plan($slug): draft, ${what:-not accepted}"; then
      say "pap-plan: the plan draft of \"$slug\" ($w words) is committed with no acceptance: $(tgit log -n 1 --format='%h %s')"
    else
      say "pap-plan: the plan draft of \"$slug\" ($w words) is already committed, with no acceptance"
    fi
    say "pap-plan: nothing was pushed. /pap:plan $slug resumes it."
    [ "$w" -le 1000 ] ||
      say "pap-plan: the plan draft is $w words, over 1000, so it is not put to the owner for a yes." \
        "pap-plan: tell the owner the count, and to run /pap:plan $slug again or narrow the spec with /spec $slug."
    ;;

  accept)
    case "$by" in "") die 2 "accept needs --by <login>: who said yes" ;; esac
    by="@${by#@}"
    case "${by#@}" in "" | *[!A-Za-z0-9-]*) die 2 "--by takes a GitHub login" ;; esac
    [ -n "$what" ] || die 2 "accept needs --what <text>: what the plan builds, for the commit message"
    plan_state
    [ "$pl_state" != accepted ] || die 17 "the plan of \"$slug\" is already accepted; an edit to it is committed with amend"
    [ -f "$plan" ] || die 17 "there is no plan draft at $dir/plan.md to accept"
    spec_accepted || die 10 "/spec $slug comes first: a plan is accepted only against an accepted spec"
    faults="$(shape "$plan" reviewed)" || die 13 "the plan draft cannot be accepted as it is:" "$faults"
    w="$(words "$plan")"
    [ "$w" -le 1000 ] || die 14 "the plan is $w words, over 1000, and is not accepted" \
      "shorten it and ask for the yes again, or keep it: pap-plan.sh keep $slug."
    register_ok
    code=no
    ! plan_code || code=yes
    cp "$plan" "$plan.was" || die 18 "cannot write beside $plan"
    undo() { mv "$plan.was" "$plan"; }
    on="$(today)"
    fill "$plan" accepted-by "$by" && fill "$plan" accepted-on "$on" || { undo; die 18 "cannot write $plan"; }
    msg="plan($slug): $what"
    [ "$code" = no ] || msg="plan($slug): rework, $what"
    commit "$msg" || { undo; die 18 "nothing to commit"; }
    rm -f "$plan.was"
    class="$(pl_show intent.md | plan_hdr class)" || class="<class>"
    say "pap-plan: the plan of \"$slug\" is accepted by $by on $on, and committed with its register in one commit: $(tgit log -n 1 --format='%h %s')" \
      "pap-plan: nothing was pushed and no pull request is open: the build's /change opens the one draft pull request." \
      "pap-plan: a launch from another clone needs change/$slug there first: push the branch, or fetch it there." \
      "pap-plan: the build is launched by the owner typing /pap:pm launch $slug in a PM session, or /change $slug $class in a solo session."
    [ "$code" = no ] || say "pap-plan: the branch already carries code, so this yes is plan rework (process 5.2)."
    ;;

  amend)
    plan_state
    [ "$pl_state" = accepted ] || die 17 "the plan of \"$slug\" is not accepted, so there is no accepted plan to edit; /pap:plan $slug takes it to a yes"
    [ -f "$plan" ] && ! tgit diff --quiet HEAD -- "$dir/plan.md" || die 17 "the plan in the work tree is the committed one: there is no edit to commit"
    faults="$(shape "$plan" accepted)" || die 13 "the edited plan cannot be committed as it is:" "$faults"
    for k in accepted-by accepted-on; do
      [ "$(plan_hdr "$k" < "$plan")" = "$(pl_show plan.md | plan_hdr "$k")" ] ||
        die 17 "the edit changes $k:; the acceptance is kept as the yes recorded it"
    done
    [ ! -f "$reg" ] || register_ok
    if plan_code; then
      [ -n "$rework" ] || die 17 "the change branch carries code, so this commit is plan rework: say what the code surfaced with --rework <text>"
      note="$rework" msg="plan($slug): rework, $rework"
    else
      [ -n "$what" ] || die 2 "amend needs --what <text>: what the edit changes"
      note="$what" msg="plan($slug): $what"
    fi
    cp "$plan" "$plan.was" || die 18 "cannot write beside $plan"
    undo() { mv "$plan.was" "$plan"; }
    NOTE="Edited $(today) after the yes: $note" awk '
      { print }
      /^```/ && !d { if (o) { d = 1; print ""; print ENVIRON["NOTE"] } o = !o }' "$plan.was" > "$plan" || { undo; die 18 "cannot write $plan"; }
    w="$(words "$plan")"
    [ "$w" -le 1000 ] || { undo; die 14 "the edited plan is $w words with its note, over 1000, and is not committed"; }
    commit "$msg" || { undo; die 18 "nothing to commit"; }
    rm -f "$plan.was"
    say "pap-plan: the edit to the accepted plan of \"$slug\" is committed, the acceptance kept and the edit noted in the plan: $(tgit log -n 1 --format='%h %s')" \
      "pap-plan: nothing was pushed."
    ;;

  drop)
    was=no
    for f in "$dir/plan.md" "$dir/reviews/plan-review.md"; do
      if tgit cat-file -e "HEAD:$f" 2>/dev/null; then
        [ "$f" != "$dir/plan.md" ] || was=yes
        tgit checkout -q HEAD -- "$f" 2>/dev/null || die 18 "cannot put $f back as committed"
      else
        tgit rm -q --cached --ignore-unmatch -- "$f" >/dev/null 2>&1
        rm -f "$top/$f"
      fi
    done
    rmdir "$top/$dir/reviews" 2>/dev/null || true
    if [ "$was" = yes ]; then
      say "pap-plan: the new draft and its review are lost; the work tree holds the plan as it was committed."
    else
      say "pap-plan: the draft and the review are lost; the work tree holds no plan and no register."
    fi
    say "pap-plan: nothing is committed, and the change branch is as it was."
    ;;
esac
exit 0
