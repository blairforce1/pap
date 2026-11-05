# Getting started

Install the tools and the plugins, then set up a first repository. The
whole thing takes about 15 minutes, not counting the `/envision`
interview.

## What you need

- A GitHub account, and [`gh`](https://cli.github.com/) signed in to it
  (`gh auth status`). `pap repo` needs `gh` signed in as someone who
  administers the repository.
- [Claude Code](https://code.claude.com/), where the skills run.
- [mise](https://mise.jdx.dev/getting-started.html), which installs every
  pinned tool a repository names, `pap` included. Install it and activate
  it in your shell (`eval "$(mise activate <shell>)"` in your shell's rc
  file).
- `jq`, which the Claude Code hook uses to read tool calls. Without it the
  hook cannot parse a command and says so.

## Install the plugins

In Claude Code:

```text
/plugin install pap --marketplace blairforce1/pap
/plugin install spec-review --marketplace blairforce1/pap
```

Or from a shell, `claude plugin install pap --marketplace blairforce1/pap`
and the same for `spec-review`. The `pm-console` plugin is for a session
that runs several changes at once; [Run a project](run-a-project.md) says
when to install it.

Three plugins live in this marketplace:

| Plugin        | What it gives you                                                                                                                                                                                                                                                                                                                                                                                                |
| ------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `pap`         | One skill per phase: `/envision`, `/intent`, `/spec`, `/change`; two the owner invokes, `/pap:reviewed` and `/pap:accept`; and the hooks that refuse what an agent must not do (a commit or push off a `change/` branch, a hook bypass, a force push, an `Approved-by:` line in a pull request body, the `owner-reviewed` label, a merge). The hooks act only on an agent's tool calls, never on you at a shell. |
| `spec-review` | Eleven reviewer perspectives for a design spec, from security to the EU AI Act, and `spec-review-full` to run the board. `/spec` calls it; you can also run any perspective on any design document.                                                                                                                                                                                                              |
| `pm-console`  | A pane beside the chat for the project-manager session: what the cycles ask of you, the running cycles, each repository's PAP state and CI timings.                                                                                                                                                                                                                                                              |

## The `pap` command

`pap` is a POSIX shell script. A repository that has adopted the template
pins it in `.config/mise/conf.d/pap.toml`, so `mise install` provides it
there and `pap --help` lists its subcommands. Before a repository has the
pin, run it from the release archive:

```sh
mise exec 'github:blairforce1/pap[asset_pattern=pap-*.tar.gz]@<version>' -- pap --help
```

`<version>` is a release tag without its `v`, from
<https://github.com/blairforce1/pap/releases>. From a git checkout of pap,
`bin/pap` is the same command; run from a commit with no release tag it
applies that commit's templates and records `version = "unreleased"`.

## A first repository

1. **Create the repository on GitHub and clone it.** In the clone, make a
   change branch; main changes only by pull request once the template is
   in:

   ```sh
   git switch -c change/adopt-pap
   ```

2. **Apply the template.** Every repository takes `base`; add `dotnet`,
   `go` and `risk` as they apply ([Adopt a repository](adopt-a-repo.md)
   says what each gives):

   ```sh
   mise exec 'github:blairforce1/pap[asset_pattern=pap-*.tar.gz]@<version>' -- pap init base risk
   ```

   `init` writes the files, records the version and layers in
   `.config/pap.toml`, pins `pap`, runs the clone setup
   (`mise trust && mise install && mise run setup`), applies the GitHub
   settings with `pap repo apply`, and prints what is left. From here
   `pap` is on your path through mise.

3. **Commit, push, and open the pull request.**

   ```sh
   git add -A && git commit -m "build(pap): adopt the template"
   git push -u origin change/adopt-pap
   gh pr create --draft --label class:infra
   ```

   This one is by hand: `/intent` needs a product layer, which does not
   exist yet. The pull request template comes from the account's
   `.github` repository ([Set up the account](account-setup.md)). Answer
   its Checks section: every box ticked, or a one-line reason on the very
   next line. This first pull request cannot run its own `pr-checks`, so
   it needs a one-time ruleset bypass to merge; see "The first pull
   request" in [Adopt a repository](adopt-a-repo.md#the-first-pull-request).

4. **Write the product layer.** In Claude Code, in the repository, run
   `/envision`. It interviews you and writes `product/` (vision,
   invariants with protected paths, a hypothesis backlog, a conventions
   skeleton). Then `pap codeowners` writes `.github/CODEOWNERS` from the
   protected paths. [Start a project](start-a-project.md) has the detail.

5. **Make the first change.** `/intent <slug> <class>` followed by what
   you want, then `/spec <slug>`, then `/change <slug> <class>` with a
   brief. [Make a change](make-a-change.md) walks the flow.

## Check the result

- `pap doctor`: mise, the git hooks and every tool pin on this machine.
- `pap repo status`: the GitHub side, from settings to labels.
- `mise run check` and `mise run test`: what the hooks and CI run.

## Where next

[Set up the account](account-setup.md) if you own the account or
organisation; [Adopt a repository](adopt-a-repo.md) for the template in
depth; [Troubleshooting](troubleshooting.md) when something refuses.
