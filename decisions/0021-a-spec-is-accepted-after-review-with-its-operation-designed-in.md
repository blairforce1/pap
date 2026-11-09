# 0021. A spec is accepted after review, with its operation designed in

- **Status:** proposed
- **Date:** 2026-11-05
- **Deciders:** blairforce1, with Claude
- **Supersedes:** none; amends process principle 5, section 4 (the docs row), 5.1 (phases 2 and 3), 5.2 (the intent, specification and planning rows), 5.4 and 5.5; delivers the `/spec` slice of [0017](0017-specs-carry-executable-scenarios-in-a-domain-vocabulary.md), whose status does not change; closes the follow-up [0020](0020-intent-is-accepted-by-a-recorded-yes-on-the-change-branch.md) left on 5.2's intent row, 5.1 row 2 and principle 5
- **PIP:** the owner's call of 2026-11-05: once `/intent` has accepted the intent, the change is specified in full, with acceptance scenarios in Given/When/Then, and its operation, how the intent is monitored, traced and undone, is designed at spec time. Of pap's 78 merged change pull requests none carries a `spec.md`; the one `intent.md` (process-coverage, written from the brief and never accepted) went straight to code. The pull request template's "How to revert" is answered last, by the context that wrote the code, and process 5.9's control bands exist in the process document and in no change
- **Expected effect:** share of merged feature, infra and security-sensitive change pull requests whose `changes/<slug>/spec.md` carries Signals, Good, Wrong and Undo ↑ from 0 of 78 to every change started with `/spec`, read from `changes/*/spec.md` on main against merged `change/` pull requests, in pap and in each adopting repository separately; escapes attributed to a specification gap (5.11) at a median of 0 per closed change once `findings.md` exists, and until then 0017's proxy, `fix:` or `revert:` pull requests merged within 14 days that touch a file the change changed, ↓; the pull request's "How to revert" equal to the spec's Undo in every such change
- **Introduced in:** not yet released; the release that ships `/spec`
- **Revisit:** when 10 change PRs started with `/spec` have merged in one repository, counted from the first change started with `/spec` after the amendment of 2026-11-09: the share and the proxy over those 10, how many specs were returned to (5.10) from code review or verification, how many operational scenarios were exercised, by hand or by H-015's watcher, and whether docs and chore specs earned their half page

## Context

Process 5.1 makes specification phase 2, "agent drafts, human edits",
accepted when `spec.md` is merged; 5.4 lists its candidate sections,
"Operations: deployment, configuration, observability, rollback" among
them, and 5.9 describes an operation window watched against control bands
with a tiered response. Nothing connects them. No tool writes a spec
(backlog H-011), so none of pap's 78 merged change pull requests has one;
`/change` goes from the brief to the code, and the brief, a good
instruction, says what to build and not what would show it working or how
it would be taken back.

Decision 0020 put the intent on the change branch, accepted by the human's
recorded yes, and left the spec's trigger as it was: "Merged", which on
one branch with the code fires only at the end, after the code the spec
was meant to precede. It also left 5.2's intent row and principle 5
("acceptance is a merge") unchanged, for a later record. Decision 0017
settled what a spec's functional half carries, scenarios in a domain
vocabulary bound to tests, and named `/spec` as the slice that ships them
with the process amendments.

The pull request template gained a "How to revert" section. It is filled
at the pull request, by the agent that wrote the code, from what it
remembers. The operations perspective of the `spec-review` plugin asks
whether rollback, alerting and runbooks are designed in or assumed; with
no spec to read, it has never been run on a pap change.

## Decision

1. **The spec is accepted by the human's recorded yes, after review.**
   `/spec <slug>` runs in the main session. It reads the accepted
   `changes/<slug>/intent.md` and refuses to go on without one. It drafts
   `spec.md` with the sections the class requires (5.4), carrying every
   open question from the intent as answered or still open, and noting
   intent churn. It runs the spec review board the class requires (5.5,
   the `spec-review` plugin, selected by class), writes the register to
   `changes/<slug>/reviews/`, and takes the human through the findings:
   each gets accepted, rejected with a reason, or deferred to a phase, and
   an accepted finding changes the spec before the yes. The human's yes to
   the reviewed spec is the acceptance: the skill records who and when in
   the file (`accepted-by:`, `accepted-on:`) and commits on
   `change/<slug>`, after `intent.md` and before any code, as 0020 ordered
   them. There is no separate merge; the change's one pull request carries
   intent, spec and code in that order.
