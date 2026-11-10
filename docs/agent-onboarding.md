# Onboard a repository with an agent

A runbook a Claude Code session follows to bring a repository onto PAP,
with a check after every step. Two paths: [greenfield](#greenfield), a new
repository with nothing in it but a first commit, and
[brownfield](#brownfield), a repository that already has code, hooks or
CI. The human pastes [a prompt](#paste-this-into-claude-code); the agent
does the rest, and stops where the work is the human's.

This guide orders the steps and says who does each. What each command
does is in the guides it links; where they disagree with the
[reference](README.md), the reference wins.

## The minimum to know

Adopting PAP puts three things in place, in this order:

| What              | Put there by                       | Who runs it                            |
| ----------------- | ---------------------------------- | -------------------------------------- |
| The template      | `pap init <layer>...`              | The agent, on a `change/<slug>` branch |
| The GitHub side   | `pap repo apply`                   | The human, from their own terminal     |
| The product layer | `/envision`, then `pap codeowners` | The agent asks, the human answers      |

Each of the first and third lands as a draft pull request. From then on
every change is `/intent`, `/spec`, `/change`
([Make a change](make-a-change.md)).

Four rules bind the agent from the moment the template is in. Hooks
enforce them, so working around one fails; stop and say so instead.

- Commit and push only on a `change/<slug>` branch. Never on `main`.
- Never bypass a git hook, never force-push.
- Never merge, never approve, never add `owner-reviewed` or an
  `Approved-by:` line. Those are the owner's acts.
- Never invent the product: every line `/envision` writes is something
  the human said or confirmed.

## What only the human does

| When                | What                                                                                                                                                          | Guide                                                                               |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| Once per machine    | Install git, mise and Claude Code; `gh auth login`; install the `pap` and `spec-review` plugins                                                               | [Getting started](getting-started.md)                                               |
| Once per account    | The `.github` repository, the labels, the Renovate app, the `pap-agent` app                                                                                   | [Set up the account](account-setup.md)                                              |
| Once per repository | Create it on GitHub with a first commit on `main`; install the `pap-agent` app on it; start the session there with `pap claude`                               | [Set up the account](account-setup.md#the-pap-agent-app)                            |
| During the runbook  | Choose the layers and the version; run `pap repo apply`; answer `/envision`; review and merge both pull requests, the first through a one-time ruleset bypass | [Adopt a repository](adopt-a-repo.md#the-first-pull-request)                        |
| Public repositories | The Actions policy that allows `pull_request_target` for `pr-checks`                                                                                          | [Adopt a repository](adopt-a-repo.md#public-repositories-allow-pull_request_target) |

Before the repository pins `pap`, the human needs it on `PATH` to run
`pap claude`: a global mise install of the release archive
([Set up the account](account-setup.md#your-own-sign-in-and-pap-claude)).
A session not started by `pap claude` can still do every local step; once
the template is in, the hooks refuse its `gh` calls and pushes, so the
human runs those.

## Paste this into Claude Code

Fill in the two angle-bracket fields. `<version>` is a release tag
without its `v`, from <https://github.com/blairforce1/pap/releases>. The
layers are `base`, plus any of `dotnet`, `go` and `risk`
([what each adds](adopt-a-repo.md#pap-init-layer)).

Greenfield:

```text
Onboard this repository onto PAP. It is new: one commit on main, no code yet.
Read https://raw.githubusercontent.com/blairforce1/pap/main/docs/agent-onboarding.md
and follow its greenfield runbook step by step, running the check after each
step and showing me its result before the next.
pap version: <version>
Layers: <base [dotnet] [go] [risk]>
Stop wherever the runbook says the step is mine, tell me exactly what to run
or decide, and wait. Do not merge anything.
```

Brownfield:

```text
Onboard this existing repository onto PAP. It already has code and may have
its own hooks, formatters and CI.
Read https://raw.githubusercontent.com/blairforce1/pap/main/docs/agent-onboarding.md
and follow its brownfield runbook step by step, running the check after each
step and showing me its result before the next. Start with the survey and
change nothing until I have read it.
pap version: <version>
Layers: <base [dotnet] [go] [risk]>
Stop wherever the runbook says the step is mine, tell me exactly what to run
or decide, and wait. Do not merge anything.
```

## Greenfield

In every command below, `pap` is on `PATH` where the shell has activated
mise; where it has not, as in an agent's shell, write `mise exec -- pap`.
Before step 3 the repository has no pin, so step 3 names the release in
full.

1. **Check the starting point.**

   ```sh
   git status --porcelain            # prints nothing
   git rev-parse --verify origin/main   # prints a commit
   git remote get-url origin         # an https://github.com/ URL
   mise --version
   ```

   Check: all four hold. An empty repository has no `main` to open a
   pull request against, and the hooks refuse an agent's push to an SSH
   remote; either one is the human's to fix first. Stop and say which.

2. **Make the branch.**

   ```sh
   git switch -c change/adopt-pap
   ```

   Check: `git branch --show-current` prints `change/adopt-pap`.

3. **Apply the template**, with the version and layers from the prompt.

   ```sh
   mise exec 'github:blairforce1/pap[asset_pattern=pap-*.tar.gz]@<version>' -- pap init <layers>
   ```

   Check: `.config/pap.toml` names that version and those layers, and
   `git status --short` lists the new files. From an agent's shell, expect
   the line `pap repo apply reported failures`: the agent app cannot
   administer a repository, and step 5 is where the human runs it. If
   `init` ends with `clone setup failed`, fix what mise reported and run
   the same command again.

4. **Check the machine and the repository.**

   ```sh
   mise exec -- pap doctor
   mise run check
   mise run test
   ```

   Check: `pap doctor` exits 0, or every item it flags is one this guide
   gives the human; `check` passes; `test` prints `no test:* task is
   defined; nothing to test` until the repository has tests.

5. **Stop: the human applies the GitHub side.** Ask them to run, from
   their own terminal in this directory:

   ```sh
   pap repo apply
   ```

   Check, once they say it is done: `mise exec -- pap repo status`. From
   an agent's shell the items that need administration read `skipped`;
   nothing may read `missing` or `drift`, bar the public-repository
   Actions policy, which is in the table above.

6. **Commit, push and open the draft pull request.**

   ```sh
   git add -A && git commit -m "build(pap): adopt the template"
   git push -u origin change/adopt-pap
   gh pr create --draft --label class:infra
   ```

   The body comes from the account's pull request template. Answer its
   Checks section: every box ticked, or a one-line reason on the very
   next line. Under Verification, give the output of step 4.

   Check: `gh pr view --json isDraft,labels` shows a draft with
   `class:infra`.

7. **Stop: the human merges.** This pull request cannot run its own
   `pr-checks`, so it merges through a one-time bypass of the `main`
   ruleset ([The first pull request](adopt-a-repo.md#the-first-pull-request)).
   Give them the URL and that link, and wait for the merge.

8. **Write the product layer**, on a new branch from the merged `main`.

   ```sh
   git fetch origin && git switch -c change/product-layer origin/main
   ```

   Run `/envision`. It is an interview: ask one question at a time, and
   write nothing the human has not said or confirmed
   ([Start a project](start-a-project.md)). Then:

   ```sh
   mise exec -- pap codeowners
   git add -A
   mise exec -- pap codeowners --check
   ```

   Check: the four files `product/vision.md`, `invariants.md`,
   `backlog.md` and `conventions.md` exist, `invariants.md` has a
   "Protected paths" section with an `Owner:` line, and the `--check`
   exits 0.

9. **Commit, push, open the second draft pull request and stop.**

   ```sh
   git commit -m "docs(product): add the product layer"
   git push -u origin change/product-layer
   gh pr create --draft --label class:docs
   ```

   Check: as step 6, and this time `pr-checks` reports on the pull
   request. With the `risk` layer it is labelled `risk:high`, because it
   touches `product/invariants.md`; the human reviews it and adds
   `owner-reviewed`.

   Report both pull request URLs, what is left for the human, and stop.
   The first real change is theirs to start: `/intent <slug> <class>`.

## Brownfield

The same nine steps, with a survey before them and more to settle inside
them. Do the greenfield step of the same number, then what is added here.

0. **Survey; change nothing.** Report to the human, one line each:

   - A hook manager already in use: `.husky/`, `.pre-commit-config.yaml`,
     a `lefthook.yml`, or `git config core.hooksPath`.
   - Formatter and style configuration: `.editorconfig`, `dprint.json`,
     a Prettier or other formatter config.
   - The workflows in `.github/workflows/`, and the command that runs the
     tests today.
   - `.github/CODEOWNERS`, if there is one: `pap codeowners` will
     generate that file from `product/invariants.md`.
   - Whether `origin` is SSH (step 1 needs HTTPS).
   - What `pap repo apply` will change on GitHub: `main` takes pull
     requests only, squash merges only and linear history, and no branch
     takes a force push ([`pap repo`](adopt-a-repo.md#pap-repo)).

   Check: the human has read the survey and said go.

1. As greenfield. `pap init` refuses a working tree with uncommitted
   changes; if there are any, they are the human's to commit or stash.

2. As greenfield.

3. As greenfield, then resolve what `init` could not. It prints `C
   <path>` for each file that already existed and differs from the
   template, and leaves ordinary conflict markers in it.

   - Keep what is the repository's own: its ignore entries, its
     workflow jobs, its editor settings.
   - Keep the template's where a hook or a check reads the file.
   - Where both set the same thing differently, and for a second hook
     manager, ask the human. Do not remove their hooks or a formatter
     config on your own judgement. The base template's
     ["What other tools must not duplicate"](../templates/base/README.md#what-other-tools-must-not-duplicate)
     says which settings must live in one place.

   Commit the resolution, then run the same `pap init` command again to
   finish the setup.

   Check: `git diff --check origin/main` reports no conflict marker, and
   the second `init` prints no `C` line.

4. As greenfield, with two additions.

   **Wire in the tests.** `mise run test` runs every task named `test:*`,
   and the required `tests` check runs that. The `dotnet` and `go` layers
   bring their own; for anything else, add a task to a file of the
   repository's own in `.config/mise/conf.d/`:

   ```toml
   [tasks."test:unit"]
   run = "<the command that runs the tests today>"
   ```

   Check: `mise run test` runs the existing suite, and it passes.

   **Sort what `mise run check` reports.** On a codebase that has never
   run these checks, expect findings. By kind:

   - Formatting (`check:dprint`, `check:editorconfig`): `mise run fmt`
     fixes most. Keep it out of this pull request: a formatting-only
     change goes in its own, so its squash commit can be listed in
     `.git-blame-ignore-revs`. Tell the human it is the next change.
   - `check:gitleaks`: stop. A secret in the history is the human's to
     rotate and to rule on. Never allowlist a finding yourself.
   - `check:shellcheck`: report the count; fixing them is a change of
     its own unless the human says otherwise.

   Whatever still fails goes in the pull request's Verification as it
   is, with the box unticked and the reason beneath. Do not hide it.

5. As greenfield, but the human reads before applying:

   ```sh
   pap repo apply --dry-run
   pap repo apply
   ```

   A status check the repository already requires is kept. To have PAP
   require a workflow job of the repository's own, list its check name
   in `.github/required-checks.yml`, one YAML list item each, before the
   human applies; a check that needs a baseline on `main` goes in after
   the first merge ([The first pull request](adopt-a-repo.md#the-first-pull-request)).

6. As greenfield. In the body, list every conflict resolved in step 3
   and which side won, and every check from step 4 that still fails.

7. As greenfield.

8. As greenfield. `/envision` skims the code first and proposes
   candidate invariants from what it finds; each one still needs the
   human's yes. If `product/` already exists it runs as a review and
   edits in place.

9. As greenfield. In the report, add the changes this one leaves behind:
   the formatting pull request, any shellcheck findings, any hook or
   formatter the human chose to retire.

## Stop and ask

Stop, say what you found and what you need, and wait, when:

- A step's check does not hold and the fix is not named in the step.
- A command is refused by a hook. The refusal names the rule;
  [Troubleshooting](troubleshooting.md#hooks) has each one. Do not retry
  it another way.
- `gh` or a push is refused for want of a token or an installation: the
  `pap-agent` app does not cover this repository, or the session was not
  started by `pap claude` ([Troubleshooting](troubleshooting.md#the-gh-shim-and-pap-agent)).
- Resolving a conflict would drop something the repository had.
- `/envision` needs an answer you would have to make up.

## Done

- Both pull requests are merged, by the human.
- `pap doctor` exits 0, and `pap repo status` exits 0 from the human's
  terminal.
- `mise run check` and `mise run test` pass on `main`, or what fails is
  written down as a change to make.
- `product/` has its four files and `pap codeowners --check` exits 0.

Next: [Make a change](make-a-change.md) for the first one, and
[Run a project](run-a-project.md) when there are several at once.
