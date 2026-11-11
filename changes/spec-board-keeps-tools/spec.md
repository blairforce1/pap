# Spec: spec-board-keeps-tools

```text
id:                 spec-board-keeps-tools
class:              bugfix
intent:             changes/spec-board-keeps-tools/intent.md
scenarios:          features/spec-board-keeps-tools.feature, spec-board-keeps-tools-1 to spec-board-keeps-tools-8
accepted-by:        @blairforce1
accepted-on:        2026-11-11
generated-by:       Claude Fable 5.2 via Claude Code
skills:             pap:spec 0.19.0; spec-review 1.3.1
prompt:             /pap:spec spec-board-keeps-tools
```

## Functional behaviour

**The escaped defect.** `/spec` step 6 invokes a `spec-review-*` skill in
the main session and then says to write the register. Each of those
skills withholds Bash, Edit and Write, and Claude Code lifts a skill's
withheld tools only at the owner's next message (its skills
documentation: "The restriction clears when you send your next
message"). So in the turn the review returns the session cannot write
`changes/<slug>/reviews/spec-review.md`, and the register lives only in
the conversation until the owner speaks. Surfaced in use at pap 0.19.0
with spec-review 1.3.1. Attribution: specification gap (decision 0021's
step order assumed the session kept its tools).

**The fix, as behaviour.** `/spec` no longer invokes a skill of the
spec-review plugin in the main session. It starts the spec review as
sub-agents: one for each perspective the class requires (one, qa, for a
bugfix whose intent touches no invariant; the board's set otherwise,
selected as the board selects today). Each such sub-agent reads its
perspective and the spec, returns its verdict and findings table, and
holds no tool that edits, writes, runs a shell or starts a sub-agent.
While perspectives are still reporting, the session consolidates nothing
and tells the owner in one line, each time one reports, how many have
reported, of how many; a review of one perspective gets no such line. When the last
reports, the session consolidates, writes the spec review register in
that same turn, and only then asks for dispositions. The rules for
selecting perspectives and for consolidating (deduplication, verdict,
the register's sections and columns) are the board's own, unchanged:
the session reads the board's skill file as data and follows it, and
restates none of it. A review of one perspective is not consolidated:
its register is that perspective's report as returned. It asks for the first of them in that same turn, so a finding the owner
accepts there is applied to the spec draft and recorded in the register
without waiting for another message. Nothing is committed before the
owner's yes to the spec (rule 21.1); the intent's "and commit" means
the commit at that yes, which no longer waits on a lost register.

A perspective fails when its sub-agent ends without a verdict and a
findings table, or has not reported 20 minutes after it started (the cap
`/pap:plan` gives its sub-agents). It is started once more; on a second failure the owner
is told which perspective and asked whether to go on without it, and a
register written without it names it as not run.

Where the spec-review plugin is not installed, or the session has no
sub-agent type that reads a perspective (it started before the plugin
shipped one), `/spec` stops and says which, and what to do: install the
plugin, or start a new session. It starts no sub-agent of another type
in its place, since another type may hold a tool that writes.

Outside `/spec` nothing changes: a person who invokes a perspective or
the board directly gets it in the conversation, with the same tools
withheld, with or without the pap plugin installed.

Scenarios added, in `features/spec-board-keeps-tools.feature`:

- `spec-board-keeps-tools-1` The register is written before any disposition is asked: the defect; fails before the fix, for the single perspective and the board alike.
- `spec-board-keeps-tools-2` An accepted finding is applied in the turn it is accepted: the second half of the intent's outcome.
- `spec-board-keeps-tools-3` A perspective is read by a sub-agent that cannot change a file: the intent's first constraint, kept by the tool list.
- `spec-board-keeps-tools-4` A perspective invoked directly runs as before: the intent's second and third constraints.
- `spec-board-keeps-tools-5` A spec review still running is not consolidated: the wait and the progress line.
- `spec-board-keeps-tools-6` A perspective that fails is started once more: a wait needs an end.
- `spec-board-keeps-tools-7` A perspective that fails twice is named: the owner decides, and the register does not pass as whole.
- `spec-board-keeps-tools-8` /spec stops when it cannot start a perspective's sub-agent: no fallback reader that might write.

How each is bound: 3 and 4 by a structure test under `tests/` (the
sub-agent definition's tool list; every `spec-review-*` skill's withheld
tools equal to the list the test itself pins, not to `main`). 1, 2 and
5 to 8 are what a session does, and
pap has no eval suite to run a session in (backlog H-010); the same test
binds them to five sentences `/spec` step 6 carries word for word, each
absent from the skill before the fix:

1. `Do not invoke a spec-review skill in this session.`
2. `Write the register before you ask for any disposition.`
3. `Wait for every perspective before you consolidate.`
4. `Start a failed perspective once more.`
5. `Start no sub-agent of another type in its place.`

A wording test passes on words alone, so the behaviour itself is read
from the intent's success measure, five transcripts. The eval process
section 4 asks of a bugfix is deferred to H-010, when pap has a harness
to run a session in.

Terms added to `product/domain.md`: Turn, Perspective, Spec review, Spec
review register; events The owner runs /spec, A perspective reports, A
spec review returns; two rules.

## Operations

**Undo.** Revert the merge. Outside git: none; no setting, release or
version changes with this change. Until a release carries it, adopting
repositories run the pinned 0.19.0 behaviour. This text is the pull
request's "How to revert".

## Open questions

- Does the restriction outlast the skill for the whole turn: answered, yes, and by design. Claude Code's skills documentation says a skill's `disallowed-tools` clear "when you send your next message". A headless reproduction was refused by the session's permission classifier; this spec's own review (step 6, `spec-review-qa` invoked the old way) is the live reproduction, and its result is recorded in the register's first lines.
- Can a review sub-agent start the per-perspective sub-agents, or must the caller run the fan-out: answered, it can (Claude Code nests sub-agents three layers deep by default), and this spec has the caller run it anyway. A chair sub-agent that can start sub-agents can start one that writes, which breaks the first constraint by proxy; pap's other reviewers hold no such tool, and `tests/plugin-agents.test.sh` checks it. Cost: consolidation happens in the main session, which can write. The owner's word: nothing in a review may start a writer, so the caller runs the fan-out.
- Does the agent definition live in the `spec-review` plugin or in `pap`: answered, in `pap`, beside `pap:reviewer` and `pap:plan-reviewer`. The defect is `/spec`'s alone (the intent's third non-goal), the spec-review plugin stays untouched so three of the constraints hold by construction, and there is no skew between the two plugins' versions. Cost: `/spec` must find the spec-review plugin's files from outside it.
- Does decision 0021 or any rule name the skill invocation in words this change would contradict: answered, no. Decision 0021 says `/spec` "runs the spec review board the class requires (5.5, the `spec-review` plugin, selected by class)", process 5.5 says the plugin "provides" the perspectives, and rule 21.1 speaks only of dispositions recorded in `reviews/`. None says how the board is run. No rule is added and no record edited.
- New, from drafting: process section 4 asks a bugfix to add an eval. This change adds a structure test and no eval, since `claude plugin eval` is not yet pap's harness (H-010). answered: deferred to H-010 (QA-003).

## Intent churn

The intent's first constraint read "Whatever runs the review can read
and cannot edit, write or run shell". Drafting showed the main session
has to select the perspectives and consolidate their reports, and it can
write. The constraint now binds each sub-agent that reads a perspective,
which also may not start a sub-agent, and names the main session as the
consolidator (QA-002). Churn commit: `intent(spec-board-keeps-tools):
churn, the read-only constraint binds the perspective sub-agents`.