2. **Operations are designed in at spec time.** For feature, infra and
   security-sensitive changes the Operations section is mandatory and
   connects the intent's success measure to 5.9. **Signals**: what is
   measured for each success measure in the intent, and for the health the
   change could move. **Good**: the control band, thresholds and the window,
   inside the class's operation window. **Wrong**: what a breach looks like,
   how fast it would be noticed and the first checks, a short runbook.
   **Undo**: revert the merge, a feature flag off, or a config rollback,
   with the steps in order for anything outside git. **Operational
   scenarios** in Given/When/Then: "Given it is live, When <signal>
   breaches <band> over <window>, Then <undo> and the human is told", one
   per band at least. The pull request's "How to revert" is the Undo,
   copied, not composed. A bugfix writes Undo only; docs and chore none.
3. **Operational scenarios stay in the spec, not in `features/`.** Rule
   17.1 says a scenario in `features/` is bound by a test or pending.
   Nothing can bind a scenario about a live system until an operations
   role watches the window (backlog H-015); put there, they would be
   pending for ever and fail the binding check the day it ships. They are
   prose in the spec's Operations section until H-015 gives them a runner.
4. **This is 0017's `/spec` slice, and no more.** Functional scenarios are
   Gherkin in `features/<slug>.feature`, tagged `@id:<slug>-<n>` and
   `@pending:<slug>`, in the words of `product/domain.md`, which the spec
   extends in the same diff; `spec.md` lists the scenarios it added and
   why. 0017's first slice, `/envision` seeding `domain.md`, has not
   shipped, so `/spec` starts the file when a repository has none. The
   binding check (17.1), `pr-checks` for 17.3 and 17.4, the vocabulary pass
   and the executed runners follow as their own slices. 0017 stays
   proposed; its revisit is unchanged.
5. **The process says acceptance, not merge, where the branch does.**
   Principle 5 becomes "acceptance is recorded, and the record is a
   trigger": the human's yes in the file for intent and spec, the merge or
   the closed review for the rest. 5.1 row 2 names the recorded yes after
   review, the scenarios, the Operations section and the order on the
   branch; row 3 says the dispositions are recorded with the spec and that
   the human's approval is the spec's yes. 5.2's intent and specification
   rows count to acceptance, and spec rework is a `spec.md` commit after
   `plan.md` or code exists. 5.4 says what Functional behaviour and
   Operations carry and when a spec is accepted; 5.5 says where the
   dispositions go; section 4's docs row says a half-page spec and no
   board. 0017's amendments to sections 3, 4 (the scenario columns of the
   class matrix), 5.6 and 5.10 wait for the slices that give them
   something to enforce.
6. **`/change` reads the spec.** Where the branch has `spec.md`, its
   scenarios are the acceptance criteria, its rows the thresholds and its
   Undo the pull request's "How to revert", which `/change`'s body template
   now has. A test made to pass by rewriting a scenario is a return to spec
   (17.3), not a fix.
7. **Lighter by class** (principle 2). Docs and chore get half a page: what
   changes and where, how a reader checks it, open questions; no board, the
   human's read is the review. A bugfix gets the escaped defect it cites,
   one scenario that fails before the fix (17.4), Undo, and the qa
   perspective. A spike has no spec (section 4).

8. **`/spec` follows `/intent`, so it too is for a change that needs it**
   (amended 2026-11-09, rule 20.2 of
   [0020](0020-intent-is-accepted-by-a-recorded-yes-on-the-change-branch.md)).
   A change started with `/intent` goes on to `/spec` as its class asks;
   one that rule 20.2 sends to `/change` has no spec.

The reason that carried it: the signal for a success measure is designed
when the measure is, or it is never designed; and the person who can say
how a change is undone is the one who has just read what it does, before
the code exists to argue with.

## Result

### Revisit of 2026-11-09

The trigger fired at #116, the 20th change pull request merged after
#89 in merge order, as `pap revisits` counts (#91 and #92 merged
before #89): #90, #93 to #99, #101, #102 and #107 to #116. `pap measure 0021`
ran (the ten merged before the start and the first ten after); the
Expected effect reads `changes/*/spec.md`, not a measure column, so no
`--verdict` ran.

