# 0020. Intent is accepted by the human's recorded yes, on the change branch

- **Status:** proposed
- **Date:** 2026-11-05
- **Deciders:** blairforce1, with Claude
- **Supersedes:** none; amends process 5.1 (phase 1) and 5.3, and narrows rule 2.2 of [0002](0002-skills-stop-at-draft-pr.md) for the skills that write `intent.md` and `spec.md`
- **PIP:** the owner's call of 2026-11-05 that the intent must be intentional. Process 5.1 makes intent phase 1, human-owned and "accepted when merged"; no tool writes it (backlog H-005). In practice the project manager's brief plus the human's yes to a one-line restatement (decision [0018](0018-a-project-manager-session-launches-cycles-and-keeps-the-tracker.md), rule 18.2) has stood in for intent, outside `changes/<slug>/`: of pap's 78 merged change pull requests, one carries an `intent.md` (process-coverage), so no change links to a hypothesis where a measure can read it, and `findings.md` would have no success measure to evaluate
- **Expected effect:** share of merged change pull requests whose branch carries an accepted `changes/<slug>/intent.md` naming `H-NNN` or `reactive: <reason>` ↑ from 1 of 78 (1%) to every change started with `/intent`, read as `changes/*/intent.md` on main against merged `change/` pull requests, in pap and in each adopting repository separately; intent churn (5.4: commits to `intent.md` after `spec.md` first exists on the branch) counted per change from git, expected at a median of 0 and not above 1; reactive share (6.3) reported from the same files
- **Introduced in:** not yet released; the release that ships `/intent`
- **Revisit:** when 10 change PRs started with `/intent` have merged in one repository, counted from the first change started with `/intent` after the amendment of 2026-11-09: the share, the churn and the reactive share over those 10, and how many intents accepted in the interview were returned to (5.10) at spec or review

## Context

Process 5.1 says an intent is accepted when `intent.md` is merged, with
the class declared, the hypothesis linked, the success measure written and
the invariants touched listed; principle 5 says acceptance is a merge.
For intent that means a pull request carrying one half-page file, merged
by the person who wrote it (0002 requires no approving review), before
the branch that carries the spec and the code exists. In pap's 78 merged
change pull requests nobody did it: the brief did the job. One change,
process-coverage, has an `intent.md`, written by the agent from the brief.

The brief is a good instruction and a poor intent. It says what to build;
it lives in a chat or the project manager's tracker, not in
`changes/<slug>/`; it names no hypothesis a measure can read, no success
measure a `findings.md` can evaluate, and no invariants, so the risk is
judged by the label after the fact rather than declared before. Decision
0018 added "restate and yes before any brief" (rule 18.2), which is an
acceptance, logged, of a one-line restatement, not of an intent in 5.3's
sections. The yes exists; the artefact it should accept does not.

## Decision

