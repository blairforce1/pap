# Onboard a repository with an agent

Two paths onto PAP. [Greenfield](#greenfield), a repository that does not
exist yet: one command, `pap new <name>`, run by the human from their own
terminal, makes it and ends in a Claude Code session. [Brownfield](#brownfield),
a repository that already has code, hooks or CI: a runbook a Claude Code
session follows, with a check after every step. Either way the human
pastes [a prompt](#paste-this-into-claude-code) first, and the agent stops
where the work is the human's.

This guide orders the steps and says who does each. What each command
does is in the guides it links; where they disagree with the
reference ([the process document](../process/personal-agentic-process.md), [`rules.md`](../rules.md) and [`decisions/`](../decisions/)), the reference wins.

## The minimum to know

Adopting PAP puts three things in place, in this order. `pap new` does the
first two for a new repository; the table is who does what in an existing
one:

| What              | Put there by                       | Who runs it                            |
| ----------------- | ---------------------------------- | -------------------------------------- |
| The template      | `pap init <layer>...`              | The agent, on a `change/<slug>` branch |
| The GitHub side   | `pap repo apply`                   | The human, from their own terminal     |
| The product layer | `/envision`, then `pap codeowners` | The agent asks, the human answers      |

Each of the first and third lands as a draft pull request. From then on
every change is `/intent`, `/spec`, `/change`, with `/pap:plan` before
`/change` for a feature, infra or security-sensitive change
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
| Once per repository | New: `pap new <name>`. Existing: install the `pap-agent` app on it and start the session there with `pap claude`                                              | [Set up the account](account-setup.md#the-pap-agent-app)                            |
| During the runbook  | Choose the layers and the version; run `pap repo apply`; answer `/envision`; review and merge both pull requests, the first through a one-time ruleset bypass | [Adopt a repository](adopt-a-repo.md#the-first-pull-request)                        |
| Public repositories | The Actions policy that allows `pull_request_target` for `pr-checks`                                                                                          | [Adopt a repository](adopt-a-repo.md#public-repositories-allow-pull_request_target) |

Before the repository pins `pap`, the human needs it on `PATH` to run
`pap claude`: a global mise install of the release archive
([Set up the account](account-setup.md#your-own-sign-in-and-pap-claude)).
A session not started by `pap claude` can still do every local step; once
the template is in, the hooks refuse its `gh` calls and pushes, so the
human runs those.

## Paste this into Claude Code

Greenfield, the install prompt. It names an exact version, which the
version bump of each release updates and `scripts/release.sh` checks:

<!-- The install prompt: release.sh refuses a release whose version is not the one after the @ below. -->

```text
Install pap for me: run `mise use -g 'github:blairforce1/pap[asset_pattern=pap-*.tar.gz]@0.18.2'`, then `pap version`, which must print 0.18.2. Then tell me to exit this session and run, from my own terminal: `pap agent-setup --owner <my GitHub login>` if the pap-agent app is not registered on this machine yet, then `pap new <name>` from the directory the new clone should sit under (the defaults: private, layers base risk dotnet). Run neither of those yourself.
```

- An exact version is not held back by mise's `minimum_release_age`
  (default 24 hours): mise's settings reference says "Exact versions such
  as `node@22.5.0`, and versions recorded in `mise.lock`, are not
  filtered", and an install of pap 0.17.0 five hours after its release,
  with the setting at 7 days, went through. So the prompt skips the
  cooldown on a release that may be hours old. What mise's GitHub backend
  still checks on the download: the digest GitHub reports for the asset,
  and GitHub artifact attestations when a release has them. pap's
  releases publish none, so the digest is the only check.
- The prompt on `main` can name a version for the few minutes between its
  version bump merging and that release being cut; if `mise` finds no
  such version, use the one before it from
  <https://github.com/blairforce1/pap/releases>.

Brownfield. Fill in the two angle-bracket fields. `<version>` is a release
tag without its `v`, from <https://github.com/blairforce1/pap/releases>.
The layers are `base`, plus any of `dotnet`, `go` and `risk`
([what each adds](adopt-a-repo.md#pap-init-layer)).

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

```sh
pap new <name> [--owner <login>] [--visibility private|public] [--layers <layer>...] [--yes]
```

Run it yourself, from your own terminal, in the directory the clone
should sit under. It refuses an agent's shell: it acts as you, on your own
`gh` sign-in, until the last step. The defaults are a private repository
under your own account with the layers `base`, `risk` and `dotnet`;
`--owner` takes an organisation you administer.

**Preflight** creates nothing. It checks the name, the owner, the
visibility and the layers; your `gh` sign-in and its `repo` and `workflow`
scopes, offering `gh auth login` or `gh auth refresh` and asking for no
other scope; that the `pap-agent` app is registered
([`pap agent-setup`](account-setup.md#with-pap-agent-setup)) and
installed on the owner; that the owner's plan gives a private repository
a ruleset (GitHub's free plan does not: choose `--visibility public`);
that no organisation ruleset would refuse the first push; and what
already exists of that name. It ends with a summary (the login acted as,
the repository, the visibility, the layers, and the author name and
email of the first commit, which a public repository publishes for good)
and waits for Enter; `--yes` skips the wait.

**Creation** is six steps, each named as it starts:

1. The first commit, in `./<name>`: the template at the chosen layers and
   a README whose only line is `# <name>`.
2. The repository on GitHub, empty.
3. The first push: the one direct push to `main` the repository ever
   takes, made before any hook or ruleset exists. pap adds no ruleset
   bypass for it, and stops if the clone already has hooks.
4. Clone setup: `mise trust && mise install && mise run setup`.
5. `pap repo apply`, then the `main` ruleset read back. Without an active
   `main` ruleset with no bypass actor the run stops here, and no agent
   token is asked for.
6. A `pap-agent` token for the one repository. If the installation is
   for selected repositories, it prints the installation's page, waits
   while you add the new repository there, and asks again on Enter.

Then it prints the repository's URL and the clone's path and starts
`pap claude` in the clone: Claude Code on your own install, acting on
GitHub as the agent app, not something pap provides. That session is
given what the run did, where you are, and the pap skills, mods and
agents installed on your machine, and asks what you want next. `/envision`
([Start a project](start-a-project.md)) is the likely first step; it
starts nothing unasked. A public repository, and an organisation, each
leave one setting only you can change; preflight names it, and the
welcome repeats it.

**A stop** names its step, what exists so far, the cause and the exact
command to run again, and undoes nothing. Run that command: it reads
GitHub and the current directory, goes on from what exists, and makes no
commit, repository or push a second time. Something of that name that
`pap new` did not make, in the directory or on GitHub, is left alone:
choose another name, or use the brownfield runbook. `pap new` never
deletes a repository. Read-only checks before a re-run: `pap repo status
--repo <owner>/<name>`, and `pap doctor` in the clone.

Every later change is `/intent`, `/spec`, `/change`, with `/pap:plan`
before `/change` for a feature, infra or security-sensitive change
([Make a change](make-a-change.md)). The first pull request should need
no ruleset bypass, because the template is on `main` from the first
commit.

## Brownfield

A survey, then nine steps with a check after each. The steps come first,
as they run for any repository; [what an existing repository adds](#what-an-existing-repository-adds)
to each follows them. The repository needs a first commit on `main` and
the `pap-agent` app installed on it, and the session is started there
with `pap claude`.

### The nine steps

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
   gh pr create --draft --title "build(pap): adopt the template" \
     --body-file <body> --label class:infra
   ```

   `gh` fills in no template from a shell that cannot prompt, so write
   the body to a file first, in the shape `pr-checks` reads:

   ```text
   Change: none
   Record: none

   ## Summary
   What the pull request adds, one bullet per group of files.

   ## Verification
   What step 4 ran and what it showed.

   ## How to revert
   Revert the merge.

   ## Checks
   - [x] Verification run and output shown above
   - [x] No protected path touched, or the owner has approved the head
   - [x] Generated content carries provenance (model, skill, prompt)
   Provenance: <model> via Claude Code, prompt "<the prompt's first line>"
   ```

   Tick a box only if it is true; an unticked box has a one-line reason
   on the very next line. If the account's `.github` repository has its
   own `pull_request_template.md`, use its headings instead.

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
   gh pr create --draft --title "docs(product): add the product layer" \
     --body-file <body> --label class:docs
   ```

   The body is step 6's, with one difference: this pull request touches
   a protected path, `product/invariants.md`, so leave the second box
   unticked with its reason beneath
   ([Review by risk label](make-a-change.md#5-review-by-risk-label)).

   Check: as step 6, and this time `pr-checks` reports on the pull
   request. With the `risk` layer it is labelled `risk:high`, and the
   reason under the box is `Risk: high; the owner adds owner-reviewed
   after review`. Without it, the reason is `Head to approve: <the
   pushed head's first seven characters>`, and the human types the
   `Approved-by:` line. Either way the approval is theirs.

   Report both pull request URLs, what is left for the human, and stop.
   The first real change is theirs to start: `/intent <slug> <class>`.

### What an existing repository adds

A survey before the nine steps, and more to settle inside them. Do the
step of the same number above, then what is added here.

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

1. As above. `pap init` refuses a working tree with uncommitted
   changes; if there are any, they are the human's to commit or stash.

2. As above.

3. As above, then resolve what `init` could not. It prints `C
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

4. As above, with two additions.

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

5. As above, but the human reads before applying:

   ```sh
   pap repo apply --dry-run
   pap repo apply
   ```

   A status check the repository already requires is kept. To have PAP
   require a workflow job of the repository's own, list its check name
   in `.github/required-checks.yml`, one YAML list item each, before the
   human applies; a check that needs a baseline on `main` goes in after
   the first merge ([The first pull request](adopt-a-repo.md#the-first-pull-request)).

6. As above. In the body, list every conflict resolved in step 3
   and which side won, and every check from step 4 that still fails.

7. As above.

8. As above. `/envision` skims the code first and proposes
   candidate invariants from what it finds; each one still needs the
   human's yes. If `product/` already exists it runs as a review and
   edits in place.

9. As above. In the report, add the changes this one leaves behind:
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
