# .NET template

The files a repository that builds .NET code receives at its root, on top of
the [base layer](../base/README.md). They are copied as they are; nothing in
them names a project or a person.

This layer adds files and `[*.cs]` concerns, and never replaces, edits or
overrides anything in `templates/base/`: rule 3.1 of
[decision 0003](../../decisions/0003-template-layers-compose-additively.md).

| File | What it does |
|---|---|
| `global.json` | Pins the SDK to 10.0.401, the current LTS release, with `rollForward: latestPatch`: a later patch of the 10.0.4xx feature band is accepted, nothing else is. A machine with only a 10.0.3xx or an 11.0 SDK fails at once instead of building with a compiler the repository was not written against. Raise the version here when the feature band moves. |
| `Directory.Build.props` | The build settings every project inherits. Nullable reference types and implicit usings on. Every warning is a build failure: the compiler's, the SDK analyzers' at `latest-recommended`, the third-party analyzers', and the `.editorconfig` style rules, which `EnforceCodeStyleInBuild` runs in the compiler. The XML documentation file is generated so IDE0005 runs on build, with CS1591 off so that does not become a documentation mandate. MA0007, the trailing comma in a multi-line initialiser, raised to an error here rather than in `.globalconfig` because `dotnet format` reads severities from compilation options and `.editorconfig` only; set here, the build refuses a missing comma and the formatter adds it. Deterministic output, with `ContinuousIntegrationBuild` and `RestoreLockedMode` on when the `CI` variable is set. `packages.lock.json` written on every restore. Meziantou.Analyzer and Roslynator.Analyzers referenced in every project. |
| `Directory.Packages.props` | Central package management: a project references a package by name and the version is set once here. Holds the two analyzer versions. Every other package an adopting repository uses gets a `PackageVersion` line here; a project scaffolded by `dotnet new` arrives with versions on its references, and restore refuses them (NU1008) until they move. |
| `nuget.config` | nuget.org as the only source, sources from user and machine config cleared, and source mapping sending every package id there. |
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

- **StyleCop.Analyzers**. Its last stable release is from 2019 and its last
  prerelease from 2023; it has no support for C# 12 and later syntax.
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
- **CI**: `dotnet build` with `CI` set and `dotnet format --verify-no-changes`,
  nothing else. No `--severity`, no `-warnaserror`, no separate analyzer or
  formatter step: the build is the gate.
- **Rider and VS Code**: read every file above. Nothing in `.idea/`, `.vs/`,
  `*.DotSettings` or workspace settings; those directories are ignored.

## Checking a repository

```sh
dotnet restore                      # writes packages.lock.json; commit it
dotnet build                        # style, naming, analyzer warnings are errors
dotnet test
dotnet format --verify-no-changes   # exit 2 lists every rule that would change
CI=1 dotnet restore                 # locked mode: NU1004 if the lock file is stale
```