1. **Intent is accepted by the human's recorded yes.** `/intent <slug>
   <class>`, followed by the human's usual instruction, interviews the
   human in the main session: it reads the product layer first, asks in
   small batches, and challenges the answers on a short list: which
   hypothesis the change serves or why it is reactive; whether the
   success measure is observable after release; the non-goals; the
   invariants and protected paths touched, and so the class and the risk;
   whether the class fits the ceremony it buys; constraints; open
   questions, each answered or carried forward. It restates the intent as
   half a page in 5.3's sections. The human's yes is the acceptance: the
   skill records who and when in the file (`accepted-by:`, `accepted-on:`)
   and commits `changes/<slug>/intent.md` on `change/<slug>`. No yes, no
   file. Docs and chore changes get a lighter interview (principle 2).
2. **Intent and spec ride the change's one pull request, in order.**
   `intent.md` is committed before `spec.md`, and both before code; the one
   pull request carries them in that order, so the folder's history is the
   record of the change (process 5) and the merge still closes every phase
   at once (principle 5). `/intent` and `/spec` commit and hand on;
   `/change` opens the draft pull request. That narrows rule 2.2 for them:
   they stop at a commit, not at a draft pull request, and still never
   merge.
3. **Intent churn is still recorded** (5.4). A commit to `intent.md` after
   `spec.md` first exists on the branch is churn, and its commit message
   says what the spec surfaced. An edit after the yes keeps the acceptance
   lines and notes the edit in the file; a change of class or hypothesis is
   a new yes, recorded in the same lines.
4. **Process 5.1 phase 1 and 5.3 are amended to match, nothing more.**
   5.1's "Accepted when" for intent names the recorded yes and the order on
   the branch; 5.3's frontmatter gains `source:` (rule 11.2, which the
   process document never caught up with), `accepted-by:` and
   `accepted-on:`. 5.2's intent row keeps "merged `intent.md`", read as
   the merge of the pull request that carries it; principle 5 keeps its
   wording.
5. **`/change` reads an accepted intent as the brief's intent.** On a
   branch whose `changes/<slug>/intent.md` exists, its class and
   hypothesis stand and a `<class>` argument that differs is a
   contradiction to report. Until `/spec` exists, `/intent` says that spec
   is next and how; H-012's `/pap:pm launch` calls `/intent` in a later
   cycle.

6. **`/intent` is for a change that needs it, and not otherwise**
   (amended 2026-11-09, rule 20.2). A change needs it when it adds or
   changes something a user, operator or adopter sees, or carries a
   design choice with more than one reasonable answer that nothing on
   record settles; housekeeping, docs of what exists, a version bump or
   sync, a test-only change and a fix that restores stated behaviour do
   not. The project-manager session makes the call and names it in the
   brief's first line (rule 18.8); the human can overrule it.

The reason that carried it: the yes is what the human was already giving.
Writing it into the file the next phase reads costs one interview and buys
the link to a hypothesis that every measure in 5.2 and 6.3 needs.

## Result

### Revisit of 2026-11-09

The trigger fired at #111, the 20th change pull request merged after
#86: #87 to #99, #101, #102 and #107 to #111. `pap measure 0020` ran (the ten merged before the start and the first ten after); the Expected effect reads
`changes/*/intent.md`, not a measure column, so no `--verdict` ran.

| Question                                     | Answer                                                                                                                                                                                               |
| -------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Share carrying an accepted `intent.md`       | 0 of 20. Main holds one `changes/*/intent.md`, process-coverage's, from #54 and never accepted. The one other adopting repository with a `changes/` folder has none written since `/intent` shipped. |
| Intent churn                                 | Not defined: no change in the window has an `intent.md`, so none has one to churn.                                                                                                                   |
| Reactive share                               | Not defined, for the same reason.                                                                                                                                                                    |
| Intents returned to (5.10) at spec or review | 0; none was accepted.                                                                                                                                                                                |

No change in the window was started with `/intent`: every cycle came from
a project manager's brief to `/change`, as before the record. The
Expected effect is conditional ("every change started with `/intent`"),
so the 20 tested whether the skill was used, not whether it works. Not
refuted, not confirmed.

Recommendation: amend (count from the first change started with
`/intent`, as the new Revisit line does; whether briefs should start
with `/intent` is a separate call for the Project Lead)

### Amended 2026-11-09

The Project Lead said yes to the amendment and made the separate call:
"we need to do them but only for things that need them". Point 6 and
rule 20.2 carry the test; rule 18.8 has the brief name its route. The
Revisit line counts from the first change started with `/intent`. Status
stays `proposed`.

## Considered options

- **A separate intent pull request, as 5.1 read.** Lost: one more pull
  request, holding one half-page file, merged by its author before the
  branch for the code exists; in 78 changes nobody opened one. Its record
  of acceptance, the merge, is also weaker than it looks: a merge cannot
  tell a read intent from an unread one, where a yes typed to a
  restatement can.
- **Brief-only, as practised.** Lost: the brief is outside `changes/`,
  names no hypothesis, no measure and no invariants, and `findings.md`
  has nothing to evaluate. Rule 18.2's restated yes accepts one line, not
  an intent.
- **`/change` writes `intent.md` from the brief, no interview.** Lost: a
  paraphrase of the brief is not an intent the human accepted, and the
  critique is where the value is; principle 1 makes intent the human's
  artefact, and principle 3 says a change whose measure cannot be written
  is too large or too vague, which only a question finds out.
- **Acceptance as a comment or label on the pull request.** Lost: the
  pull request does not exist when the intent is accepted, and a label is
  a GitHub record, not git (0011).

## Consequences

- Easier: every change started with `/intent` names a hypothesis or says
  why it is reactive, so the reactive share (6.3) is read from
  `changes/*/intent.md`, and `findings.md` has a measure to evaluate.
- Easier: one branch and one pull request per change; the review sees
  intent, spec and code together and in order.
- Harder: the interview costs the human's attention in the main session,
  on every change. Docs and chore get a lighter one, and the revisit asks
  whether the interview's output survived spec and review.
- Harder: a yes typed in a chat is, to a later reader, a weaker gate than
  a merge. The file records who and when, and the pull request carries it
  to the merge principle 5 asks for.
- Limit: nothing checks that the acceptance lines are true or that
  `intent.md` precedes `spec.md` in the branch's history; rule 20.1 is
  taught, not enforced. Planned: `pr-checks` checks that a pull request
  with a `Change:` line carries `changes/<slug>/intent.md` with
  `accepted-by:` and a hypothesis, the check 0011 listed as a follow-up,
  and that its first commit precedes `spec.md`'s.
- Follow-up: 5.2's intent row, 5.1 row 2's "Merged" trigger for the spec
  (on one branch with the code, it fires only at the end) and principle 5
  keep their wording. A later record changes them if the revisit finds the
  yes and the merge disagreeing about what was accepted.
- Follow-up: `/spec` (H-011) reads the accepted intent; `/pap:pm launch`
  (H-012) calls `/intent` before it writes a brief.
- Measurement: from `changes/*/intent.md` on main and the merged branches'
  history, so no hand counting. Twenty changes is a direction, not a
  significance test (0001).

## Where it is taught or enforced

Backs [`rules.md`](../rules.md) 20.1 (intent is accepted by a recorded yes
and committed before the spec and the code), 20.2 (a change starts with
`/intent` when it needs one) and 18.8 (a brief names its route), and
narrows 2.2. Taught by the
`/intent` skill ([`plugins/pap/skills/intent/SKILL.md`](../plugins/pap/skills/intent/SKILL.md))
and the `/change` skill's step 2. Enforced by nothing yet.
