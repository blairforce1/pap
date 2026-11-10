# PAP user guides

How to adopt and use PAP without its author in the room. These guides say
how to use the process and its tooling; they do not restate them. The
reference is [the process document](../process/personal-agentic-process.md)
(what must happen), [`rules.md`](../rules.md) (what a check can refuse, and
what enforces it today) and [`decisions/`](../decisions/) (why each rule
exists). Where a guide and the reference disagree, the reference wins; tell
us.

Each guide says what is a command today, what you still do by hand, and
what is planned. A planned item names its backlog entry in
[`product/backlog.md`](../product/backlog.md) (`H-NNN`), so you can see
whether it has shipped since this was written.

| Guide                                                         | Who it is for                            | When to read it                                                                                                                      |
| ------------------------------------------------------------- | ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| [Getting started](getting-started.md)                         | Anyone new to PAP                        | First. Install the tools and the plugins, and set up a first repository in about 15 minutes.                                         |
| [Onboard a repository with an agent](agent-onboarding.md)     | Whoever hands the setup to Claude Code   | In place of doing the next three by hand: a prompt to paste, and the runbook the agent follows, for a new or an existing repository. |
| [Adopt a repository](adopt-a-repo.md)                         | The person setting up a repository       | When you apply the template to a new or existing repository, or take a new template version.                                         |
| [Set up the account](account-setup.md)                        | The owner of the GitHub account or org   | Once per account: the `.github` repository, the labels and the Renovate app.                                                         |
| [Start a project](start-a-project.md)                         | The product owner                        | Before the first change: `/envision` and the product layer.                                                                          |
| [Make a change](make-a-change.md)                             | Anyone making a change                   | Every change: `/intent`, `/spec`, `/change`, review by risk label, merge, findings.                                                  |
| [Run a project](run-a-project.md)                             | Whoever runs several changes at once     | When one session will brief and track many changes as the project manager.                                                           |
| [Decide and improve](decide-and-improve.md)                   | Whoever owns the process in a repository | When you change how you work: decision records, revisits, audits, evals, the backlog.                                                |
| [Agent identity and its security](agent-identity-security.md) | Anyone adopting PAP                      | What an agent can do on GitHub as the app, what keeps your sign-in from it, and what does not.                                       |
| [Troubleshooting](troubleshooting.md)                         | Anyone stuck                             | When a check, a hook or a command refuses something you expected to work.                                                            |
