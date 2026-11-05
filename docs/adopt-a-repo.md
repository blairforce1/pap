# Adopt a repository

Apply the PAP template to a repository, keep it current, and configure the
GitHub side. Everything here is a command today. The reference is the
[base template README](../templates/base/README.md), which describes each
file the template writes, and decisions
[0003](../decisions/0003-template-layers-compose-additively.md) (layers)
and [0008](../decisions/0008-template-sync-by-assemble-and-merge-file.md)
(init and sync).

`pap init` and `pap sync` refuse a working tree with uncommitted changes,
so every change they make is one `git diff` away from being undone. Run
them on a `change/<slug>` branch.

## `pap init <layer>...`

```sh
pap init base [dotnet] [go] [risk] [--version <v>]
```

Layers add files and never replace one another's. Every repository takes
`base` first.

| Layer    | What it adds                                                                                                                                                                                                                                                                                                  |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `base`   | The git hooks (lefthook) and their checks, dprint and editorconfig, gitleaks, the devcontainer, Renovate config, the `pr-checks`, `tests` and `security` workflow callers, `mise run check`, `test`, `fmt`, `setup` and `tidy`, and `scripts/guard-branch.sh`, which the hooks and the Claude Code hook call. |
| `dotnet` | .NET pins and analyzers: `global.json`, `Directory.Build.props`, `Directory.Packages.props`, `.globalconfig`, `nuget.config`, the .NET hook checks and `scripts/heavy-build.sh`. See [its README](../templates/dotnet/README.md).                                                                             |
| `go`     | Go pins, `.golangci.yml` and the Go hook checks. See [its README](../templates/go/README.md).                                                                                                                                                                                                                 |
| `risk`   | `.github/risk.yml`, the opt-in to risk mode: a `risk:*` label and a review-focus comment on every pull request, and the `owner-reviewed` gate on `risk:high` only, in place of the `Approved-by:` line. See [its README](../templates/risk/README.md) and [Make a change](make-a-change.md).                  |

What `init` does, in order: writes the layers (a file that differs from
the template in an existing repository gets conflict markers to resolve);
records the version and layers in `.config/pap.toml`; pins `pap` in
`.config/mise/conf.d/pap.toml` when run from a release; runs
`mise trust && mise install && mise run setup`; runs `pap repo apply` when
`origin` is on GitHub; runs `pap codeowners` when `product/invariants.md`
exists; prints what is left. Run it again with another layer to add that
layer; run it unchanged and nothing changes.

`--version <v>` applies another release's templates than the running
`pap`'s own; it is fetched as tag `v<v>` from GitHub (`PAP_SOURCE`
overrides the source).

## `pap sync`

```sh
pap sync [--version <v>]
```

Re-applies the recorded layers at a new version with a three-way merge per
file: the template at the recorded version is the base, your file is ours,
the template at the new version is theirs. Your edits are kept, the
template's changes arrive, and a clash is left as ordinary git conflict
markers (`<<<<<<< <path> (here)` / `>>>>>>> template v<version>`) with
exit 1. Resolve, then commit.

To take a new version: bump the pin in `.config/mise/conf.d/pap.toml`
(Renovate proposes this as a pull request), then on that branch:

```sh
mise install && pap sync
```

Review with `git diff`, run `mise install` for any new tool pins, commit.

## `pap repo`

```sh
pap repo status [--repo owner/name]
pap repo apply  [--repo owner/name] [--dry-run] [--remove-checks]
```

The GitHub side, from the repository `gh` resolves in the current
directory unless `--repo` says otherwise. `status` is read-only and
reports each item as ok, drift, missing or unavailable on your plan, in
five groups: repository settings, security, the `main` ruleset (with each
required status check by name), the enforcement layers of decision 0002,
and labels. It exits 1 unless everything is ok, unavailable or skipped.

`apply` prints the intended changes, then makes them unless `--dry-run`.
It creates or updates two rulesets by name: `main` (squash merge only,
linear history, no deletion, no force push, review threads resolved, the
required checks) and `all-branches` (no force push on any branch, no
bypass actors; decision 0022, proposed). It applies the settings and
security options, and creates or updates the labels from pap's
`.github/labels.yml` and, for each layer `.config/pap.toml` names,
`.github/labels/<layer>.yml`. It never deletes a
label and never removes a required check it does not know unless given
`--remove-checks`.

To require a check of the repository's own, a workflow job PAP does not
ship, list its check name in `.github/required-checks.yml`, one YAML list
item each (`- coverage`), and run `pap repo apply`. Needs `gh` signed in
as a repository administrator, `jq`, and mikefarah's `yq` (the base layer
pins `yq`).

## `pap codeowners`

```sh
pap codeowners [--owner <owner>] [--check | -]
```

Writes `.github/CODEOWNERS` from the "Protected paths" section of
`product/invariants.md`: every backticked path on a bullet line becomes a
line owned by the section's `Owner:` line (a GitHub user or team, never an
organisation's name). `--owner` stands in when the section has no `Owner:`
line; `--check` writes nothing and exits 1 if the committed file differs
from what would be generated (the pre-commit hook and
`mise run check:codeowners` run it); `-` writes to stdout. The protected
paths are what the `pr-checks` workflow and, in risk mode, the risk level
read, so regenerate after every edit to the section.

## `pap doctor`

```sh
pap doctor
```

The machine side: mise on `PATH` and activated, this configuration
trusted, the git hooks installed, `blame.ignoreRevsFile` set, every pinned
tool installed at its pin, and how many local branches have a gone
upstream (`mise run tidy` removes them with their worktrees). Exits 1 if
anything needs attention.

## Renovate

Every pin the template writes is read by Renovate from
`.github/renovate.jsonc`: the mise tool pins, the devcontainer image and
features, the dprint plugins, pinned GitHub Actions, and the `pap` pin
itself. The owner installs Mend's Renovate GitHub App once per account
and adds each repository ([Set up the account](account-setup.md)); `pap
init` does not. The first run opens an onboarding pull request; merge it.
The base README's "Dependency updates" section lists what is read and
what, if anything, is updated by hand.

## The first pull request

Two things bite once, on the pull request that adopts the template.

**`pr-checks / checks` never reports.** The `pr-checks` caller runs on
`pull_request_target`, so GitHub runs the copy on the base branch, which a
pull request cannot edit. The pull request that adds the caller has no
caller on the base branch yet, so the check never runs, and the ruleset
`pap repo apply` created requires it, so the merge is held. The way
through, once per repository: in the repository's settings, under Rules,
open the `main` ruleset and add yourself to its bypass list; merge; remove
the bypass. Review by hand what the check would have checked (the title,
the `Change:` and `Record:` lines, the Checks boxes, one `class:*` label).
From the next pull request on, every pull request runs the base branch's
caller, including one that edits the caller.

**A check with no baseline.** A check that compares the pull request with
main, a coverage ratchet for example, has nothing to compare against on
the first pull request and cannot pass. Merge the first pull request
through the same bypass, then run `pap repo apply` from main: the checks
`.github/required-checks.yml` names are added to the ruleset and are
required from then on.

The same gap opens when an existing repository moves its caller from
`pull_request` to `pull_request_target` (pap 0.9.0 and later). The base
README's "Moving pr-checks to pull_request_target" gives a two-step route
with no bypass.
