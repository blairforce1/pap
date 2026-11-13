#!/bin/sh
# plan-lib.sh: what a plan is, read from a change branch (decision 0026,
# changes/plan-step/spec.md). Sourced by pap-plan.sh, for /pap:plan and
# /change, and by ../pm/pap-pm.sh, for the launch: one reading of
# "accepted", "code" and "started unplanned", shared by both.
#
# The caller sets three variables first:
#   pl_dir   a directory in the repository or one of its work trees
#   pl_ref   the commit read: refs/heads/change/<slug>, or HEAD in the
#            change's own work tree
#   pl_slug  the change's slug
#
# Everything is read from that commit. The work tree is never read and
# nothing is fetched.
#
#   plan_hdr <key>   On stdin an intent, a spec or a plan: prints the key's
#                    value from the file's first fenced block. Fails when the
#                    block does not open and close or lacks the key.
#   plan_filled      On stdin the same: succeeds when accepted-by: and
#                    accepted-on: are both filled.
#   pl_show <file>   Prints changes/<slug>/<file> as committed.
#   plan_code        Succeeds when the change branch carries code: a commit
#                    of its own (not on main or origin/main, and not a
#                    merge) that changes a path outside changes/, features/
#                    and product/ (rule 21.1's line).
#   plan_state       Sets pl_state, and pl_acc for an accepted plan:
#                      nobranch      the commit cannot be read
#                      absent        it has no changes/<slug>/plan.md
#                      unreadable    the plan's header cannot be read
#                      draft         the acceptance is missing or half filled
#                      spec-changed  accepted, and spec.md has a commit later
#                                    than the one that accepted the plan
#                      accepted      accepted, and the spec is as it was
#                    pl_acc is the commit that accepted the plan: the oldest
#                    of the latest run of plan.md commits that carry the
#                    acceptance, so an edit after the yes does not move it.
#                    The run stops at a second yes (plan_reaccept).

# SC2154: pl_dir, pl_ref and pl_slug are the caller's. SC2034: pl_state and
# pl_acc are read by the caller.
# shellcheck disable=SC2154,SC2034

pl_git() { git -C "$pl_dir" "$@"; }
pl_show() { pl_git show "$pl_ref:changes/$pl_slug/$1" 2>/dev/null; }

plan_hdr() {
  awk -v k="$1" '
    /^```/ { if (open) { closed = 1; exit } open = 1; next }
    open {
      i = index($0, ":")
      if (i && substr($0, 1, i - 1) == k) { v = substr($0, i + 1); gsub(/^[ \t]+|[ \t]+$/, "", v); print v; found = 1 }
    }
    END { exit !(closed && found) }'
}

plan_filled() {
  pf_in="$(cat)"
  pf_by="$(printf '%s\n' "$pf_in" | plan_hdr accepted-by)" || return 1
  pf_on="$(printf '%s\n' "$pf_in" | plan_hdr accepted-on)" || return 1
  [ -n "$pf_by" ] && [ -n "$pf_on" ]
}

plan_code() {
  pc_not=""
  for pc_r in refs/heads/main refs/remotes/origin/main; do
    ! pl_git rev-parse -q --verify "$pc_r" >/dev/null 2>&1 || pc_not="$pc_not ^$pc_r"
  done
  # shellcheck disable=SC2086 # pc_not is a list of ^<ref>, split on purpose
  [ -n "$(pl_git log --no-merges --format= --name-only "$pl_ref" $pc_not -- \
    ':(top)' ':(top,exclude)changes' ':(top,exclude)features' ':(top,exclude)product' 2>/dev/null | sed -n '/./{p;q;}')" ]
}

# plan_reaccept <older> <newer>: true when <newer>, a plan commit that keeps
# an acceptance <older> already had, is a fresh yes and not an amend. An
# amend is refused once the spec has changed since the yes, and a yes after
# a redraft commits the register the second review wrote. So a spec commit
# between the two, and the register in <newer>, make it a second accept.
plan_reaccept() {
  [ -n "$(pl_git rev-list -n 1 "$2^" "^$1" -- ":(top)changes/$pl_slug/spec.md" 2>/dev/null)" ] &&
    [ -n "$(pl_git diff-tree --no-commit-id --name-only -r "$2" -- ":(top)changes/$pl_slug/reviews/plan-review.md" 2>/dev/null)" ]
}

plan_state() {
  pl_state=nobranch pl_acc=""
  pl_git rev-parse -q --verify "$pl_ref^{commit}" >/dev/null 2>&1 || return 0
  pl_state=absent
  pl_git cat-file -e "$pl_ref:changes/$pl_slug/plan.md" 2>/dev/null || return 0
  pl_state=unreadable
  ps_body="$(pl_show plan.md)" || return 0
  printf '%s\n' "$ps_body" | plan_hdr id >/dev/null || return 0
  pl_state=draft
  printf '%s\n' "$ps_body" | plan_filled || return 0
  for ps_c in $(pl_git log --format=%H "$pl_ref" -- ":(top)changes/$pl_slug/plan.md" 2>/dev/null); do
    pl_git show "$ps_c:changes/$pl_slug/plan.md" 2>/dev/null | plan_filled || break
    [ -z "$pl_acc" ] || ! plan_reaccept "$ps_c" "$pl_acc" || break
    pl_acc="$ps_c"
  done
  pl_state=unreadable
  [ -n "$pl_acc" ] || return 0
  pl_state=accepted
  [ -z "$(pl_git rev-list -n 1 "$pl_acc..$pl_ref" -- ":(top)changes/$pl_slug/spec.md" 2>/dev/null)" ] || pl_state=spec-changed
}