| Question                                        | Answer                                                                                                                                                                                                                                                                                |
| ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Share with Signals, Good, Wrong and Undo        | 0 of 12 feature, infra and security-sensitive pull requests in the window (#90, #94, #97, #99, #101, #107, #108, #110, #111, #113, #115, #116). Main holds no `changes/*/spec.md`; the one other adopting repository with a `changes/` folder has none written since `/spec` shipped. |
| The proxy: `fix:` or `revert:` within 14 days   | Not applicable as defined: it is read per change with a spec, and there is none. For the record, two `fix:` pull requests in the window touch files a change in it changed (#102 after #99 and #101; #107 after #99, #101 and #102); no `revert:`.                                    |
| Specs returned to (5.10)                        | 0; none was written.                                                                                                                                                                                                                                                                  |
| Operational scenarios exercised                 | 0; none was written, and H-015's watcher is not built.                                                                                                                                                                                                                                |
| Whether docs and chore specs earned a half page | Cannot judge: none was written.                                                                                                                                                                                                                                                       |

As with [0020](0020-intent-is-accepted-by-a-recorded-yes-on-the-change-branch.md),
no change in the window was started with `/spec`, so the 20 tested
whether it was used, not whether it works. The two `fix:` follow-ups
are a security boundary that took two follow-up fixes, the kind of gap a spec's
Wrong row is meant to name early; that is a reason to try it, not a
measurement of it.

Recommendation: amend (count from the first change started with `/spec`,
as the new Revisit line does)

### Amended 2026-11-09

The Project Lead said yes to the amendment: `/spec` is required for a
change that needs it and not otherwise (point 8, rule 20.2), and the
Revisit line counts from the first change started with `/spec`. Status
stays `proposed`.

## Considered options

- **The spec accepted by a merge of its own pull request, as 5.1 read.**
  Lost for 0020's reasons: one more pull request, merged by its author
  before the branch for the code exists, and a merge that cannot tell a
  read spec from an unread one. On one branch with the code, "Merged"
  fires at the end, after the thing it was meant to precede.
- **Operations at the pull request, as "How to revert" is today.** Lost:
  written after the code by the context that wrote it, from memory, and
  nothing asks for the signal or the band at all. A revert plan that
  nobody reviewed before the code is a hope.
- **A separate `operations.md`.** Lost: a seventh artefact in the change
  folder, read by nobody the spec is not already read by; the operations
  perspective reviews the spec, and the undo belongs beside the behaviour
  it withdraws.
- **Operational scenarios in `features/` with the functional ones.** Lost
  for now: rule 17.1 would leave them pending for ever, and the binding
  check would fail every spec. They move when H-015 can bind them.
- **Operations only for infra, where section 4 already says "reliability
  and ops review mandatory".** Lost: a feature's success measure is read in
  production too, and the PIP named feature and infra; security-sensitive
  runs the full board already.
- **The review as its own accepted artefact, with its own yes.** Lost:
  5.1's phase 3 ends with the human's approval, which is the yes the spec
  needs; two yeses for one reading is ceremony.
- **No spec for docs and chore, as section 4's docs row read.** Lost, for
  now: half a page that says what changes and how a reader checks it is
  the acceptance criterion `/change` would otherwise take from the brief.
  The row now says half a page; the revisit asks whether it earned it.

## Consequences

- Easier: a change's monitoring and its undo are reviewed by the operations
  perspective before any code exists, and the pull request's "How to
  revert" is copied from a reviewed section rather than composed at the
  end.
- Easier: a specification-gap escape has a scenario, or a missing one, to
  point at (0017), and an operational escape has a band it should have
  breached.
- Easier: the operations member of H-015 has its input: signals, bands and
  undo it did not have to design after the fact.
- Harder: the human reads a review register and a spec before any code, on
  every feature and infra change, and gives a disposition per finding
  (section 7, item 3, as before). Docs and chore pay half a page. The
  revisit counts specs returned to and the half pages.
- Harder: `product/domain.md` is edited by `/spec` before `/envision` seeds
  it, so the first specs define the first terms, in a protected path the
  owner then reviews. A later `/envision` pass reconciles.
- Limit: nothing enforces 21.1 or 21.2. A spec committed after code, or a
  feature spec without an Operations section, is caught by a reader.
  Planned: `pr-checks` checks that a pull request with a `Change:` line of
  class feature, infra, security-sensitive or bugfix carries `spec.md`
  with the acceptance lines and a `reviews/` file, that `spec.md`'s first
  commit follows `intent.md`'s and precedes the first commit outside
  `changes/`, `features/` and `product/`, and that the Operations section
  has its four headings for the classes that need it.
- Limit: operational scenarios are prose until H-015; nothing runs them,
  and the human is the watcher 5.9 describes.
- Measurement: from `changes/*/spec.md` on main and the pull requests'
  bodies, so no hand counting. Twenty changes is a direction, not a
  significance test (0001).
- Follow-up: the `/intent` skill's hand-on names `/spec` as "when it
  exists"; once both have merged, a docs change makes it the next step.
- Follow-up: H-015. Automatic action on a live system, even a reversible,
  pre-authorised one, needs its own decision record before any watcher
  acts; until then it proposes and the human runs the undo (5.9).

## Where it is taught or enforced

Backs [`rules.md`](../rules.md) 21.1 (a spec is accepted by a recorded
yes after review, before the code) and 21.2 (a feature, infra or
security-sensitive spec designs its operation). Taught by the `/spec` skill
([`plugins/pap/skills/spec/SKILL.md`](../plugins/pap/skills/spec/SKILL.md))
and the `/change` skill's steps 3 and 6. Enforced by nothing yet.
