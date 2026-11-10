Feature: The owner starts a greenfield repository with one command

  Rule: Preflight creates nothing

    @id:pap-new-3
    Scenario Outline: A name GitHub would not take is refused
      Given the owner is ready to create "trial"
      When the owner runs pap new "<name>"
      Then the run stops in preflight naming the name rule
      And nothing is created

      Examples:
        | name                    |
        | not a name              |
        | tri/al                  |
        | .                       |
        | ..                      |
        | -trial                  |
        | a name of 101 letters   |

    @id:pap-new-17
    Scenario: An owner that is not a GitHub login is refused
      Given the owner is ready to create "trial"
      When the owner runs pap new "trial" with owner "bad_owner"
      Then the run stops in preflight naming the owner
      And nothing is created

    @id:pap-new-20
    Scenario Outline: An unknown layer or visibility is refused
      Given the owner is ready to create "trial"
      When the owner runs pap new "trial" with <parameter> "<value>"
      Then the run stops in preflight naming the <parameter> and the values it takes
      And nothing is created

      Examples:
        | parameter  | value    |
        | layers     | rust     |
        | layers     | ../x     |
        | visibility | internal |

    @id:pap-new-4
    Scenario Outline: A run from an agent shell is refused before any sign-in is offered
      Given the shell is an agent shell by <signal>
      When pap new "trial" is run
      Then the run stops in preflight saying it is the owner's to run
      And it prints the command to run from the owner's own terminal
      And no sign-in is offered
      And nothing is created

      Examples:
        | signal                                        |
        | the session marker                            |
        | the agent's gh directory, without the marker  |
        | the agent's gh first on the path, without the marker |

    @id:pap-new-21
    Scenario: A run with no terminal stops in preflight
      Given the owner is ready to create "trial"
      And the run has no terminal to prompt on
      When pap new "trial" is run
      Then the run stops in preflight saying it needs a terminal
      And nothing is created
      And no welcome session starts

    @id:pap-new-25
    Scenario: GitHub out of reach is not taken for signed out
      Given GitHub cannot be reached
      When the owner runs pap new "trial"
      Then the run stops in preflight naming the network
      And no sign-in is offered

    @id:pap-new-5
    Scenario: A signed-out owner is offered the sign-in
      Given the owner sign-in is signed out
      When the owner runs pap new "trial"
      Then the run offers gh auth login in the owner's gh directory
      And it rechecks the owner sign-in after the offer is taken

    @id:pap-new-6
    Scenario: A missing workflow scope is offered the refresh
      Given the owner sign-in lacks the workflow scope
      When the owner runs pap new "trial"
      Then the run offers gh auth refresh for the workflow scope in the owner's gh directory
      And it rechecks the owner sign-in after the offer is taken

    @id:pap-new-18
    Scenario: A declined sign-in offer stops the run
      Given the owner sign-in is signed out
      And the owner declines the sign-in offer
      When the owner runs pap new "trial"
      Then the run stops in preflight naming the owner sign-in
      And nothing is created

    @id:pap-new-7
    Scenario: A sign-in whose scopes cannot be read is reported and let through
      Given the owner sign-in reports no scopes
      And the agent app is registered with an all-repositories installation on the owner
      When the owner runs pap new "trial"
      Then the run says the scopes could not be checked and that the first push may be refused
      And the run goes on past the sign-in check

    @id:pap-new-8
    Scenario: An unregistered agent app stops the run
      Given the owner sign-in is sufficient
      And the agent app is unregistered
      When the owner runs pap new "trial"
      Then the run stops in preflight naming pap agent-setup
      And nothing is created

    @id:pap-new-19
    Scenario: An agent app not installed on the owner stops the run
      Given the owner sign-in is sufficient
      And the agent app is registered with no installation on the owner
      When the owner runs pap new "trial"
      Then the run stops in preflight naming the page where the agent app is installed
      And nothing is created

    @id:pap-new-9
    Scenario: A selected-repositories installation is warned of before creation
      Given the owner sign-in is sufficient
      And the agent app is registered with a selected-repositories installation on the owner
      When the owner runs pap new "trial"
      Then preflight reports the installation as selected-repositories
      And it says one prompted step will follow creation, adding "trial" to the installation
      And the run goes on to the summary

    @id:pap-new-23
    Scenario Outline: A run that will leave a prompted step says so before creation
      Given the owner is ready to create "trial"
      When the owner runs pap new "trial" with <parameter> "<value>"
      Then preflight names the step that will be left for the owner and where it is done
      And the run goes on to the summary

      Examples:
        | parameter  | value  |
        | visibility | public |
        | owner      | acme   |

    @id:pap-new-24
    Scenario: An organisation ruleset that would refuse the first push stops the run
      Given the owner is ready to create "trial" for the organisation "acme"
      And "acme" has a ruleset on the default branch of every repository
      When the owner runs pap new "trial" with owner "acme"
      Then the run stops in preflight naming that ruleset
      And nothing is created

    @id:pap-new-27
    Scenario: A private repository that can have no main ruleset stops the run
      Given the owner is ready to create "trial"
      And the owner's plan has no rulesets for private repositories
      When the owner runs pap new "trial"
      Then the run stops in preflight saying a private repository would have no main ruleset
      And nothing is created

    @id:pap-new-22
    Scenario: The summary waits for the owner before anything is created
      Given the owner is ready to create "trial"
      When the owner runs pap new "trial"
      Then the summary shows the login acted as, the owner and name, the visibility, the layers, and the author name and email of the first commit
      And nothing is created until the owner confirms

    @id:pap-new-28
    Scenario: A declined summary stops the run
      Given the owner is ready to create "trial"
      And the owner declines the summary
      When the owner runs pap new "trial"
      Then the run stops in preflight
      And nothing is created

  Rule: Creation runs in one order and never past a missing control

    @id:pap-new-1
    Scenario: A fresh run reaches the welcome session
      Given the owner is ready to create "trial"
      When the owner runs pap new "trial" and confirms the summary
      Then each step is named as it starts
      And a private greenfield repository "trial" exists for the owner
      And the applied version and the layers base, risk and dotnet are recorded in it
      And main holds exactly one commit, the template and a README whose only line is "# trial"
      And the clone's remote is HTTPS on github.com
      And the clone's working tree is clean
      And the repository settings are applied
      And a welcome session starts in the clone as the agent

    @id:pap-new-2
    Scenario: Named visibility, layers and owner are used
      Given the owner is ready to create "trial" for the organisation "acme"
      When the owner runs pap new "trial" with visibility public, layers base and go, and owner "acme", and confirms the summary
      Then a public greenfield repository "trial" exists for "acme"
      And the layers base and go are recorded in it

    @id:pap-new-10
    Scenario: The first push meets no hook and no ruleset
      Given the owner is ready to create "trial"
      When the owner runs pap new "trial" and confirms the summary
      Then the first push happens before clone setup and before the repository settings are applied
      And it is the only push to main the run makes
      And no git call in the run skips a hook
      And the main ruleset has no bypass actor

    @id:pap-new-26
    Scenario: Hooks found before the first push stop the run
      Given a run of pap new "trial" stopped with the greenfield repository created
      And the clone has git hooks installed
      When the owner runs pap new "trial" again
      Then the run stops at the first push naming the hooks
      And nothing is pushed

    @id:pap-new-30
    Scenario: A refused first push names what refused it
      Given a run of pap new "trial" has created the greenfield repository
      And the owner sign-in may not push workflows
      When the first push is refused
      Then the run stops at the first push naming the missing permission
      And it says main is not yet protected and gives the command to run again

    @id:pap-new-29
    Scenario: A stop says where the run is and how to go on
      Given a run of pap new "trial" with owner "acme" has set up the clone
      When applying the repository settings fails
      Then the run stops naming the step and its number of six
      And it says what exists so far and the cause
      And it gives the command to run again, with the owner "acme"
      And it ends with a one-line count of steps done and prompts taken

    @id:pap-new-31
    Scenario: No main ruleset means no agent token
      Given a run of pap new "trial" has set up the clone
      When the repository settings are applied without a main ruleset
      Then the run stops at the repository settings naming the main ruleset
      And no agent token is requested
      And no welcome session starts

    @id:pap-new-11
    Scenario: An agent token the installation does not cover waits for the owner
      Given a run of pap new "trial" has applied the repository settings
      And the agent installation does not cover "trial"
      When an agent token is requested
      Then the run says the installation does not cover "trial", prints its settings URL and waits for Enter
      And on Enter it requests the agent token again
      And no welcome session starts until an agent token is minted

    @id:pap-new-32
    Scenario: Leaving the wait for the agent token is a stop the owner can resume
      Given a run of pap new "trial" is waiting for Enter at the agent token
      When the owner interrupts the run
      Then the run stops at the agent token and gives the command to run again
      And no welcome session starts

  Rule: A re-run goes on from what exists and repeats no commit, creation or push

    @id:pap-new-12
    Scenario Outline: A re-run picks up where the last run stopped
      Given a run of pap new "trial" stopped with the greenfield repository <state>
      When the owner runs pap new "trial" again
      Then no commit, repository creation or push already made is made again
      And the run reaches the welcome session
      And main holds exactly one commit

      Examples:
        | state            |
        | committed        |
        | created          |
        | pushed           |
        | set up           |
        | settings applied |

    @id:pap-new-33
    Scenario: An interrupted first commit leaves nothing behind
      Given a run of pap new "trial" was interrupted while making the first commit
      When the owner runs pap new "trial" again
      Then the run makes the first commit and reaches the welcome session

    @id:pap-new-34
    Scenario: A pushed repository with no clone is cloned again
      Given the greenfield repository "trial" is pushed
      And no directory named "trial" exists
      When the owner runs pap new "trial"
      Then the run clones "trial" and goes on from clone setup
      And nothing is pushed

    @id:pap-new-35
    Scenario Outline: A re-run of a complete run welcomes again and changes nothing
      Given the greenfield repository "trial" is welcomed
      And main holds <commits>
      When the owner runs pap new "trial" again
      Then no commit, repository creation or push is made
      And the repository settings are not written
      And a welcome session starts in the clone as the agent

      Examples:
        | commits                                        |
        | only the first commit                          |
        | the first commit and later merged pull requests |

    @id:pap-new-36
    Scenario: A re-run that names other parameters is refused
      Given a run of pap new "trial" with layers base and go stopped with the greenfield repository committed
      When the owner runs pap new "trial" with layers base and dotnet
      Then the run stops naming the recorded layers
      And nothing is changed

    @id:pap-new-13
    Scenario Outline: Something of that name that is not this command's own is left alone
      Given <what exists> named "trial"
      When the owner runs pap new "trial"
      Then the run stops naming what it found and why it is not its own
      And it offers another name or the brownfield runbook
      And nothing is changed

      Examples:
        | what exists                                                    |
        | a repository on GitHub whose first commit is not the template  |
        | an empty repository on GitHub and no clone                     |
        | a local directory that is not a git repository                 |
        | a local clone of another repository                            |
        | a clone whose first commit differs from the repository's       |

  Rule: The welcome session is the agent's, and is told only what the run knows

    @id:pap-new-14
    Scenario: The welcome session is given what happened and what is installed
      Given a run of pap new "trial" has minted an agent token
      And the pap plugin is installed
      When the welcome session starts
      Then the run first prints the repository's URL, the clone's path and how to start the session again
      And the session is given a welcome to the Personal Agentic Process, what the run did and where the owner is
      And it is given the installed skills, mods and agents by name and description, /envision among them, as text to show
      And it is told to ask what the owner wants next and to start none of them
      And nothing is read from the network

    @id:pap-new-15
    Scenario: A machine without the pap plugin is told so in the welcome
      Given a run of pap new "trial" has minted an agent token
      And the pap plugin is not installed
      When the welcome session starts
      Then the session is given what the run did and where the owner is
      And it is given that the pap plugin is not installed, with the command that installs it

    @id:pap-new-37
    Scenario: The welcome session holds nothing of the owner's
      Given a run of pap new "trial" has minted an agent token
      When the welcome session starts
      Then gh in the session acts as the agent installation
      And no owner token and no owner gh directory is in the session's environment

    @id:pap-new-38
    Scenario: No token is shown or written
      Given the owner is ready to create "trial"
      When the owner runs pap new "trial" and confirms the summary
      Then no token appears in the run's output, in the clone or in any command line

    @id:pap-new-39
    Scenario: Only the repo and workflow scopes are asked for
      Given the owner sign-in lacks the workflow scope
      When the owner runs pap new "trial"
      Then the scope refresh asks for workflow and for nothing else

  Rule: A release carries the install prompt's version

    @id:pap-new-16
    Scenario: A release whose install prompt names another version is refused
      Given the install prompt names version "0.17.0"
      When a release of version "0.18.0" is cut
      Then the release is refused naming both versions
      And no release is created

    @id:pap-new-40
    Scenario: A release whose install prompt names its version goes on
      Given the install prompt names version "0.18.0"
      When a release of version "0.18.0" is cut
      Then the release is not refused for the install prompt
