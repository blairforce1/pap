Feature: pap runs as the project manager by default
  A session started by pap claude or pap new is the project manager: it
  proposes the route, interviews for intent and spec, launches a cycle for
  everything else, and itself writes only the PM paths.

  Rule: pap claude starts a PM session in an adopting repository

    @id:pm-mode-1
    Scenario: pap claude starts a PM session
      Given the owner is in an adopting repository
      When the owner runs pap claude
      Then a PM session starts
      And the session is given the project-manager role: the routes, the PM paths, and that it opens, approves and merges nothing
      And gh in the session acts as the agent installation
      And the session log gains one line naming PM, the repository and the Claude Code version, and one naming the role given at the start

    @id:pm-mode-2
    Scenario: A PM session with no product layer is told to propose /envision
      Given an adopting repository whose product layer is absent
      When a PM session starts
      Then the session is told that /envision is the route to propose first

    @id:pm-mode-3
    Scenario: A PM session with a product layer is told how to route an ask
      Given an adopting repository whose product layer is present
      When a PM session starts
      Then the session is told to answer a question and launch nothing
      And it is told to propose /intent for a ripe ask that rule 20.2 says needs one, and a cycle for any other ripe ask
      And it is told to propose a route only once the ask is ripe

    @id:pm-mode-4
    Scenario: The owner may still invoke a skill directly
      Given an adopting repository whose product layer is present
      When a PM session starts
      Then the session is told that a skill the owner invokes runs as invoked, with no route proposed in its place

    @id:pm-mode-5
    Scenario Outline: An ask with no route stops
      Given an adopting repository that is <repository>
      When a PM session starts
      Then the session is told that an ask with no route stops, and that it then <hand-on>
      And it is told to file nothing itself

      Examples:
        | repository                         | hand-on                                                                      |
        | pap itself | proposes an /intent for the missing route                                    |
        | not pap | gives the owner the text of an issue for blairforce1/pap, for the owner to file |

    @id:pm-mode-6
    Scenario: pap claude outside an adopting repository starts a session as before
      Given the owner is in a directory that is in no adopting repository
      When the owner runs pap claude
      Then a session starts that is not a PM session
      And the session is given no project-manager role
      And no write is refused as outside the PM paths

    @id:pm-mode-7
    Scenario: Arguments to pap claude still reach Claude Code
      Given the owner is in an adopting repository
      When the owner runs pap claude with arguments that are not pap's own
      Then a PM session starts with those arguments passed on unchanged

    @id:pm-mode-35
    Scenario: A session whose own calls carry an agent id is told the guard is not binding
      Given the owner is in an adopting repository
      And a Claude Code whose main session's tool calls carry an agent id
      When a PM session starts
      Then the role opens with a warning that the PM paths are not enforced in this session
      And the session is told to say so to the owner in its first line
      And the session log gains one line recording it, with the Claude Code version

    @id:pm-mode-47
    Scenario: The PM's first line tells the owner the mode and the way out
      Given the owner is in an adopting repository
      When a PM session starts
      Then the session is told to open with one line to the owner: that this is a PM session, that it writes only the PM paths, and that pap claude --solo starts a session without the mode

    @id:pm-mode-54
    Scenario: The role forbids clearing a blocked commit by stash, clean or delete
      Given the owner is in an adopting repository
      When a PM session starts
      Then the session is told that on a refused commit it reports the files and stops
      And it is told never to stash, clean, check out or delete a file to clear the block

    @id:pm-mode-50
    Scenario: Without the pap plugin a session has no mode, and says why
      Given the owner is in an adopting repository
      And the pap plugin is not installed
      When the owner runs pap claude
      Then pap claude says PM mode needs the pap plugin and gives the command that installs it
      And a session starts that is not a PM session
      And the session log gains one line naming no mode and the missing plugin

    @id:pm-mode-57
    Scenario: A session started without pap claude is not bound by the PM paths
      Given an adopting repository
      And a session in it that was started without pap claude, so it has no mode
      When the session writes bin/pap with Edit
      Then the write is not refused as outside the PM paths

  Rule: A solo session is the owner's to start

    @id:pm-mode-48
    Scenario: A solo session starts anywhere and is logged
      Given the owner is at their own terminal, in a directory that is in no adopting repository
      When the owner runs pap claude --solo
      Then a solo session starts
      And the session log gains one line naming solo

    @id:pm-mode-49
    Scenario Outline: A resume takes the mode of the start that resumed it
      Given a conversation that began in a <first> session in an adopting repository
      When the owner runs <command>
      Then a <second> session starts with that conversation

      Examples:
        | first | command                    | second |
        | solo  | pap claude --resume        | PM     |
        | PM    | pap claude --solo --resume | solo   |

    @id:pm-mode-51
    Scenario: /pap:pm works in a solo session
      Given a solo session in an adopting repository whose tracker is started and clean
      When the owner runs /pap:pm start
      Then the session reports what is in flight, what waits on the owner and what is next, from the state file

    @id:pm-mode-8
    Scenario: The owner starts a solo session
      Given the owner is in an adopting repository, at their own terminal
      When the owner runs pap claude --solo
      Then a solo session starts
      And the session is given one line saying it is solo, and no project-manager role
      And no write is refused as outside the PM paths
      And the session log gains one line naming solo and the repository

    @id:pm-mode-9
    Scenario Outline: A solo session is refused from an agent shell
      Given an agent shell known by <signal>
      When pap claude --solo is run
      Then it is refused, naming the signal and the command to run from the owner's own terminal
      And no session starts

      Examples:
        | signal                                |
        | the session marker Claude Code sets   |
        | the agent's gh directory in use       |
        | the agent's gh first on the path      |

  Rule: The PM session writes only the PM paths

    @id:pm-mode-10
    Scenario Outline: The PM session writes a PM path
      Given a PM session in an adopting repository
      When the PM session writes <path> with <tool>
      Then the write is made

      Examples:
        | path                                   | tool         |
        | changes/trial/intent.md                | Write        |
        | changes/trial/spec.md                  | Edit         |
        | changes/trial/reviews/spec-review.md   | Write        |
        | features/trial.feature                 | Write        |
        | product/domain.md                      | Edit         |
        | product/backlog.md                     | Edit         |
        | the tracker's state file               | Write        |
        | the tracker's event log                | Edit         |
        | changes/trial/reviews/deep/notes.md    | Write        |
        | features/a.b-c_d.feature               | Write        |

    @id:pm-mode-11
    Scenario Outline: The PM session is refused a write outside the PM paths
      Given a PM session in an adopting repository
      When the PM session writes <path> with <tool>
      Then the write is refused and the file is unchanged
      And the refusal names the rule, the path, and the routes: a cycle through /pap:pm launch, or /intent for a change that needs one
      And the refusal log gains one line naming the session, the mode, the main session as the caller, and the path

      Examples:
        | path                               | tool         |
        | bin/pap                            | Edit         |
        | rules.md                           | Edit         |
        | decisions/0025-a-new-record.md     | Write        |
        | plugins/pap/hooks/guard-route.sh   | Edit         |
        | tests/guard-route.test.sh          | Write        |
        | CLAUDE.md                          | Edit         |
        | README.md                          | Write        |
        | features/README.md                 | Write        |
        | changes/notes.md                   | Write        |
        | docs/analysis.ipynb                | NotebookEdit |
        | features/sub/trial.feature         | Write        |
        | features/trial.txt                 | Write        |
        | changes/-bad/intent.md             | Write        |

    @id:pm-mode-12
    Scenario Outline: A path is judged by where it resolves
      Given a PM session in an adopting repository
      When the PM session writes a path that <form> and resolves outside the PM paths
      Then the write is refused

      Examples:
        | form                                             |
        | starts under changes/trial/ and climbs out with .. |
        | goes through a symbolic link under changes/trial/  |

    @id:pm-mode-13
    Scenario: A write outside every adopting repository passes
      Given a PM session in an adopting repository
      When the PM session writes a file in a scratch directory or the session's memory, in no adopting repository
      Then the write is made

    @id:pm-mode-36
    Scenario Outline: The guard's own files are refused to the PM session
      Given a PM session in an adopting repository
      When the PM session writes <file> with Edit or Write
      Then the write is refused and the file is unchanged
      And the refusal says the file belongs to the guard and names no route

      Examples:
        | file                                                  |
        | Claude Code's user settings file                      |
        | the project's Claude Code settings file               |
        | a hook in the directory the pap plugin runs from      |
        | the refusal log                                       |
        | the session log                                       |

    @id:pm-mode-38
    Scenario: A first write into a new change folder is judged from its deepest existing parent
      Given a PM session in an adopting repository with no changes/newslug/ folder
      When the PM session writes changes/newslug/intent.md with Write
      Then the write is made

    @id:pm-mode-39
    Scenario: A path the guard cannot resolve is refused
      Given a PM session in an adopting repository
      When the PM session writes a path that goes through a symbolic link pointing at nothing
      Then the write is refused, saying the path could not be resolved

    @id:pm-mode-14
    Scenario: The PM session is refused a write in another adopting repository
      Given a PM session in an adopting repository
      And a second adopting repository on the machine
      When the PM session writes bin/pap in the second repository
      Then the write is refused
      And the refusal says the change belongs to that repository's own PM session, and names no /pap:pm launch

    @id:pm-mode-52
    Scenario Outline: The PM session writes nothing in another adopting repository, the PM paths included
      Given a PM session in an adopting repository
      And <second>, a second adopting repository on the machine
      When the PM session writes changes/trial/intent.md in the second repository
      Then the write is refused
      And the refusal names <instead>

      Examples:
        | second                        | instead                                                  |
        | pap itself                    | the text of an issue for blairforce1/pap, for the owner to file |
        | a repository that is not pap  | that repository's own PM session                         |

    @id:pm-mode-15
    Scenario: A commit of PM paths only passes
      Given a PM session in an adopting repository
      And a work tree on change/trial whose only changes are under the PM paths
      When the PM session commits in that work tree
      Then the commit is not refused as outside the PM paths

    @id:pm-mode-16
    Scenario Outline: A commit from a work tree holding a change outside the PM paths is refused
      Given a PM session in an adopting repository
      And a work tree on change/trial holding <change> to bin/pap
      When the PM session commits in that work tree
      Then the commit is refused, saying the whole work tree is judged and naming bin/pap
      And the refusal names committing from the change's own work tree, or the file's owner moving it, and names no route
      And nothing is committed
      And the refusal log gains one line naming the session and bin/pap

      Examples:
        | change                |
        | a staged change       |
        | an unstaged change    |

    @id:pm-mode-17
    Scenario: A new untracked file outside the PM paths stops the commit
      Given a PM session in an adopting repository
      And a work tree on change/trial holding an untracked file notes.md that is not ignored
      When the PM session commits in that work tree
      Then the commit is refused, saying the whole work tree is judged and naming notes.md

    @id:pm-mode-37
    Scenario Outline: Other commands that write a commit are not judged against the PM paths
      Given a PM session in an adopting repository
      And a work tree on change/trial
      When the PM session runs <command> there
      Then the command is not refused as outside the PM paths

      Examples:
        | command                 |
        | git merge main          |
        | git cherry-pick abc1234 |
        | git revert abc1234      |
        | git rebase main         |

    @id:pm-mode-55
    Scenario Outline: A command that sets or unsets the mode is refused
      Given a PM session in an adopting repository
      When the PM session runs <command>
      Then the command is refused, saying the mode is set by pap claude and stays so

      Examples:
        | command                      |
        | PAP_MODE=solo claude -p hi   |
        | env -u PAP_MODE claude -p hi |
        | export PAP_MODE=solo         |
        | unset PAP_MODE               |

  Rule: A sub-agent is not bound by the PM paths

    @id:pm-mode-18
    Scenario Outline: A sub-agent of a PM session writes any path
      Given a PM session in an adopting repository
      When a sub-agent of type <type> writes <path>
      Then the write is made

      Examples:
        | type                   | path                               |
        | pap:cycle              | bin/pap                            |
        | pap:cycle              | plugins/pap/hooks/guard-route.sh   |
        | pap:cycle              | rules.md                           |
        | pap:cycle              | tests/guard-route.test.sh          |
        | pap:cycle-mechanical   | CHANGELOG.md                       |
        | general-purpose        | docs/run-a-project.md              |

    @id:pm-mode-19
    Scenario: A sub-agent of a PM session commits a change outside the PM paths
      Given a PM session in an adopting repository
      And a work tree on change/trial holding a staged change to bin/pap
      When a sub-agent of type pap:cycle commits in that work tree
      Then the commit is not refused as outside the PM paths

    @id:pm-mode-20
    Scenario Outline: What was refused before is still refused, whoever calls
      Given a <caller> in an adopting repository
      When the caller runs <command>
      Then the command is refused as it was before pm-mode

      Examples:
        | caller                        | command                                  |
        | PM session                    | git commit --no-verify                   |
        | PM session                    | gh pr merge 1                            |
        | PM session                    | gh pr edit 1 --add-label owner-reviewed  |
        | PM session                    | git push --force                         |
        | solo session                  | git commit --no-verify                   |
        | solo session                  | gh pr merge 1                            |
        | sub-agent of a PM session     | git commit --no-verify                   |
        | sub-agent of a PM session     | gh pr merge 1                            |
        | sub-agent of a PM session     | git push --force                         |

    @id:pm-mode-21
    Scenario: A tool call the guard cannot read is reported, not blocked
      Given a PM session in an adopting repository
      And the guard cannot read the tool call
      When the PM session writes bin/pap
      Then the guard says it could not read the call
      And the refusal log gains one line of the unread kind
      And the write is not blocked by the guard

  Rule: The PM session resumes from the committed tracker

    @id:pm-mode-22
    Scenario: /pap:pm start starts the tracker
      Given a PM session in an adopting repository whose tracker is absent
      When the owner runs /pap:pm start
      Then the tracker is started outside the repository, with a state file and an event log
      And the event log's first line is a start event
      And the tracker is committed

    @id:pm-mode-56
    Scenario: A repository whose key changed is told where its tracker is
      Given an adopting repository whose tracker was started before it had an origin
      And the repository now has an origin
      When the owner runs /pap:pm start
      Then the session says the tracker is under the repository's earlier key, and uses it
      And no second tracker is started

    @id:pm-mode-23
    Scenario: /pap:pm start reports where things stand
      Given a PM session in an adopting repository whose tracker is started and clean
      When the owner runs /pap:pm start
      Then the session reports what is in flight, what waits on the owner and what is next, from the state file
      And nothing is launched

    @id:pm-mode-24
    Scenario: /pap:pm start stops on an uncommitted tracker
      Given a PM session in an adopting repository whose tracker is uncommitted
      When the owner runs /pap:pm start
      Then the session shows the uncommitted change as a diff, file by file, with its likely cause
      And it asks the owner whether to commit or discard it
      And nothing else is done until the owner answers

    @id:pm-mode-53
    Scenario: Discarding an uncommitted tracker takes a second yes
      Given a PM session in an adopting repository whose tracker is uncommitted
      And the owner has answered discard once
      When the owner confirms the discard
      Then the tracker is clean and the uncommitted change is gone
      And until that confirmation the tracker was unchanged

    @id:pm-mode-25
    Scenario Outline: A PM session is given the role and the state again
      Given a PM session in an adopting repository whose tracker is started
      When the session <restarts>
      Then the session is given the project-manager role again
      And it is given the state file, up to its first 60 lines, and whether the tracker is uncommitted
      And it is told to report where things stand and to launch and resume nothing until the owner says

      Examples:
        | restarts                        |
        | starts after a /clear           |
        | is resumed                      |
        | starts after a compaction       |

    @id:pm-mode-26
    Scenario: A PM session with no tracker is told to start one
      Given a PM session in an adopting repository whose tracker is absent
      When a PM session starts
      Then the session is told that /pap:pm start comes before the first launch

    @id:pm-mode-27
    Scenario Outline: A tracker kept in a companion clone is pushed on every commit
      Given the owner has pointed the tracker at a clone of a companion repository
      And the companion's remote <outcome>
      When the tracker is committed
      Then <result>

      Examples:
        | outcome   | result                                                                  |
        | accepts pushes | the commit is on the companion's remote                                 |
        | rejects pushes | the session is told the tracker is committed but not pushed, and why    |

  Rule: The owner launches a cycle, from a brief with a route, after the ask is restated

    @id:pm-mode-28
    Scenario: A launch without a restated ask is refused
      Given a PM session whose tracker is started
      And the event log has no restate event for "trial"
      When the owner runs /pap:pm launch trial
      Then the launch is refused, saying the ask is restated first
      And no cycle starts

    @id:pm-mode-40
    Scenario: A launch the owner did not type is refused
      Given a PM session whose event log has a restate event for "trial"
      And a complete brief for "trial"
      And no launch record for "trial"
      When the PM session invokes /pap:pm launch trial itself
      Then the launch is refused, saying the owner types the command
      And the event log gains no yes event and no launch event
      And no cycle starts

    @id:pm-mode-29
    Scenario Outline: A launch from an incomplete brief is refused
      Given a PM session whose event log has a restate event for "trial"
      And the brief for "trial" lacks <part>
      When the owner runs /pap:pm launch trial
      Then the launch is refused, naming the part and its rule
      And no cycle starts

      Examples:
        | part                                       |
        | a first line naming its route              |
        | a second line naming the item of rule 20.2 |
        | a budget in tokens or wall time            |

    @id:pm-mode-30
    Scenario Outline: A launch starts one cycle in the background
      Given a PM session whose event log has a restate event for "trial"
      And a complete brief for "trial" whose change is <kind>
      When the owner runs /pap:pm launch trial
      Then the event log gains a yes event and a launch event for "trial" naming the route
      And the state file lists "trial" as in flight
      And the tracker is committed
      And then one cycle starts in the background as a sub-agent of type <type>, given the brief and nothing else

      Examples:
        | kind           | type                 |
        | not mechanical | pap:cycle            |
        | mechanical     | pap:cycle-mechanical |

    @id:pm-mode-31
    Scenario: A second launch of a cycle in flight is refused
      Given a PM session whose event log has a launch event for "trial" and no later report, pause, merge or abandoned decision for it
      When the owner runs /pap:pm launch trial
      Then the launch is refused, saying "trial" is in flight
      And no cycle starts

    @id:pm-mode-43
    Scenario: An abandoned cycle is no longer in flight
      Given a PM session whose event log has a launch event for "trial"
      And a later decision event for "trial" whose text starts "abandoned"
      When the owner runs /pap:pm start
      Then the state file does not list "trial" as in flight

    @id:pm-mode-44
    Scenario: A launch whose tracker commit fails starts no cycle
      Given a PM session whose event log has a restate event for "trial"
      And a complete brief for "trial"
      And a tracker whose commit will fail
      When the owner runs /pap:pm launch trial
      Then the launch is refused, saying the tracker could not be committed
      And no cycle starts

    @id:pm-mode-45
    Scenario: An event log line that cannot be read stops the launch
      Given a PM session whose event log has a restate event for "trial"
      And a line in the event log that is not four tab-separated fields
      When the owner runs /pap:pm launch trial
      Then the launch is refused, naming the line and the format
      And no cycle starts

    @id:pm-mode-41
    Scenario: A second PM session does not write the tracker
      Given a PM session that holds the tracker
      And a second PM session in the same adopting repository
      When the owner runs /pap:pm start in the second session
      Then the second session is told which session holds the tracker
      And the tracker is unchanged

    @id:pm-mode-42
    Scenario: A lock left by an ended session is taken over
      Given a tracker whose lock names a session that has ended
      When the owner runs /pap:pm start
      Then the session takes the lock and says it took it over
      And the session reports where things stand

    @id:pm-mode-32
    Scenario: A cycle's pull request carries its route
      Given a cycle launched from a brief whose first two lines name its route and its item of rule 20.2
      When the cycle opens its draft pull request
      Then the pull request's body carries a Route line with that route and that item

    @id:pm-mode-33
    Scenario: /pap:pm is for the PM session only
      Given a sub-agent of a PM session
      When the sub-agent runs the /pap:pm script
      Then the guard refuses it, saying /pap:pm needs the PM session
      And the tracker is unchanged

    @id:pm-mode-46
    Scenario: A message to a cycle is logged by the guard
      Given a PM session with a cycle in flight
      When the PM session sends the cycle a message
      Then the message log gains one line naming the session and the cycle's sub-agent
      And the PM session wrote none of it

  Rule: pap new ends in a PM session

    @id:pm-mode-34
    Scenario: The welcome session is a PM session
      Given a run of pap new "trial" has minted an agent token
      And the pap plugin is installed
      When the welcome session starts
      Then it is a PM session in the clone
      And it is given what the run did and what is installed, as before
      And it is told that /envision is the route to propose first, and to start nothing until the owner answers
