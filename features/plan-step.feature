Feature: A reviewed plan sits between an accepted spec and the code
  After a spec is accepted and before any code, a plan says how the
  change will be built. A sub-agent drafts it, another reviews it, the
  owner says yes, and the build is not launched without it.

  Rule: A plan is drafted in the background, from an accepted spec

    @id:plan-step-1 @pending:plan-step
    Scenario Outline: /pap:plan starts a planner in the background
      Given a change of class <class> whose spec is accepted
      And its change branch carries no code and its plan is absent
      When the owner runs /pap:plan for the change in a main session
      Then one sub-agent of type pap:planner starts in the background
      And it is given the change's slug and work tree and nothing of the session's conversation
      And the owner is told the plan is being drafted and that they will be told once, when it is ready for a yes

      Examples:
        | class              |
        | feature            |
        | infra              |
        | security-sensitive |

    @id:plan-step-2
    Scenario Outline: /pap:plan is refused without an accepted spec
      Given a change of class feature whose spec is <state>
      When the owner runs /pap:plan for the change
      Then it stops, saying /spec comes first
      And no planner starts and nothing is written

      Examples:
        | state   |
        | absent  |
        | a draft |

    @id:plan-step-3
    Scenario Outline: A change that needs no plan gets none
      Given a change that needs no plan because <reason>
      When the owner runs /pap:plan for the change
      Then it stops, naming the reason and saying <next>
      And no planner starts and nothing is written

      Examples:
        | reason                              | next                                                              |
        | its class is bugfix                 | the build is launched with /pap:pm launch, or /change when solo   |
        | its class is chore                  | the build is launched with /pap:pm launch, or /change when solo   |
        | its class is docs                   | the build is launched with /pap:pm launch, or /change when solo   |
        | its class is spike                  | a spike has no spec and no plan                                   |
        | its change branch carries no intent | it is exempt under rule 20.2, or /intent comes first              |
        | it started unplanned                | the build goes on without a plan                                  |

    @id:plan-step-4 @pending:plan-step
    Scenario: /pap:plan is for a main session
      Given a sub-agent of any session
      When the sub-agent is given /pap:plan for a change
      Then it stops and reports that /pap:plan needs the main session
      And nothing is written

    @id:plan-step-5 @pending:plan-step
    Scenario: A second /pap:plan while a planner runs is refused
      Given a main session in which a planner is drafting the plan of "trial"
      When the owner runs /pap:plan for "trial" in that session
      Then it stops, saying the plan of "trial" is being drafted
      And no second planner starts

    @id:plan-step-6 @pending:plan-step
    Scenario: The planner writes nothing
      Given a planner drafting the plan of a change
      When the planner returns a complete plan draft
      Then it has changed no file, made no commit and pushed nothing
      And the main session has written the plan draft to changes/<slug>/plan.md, as data and unchanged

    @id:plan-step-7 @pending:plan-step
    Scenario Outline: A planner that fails leaves nothing behind
      Given a planner drafting the plan of a change
      When the planner <failure>
      Then nothing is written to the change's folder
      And the owner is told the draft failed, why, and that /pap:plan starts it again
      And no plan review starts and the owner is not asked for a yes

      Examples:
        | failure                                               |
        | ends without a report                                 |
        | returns a report missing the header or a section      |
        | reaches its cap of 200000 tokens across its runs      |
        | reaches its cap of 20 minutes for a run               |

    @id:plan-step-8
    Scenario: Plan files left uncommitted by an ended session are not silently reused
      Given a change whose work tree holds a plan draft that is not committed
      When the owner runs /pap:plan for the change
      Then the owner is shown the uncommitted plan draft and asked: resume it, or start again
      And nothing is overwritten before the owner answers

  Rule: The plan says how the change will be built, in two pages

    @id:plan-step-9
    Scenario: A plan draft carries the plan's header and sections
      Given a change whose spec is accepted
      When its plan is drafted
      Then the plan draft's header names the change's id and class, its spec, what drafted it, what reviewed it, the skill and the command typed
      And it has the sections Increments, Design, Fit, Tests and Observation, in that order, each with content or "none"
      And it carries no acceptance

    @id:plan-step-10 @pending:plan-step
    Scenario: Everything the spec asks for is reached by an increment and a test
      Given a change whose accepted spec lists scenarios, non-functional rows and signals
      When its plan is drafted
      Then every scenario id of the spec is named by at least one increment
      And Tests names, for every scenario id and every non-functional row, the test tier and the evidence that passes
      And Observation names, for every signal of the spec, the increment that builds it
      And Fit lists every protected path the build will touch, or says "none"

    @id:plan-step-11
    Scenario Outline: A plan is at most 1000 words
      Given a plan draft whose file, header included, counts <words> words by wc -w
      When the main session has written it
      Then <outcome>

      Examples:
        | words | outcome                                             |
        | 1000  | the plan review starts                              |
        | 1001  | the planner is sent back once to shorten it         |

    @id:plan-step-12
    Scenario: A plan draft still over 1000 words is kept and not put to the owner
      Given a plan draft the planner has already shortened once, or revised after its review, that counts more than 1000 words
      When the main session has written it
      Then the plan draft is committed with no acceptance
      And the owner is told the word count and to run /pap:plan again or narrow the spec
      And the owner is not asked for a yes

  Rule: A plan is reviewed by a sub-agent that did not draft it

    @id:plan-step-13 @pending:plan-step
    Scenario: A plan review follows the plan draft
      Given a plan draft of at most 1000 words, written to the change's folder
      When the plan review starts
      Then one sub-agent of type pap:plan-reviewer starts, given the change's slug and work tree and nothing of the planner's reasoning
      And it changes no file
      And the main session writes its findings to changes/<slug>/reviews/plan-review.md
      And each finding carries its viewpoint (conformance, design or verification), its severity and an empty disposition
      And the register's first lines give the planner's and the plan reviewer's tokens and minutes

    @id:plan-step-14 @pending:plan-step
    Scenario: A security-sensitive plan is also read from the security viewpoint
      Given a plan draft for a change of class security-sensitive
      When the plan review runs
      Then the plan review register also carries the security viewpoint, with its findings or "no findings"

    @id:plan-step-15 @pending:plan-step
    Scenario: Instructions embedded in a plan are a finding
      Given a plan draft that tells its reader to use a tool, a path or a scope the brief and the spec do not give
      When the plan review runs
      Then the plan review register carries a design finding naming the embedded instruction

    @id:plan-step-16 @pending:plan-step
    Scenario Outline: A plan review that fails blocks the yes
      Given a plan draft written to the change's folder
      When the plan reviewer <failure>
      Then no plan review register is written
      And the owner is told the review failed and that /pap:plan runs it again
      And the owner is not asked for a yes

      Examples:
        | failure                                    |
        | ends without a report                      |
        | returns findings that cannot be read       |
        | reaches its cap of 100000 tokens           |
        | reaches its cap of 20 minutes              |

    @id:plan-step-17 @pending:plan-step
    Scenario: The planner answers the review once
      Given a plan review register with findings
      When the planner is given the register
      Then it returns a revised plan draft once
      And each finding it resolved is marked "fixed" in the register with the section that changed
      And every other finding is left waiting for the owner
      And no second plan review runs

    @id:plan-step-18 @pending:plan-step
    Scenario: A plan review with no findings goes straight to the owner
      Given a plan review register that says "no findings"
      When the register is written
      Then the planner is not given it
      And the owner is told the plan is ready for a yes

    @id:plan-step-19 @pending:plan-step
    Scenario: A fault in the spec is a return to the spec
      Given a plan review that finds the spec missing a requirement
      When the plan review register is written
      Then the finding is marked "return: spec"
      And the planner cannot mark it fixed
      And its only dispositions are accepted, and rejected with a reason

    @id:plan-step-20 @pending:plan-step
    Scenario: An accepted return to the spec sends the owner back to /spec
      Given a reviewed plan draft with a finding marked "return: spec"
      When the owner gives that finding the disposition accepted
      Then the plan draft and its register are committed with no acceptance
      And the owner is told to run /spec for the change, then /pap:plan
      And the owner is not asked for a yes

  Rule: The owner's yes accepts the plan

    @id:plan-step-21 @pending:plan-step
    Scenario: The owner is told once, when the plan is ready
      Given a plan draft that has been reviewed and, where there were findings, answered once by the planner
      When the main session next replies to the owner
      Then the owner is told the plan is ready for a yes, with its word count and the number of findings waiting
      And the register's first lines give the time the owner was told
      And the owner is shown, in this order: what the planner changed in its answer, any finding marked "return: spec", the findings waiting with Blockers and Majors first, the protected paths in Fit, then the plan
      And each finding waiting comes with a proposed disposition

    @id:plan-step-22
    Scenario: The owner's yes is recorded in the plan and committed
      Given a reviewed plan draft whose every finding is fixed or has the owner's disposition
      When the owner says yes to the plan
      Then the plan records who said yes and when
      And the plan and the plan review register are committed on the change branch in one commit whose message starts "plan(<slug>): "
      And nothing is pushed and no pull request is opened
      And the owner is told that nothing was pushed, that a launch from another clone needs the branch there first, and what launches the build

    @id:plan-step-23 @pending:plan-step
    Scenario: No yes is taken while a finding waits for a disposition
      Given a reviewed plan draft with a finding that is neither fixed nor given a disposition
      When the owner says yes to the plan
      Then the plan is not accepted
      And the owner is asked for that finding's disposition

    @id:plan-step-24 @pending:plan-step
    Scenario: The owner asks for an edit before the yes
      Given a reviewed plan draft put to the owner
      When the owner asks for a change to the plan
      Then the change is made, the changed part is shown, and the owner is asked for a yes again
      And an edited plan of more than 1000 words is not accepted

    @id:plan-step-25
    Scenario Outline: A plan the owner does not accept
      Given a reviewed plan draft put to the owner, on a change branch where the plan was <before>
      When the owner answers <answer>
      Then <outcome>
      And the change branch still carries its accepted intent and spec

      Examples:
        | before  | answer | outcome                                                                                                                                  |
        | absent  | later  | the plan draft and its register are committed with no acceptance                                                                         |
        | absent  | no     | the owner is told the draft and the review are lost, nothing is committed, and the work tree holds no plan and no register               |
        | a draft | no     | the owner is told the new draft and review are lost, nothing is committed, and the work tree holds the plan draft as it was committed    |

    @id:plan-step-26
    Scenario Outline: A committed plan draft is resumed
      Given a change whose change branch carries a plan draft and its register, and whose spec <spec>
      When the owner runs /pap:plan for the change
      Then <outcome>

      Examples:
        | spec                                  | outcome                                                                                                   |
        | has no commit later than the draft's  | the owner is shown the draft and the register with the dispositions already given, and asked for a yes    |
        | has a commit later than the draft's   | a planner redrafts against the spec as it is now and a plan review runs again                             |

    @id:plan-step-27
    Scenario Outline: An edit to an accepted plan needs the owner's yes
      Given a change whose plan is accepted and whose change branch <code>
      When the owner runs /pap:plan for the change and asks for an edit that is <kind>
      Then the plan reviewer <review>
      And the edit is committed only on the owner's yes, with the acceptance kept and the edit noted in the plan
      And the commit's message <message>

      Examples:
        | code            | kind              | review                                 | message                                                    |
        | carries no code | wording only      | is not run                             | starts "plan(<slug>): "                                    |
        | carries no code | more than wording | re-reads the part the edit bears on    | starts "plan(<slug>): "                                    |
        | carries code    | more than wording | re-reads the part the edit bears on    | says it is plan rework and what the code surfaced          |

    @id:plan-step-28
    Scenario: A spec changed after the plan's yes makes the plan a draft again
      Given a change whose plan was accepted
      When its spec gains a commit later than the commit that accepted the plan
      Then the plan is a draft
      And /spec's reply to that commit tells the owner to run /pap:plan before the build

  Rule: The build is launched only with an accepted plan

    @id:plan-step-29
    Scenario Outline: A build launched without an accepted plan is refused
      Given a PM session whose event log has a restate event for "trial"
      And a complete brief for "trial" whose route is /change, whose class is <class> and whose second line names item 1 or item 2 of rule 20.2
      And the change "trial" did not start unplanned
      And <state>
      When the owner runs /pap:pm launch trial
      Then the launch is refused with exit code 20, saying <said>, and naming /pap:plan trial, its rule, and /change in a solo session for a refusal the owner believes is wrong
      And the event log gains no yes event and no launch event
      And no cycle starts
      And the launch record is used up
      And a line beside the launch record names "trial" and the reason

      Examples:
        | class              | state                                                                              | said                                           |
        | feature            | the plan of "trial" is absent                                                      | the plan is absent                             |
        | infra              | the plan of "trial" is absent                                                      | the plan is absent                             |
        | security-sensitive | the plan of "trial" is absent                                                      | the plan is absent                             |
        | feature            | the change branch carries a plan with no acceptance                                | the plan is a draft                            |
        | feature            | the change branch carries a plan whose acceptance names who but not when           | the plan is a draft                            |
        | feature            | the plan is accepted in the work tree and that is not committed                    | the plan is a draft                            |
        | feature            | the plan was accepted and the spec has a later commit                              | the spec changed after the plan's yes          |
        | infra              | the change branch carries code and a plan with no acceptance                       | the plan is a draft                            |
        | feature            | this clone has no change branch for "trial"                                        | the change branch cannot be read               |
        | feature            | the plan's header cannot be read                                                   | the plan cannot be read                        |

    @id:plan-step-30
    Scenario: The plan is checked last
      Given a PM session whose event log has no restate event for "trial"
      And the plan of "trial" is absent
      When the owner runs /pap:pm launch trial
      Then the launch is refused, saying the ask is restated first
      And nothing is said of the plan

    @id:plan-step-31
    Scenario Outline: A build with an accepted plan is launched
      Given a PM session whose event log has a restate event for "trial"
      And a complete brief for "trial" whose route is /change, whose class is <class> and whose second line names item 1 of rule 20.2
      And the plan of "trial" is accepted, on a change branch that carries no code
      When the owner runs /pap:pm launch trial
      Then the event log gains a yes event and a launch event for "trial" naming the route
      And the tracker is committed
      And then one cycle starts in the background, given the brief and nothing else

      Examples:
        | class              |
        | feature            |
        | infra              |
        | security-sensitive |

    @id:plan-step-32
    Scenario Outline: A launch that needs no plan is not refused for want of one
      Given a PM session whose event log has a restate event for "trial"
      And a complete brief for "trial" where <case>
      And the plan of "trial" is absent
      When the owner runs /pap:pm launch trial
      Then the event log gains a yes event and a launch event for "trial" naming the route
      And the tracker is committed
      And then one cycle starts in the background, given the brief and nothing else

      Examples:
        | case                                                                                           |
        | the route is /change and the class is bugfix                                                   |
        | the route is /change and the class is chore                                                    |
        | the route is /change and the class is docs                                                     |
        | the route is /change and the class is spike                                                    |
        | the route is /change, the class is feature and the second line names an exemption of rule 20.2 |
        | the route is /intent and the class is feature                                                  |
        | the route is /change, the class is infra and the change started unplanned                      |

  Rule: The build reads the plan and reports where it deviated

    @id:plan-step-33 @pending:plan-step
    Scenario: A cycle's pull request says how the build kept to the plan
      Given a cycle building a change whose plan is accepted
      When the cycle opens its draft pull request
      Then the pull request carries the line "Plan: changes/<slug>/plan.md, <n> deviations", where <n> may be 0
      And each deviation is listed with its increment, what differed and why
      And the cycle's report carries the same

    @id:plan-step-34 @pending:plan-step
    Scenario: A build of a change with no plan says so
      Given a cycle building a change that needs no plan and has none
      When the cycle opens its draft pull request
      Then the pull request carries the line "Plan: none"
      And the build is otherwise as it was before plan-step

    @id:plan-step-35 @pending:plan-step
    Scenario: A build does not start from a plan draft
      Given a change whose change branch carries a plan draft
      When /change is run for the change
      Then it stops before building and reports the plan draft: the owner has not accepted it

    @id:plan-step-36 @pending:plan-step
    Scenario: A plan does not widen a build
      Given a cycle building a change whose accepted plan names a tool, a path or a scope the brief and the spec do not give
      When the cycle reaches that part of the plan
      Then it does not act on it
      And it reports it as a deviation

  Rule: The PM and /spec know where the plan sits

    @id:plan-step-37
    Scenario: A PM session is told where the plan sits
      Given a PM session in an adopting repository with a product layer
      When the PM session starts
      Then the role names /pap:plan after /spec for feature, infra and security-sensitive changes
      And it says the brief of a build with an accepted plan does not restate the plan

    @id:plan-step-38 @pending:plan-step
    Scenario Outline: /spec hands on to the plan or to the build
      Given a change of class <class> whose spec the owner has just accepted
      When /spec hands on
      Then the owner is told <next> comes next

      Examples:
        | class              | next       |
        | feature            | /pap:plan  |
        | infra              | /pap:plan  |
        | security-sensitive | /pap:plan  |
        | bugfix             | the build  |
        | docs               | the build  |
