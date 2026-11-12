Feature: An agent of a PM session opens its pull request from a worktree, with its class label
  The guard refuses the two symptoms of a cycle that skipped /change: a
  pull request opened with no class label or from the main checkout, and
  the main checkout's branch switched. pap doctor reports a main checkout
  left off main.

  Background:
    Given an adopting repository whose main checkout is on main
    And a linked work tree of it on change/add-thing

  Rule: A change pull request carries its class label when it is opened

    @id:cycle-pr-guard-1
    Scenario Outline: gh pr create with no class label is refused
      Given a PM session
      When <caller> runs gh pr create in the linked work tree with <labels>
      Then the guard refuses it, naming rule 27.1, /change and the --label class:<class> to add
      And no pull request is opened

      Examples:
        | caller           | labels                         |
        | a sub-agent      | no label                       |
        | the main session | no label                       |
        | a sub-agent      | a label that is not a class    |
        | a sub-agent      | two class labels               |
        | a sub-agent      | a class label that is not one of the seven |
        | a sub-agent      | only a label given as a variable |
        | a sub-agent      | a class label in capitals      |

    @id:cycle-pr-guard-2
    Scenario Outline: gh pr create with one class label is let through
      Given a PM session
      When a sub-agent runs gh pr create in the linked work tree with <labels>
      Then the guard does not refuse it for its label

      Examples:
        | labels                                   |
        | --label class:bugfix                     |
        | -l class:docs                            |
        | --label class:infra and another label    |
        | --label "class:chore, another"           |
        | --label class:bugfix and a label given as a variable |

  Rule: A change pull request is opened from a linked work tree

    @id:cycle-pr-guard-3
    Scenario Outline: gh pr create in the main checkout is refused
      Given a PM session
      When a sub-agent runs gh pr create <where>, <labelled>
      Then the guard refuses it, naming rule 27.1, the work tree and /change
      And no pull request is opened

      Examples:
        | where                                              | labelled             |
        | in the main checkout                               | with a class label   |
        | after a cd into the main checkout                  | with a class label   |
        | in a directory under the main checkout             | with a class label   |
        | in the main checkout                               | with no label: the refusal is the main checkout's, and one line of kind pr-main-checkout is logged |

  Rule: An agent never switches the branch of the main checkout

    @id:cycle-pr-guard-4
    Scenario Outline: A switch of the main checkout's branch is refused
      Given a PM session
      When <caller> runs <command> in the main checkout
      Then the guard refuses it, naming rule 27.2, the work tree and /change
      And the main checkout is on main

      Examples:
        | caller           | command                               |
        | a sub-agent      | git switch change/add-thing           |
        | a sub-agent      | git switch -c change/other            |
        | a sub-agent      | git checkout change/add-thing         |
        | a sub-agent      | git checkout -b change/other          |
        | a sub-agent      | git checkout --detach                 |
        | a sub-agent      | git checkout origin/main              |
        | the main session | git switch change/add-thing           |
        | a sub-agent      | git -C <the main checkout> switch change/add-thing, run from the linked work tree |
        | a sub-agent      | git checkout change/add-thing --      |
        | a sub-agent      | git checkout -b change/other --       |
        | a sub-agent      | git checkout README.md                |
        | a sub-agent      | git checkout .                        |
        | a sub-agent      | git checkout -                        |
        | a sub-agent      | git switch -                          |

    @id:cycle-pr-guard-5
    Scenario Outline: What the main checkout is for keeps working
      Given a PM session
      When a sub-agent runs <command> in the main checkout
      Then the guard does not refuse it under rule 27.1 or 27.2

      Examples:
        | command                                             |
        | git switch main                                     |
        | git checkout main                                   |
        | git switch -q main                                  |
        | git checkout                                        |
        | git checkout -- README.md                           |
        | git checkout HEAD -- README.md                      |
        | git fetch origin                                    |
        | git pull                                            |
        | git worktree add ../x -b change/x origin/main       |
        | git worktree remove ../x                            |
        | git branch -D change/x                              |
        | git status                                          |
        | git worktree prune                                  |
        | git fetch --prune                                   |
        | git fetch --quiet --tags origin main                |

    @id:cycle-pr-guard-13
    Scenario Outline: A directory the guard cannot place is refused
      Given a PM session whose project is the adopting repository
      When a sub-agent runs <command>
      Then the guard refuses it, naming rule <rule> and to run it as its own command from the work tree

      Examples:
        | command                                                                 | rule |
        | git worktree add ../new -b change/new origin/main && cd ../new && gh pr create --label class:docs | 27.1 |
        | cd "$somewhere" && gh pr create --label class:docs                      | 27.1 |
        | cd "$somewhere" && git switch change/add-thing                          | 27.2 |
        | pushd <the main checkout> && git checkout change/add-thing              | 27.2 |
        | GIT_DIR=<the main checkout>/.git git switch change/add-thing            | 27.2 |

    @id:cycle-pr-guard-14
    Scenario Outline: gh pr create outside the repository is still bound by the session's project
      Given a PM session whose project is the adopting repository
      When a sub-agent runs gh pr create -R <owner>/<name> in a directory in no repository, with <labels>
      Then <outcome>

      Examples:
        | labels               | outcome                                             |
        | no label             | the guard refuses it, naming rule 27.1 and /change  |
        | --label class:bugfix | the guard does not refuse it under rule 27.1        |

    @id:cycle-pr-guard-6
    Scenario: A branch switched in a linked work tree is not this rule's
      Given a PM session
      When a sub-agent runs git switch -c change/other in the linked work tree
      Then the guard does not refuse it under rule 27.2

  Rule: The rules bind the agents of a PM session, in an adopting repository

    @id:cycle-pr-guard-7
    Scenario Outline: Outside a PM session, or outside an adopting repository, nothing new is refused
      Given <session> in <repository>
      When it runs gh pr create with no label, or git switch change/x in the main checkout
      Then the guard does not refuse it under rule 27.1 or 27.2

      Examples:
        | session                            | repository                         |
        | a solo session                     | an adopting repository             |
        | a session with no mode             | an adopting repository             |
        | a PM session                       | a repository that does not adopt PAP |

    @id:cycle-pr-guard-8
    Scenario: Whatever the guard refused before it refuses still
      Given the guard's test suite as it stood before this change
      When it is run against the guard as changed
      Then every case of it passes

  Rule: Each refusal is logged

    @id:cycle-pr-guard-9
    Scenario Outline: A refusal leaves one line in the refusal log
      Given a PM session
      When the guard refuses <what>
      Then the refusal log gains one line of kind <kind>, with the time, the session, the mode, the caller, the directory, the repository and the form refused, and never the whole command

      Examples:
        | what                                         | kind             |
        | gh pr create with no class label             | pr-label         |
        | gh pr create in the main checkout            | pr-main-checkout |
        | a switch of the main checkout's branch       | branch-switch    |
        | git checkout README.md in the main checkout  | path-without-dashes |
        | a command whose directory it cannot place    | unplaced         |

    @id:cycle-pr-guard-17
    Scenario: A refusal whose log line cannot be written is still made
      Given a PM session whose refusal log cannot be written
      When a sub-agent runs git switch change/add-thing in the main checkout
      Then the guard refuses it, and a third line says the refusal could not be logged

  Rule: pap doctor reports a main checkout that is off main

    @id:cycle-pr-guard-10 @pending:cycle-pr-guard
    Scenario Outline: pap doctor reads the main checkout
      Given the main checkout is <state>
      When the owner runs pap doctor in <where>
      Then it reports the main checkout as <report>

      Examples:
        | state                 | where                  | report                                              |
        | on main               | the main checkout      | ok                                                  |
        | on change/add-thing   | the main checkout      | drift, naming the branch and git switch main, and exits 1 |
        | at a detached commit  | the main checkout      | drift, saying it is detached, and exits 1           |
        | on change/other       | the linked work tree   | drift, naming the branch and the main checkout's path, and exits 1 |
        | on change/adopt-thing, in a repository that does not adopt PAP | the main checkout | skipped |

    @id:cycle-pr-guard-11 @pending:cycle-pr-guard
    Scenario: pap doctor outside a repository
      Given a directory in no git repository
      When the owner runs pap doctor
      Then it reports the main checkout as skipped

  Rule: A cycle that cannot label its pull request says so

    @id:cycle-pr-guard-12 @pending:cycle-pr-guard
    Scenario: A cycle's label command is denied
      Given a cycle whose pull request is open with no class label
      When its command to add the label is denied by Claude Code's permissions
      Then the cycle ends with ASK:, giving the owner the one command gh pr edit <number> --add-label class:<class>
      And it does not try the command another way

  Rule: A PM session is told when it starts with the main checkout off main

    @id:cycle-pr-guard-15 @pending:cycle-pr-guard
    Scenario Outline: The reading at session start
      Given the main checkout is <state>
      When a PM session starts
      Then <outcome>

      Examples:
        | state                | outcome                                                                                           |
        | on main              | the role and the session log line are as they were before this change                             |
        | on change/add-thing  | the session log line for that start names change/add-thing, and the role tells the session to tell the owner first and switch nothing |
        | at a detached commit | the session log line for that start says the main checkout is detached, and the role says the same |

  Rule: What the guard cannot read is recorded

    @id:cycle-pr-guard-16
    Scenario: A pull request command the guard cannot parse
      Given a PM session
      When a sub-agent runs a gh pr create the guard cannot parse
      Then the guard lets it through
      And the refusal log gains one line of kind unread
