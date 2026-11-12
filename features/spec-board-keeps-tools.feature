Feature: /spec writes the spec review register in the turn the review returns
  The spec review that /spec runs is read by sub-agents that cannot edit,
  write or run a shell. The main session keeps its own tools, so the
  register is on disk before the owner is asked for a disposition.

  Rule: The register is written in the turn the spec review returns

    @id:spec-board-keeps-tools-1
    Scenario Outline: The register is written before any disposition is asked
      Given a change of class <class> whose spec is a draft
      And the owner ran /spec for the change in a main session
      When the spec review returns
      Then the session writes the spec review register in that turn
      And it asks the owner for no disposition before the register is written

      Examples:
        | class   |
        | bugfix  |
        | feature |

    @id:spec-board-keeps-tools-2
    Scenario: An accepted finding is applied in the turn it is accepted
      Given a spec review returned in this turn and its spec review register is written
      And the session asked the owner, in that turn, for the dispositions of the first findings
      When the owner accepts a finding in that turn
      Then the session changes the spec draft in that turn
      And it records the disposition in the spec review register in that turn
      And nothing is committed before the owner's yes to the spec

  Rule: The spec review reads and changes nothing

    @id:spec-board-keeps-tools-3
    Scenario: A perspective is read by a sub-agent that cannot change a file
      Given a change whose spec is a draft
      When /spec starts a spec review
      Then each perspective is read by a sub-agent of its own
      And no such sub-agent holds a tool that edits, writes, runs a shell or starts a sub-agent
      And the main session invokes no skill of the spec-review plugin

    @id:spec-board-keeps-tools-4
    Scenario: A perspective invoked directly runs as before
      Given the spec-review plugin is installed and the pap plugin is not
      When a person invokes a perspective or the whole board on a spec
      Then it runs in the conversation and returns its findings there
      And it holds no tool that edits, writes or runs a shell while it runs

  Rule: /spec waits for every perspective

    @id:spec-board-keeps-tools-5
    Scenario: A spec review still running is not consolidated
      Given a spec review of more than one perspective is running
      When a perspective reports and another has not
      Then the session consolidates nothing and writes no spec review register
      And the owner is told in one line, each time a perspective reports, how many have reported, of how many

    @id:spec-board-keeps-tools-6
    Scenario: A perspective that fails is started once more
      Given a spec review is running
      When a perspective fails for the first time
      Then the session starts that perspective once more
      And the spec review stays running

    @id:spec-board-keeps-tools-7
    Scenario: A perspective that fails twice is named, and the review is not passed off as whole
      Given a spec review is running and a perspective has failed once
      When that perspective fails again
      Then the owner is told which perspective failed and asked whether to go on without it
      And a spec review register written without it names it as not run

  Rule: /spec starts no reader it cannot vouch for

    @id:spec-board-keeps-tools-8
    Scenario Outline: /spec stops when it cannot start a perspective's sub-agent
      Given a change whose spec is a draft
      And <what is missing>
      When /spec starts a spec review
      Then it stops, saying <what to do>
      And no sub-agent of any other type starts and no spec review register is written

      Examples:
        | what is missing                                             | what to do                         |
        | the spec-review plugin is not installed                     | to install the spec-review plugin  |
        | the session has no sub-agent type that reads a perspective  | to start a new session             |
