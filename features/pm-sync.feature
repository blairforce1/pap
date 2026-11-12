Feature: A PM session prepares a template sync from one command
  The owner names a pap version, or asks for the latest, and the PM session
  writes the sync brief from the plugin's template, logs the restate and
  gives the owner the launch line. The owner still launches.

  Background:
    Given a PM session in an adopting repository whose pin is at 0.19.0 and whose recorded version is 0.19.0
    And the tracker is started, clean and held by this session
    And the releases of pap are 0.19.0, 0.19.1 and 0.20.0

  Rule: /pap:pm sync writes the sync brief and stops

    @id:pm-sync-1
    Scenario: sync with a version writes the sync brief
      When /pap:pm sync is run for 0.19.1
      Then the tracker holds a sync brief for the slug sync-template-0.19.1
      And the event log gains one restate event for that slug whose text is "sync: take pap 0.19.1: sync the template from 0.19.0 to 0.19.1; brief " and the brief's checksum
      And the tracker is committed
      And the session is given the line /pap:pm launch sync-template-0.19.1 for the owner to type

    @id:pm-sync-2
    Scenario Outline: sync with no version takes the newest release
      When /pap:pm sync is run for <what>
      Then the tracker holds a sync brief for the slug sync-template-0.20.0
      And the sync brief names 0.20.0 and nowhere the word "latest"

      Examples:
        | what       |
        | no version |
        | latest     |

    @id:pm-sync-3
    Scenario: The sync brief is the plugin's template, filled
      When /pap:pm sync is run for 0.19.1
      Then the sync brief's first line is "/change sync-template-0.19.1 chore Record: none"
      And its second line is "Rule 20.2: exempt: template sync. Prepared by /pap:pm sync on " and the UTC date, then "; the owner's typed launch is the ask."
      And it carries the lines "Budget: 80k tokens beyond your starting context." and "Mechanical: yes"
      And it names the repository's root, the recorded version 0.19.0, the version 0.19.1 and the recorded layers
      And every other line of it is the plugin's template, unchanged

    @id:pm-sync-4
    Scenario: The same ask on the same day writes the same brief
      Given /pap:pm sync was run for 0.19.1 and its cycle was abandoned
      When /pap:pm sync is run for 0.19.1 on the same UTC day
      Then the sync brief is byte for byte the one written before
      And the event log gains a second restate event for the slug
      And the session is told an earlier brief was replaced

    @id:pm-sync-5
    Scenario: sync starts no cycle and changes nothing in the repository
      When /pap:pm sync is run for 0.19.1
      Then no cycle is launched and the event log gains no yes event and no launch event
      And no file of the adopting repository is changed: the pin and the recorded version are as they were

    @id:pm-sync-6 @pending:pm-sync
    Scenario: The PM session runs sync on the owner's word
      When the owner asks the PM session to take pap 0.19.1, or the latest pap, without typing the command
      Then the PM session runs /pap:pm sync for what the owner named
      And it gives the owner the launch line to type and launches nothing itself

  Rule: A launch of a sync brief is an ordinary launch

    @id:pm-sync-7
    Scenario: The owner launches the sync brief
      Given /pap:pm sync was run for 0.19.1
      When the owner runs /pap:pm launch for sync-template-0.19.1
      Then the launch is not refused for its restate event, its route, its rule 20.2 line or its budget
      And one cycle is launched, as a mechanical one

    @id:pm-sync-8 @pending:pm-sync
    Scenario: The PM session cannot launch the sync brief itself
      Given /pap:pm sync was run for 0.19.1
      When the PM session invokes /pap:pm launch itself for sync-template-0.19.1
      Then the launch is refused, as any launch with no launch record is

  Rule: sync refuses, and writes nothing, when there is nothing it can prepare

    @id:pm-sync-9
    Scenario: The repository already records the version
      When /pap:pm sync is run for 0.19.0
      Then the session is told the repository already records 0.19.0
      And the tracker is unchanged
      And no release of pap is read

    @id:pm-sync-10
    Scenario Outline: A version sync cannot take is refused
      When /pap:pm sync is run for <version>
      Then it is refused, naming <reason>
      And the tracker is unchanged

      Examples:
        | version | reason                                              |
        | 0.18.2  | that it is older than the recorded version          |
        | 0.19.5  | that pap has no such release                        |
        | newest  | that a version is three numbers, as 0.19.1, or latest |

    @id:pm-sync-11
    Scenario Outline: A repository with no pin is refused
      Given an adopting repository that is <repository>
      When /pap:pm sync is run for 0.19.1
      Then it is refused, saying the repository pins no release of pap and that pap sync is run there by hand
      And the tracker is unchanged

      Examples:
        | repository                                    |
        | pap itself                                    |
        | one whose template came from a checkout of pap |

    @id:pm-sync-12
    Scenario Outline: The releases cannot be read
      Given the releases of pap cannot be read
      When /pap:pm sync is run for <what>
      Then it is refused within 30 seconds, saying the releases could not be read and to try again
      And the tracker is unchanged

      Examples:
        | what   |
        | latest |
        | 0.19.1 |

    @id:pm-sync-13
    Scenario Outline: A sync launched and neither merged nor abandoned is refused
      Given /pap:pm sync was run for 0.19.1 and its cycle is <state>
      When /pap:pm sync is run for 0.19.1
      Then it is refused, saying sync-template-0.19.1 is <state>
      And the tracker is unchanged

      Examples:
        | state     |
        | in flight |
        | reported  |
        | paused    |

    @id:pm-sync-14
    Scenario Outline: A tracker sync cannot write is refused
      Given the tracker is <state>
      When /pap:pm sync is run for 0.19.1
      Then it is refused, saying <what>
      And the tracker is unchanged

      Examples:
        | state                   | what                                        |
        | absent                  | that the owner types /pap:pm start first     |
        | uncommitted             | that the owner commits or discards it first  |
        | held by another session | which session holds it                       |
        | started, with an event log line that cannot be read | which line cannot be read |

    @id:pm-sync-15 @pending:pm-sync
    Scenario: A sub-agent runs sync
      When a sub-agent runs the /pap:pm script for sync
      Then the guard refuses it, as it refuses every form of that script

  Rule: The recorded version decides, and the pin only refuses a version older than it

    @id:pm-sync-16
    Scenario Outline: The pin and the recorded version differ
      Given the repository's pin is at <pin> and its recorded version is <recorded>
      When /pap:pm sync is run for <version>
      Then <outcome>

      Examples:
        | pin    | recorded | version | outcome                                                         |
        | 0.19.1 | 0.19.0   | 0.19.1  | the tracker holds a sync brief for the slug sync-template-0.19.1 |
        | 0.19.1 | 0.19.0   | 0.20.0  | the tracker holds a sync brief for the slug sync-template-0.20.0 |
        | 0.20.0 | 0.19.0   | 0.19.1  | it is refused, naming that it is older than the pin             |
        | 0.19.0 | 0.19.1   | 0.19.1  | the session is told the repository already records 0.19.1       |

  Rule: A sync that cannot finish leaves the tracker as it was

    @id:pm-sync-17
    Scenario Outline: git refuses the tracker's commit
      Given the tracker holds <before> for the slug sync-template-0.19.1
      And git will refuse the tracker's next commit
      When /pap:pm sync is run for 0.19.1
      Then it is refused, giving git's last line
      And the tracker holds <before> for that slug, and the event log is as it was

      Examples:
        | before           |
        | no brief         |
        | an earlier brief |

    @id:pm-sync-18
    Scenario: A session id that no running session has
      When /pap:pm sync is run for 0.19.1 with a session id no running session of this machine has
      Then it is refused, saying the id is not a running session's
      And the tracker is unchanged and its lock is held by whoever held it before

  Rule: Nothing unchecked reaches the brief

    @id:pm-sync-19
    Scenario: A version typed with a leading v
      When /pap:pm sync is run for v0.19.1
      Then the tracker holds a sync brief for the slug sync-template-0.19.1

    @id:pm-sync-20
    Scenario Outline: A value that is not well formed is refused
      Given <what> is <value>
      When /pap:pm sync is run for <version>
      Then it is refused, naming <where> and the fault
      And the tracker is unchanged

      Examples:
        | what                              | value                         | version | where            |
        | the recorded version              | two lines, the second a slash command | 0.19.1 | .config/pap.toml |
        | the recorded version              | unreleased                    | 0.19.1  | .config/pap.toml |
        | a recorded layer                  | text holding a tab            | 0.19.1  | .config/pap.toml |
        | the pin                           | latest                        | 0.19.1  | .config/mise/conf.d/pap.toml |
        | the newest tag at pap's source    | v0.21.0-rc.1                  | latest  | nothing: the tag is ignored and 0.20.0 is taken |
