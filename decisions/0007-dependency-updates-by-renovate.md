# 0007. Renovate keeps every template pin current, mise pins included

- **Status:** accepted
- **Date:** 2026-09-24
- **Deciders:** blairforce1, with Claude Code
- **Supersedes:** none
- **PIP:** none; this is a structural record, not an intervention under 0001
- **Expected effect:** not applicable
- **Introduced in:** unreleased
- **Revisit:** when Dependabot ships mise support ([dependabot-core#12320](https://github.com/dependabot/dependabot-core/issues/12320)), Mend changes the Community Cloud terms or permissions, or a layer adds a pin that neither a Renovate manager nor a custom manager can read

## Context

Every repository that adopts the template carries exact pins: the tools in
each layer's `.config/mise/conf.d/<layer>.toml`, the .NET SDK in
`global.json`, packages in `Directory.Packages.props` and
`packages.lock.json`, modules in `go.mod` and `go.sum`, the devcontainer
image and features by digest, and GitHub Actions by commit SHA. A pin that
nobody moves turns into a stale toolchain and an unpatched dependency, and
moving them by hand does not happen weekly. Decision
[0003](0003-template-layers-compose-additively.md) rule 4 already listed
"its Dependabot ecosystem" as a touch point for a new language, before
either tool had been evaluated.

Both tools were checked against current documentation and, for Renovate,
against a dry run of 44.112.3 on a repository built by
`scripts/assemble.sh base dotnet go`:

| Need                                       | Dependabot                                                    | Renovate                                                                                                                                          |
| ------------------------------------------ | ------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| mise pins in `.config/mise/conf.d/*.toml`  | Not supported; the request is On Hold (dependabot-core#12320) | `mise` manager, on by default, matches `conf.d/*.toml`; read every base and Go pin, and `ubi:` and `go:` backends. Skips `dotnet` (no datasource) |
| nuget, `Directory.Packages.props`          | Yes, central package management included                      | Yes                                                                                                                                               |
| .NET SDK in `global.json`                  | `dotnet-sdk` ecosystem, version updates only                  | `nuget` manager, `dotnet-sdk` dependency                                                                                                          |
| gomod, `go.sum`                            | Yes; `go.sum` updated with `go.mod`                           | Yes; `go.sum` updated with `go.mod`, `gomodTidy`                                                                                                  |
| github-actions by SHA with version comment | Yes, comment updated                                          | Yes, SHA and comment updated                                                                                                                      |
| devcontainer image                         | Not documented; features only                                 | Yes, tag and digest                                                                                                                               |
| devcontainer features pinned by digest     | Features by tag, with the devcontainer lock file              | Not by its manager (no version to read); a regex custom manager reading the version comment works                                                 |
| npm                                        | Yes                                                           | Yes                                                                                                                                               |
| Cooldown                                   | `cooldown.default-days`                                       | `minimumReleaseAge`; held when a release has no date unless `timestamp-optional`                                                                  |
| Minor and patch grouped, majors separate   | `groups` with `update-types`                                  | `packageRules` with `groupName`; `separateMajorMinor`                                                                                             |
| Lock file maintenance                      | `versioning-strategy: lockfile-only`, within declared ranges  | `lockFileMaintenance` for `packages.lock.json` and npm; none for `go.sum`                                                                         |
| `build(deps):` prefix, label               | `commit-message.prefix`, `labels`                             | `semanticCommitType`, `semanticCommitScope`, `labels`                                                                                             |
| Access                                     | Native to GitHub, nothing to install                          | Mend's hosted GitHub App, or self-hosted with a token or app                                                                                      |

## Decision

Renovate, with one configuration file in the base layer,
`.github/renovate.jsonc`, carrying every language's section as decision
0003 rule 3 requires. Weekly on Monday before 06:00 UTC; minor and patch
grouped per ecosystem, majors in their own pull requests; a seven-day
`minimumReleaseAge`; `build(deps):` commits; the `class:infra` label. Pins
that must agree move in one pull request: `global.json` with `dotnet.toml`,
and the `go` directive with the mise `go` pin.

The file extends no preset. Built-in presets such as `config:recommended`
ship inside Renovate and cannot be pinned to a tag; the hosted app runs the
current release, so an `extends` would change behaviour without a commit.
Every setting is stated in the file instead, and the file names the
Renovate version it was written against.

The reason that carried it: the mise pins. They are the toolchain of every
layer, the SDKs and linters included, and Dependabot cannot read them and
has put the request on hold. Everything else on the list, both tools do
well enough.

## Considered options

- **Dependabot.** Native, no third party, schema on SchemaStore. Lost: no
  mise support, so every toolchain pin would stay manual, and its
  documentation covers devcontainer features but not the image.
- **Dependabot plus a scheduled workflow running `mise outdated`.** Lost:
  a second updater with its own pull request format, cooldown and
  grouping, written and maintained here, to cover what Renovate covers
  natively.
- **Self-hosted Renovate in a workflow.** Kept as the fallback: same file,
  no Mend app, but a token or GitHub App to manage and runner minutes to
  pay. Adopt it if the hosted app's permissions or terms become
  unacceptable.

## Consequences

- Easier: every pin in the template is proposed for update, mise tools
  included, in grouped weekly pull requests carrying the `class:infra`
  label.
- Easier: a new language adds a commented section to one file.
- Harder: a third party. The Mend app reads and writes code, pull
  requests, issues, checks and workflows in every repository it is
  installed on, and clones each one for the length of a job. The base
  README says what to install and what it sees.
- Harder: two custom managers carry what Renovate's own managers miss: the
  devcontainer features, read from the version comment above each digest
  (the devcontainer CLI refuses a tag and a digest together), and the mise
  `dotnet` pin. The comment format in `devcontainer.json` is now
  load-bearing.
- Harder: the cooldown cannot hold a devcontainer feature, because ghcr.io
  gives no release date; those updates are proposed on the next run.
- Harder: some pins stay manual: mise itself and its install script's
  sha256 in the devcontainer's `onCreateCommand`, and the dprint plugin
  versions in `dprint.json`. The base README lists them.
- Follow-up: decision 0003 rules 3 and 4 name `.github/renovate.jsonc`
  instead of `dependabot.yml` and the Dependabot ecosystem.
- Follow-up: nothing checks that an adopting repository keeps the file or
  that a new pin is covered; the sync tool is where that check belongs.
- 2026-09-24, found on #34: Renovate's own pull requests must pass
  pr-checks. They carry `Change: none` and `Record: none` through
  `prBodyNotes`, and the reusable workflow in `blairforce1/.github` exempts
  a bot account (a login ending in `[bot]`) from the Checks-section and
  provenance checks only, still holding it to the title, `Change:` line and
  class label. The same pull request found that the hosted app reads
  configuration through the GitHub API, which does not follow symlinks, so
  pap carries a copy of the template file, not a link to it.

## Where it is taught or enforced

Backs [`rules.md`](../rules.md) 7.1 (every pin is kept current or named as
manual). Taught in `templates/base/README.md` ("Dependency updates") and in
the comments of `templates/base/.github/renovate.jsonc`. Enforced by
nothing yet. The status lifecycle follows
[0001](0001-process-changes-are-measured-interventions.md).
