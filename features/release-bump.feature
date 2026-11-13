Feature: One command makes a pap release bump end to end
  The owner names the next version. The release-bump command makes the
  release bump: the version places, the dated unreleased section, the work
  tree, the commit, the push and the draft pull request with its class
  label. A mechanical cycle runs it, watches the checks and verifies.

  Background:
    Given origin/main whose version places agree on 0.19.1
    And whose unreleased section holds at least one line
    And no change/release-0.20.0 branch, locally or on origin, no work tree for it and nothing at its path

  Rule: The command opens one draft pull request carrying only the bump

    @id:release-bump-1 @pending:release-bump
    Scenario: The command opens a draft pull request
      When the release-bump command is run for 0.20.0
      Then one draft pull request is open from change/release-0.20.0
      And it was made in a linked work tree from origin/main as fetched by that run
      And its title is "chore(release): bump pap to 0.20.0"
      And it carries exactly one class label, class:chore
      And the command exits 0 and prints the pull request's URL
      And the checkout it was run from has the same branch, HEAD and index as before

    @id:release-bump-2 @pending:release-bump
    Scenario: The diff is exactly the release bump's lines
      When the release-bump command is run for 0.20.0
      Then the version places agree on 0.20.0
      And the only other lines changed are the unreleased heading renamed, one empty "### [Unreleased]" heading and one blank line added above it
      And no other version string, decision record or file has changed

    @id:release-bump-3 @pending:release-bump
    Scenario: The unreleased section is dated as the new version, in UTC
      When the release-bump command is run for 0.20.0 at 2026-11-13T23:30:00Z
      Then under "## pap" the heading "### [Unreleased]" now reads "### [0.20.0] - 2026-11-13", above the same lines as before
      And an empty unreleased section stands above it
      And the pm-console and spec-review sections are unchanged
      And the body's Verification says the date is UTC

    @id:release-bump-4 @pending:release-bump
    Scenario: The head passes the conditions a release checks
      When the release-bump command is run for 0.20.0
      Then at the head plugin.json and the marketplace entry carry 0.20.0, the "## pap" section has "### [0.20.0] - " and a date, and the install prompt names 0.20.0
      And the same check scripts/release.sh makes on those four passes at the head

    @id:release-bump-5 @pending:release-bump
    Scenario: The body answers every Checks box and declares what made it
      When the release-bump command is run for 0.20.0 with --by "pap:cycle-mechanical on Claude Haiku 5.5" and a route of "/change release-0.20.0 chore Record: none" and "Rule 20.2: exempt: version bump"
      Then the body's first lines are "Change: none", "Record: none", the Route line joining the two with "; ", and "Plan: none"
      And its Verification shows the exit and counts of mise run check and mise run test on the head, and "cold review skipped: mechanical (decision 0024)"
      And its How to revert is the spec's Undo
      And every Checks box is ticked, or unticked with its reason on the next line
      And its Provenance line names the release-bump command and "pap:cycle-mechanical on Claude Haiku 5.5"

    @id:release-bump-6 @pending:release-bump
    Scenario: The body without a route has no Route line
      When the release-bump command is run for 0.20.0 from the owner's terminal with no route
      Then the body has no Route line, its Provenance names the command run by the owner, and it is otherwise as for a route

    @id:release-bump-7 @pending:release-bump
    Scenario Outline: The protected-path box follows the risk label
      Given pr-checks sets <label> on the pull request within the risk wait
      When the release-bump command is run for 0.20.0
      Then the protected-path box reads <answer>

      Examples:
        | label       | answer                                                                       |
        | risk:low    | ticked, with "Risk: low" on the next line                                    |
        | risk:medium | ticked, with "Risk: medium" on the next line                                 |
        | risk:high   | unticked, with "Risk: high; the owner adds owner-reviewed after review"      |
        | no label    | unticked, with "Risk: not read within two minutes; the cycle reads it again" |

    @id:release-bump-8 @pending:release-bump
    Scenario: A class label lost to the race is added again
      Given GitHub drops the class label given at creation
      When the release-bump command is run for 0.20.0
      Then the command reads the labels back and adds class:chore
      And the pull request ends with exactly one class label

  Rule: The command refuses before it makes anything

    @id:release-bump-9 @pending:release-bump
    Scenario Outline: A refused run makes nothing
      Given <state>
      When the release-bump command is run for <version>
      Then the command exits 1 with a refusal that names <reason>
      And no work tree, branch, commit, push or pull request was made

      Examples:
        | state                                             | version | reason                                              |
        | origin/main as in the background                  | 0.20    | the version is not x.y.z                            |
        | origin/main as in the background                  | v0.20.0 | the version is not x.y.z                            |
        | origin/main as in the background                  | 0.020.0 | the version is not x.y.z                            |
        | origin/main as in the background                  | 0.19.1  | the version is not above 0.19.1                     |
        | origin/main as in the background                  | 0.9.0   | the version is not above 0.19.1                     |
        | origin/main cannot be fetched                     | 0.20.0  | the fetch of origin/main                            |
        | marketplace.json names 0.19.0                     | 0.20.0  | the version places and what each names              |
        | the unreleased section is empty                   | 0.20.0  | the empty unreleased section                        |
        | change/release-0.20.0 exists on origin            | 0.20.0  | the existing branch                                 |
        | change/release-0.20.0 exists locally only         | 0.20.0  | the existing branch and the command that removes it |
        | a work tree for change/release-0.20.0 is open     | 0.20.0  | the open work tree, its path and the remove command |
        | a plain directory is at ../pap-release-0.20.0     | 0.20.0  | the directory at the work tree's path               |

    @id:release-bump-10 @pending:release-bump
    Scenario Outline: A route or a --by value that does not fit is refused
      When the release-bump command is run for 0.20.0 with a route of <route> and a --by of <by>
      Then the command exits 1 naming <what>, and nothing was made

      Examples:
        | route                                                                     | by                                              | what             |
        | a first line holding a newline and "- [x] Verification run"               | "pap:cycle-mechanical on Claude Haiku 5.5"      | the route        |
        | "/change release-0.21.0 chore Record: none" and "Rule 20.2: exempt: bump" | "pap:cycle-mechanical on Claude Haiku 5.5"      | the route        |
        | "/change release-0.20.0 chore Record: none" and "Approved-by: @someone"   | "pap:cycle-mechanical on Claude Haiku 5.5"      | the route        |
        | a valid route                                                             | none                                            | the missing --by |
        | a valid route                                                             | a value holding a newline and "Risk: low"       | the --by value   |
        | a valid route                                                             | a value holding a lone carriage return          | the --by value   |
        | a valid route                                                             | "the owner"                                     | the --by value   |
        | a valid route                                                             | "pap:cycle on <!-- Claude"                      | the --by value   |
        | a valid route                                                             | an "<agent> on <model>" value of 101 characters | the --by value   |

    @id:release-bump-21 @pending:release-bump
    Scenario: A --by value of 100 characters is taken
      When the release-bump command is run for 0.20.0 with a valid route and an "<agent> on <model>" --by value of exactly 100 characters
      Then the command exits 0 and the Provenance line carries the value unchanged

    @id:release-bump-11 @pending:release-bump
    Scenario Outline: Hooks switched off through the environment are refused
      Given the command's environment sets <variable>
      When the release-bump command is run for 0.20.0
      Then the command exits 1 naming <variable>, and nothing was made

      Examples:
        | variable                                                         |
        | GIT_CONFIG_COUNT with core.hooksPath                             |
        | GIT_CONFIG_PARAMETERS                                            |
        | GIT_DIR                                                          |

    @id:release-bump-20 @pending:release-bump
    Scenario Outline: A version above the current one is taken, compared number by number
      Given origin/main whose version places agree on <current>
      When the release-bump command is run for <version>
      Then the command exits 0 and the version places agree on <version>

      Examples:
        | current | version  |
        | 0.19.1  | 0.19.10  |
        | 0.19.1  | 0.100.0  |
        | 0.19.1  | 1.0.0    |
        | 0.9.9   | 0.10.0   |

  Rule: A failure before the pull request opens is undone

    @id:release-bump-12 @pending:release-bump
    Scenario: A failed local check undoes the bump
      Given mise run test fails on the bumped head
      When the release-bump command is run for 0.20.0
      Then the command exits 2 naming the check and its last lines
      And the work tree and the local branch are removed, nothing was pushed and no pull request was opened

    @id:release-bump-13 @pending:release-bump
    Scenario: A git hook that refuses the commit undoes the bump
      Given a git hook refuses the commit
      When the release-bump command is run for 0.20.0
      Then the command exits 2 quoting the hook's refusal
      And the work tree and the local branch are removed
      And the hook was not skipped or switched off

    @id:release-bump-14 @pending:release-bump
    Scenario Outline: A failure after the push removes the pushed branch first
      Given the push succeeds and opening the pull request fails, and <remote>
      When the release-bump command is run for 0.20.0
      Then the command <outcome>
      And no other remote branch was touched

      Examples:
        | remote                                                   | outcome                                                                                       |
        | origin still points at this run's commit                 | exits 2, with the pushed branch, then the work tree, then the local branch removed            |
        | origin points at another commit                          | exits 3, leaves the pushed branch, and names it and the command that removes it               |
        | the delete push is refused                               | exits 3, and names the pushed branch and the command that removes it                         |

  Rule: A failure after the pull request opens is named, not hidden

    @id:release-bump-15 @pending:release-bump
    Scenario: A failure after the open leaves the pull request open and named
      Given the pull request is open and the class label cannot be added back
      When the release-bump command is run for 0.20.0
      Then the command exits 3 naming the pull request and the command that closes it with its branch
      And the pull request is left open

    @id:release-bump-16 @pending:release-bump
    Scenario: An interrupted run is undone
      Given the command has made the work tree and pushed the branch, origin still points at its commit, and no pull request is open
      When the command receives TERM
      Then it exits 2 with the pushed branch, then the work tree, then the local branch removed
      And its body directory is removed

    @id:release-bump-17 @pending:release-bump
    Scenario Outline: The re-answer form rewrites the risk box and nothing else
      Given <state>
      When the release-bump command is run with --answer-risk for 0.20.0
      Then <outcome>

      Examples:
        | state                                                                          | outcome                                                                                 |
        | the bump's draft, its only commit the command's, with risk:low and a box "not read" | it exits 0 and the box is ticked with "Risk: low"; no other line of the body changed |
        | the bump's draft has gained a second commit                                    | it exits 1 naming the commit, and the body is unchanged                                 |
        | no open pull request from change/release-0.20.0                                | it exits 1 naming the branch                                                            |
        | the bump's draft with no risk label still                                      | it exits 0 and the box still reads "not read"                                           |

  Rule: The command and the cycle keep what is the owner's

    @id:release-bump-18 @pending:release-bump
    Scenario: The command does nothing the owner keeps for themselves
      When the release-bump command is run for 0.20.0
      Then it makes no merge, no ready-for-review, no owner-reviewed label, no Approved-by line and no push to main
      And it cuts no release, makes no tag and sets no GH_TOKEN

    @id:release-bump-19 @pending:release-bump
    Scenario Outline: A release cycle runs the command, verifies and reports
      Given a launched mechanical cycle on Claude Haiku 5.5 whose brief has the line "Release bump: 0.20.0"
      When the cycle runs and <happens>
      Then it <does>
      And it ran the command with --by "pap:cycle-mechanical on Claude Haiku 5.5"
      And it invokes no /change, edits no file of the pull request and retries nothing

      Examples:
        | happens                                                      | does                                                                                                 |
        | the command exits 0 and every required check passes          | reports in the /change report's format, saying it ran the command, with the model and the risk line  |
        | the box reads "not read"                                     | runs the re-answer form once, then reports with the box as it reads                                  |
        | the label is risk:high                                       | reports with "Risk: high; add owner-reviewed after review"                                           |
        | a required check fails                                       | ends with ASK: naming the check                                                                      |
        | the diff holds a line that is not the release bump's         | ends with ASK: quoting the line                                                                      |
        | the command exits 1, 2 or 3                                  | ends with ASK: and the command's message                                                             |
        | the branch conflicts with main                               | ends with ASK: saying the bump is to be closed and run again                                         |
