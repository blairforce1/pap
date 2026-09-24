# .NET template

The files a repository that builds .NET code receives at its root, on top of
the [base layer](../base/README.md). They are copied as they are; nothing in
them names a project or a person.

This layer adds files and `[*.cs]` concerns, and never replaces, edits or
overrides anything in `templates/base/`: rule 3.1 of
[decision 0003](../../decisions/0003-template-layers-compose-additively.md).

| File | What it does |
|---|---|
| `global.json` | Pins the SDK to 10.0.401, the current LTS release, with `rollForward: latestPatch`: a later patch of the 10.0.4xx feature band is accepted, nothing else is. A machine with only a 10.0.3xx or an 11.0 SDK fails at once instead of building with a compiler the repository was not written against. Raise the version here when the feature band moves. `global.json` is authoritative for the SDK version. |
| `mise.toml` | The same SDK version as a mise tool pin, so `mise install` provides the SDK `global.json` asks for. The two must agree; when they differ, `global.json` is right and this line is the bug. The sync tool merges this file into the repository's `mise.toml` (decision 0003) and will check the two agree. |
| `Directory.Build.props` | The build settings every project inherits. Nullable reference types and implicit usings on. Every warning is a build failure: the compiler's, the SDK analyzers' at `latest-recommended`, the third-party analyzers', and the `.editorconfig` style rules, which `EnforceCodeStyleInBuild` runs in the compiler. The XML documentation file is generated so IDE0005 runs on build, with CS1591 off so that does not become a documentation mandate. MA0007, the trailing comma in a multi-line initialiser, raised to an error here rather than in `.globalconfig` because `dotnet format` reads severities from compilation options and `.editorconfig` only; set here, the build refuses a missing comma and the formatter adds it. Provenance, for process principle 6 (every artefact records what produced it): deterministic output, `ContinuousIntegrationBuild` when the `CI` variable is set, SourceLink (built into the SDK for GitHub, so no package reference), `PublishRepositoryUrl` and `EmbedUntrackedSources`. All build output under `artifacts/` (`UseArtifactsOutput`), so no `bin/` or `obj/` in project folders. `packages.lock.json` written on every restore and enforced with `RestoreLockedMode` when `CI` is set. Restore audit of every package, direct and transitive, at every severity (`NuGetAuditMode=all`, `NuGetAuditLevel=low`), so an advisory fails restore. NU3018 kept a warning; see "Package source". Projects whose name ends in `.Tests` are never packed and have CA1707 and CA1816 off. Meziantou.Analyzer and Roslynator.Analyzers referenced in every project. |
| `Directory.Packages.props` | Central package management: a project references a package by name and the version is set once here. Holds the two analyzer versions. Every other package an adopting repository uses gets a `PackageVersion` line here; a project scaffolded by `dotnet new` arrives with versions on its references, and restore refuses them (NU1008) until they move. |
| `nuget.config` | nuget.org as the only source, sources from user and machine config cleared, and source mapping sending every package id there. Signature validation in `require` mode: a package is extracted only if a trusted signer signed it. Trusted are the nuget.org repository signature (three certificates) and Microsoft's author signature (four certificates). |
| `.globalconfig` | What the build enforces beyond `.editorconfig`: IDE1006 naming at warning, so a misnamed symbol is a build error, and every analyzer rule an IDE rule already covers switched off, each group naming the IDE rule. Records why IDE0130 (namespace matches folder) is not there and why MA0007 is not either. |

## Analyzers

Two packages, both pinned in `Directory.Packages.props`.

- **Meziantou.Analyzer** (MA rules): usage, design and performance rules,
  and MA0007, the trailing comma in multi-line initialisers, collection
  expressions and switch expressions.
- **Roslynator.Analyzers** (RCS rules): the analyzers and their fixes. Not
  Roslynator.Formatting.Analyzers: every RCS0xxx rule in it is a formatting
  opinion `.editorconfig` already holds.

Not used, on purpose:

- **StyleCop.Analyzers**. Its last stable release, 1.1.118, is from April
  2019 and its last prerelease, 1.2.0-beta.556, from December 2023; it has
  no support for C# 12 and later syntax.
- **CSharpier**. It is a second formatter with its own opinions, and
  `.editorconfig` is the single style source; `dotnet format` applies it.
- **SonarAnalyzer.CSharp**. Planned for the security-scanning layer, not
  here.

## What the build refuses and what the formatter fixes

Measured on SDK 10.0.401 with a class library and an xunit project.

- `.editorconfig` style rules: `dotnet format` fixes them; the build fails on
  them.
- MA0007, the trailing comma: the build fails; `dotnet format` adds it, since
  Meziantou ships the fix and `dotnet format` runs third-party fixers. That
  holds because the severity is set in `Directory.Build.props`: set in
  `.globalconfig`, the build still failed and `dotnet format` did nothing.
- IDE1006 naming: the build fails; `dotnet format --verify-no-changes` lists
  it and exits 2; `dotnet format` says it cannot fix it, applies everything
  else and exits 0.
- Every other Meziantou and Roslynator rule at warning by default: the build
  fails; those with a fix are applied by `dotnet format`.
- IDE0130 namespace matches folder: not enforced. See `.globalconfig`.
- A stale `packages.lock.json` with `CI` set: restore fails (NU1004).
- A package with a known advisory, direct or transitive: restore fails
  (NU1901 to NU1904, raised by `TreatWarningsAsErrors`).
