---
name: accept
description: "Accept proposed decision records on the Project Lead's word. Only a person invokes it: /pap:accept <NNNN> [NNNN ...]. The skill's script checks each record is on main and proposed, sets its Status to accepted with the login and date, and opens a draft docs pull request; the model only relays the result and never accepts a record itself."
argument-hint: "<NNNN> [NNNN ...]"
disable-model-invocation: true
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/accept.sh *)
---

# Accept

The Project Lead accepts one or more proposed decision records. The script ran when this skill was invoked, in the current repository, with the ids typed after `/pap:accept`: it checked that each record exists on main and is `proposed`, showed what is accepted, set each Status line to `accepted (<login>, <date>)` and nothing else, committed on a new `change/accept-<ids>` branch, pushed it and opened a draft pull request. Its output:

!`${CLAUDE_SKILL_DIR}/accept.sh "$ARGUMENTS"`

Relay the output above to the Project Lead word for word, then stop. Do not run the script again, do not edit any record, label or pull request, do not merge and do not mark it ready: accepting a decision is the Project Lead's act, and the merge that makes it so is theirs too. If the output says `refused:`, the reason is the whole answer; the Project Lead decides what to do next.
