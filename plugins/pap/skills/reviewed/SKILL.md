---
name: reviewed
description: "Add the owner-reviewed label to a risk:high pull request after the Project Lead has reviewed its head (decision 0016, rule 16.1). Only a person invokes it: /pap:reviewed <PR#> [sha7+]. The skill's script adds the label when the skill is invoked; the model only relays the result and never adds the label itself."
argument-hint: "<PR#> [sha7+]"
disable-model-invocation: true
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/reviewed.sh *)
---

# Reviewed

The Project Lead has reviewed the head of a `risk:high` pull request and wants the `owner-reviewed` label on it (decision 0016). The script ran when this skill was invoked, in the current repository, with the arguments typed after `/pap:reviewed`: it checked that the pull request is open, that any SHA given is a prefix of its head and that it is `risk:high`, then added the label through `gh` and read it back. Its output:

!`${CLAUDE_SKILL_DIR}/reviewed.sh "$ARGUMENTS"`

Relay the output above to the Project Lead word for word, in one line, then stop. Do not run the script again, do not add, remove or edit any label, do not merge and do not re-run any check: the label is the Project Lead's act, and an agent never adds `owner-reviewed` by any route (rule 16.2). If the output says `refused:`, the reason is the whole answer; the Project Lead decides what to do next.