- An unsigned package: restore fails (NU3004). A package signed by anyone
  not in `trustedSigners`: restore fails (NU3034).

## What other tools must not duplicate

Style is set once, in the base `.editorconfig`. Each of these files has a
place it could restate a value, and must not.

- **Project files**: no `Nullable`, `ImplicitUsings`,
  `TreatWarningsAsErrors`, analyzer references or `Version` on a
  `PackageReference`. A project overrides an inherited setting only by
  restating it, and that restatement is a review item.
- **`.globalconfig`**: no `.editorconfig` key. `.editorconfig` wins on a
  shared key, so the copy is dead; that is how IDE0130 was found not to be
  enforceable from there. Analyzer rules switched off go here and nowhere
  else.
- **`Directory.Build.props`**: no style. Its `NoWarn` carries CS1591 and its
  `WarningsAsErrors` carries MA0007, and nothing joins either list without
  the reason `dotnet format` needs it there.
- **Environment**: `DOTNET_NUGET_SIGNATURE_VERIFICATION` unset. Signature
  verification on restore is on by default on Linux (measured on SDK
  10.0.401), and setting the variable to `false` turns it off, so nothing,
  including `mise.toml`, sets it. Not measured on macOS.
- **CI**: `dotnet build` with `CI` set and `dotnet format --verify-no-changes`,
  nothing else. No `--severity`, no `-warnaserror`, no separate analyzer or
  formatter step: the build is the gate.
- **Rider and VS Code**: read every file above. Nothing in `.idea/`, `.vs/`,
  `*.DotSettings` or workspace settings; those directories are ignored.

## Package source

nuget.org is the only source, and source mapping sends every package id to
it. For a single developer, one public source with its own controls is
simpler and cheaper than running or renting a private feed, and the
controls here address the risks a proxy is usually bought for:

- **Locked restore**: `packages.lock.json` records the exact version and
  content hash of every package, and CI refuses to restore anything else.
- **Audit**: every package in the graph is checked against the advisory
  database on restore, and an advisory of any severity fails it.
- **Required signatures**: every package must carry a signature from a
  trusted signer. Every nuget.org package carries the nuget.org repository
  signature, so a package that did not come through nuget.org, or was
  altered after it, is refused.
- **Source mapping**: a package id resolves from one source only, which
  closes dependency confusion between feeds.

Signature publishers, checked with `dotnet nuget verify --all` on the
packages this template and a `dotnet new xunit` project restore:

| Publisher | Author-signs | Entry in `trustedSigners` |
|---|---|---|
| Microsoft | Yes | `author`, the four certificates from Microsoft's 2026 signing-certificate update, including the one that signs from 2026-09-23 |
| Meziantou (Meziantou.Analyzer) | No, repository signature only | none |
| Roslynator (Roslynator.Analyzers) | No, repository signature only | none |
| xUnit.net, Coverlet, Json.NET (.NET Foundation) | Yes | none; not template packages, covered by the repository entry |

A package is trusted when any one of its signatures matches an entry, so
the Microsoft entry changes nothing while the nuget.org repository entry
stands. It keeps Microsoft packages trusted if that entry is narrowed with
`<owners>` or replaced by a proxy's certificate.

NU3018 is a warning, not an error, in every project. In `require` mode
NuGet also checks revocation on each signature, and on Linux that check
reports "revocation status unknown" for a signature whose certificate has
expired, with every revocation list reachable and current. Measured on SDK
10.0.401, on author signatures (xunit.abstractions 2.0.3 under xunit 2,
Microsoft.Bcl.AsyncInterfaces 6.0.0 and Microsoft.Win32.Registry 5.0.0
under xunit.v3) and on the 2018 nuget.org repository signature
(NETStandard.Library 1.6.1). NuGet reports it as a warning; `TreatWarningsAsErrors`
would fail every such restore. The refusals that matter are other codes and
stay errors: NU3004 for an unsigned package, NU3034 for a signer not in
`trustedSigners`.

What a proxy would add that this does not:

- An audit trail of which packages entered which builds.
- Quarantine: blocking a version after the fact, across every repository.
- Availability when nuget.org is down or a package is unlisted or deleted.
- An approved-component list, which a regulated client may require.

What changes to use a private feed or proxy instead:

- The one source URL in `nuget.config`.
- The source-mapping pattern, from nuget.org to the new source.
- A credential provider on every machine and in CI.
- A check that the proxy passes the original nuget.org signatures through.
  If it re-signs packages, `trustedSigners` needs its certificate.

The realistic options are Azure Artifacts with upstream sources,
Cloudsmith or JFrog on their cloud tiers, and self-hosted ProGet. GitHub
Packages hosts packages but does not proxy nuget.org.

Planned hardening:

- Dependabot with a cooldown, so a version is not adopted the day it is
  published: the dependency-updates layer.
- Trivy and SonarAnalyzer.CSharp: the security-scanning layer.
- The sync tool verifying that `global.json` and `mise.toml` name the same
  SDK version.

## Checking a repository

```sh
dotnet restore                      # writes packages.lock.json; commit it
dotnet build                        # style, naming, analyzer warnings are errors
dotnet test
dotnet format --verify-no-changes   # exit 2 lists every rule that would change
CI=1 dotnet restore                 # locked mode: NU1004 if the lock file is stale
dotnet nuget trust source nuget.org --configfile nuget.config   # refresh repository certificates after a rotation
```
