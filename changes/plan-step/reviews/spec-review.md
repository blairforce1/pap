# Spec review: plan-step

Reviewed 2026-11-11 against spec.md at draft; dispositions by @blairforce1.

Class: feature. Mandatory set: none (no class matrix in `product/`; the process's starting set names none for feature). Run by content: the default six, plus ux (the owner drives a command and a session), gdpr (the draft did not state that no personal data is held) and ai-act (sub-agents draft and review a plan; EU exposure unknown). Skipped: soc2 and iso27001, neither scope applies. Invariants reviewed against: INV-006, INV-007, INV-008.

## Executive verdict

**Fail as reviewed.** qa returned Fail with three Blockers, all on the launch gate: what "accepted" is, the plan's states, and two boundaries with no behaviour. Every Blocker and Major was accepted and the spec changed before the yes; one Observation was rejected.

| Perspective | Verdict              | Blocker | Major | Minor | Observation |
| ----------- | -------------------- | ------- | ----- | ----- | ----------- |
| security    | Pass with conditions | 0       | 3     | 3     | 1           |
| reliability | Pass with conditions | 0       | 5     | 3     | 2           |
| operations  | Pass with conditions | 0       | 3     | 4     | 1           |
| cost        | Pass with conditions | 0       | 3     | 3     | 1           |
| performance | Pass with conditions | 0       | 1     | 3     | 1           |
| qa          | Fail                 | 3       | 8     | 5     | 1           |
| ux          | Pass with conditions | 0       | 7     | 4     | 1           |
| gdpr        | Pass with conditions | 0       | 0     | 2     | 2           |
| ai-act      | Pass                 | 0       | 0     | 0     | 3           |

73 findings as returned. The gdpr and ai-act verdicts come from a design review and are not legal advice, an audit or a conformity assessment.

Dispositions: 72 accepted, 1 rejected (COST-007), 0 deferred.

## Top findings

1. QA-001 (Blocker; reinforced by SEC-002, REL-001, REL-004): the gate never says what "accepted" is or where it reads it.
2. QA-002 (Blocker): the plan's states disagree across the domain file and the gate's table.
3. QA-003 (Blocker): a plan committed before its spec, and a spec reworked after the plan's yes, have no behaviour.
4. REL-002, REL-003, UX-007 (Major): no behaviour for a planner or reviewer that fails or returns a partial draft.
5. COST-001, COST-002, COST-003, PERF-001 (Major): the cost guard measures wall-clock minutes between two commits, has no method for rework minutes and ignores tokens.
6. OPS-001, OPS-002, OPS-003 (Major): S1 cannot be read by the named check, planned changes are not identified, the refusal line has no home.
7. SEC-001, SEC-003 (Major): the INV-006 narrowing is unrecorded; repository text can ride through the plan into the build.
8. UX-001 to UX-006 (Major): the owner is left without a next step at the wait, the over-length stop, the return to spec and the refusal.
9. QA-004, QA-005, REL-005 (Major): "in flight" names two states; code plus a plan draft has no outcome; "code" has no path rule.

## Full findings register

### Security

| ID      | Severity    | Spec section             | Finding                                                                                       | Recommendation                                                                         | Invariant | Disposition                                                   |
| ------- | ----------- | ------------------------ | --------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- | --------- | ------------------------------------------------------------- |
| SEC-001 | Major       | step 5; Areas of concern | `/pap:plan` stops at a commit, not a draft PR; nothing requires 0026 to record the narrowing. | 0026 records the narrowing of INV-006 for `plan.md`, in the same release.              | INV-006   | accepted: Security, INV-006; plan-step-22                     |
| SEC-002 | Major       | The build; Security      | The gate checks only an acceptance line any writer can add.                                   | Define what the gate reads; list a hand-edited line as escaping.                       | INV-008   | accepted: When a plan is accepted; Security, Still escaping   |
| SEC-003 | Major       | steps 1-4; `/change`     | Indirect prompt injection: repository text through the planner's report into the build.       | The report is written as data; the plan never widens the build; the reviewer flags it. | -         | accepted: Security, Trust; The build; plan-step-15, -36       |
| SEC-004 | Minor       | step 3; Fit              | A plan can name protected paths with nobody told.                                             | Fit lists them; the owner sees them at the yes.                                        | INV-007   | accepted: The plan's sections, Fit; step 5; plan-step-10, -21 |
| SEC-005 | Minor       | Security                 | The bypasses have no detection signal.                                                        | A false-pass signal from the `Plan:` line.                                             | INV-008   | accepted: Operations, H2; plan-step-34                        |
| SEC-006 | Minor       | Non-functional           | The reviewer has no cap.                                                                      | Cap it; say what happens at the cap.                                                   | -         | accepted: Failures; Non-functional                            |
| SEC-007 | Observation | Undo                     | A rollback teaches the solo bypass.                                                           | Note it in 0026 as an accepted, time-boxed exposure.                                   | INV-007   | accepted: Security, Still escaping                            |

### Reliability

| ID      | Severity    | Spec section           | Finding                                                                     | Recommendation                                                             | Invariant | Disposition                                            |
| ------- | ----------- | ---------------------- | --------------------------------------------------------------------------- | -------------------------------------------------------------------------- | --------- | ------------------------------------------------------ |
| REL-001 | Major       | The build              | Nothing says what the gate does when it cannot decide.                      | Fail closed or open per input, with its own reason.                        | INV-006   | accepted: fails closed; The build; plan-step-29        |
| REL-002 | Major       | steps 1, 4             | No behaviour for a planner that dies, times out or returns a partial draft. | Check the report before writing; tell the owner; write nothing.            | -         | accepted: no automatic retry; Failures; plan-step-7    |
| REL-003 | Major       | steps 3, 5             | No behaviour for a failed plan review.                                      | No register, and the yes is blocked.                                       | INV-006   | accepted: Failures; plan-step-16                       |
| REL-004 | Major       | steps 1, 5             | A session that ends mid-flow leaves uncommitted files with no rule.         | Detect, tell the owner, resume or restart; the gate reads committed state. | -         | accepted: step 8; When a plan is accepted; plan-step-8 |
| REL-005 | Major       | Which changes need one | "Carries code" has no operational definition.                               | One path rule shared by the gate and `/pap:plan`.                          | -         | accepted: Which changes need a plan                    |
| REL-006 | Minor       | steps 2, 4             | The revised draft is not re-checked for length.                             | Re-apply the checks to the revised draft.                                  | -         | accepted: step 2; plan-step-12                         |
| REL-007 | Minor       | Interfaces             | The exit code and the log line are unnamed.                                 | Name them.                                                                 | -         | accepted: exit 20, `launches.log`; The build           |
| REL-008 | Minor       | step 6; plan-step-16   | An edit after the yes: reviewed and accepted again, or not?                 | Committed only after its own review and yes.                               | INV-006   | accepted: step 9; plan-step-27                         |
| REL-009 | Observation | Areas of concern       | A plan not pushed is absent on another clone.                               | 0026 states the narrowing; tell the owner at the yes.                      | INV-006   | accepted: step 6; plan-step-22                         |
| REL-010 | Observation | Operations, Good       | 0026's typed revisit trigger is not written out.                            | Name it.                                                                   | INV-008   | accepted: Interfaces and contracts                     |

### Operations

| ID      | Severity    | Spec section          | Finding                                                               | Recommendation                              | Invariant        | Disposition                                                                   |
| ------- | ----------- | --------------------- | --------------------------------------------------------------------- | ------------------------------------------- | ---------------- | ----------------------------------------------------------------------------- |
| OPS-001 | Major       | first check 1; S1     | `pap measure` has no column for commits after open.                   | Add a column, or name the `gh api` query.   | INV-008          | accepted: the `gh` query; no new measure column; Operations, first check 1    |
| OPS-002 | Major       | S1; Good              | Nothing identifies a planned change or joins the three repositories.  | Say how.                                    | INV-008          | accepted: by the `Plan:` line; Operations, Signals                            |
| OPS-003 | Major       | The build; H1         | The refusal line has no file, format or exit code.                    | Name them; say the typed line is used up.   | INV-008          | accepted: exit 20, checked last, `launches.log`; The build; plan-step-29, -30 |
| OPS-004 | Minor       | first check 3; S2     | The S2 check does not filter and `<tracker>` has no location.         | Give the filter and the location.           | -                | accepted: Operations, first check 3                                           |
| OPS-005 | Minor       | S3                    | Rework minutes are undefined.                                         | Define the source and the span.             | INV-008          | accepted: Operations, Signals                                                 |
| OPS-006 | Minor       | Undo                  | The order leaves a repository refusing; 0026's withdrawal is unowned. | Withdrawal in the revert PR; say the order. | INV-007, INV-008 | accepted: plugin before pin; Operations, Undo                                 |
| OPS-007 | Minor       | Areas of concern      | 0026 must state the INV-006 narrowing.                                | Make it a deliverable with a scenario.      | INV-006          | accepted: Security, INV-006; plan-step-22                                     |
| OPS-008 | Observation | Operational scenarios | 0026's Revisit line is not given.                                     | Give the exact line.                        | INV-008          | accepted: Interfaces and contracts                                            |

### Cost

| ID       | Severity    | Spec section           | Finding                                                              | Recommendation                                             | Invariant | Disposition                                                                        |
| -------- | ----------- | ---------------------- | -------------------------------------------------------------------- | ---------------------------------------------------------- | --------- | ---------------------------------------------------------------------------------- |
| COST-001 | Major       | S3; Non-functional     | Tokens have no cost model; a plan can cost more than it saves.       | Model it, add a token signal, or accept it as unrecovered. | -         | accepted: tokens reported, not guarded; Operations, S4; Areas of concern           |
| COST-002 | Major       | S3                     | Yes-to-yes minutes mix waiting with the owner's reading.             | Measure the owner's active time.                           | -         | accepted: Operations, S3                                                           |
| COST-003 | Major       | Good, S3               | "Rework minutes" has no definition or source.                        | Define it with one command for baseline and the 10.        | -         | accepted: Operations, Signals; first check 1                                       |
| COST-004 | Minor       | Good; scenarios        | The cost guard reads only at 10, as a mean.                          | Early read at 5; median and share over 30 minutes.         | -         | accepted: Operations, Good; operational scenario 4                                 |
| COST-005 | Minor       | steps 2-4              | The over-length redraft and the reviewer are outside any cap.        | Bring both under a cap.                                    | -         | accepted: Failures; Non-functional                                                 |
| COST-006 | Minor       | Non-functional         | Nothing records tokens actually used.                                | Log them in the register or the tracker.                   | -         | accepted: in the register; plan-step-13                                            |
| COST-007 | Observation | Which changes need one | Every change of the three classes pays the full step, however small. | A size threshold or a lighter path.                        | -         | rejected: the intent sets the gate by class; 0026's revisit decides from plan cost |

### Performance

| ID       | Severity    | Spec section   | Finding                                            | Recommendation                                   | Invariant | Disposition                                        |
| -------- | ----------- | -------------- | -------------------------------------------------- | ------------------------------------------------ | --------- | -------------------------------------------------- |
| PERF-001 | Major       | Non-functional | No wall-time target for the plan flow.             | A row for minutes to the draft being shown.      | -         | accepted: Non-functional, 15 minutes               |
| PERF-002 | Minor       | Non-functional | "Under 1 second" has no measuring conditions.      | State them; say the check makes no network call. | INV-007   | accepted: Non-functional; The build                |
| PERF-003 | Minor       | steps 2, 4     | Up to four serial runs; the reviewer is unbounded. | Say what is length-checked; cap the reviewer.    | INV-008   | accepted: step 2; Failures                         |
| PERF-004 | Minor       | S3             | S3 cannot tell agent time from owner latency.      | Log start and end of each run.                   | -         | accepted: Operations, S3 and S4; plan-step-13, -21 |
| PERF-005 | Observation | Non-functional | The token cap is unchecked until H-010.            | Name what records the count.                     | -         | accepted: the register's first lines               |

### QA

| ID     | Severity    | Spec section           | Finding                                                                              | Recommendation                                        | Invariant        | Disposition                                                                                 |
| ------ | ----------- | ---------------------- | ------------------------------------------------------------------------------------ | ----------------------------------------------------- | ---------------- | ------------------------------------------------------------------------------------------- |
| QA-001 | Blocker     | The build              | The gate does not say what it reads as accepted.                                     | Name the fields, the ref and "committed"; add rows.   | INV-006          | accepted: When a plan is accepted; plan-step-29                                             |
| QA-002 | Blocker     | Which changes need one | Four, three and two states for a plan; "reviewed" has no row.                        | One state list.                                       | -                | accepted: absent, a draft, accepted; reviewed is a property; domain.md                      |
| QA-003 | Blocker     | plan-step-13           | A plan before its spec, and a spec reworked after the plan's yes, have no behaviour. | State what the gate does in each.                     | INV-006          | accepted: a later spec commit voids the yes; order is not checked and is listed as escaping |
| QA-004 | Major       | Which changes need one | "In flight" names two states.                                                        | Rename.                                               | -                | accepted: "started unplanned"; domain.md                                                    |
| QA-005 | Major       | Which changes need one | Code after a plan draft has no outcome.                                              | Add rows.                                             | -                | accepted: it still needs its plan; plan-step-29                                             |
| QA-006 | Major       | Two pages; plan-step-8 | The count has two readings; no boundary row; two behaviours in one scenario.         | Name the rule; split; add rows.                       | -                | accepted: `wc -w`, header included; plan-step-11, -12                                       |
| QA-007 | Major       | The build              | The exit code, the line and the used-up typed line are in no Then.                   | Add them.                                             | -                | accepted: plan-step-29                                                                      |
| QA-008 | Major       | The build              | Precedence against pm-mode's refusals is unstated.                                   | State the order; a scenario for an unreadable branch. | -                | accepted: checked last; plan-step-29, -30                                                   |
| QA-009 | Major       | plan-step-11           | The dispositions and the sequel of a `return: spec` are undefined.                   | Define them.                                          | -                | accepted: draft kept, back to `/spec`; step 6; plan-step-19, -20                            |
| QA-010 | Major       | steps 4-6              | "Met", "resumes" and "a review of an edit" read two ways.                            | Define each; add scenarios.                           | -                | accepted: steps 4, 8, 9; plan-step-17, -18, -26, -27                                        |
| QA-011 | Major       | plan-step-15           | "Discarded" does not say which files remain.                                         | State it.                                             | -                | accepted: step 7; plan-step-25                                                              |
| QA-012 | Minor       | step 5; plan-step-13   | Prose and Thens disagree at the yes.                                                 | Align them.                                           | -                | accepted: step 6; plan-step-21, -22                                                         |
| QA-013 | Minor       | plan-step-18, -19      | The passing launches are thinner than pm-mode-30.                                    | Outline over the classes; assert the events.          | -                | accepted: plan-step-31, -32                                                                 |
| QA-014 | Minor       | plan-step-20, -21      | The `Plan:` format is unpinned; exempt and no-plan builds have no scenario.          | Pin it; add them; say whether `/change` stops.        | -                | accepted: `/change` stops on a draft; plan-step-33, -34, -35                                |
| QA-015 | Minor       | Non-functional         | No conditions for the second; no scenario for the cap; no reviewer cap.              | State them.                                           | -                | accepted: Non-functional; plan-step-7, -16                                                  |
| QA-016 | Minor       | Interfaces             | Promised changes with no scenario.                                                   | Add scenarios or name the checks.                     | INV-007, INV-008 | accepted: plan-step-38; Scenarios, how each is bound                                        |
| QA-017 | Observation | several                | Scenarios about what a model does bind only by a file check or an eval.              | Say which, per id.                                    | -                | accepted: Scenarios, how each is bound                                                      |

### UX

| ID     | Severity    | Spec section           | Finding                                                             | Recommendation                                         | Invariant | Disposition                          |
| ------ | ----------- | ---------------------- | ------------------------------------------------------------------- | ------------------------------------------------------ | --------- | ------------------------------------ |
| UX-001 | Major       | steps 1-4              | Only the start of the background work is signalled.                 | One ready notice, with the count and findings waiting. | -         | accepted: step 5; plan-step-1, -21   |
| UX-002 | Major       | step 2                 | A draft still over 1000 words is a dead end.                        | Name the way forward and what is committed.            | -         | accepted: step 2; plan-step-12       |
| UX-003 | Major       | step 5                 | No path for the owner's own edit before the yes.                    | The edit, show, ask-again loop of `/spec`.             | -         | accepted: step 6; plan-step-24       |
| UX-004 | Major       | step 3                 | Accepting a `return: spec` has no journey.                          | Define it.                                             | -         | accepted: step 6; plan-step-20       |
| UX-005 | Major       | The build              | The refusal names neither the state nor the way through.            | Word it for both; name the solo route.                 | -         | accepted: The build; plan-step-29    |
| UX-006 | Major       | step 5                 | A disposition per finding with no defaults; "a phase" is undefined. | Propose each; list the phases.                         | -         | accepted: steps 5, 6; plan-step-21   |
| UX-007 | Major       | Non-functional; step 1 | A capped or failed run is not told to the owner.                    | Specify the message; never a silent partial.           | -         | accepted: Failures; plan-step-7, -16 |
| UX-008 | Minor       | step 5                 | "No" loses work without saying so.                                  | Say what is lost.                                      | -         | accepted: step 7; plan-step-25       |
| UX-009 | Minor       | steps 5, 6             | Resume after "later" is undefined.                                  | Say what resume shows first.                           | INV-006   | accepted: step 8; plan-step-5, -26   |
| UX-010 | Minor       | Which changes need one | The next step per exemption is unspecified.                         | Give it for each reason.                               | -         | accepted: plan-step-3                |
| UX-011 | Minor       | step 5                 | The owner is not told the plan is unpushed.                         | Say so at the yes.                                     | INV-006   | accepted: step 6; plan-step-22       |
| UX-012 | Observation | Interfaces             | New terms will reach replies and pull requests.                     | Same words everywhere; no synonyms.                    | INV-008   | accepted: Scenarios, terms           |

### GDPR

| ID       | Severity    | Article        | Spec section  | Finding                                                                                  | Recommendation                                     | Relaxed under | Invariant | Disposition               |
| -------- | ----------- | -------------- | ------------- | ---------------------------------------------------------------------------------------- | -------------------------------------------------- | ------------- | --------- | ------------------------- |
| GDPR-001 | Minor       | 5(1)(c), 25(2) | steps 1, 3    | Repository content goes to the model and its output is committed, with no rule on names. | No third parties in plans; name the recipient.     | neither       | INV-007   | accepted: Data            |
| GDPR-002 | Minor       | 30, 13         | step 5        | Every accepted plan stores the owner's handle and a date in a pushed file.               | Note the handle, its purpose and its permanence.   | neither       | INV-006   | accepted: Data            |
| GDPR-003 | Observation | 5(1)(e), 17    | Undo          | Plans and registers leave GitHub only by a history rewrite.                              | Point to pm-mode's erasure note, extended.         | neither       | INV-008   | accepted: Data            |
| GDPR-004 | Observation | 5(1)(c)        | The build; H1 | The refusal line holds a slug and a reason.                                              | None, unless it gains a path with the OS username. | neither       | INV-008   | accepted: Data; no change |

### AI Act

| ID      | Severity    | Article   | Spec section        | Finding                                                    | Recommendation                                         | Relaxed under                | Invariant | Disposition                              |
| ------- | ----------- | --------- | ------------------- | ---------------------------------------------------------- | ------------------------------------------------------ | ---------------------------- | --------- | ---------------------------------------- |
| AIA-001 | Observation | 50(2)     | The plan's sections | The plan's provenance fields are not named.                | Name them, the reviewer's model included.              | neither                      | INV-007   | accepted: The plan's header; plan-step-9 |
| AIA-002 | Observation | 14, 26(2) | step 5; Security    | The owner's yes is the only human check on the plan.       | Show the planner's changes and returns beside the yes. | no EU exposure; minimal tier | INV-008   | accepted: step 5; plan-step-21           |
| AIA-003 | Observation | 15        | step 1              | The sub-agents read content that could carry instructions. | Treat reports as data; reference the security review.  | neither                      | INV-006   | accepted: Security, Trust; plan-step-6   |

## Cross-cutting themes

- **The gate was specified by its outcome, not its test.** Security, reliability and qa each asked what "accepted" reads.
- **Only the happy path was written.** Reliability, ux and qa each found failures, resumes and edits with no behaviour.
- **The cost guard could not be computed.** Cost, performance and operations each found a signal that could not be read from where the spec said.

## Trade-off register

- **Fail closed against false refusals (reliability, ux).** A gate that refuses what it cannot read protects the rule and produces H1. Decided: fail closed, with the reason named and the solo route in the refusal.
- **A spec rework voiding the plan's yes (qa, cost).** Safer, and a second yes each time against a cost guard that is already tight. Decided: void; H3 counts it.
- **Tokens against owner minutes (cost).** A plan can cost more tokens than a sent-back build saves. Decided: the guard is the owner's minutes; tokens are reported with no band.
- **A hard gate for every size of change (cost).** Decided: no lighter path; the revisit decides from S4.

## Gaps and questions

Closed by the accepted findings: the trust boundaries of agent inputs and outputs; the sub-agents' tool lists; time caps; a second `/pap:plan` while a planner runs; the gate's source for its test. Left open, for the plan: which source the gate reads the class from when the brief and `intent.md` disagree; whether EU exposure exists for any adopter.

## Recommended conditions for approval

Every Blocker and Major above, each now in the spec at the section its disposition names.
