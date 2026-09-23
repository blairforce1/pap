# .NET template

The files a repository that builds .NET code receives at its root, on top of
the [base layer](../base/README.md). They are copied as they are; the one
value to replace is the company name in `stylecop.json`.

This layer adds files and `[*.cs]` concerns, and never replaces, edits or
overrides anything in `templates/base/`: rule 3.1 of
[decision 0003](../../decisions/0003-template-layers-compose-additively.md).

| File | What it does |
|---|---|
| `global.json` | Pins the SDK to 10.0.401, the current LTS release, with `rollForward: latestPatch`: a later patch of the 10.0.4xx feature band is accepted, nothing else is. A machine with only a 10.0.3xx or an 11.0 SDK fails at once instead of building with a compiler the repository was not written against. Raise the version here when the feature band moves. |
| `Directory.Build.props` | The build settings every project inherits. Nullable reference types and implicit usings on. Every warning is a build failure: the compiler's, the SDK analyzers' at `latest-recommended`, StyleCop's, and the `.editorconfig` style rules, which `EnforceCodeStyleInBuild` runs in the compiler. The XML documentation file is generated because StyleCop (SA0001) and IDE0005 on build both need it, which also means CS1591 and SA1600 require a doc comment on every public member. Deterministic output, with `ContinuousIntegrationBuild` and `RestoreLockedMode` on when the `CI` variable is set. `packages.lock.json` written on every restore. StyleCop.Analyzers referenced in every project with `stylecop.json` passed to it, and the StyleCop rules that are off listed with the `.editorconfig` setting each would duplicate or contradict. Everything else in StyleCop runs at its default, including SA1413 (trailing comma in a multi-line initialiser), the file header rules and the documentation rules. |
| `Directory.Packages.props` | Central package management: a project references a package by name and the version is set once here. Holds the analyzer version. Every other package an adopting repository uses gets a `PackageVersion` line here; a project scaffolded by `dotnet new` arrives with versions on its references, and restore refuses them (NU1008) until they move. |
| `nuget.config` | nuget.org as the only source, sources from user and machine config cleared, and source mapping sending every package id there. |
| `.globalconfig` | The severity the build enforces that a formatter cannot fix: IDE1006 naming at warning, so a misnamed symbol is a build error. Records why IDE0130 (namespace matches folder) is not here. |
| `stylecop.json` | The settings StyleCop rules read: the company name the file header rules check for, a placeholder to replace, and using directives outside the namespace, matching `csharp_using_directive_placement` in `.editorconfig`. |

## What the build refuses and what the formatter fixes

Measured on SDK 10.0.401 with a class library and an xunit project.

- `.editorconfig` style rules: `dotnet format` fixes them; the build fails on
  them.
- SA1413, the trailing comma: the build fails; `dotnet format` adds it, since
  StyleCop ships the fix and `dotnet format` runs third-party fixers.
- IDE1006 naming: the build fails; `dotnet format --verify-no-changes` lists
  it and exits 2; `dotnet format` says it cannot fix it, applies everything
  else and exits 0.
- SA1633 file header, SA1600 and CS1591 documentation: the build fails;
  nothing fixes them.
- IDE0130 namespace matches folder: not enforced. See `.globalconfig`.
- A stale `packages.lock.json` with `CI` set: restore fails (NU1004).

## What other tools must not duplicate

Style is set once, in the base `.editorconfig`. Each of these files has a
place it could restate a value, and must not.

- **`stylecop.json`**: no `indentation` section (`indentationSize`,
  `tabSize`, `useTabs`). The rules that would read it are off, and
  `.editorconfig` owns indentation.
- **Project files**: no `Nullable`, `ImplicitUsings`,
  `TreatWarningsAsErrors`, analyzer references or `Version` on a
  `PackageReference`. A project overrides an inherited setting only by
  restating it, and that restatement is a review item.
- **`.globalconfig`**: no `.editorconfig` key. `.editorconfig` wins on a
  shared key, so the copy is dead; that is how IDE0130 was found not to be
  enforceable from here.
- **`Directory.Build.props`**: no style and no severities for IDE rules; those
  live in `.editorconfig` and `.globalconfig`. Its `NoWarn` list names
  StyleCop rules only.
- **CI**: `dotnet build` with `CI` set and `dotnet format --verify-no-changes`,
  nothing else. No `--severity`, no `-warnaserror`, no separate StyleCop or
  analyzer step: the build is the gate.
- **Rider and VS Code**: read every file above. Nothing in `.idea/`, `.vs/`,
  `*.DotSettings` or workspace settings; those directories are ignored.

## Checking a repository

```sh
dotnet restore                      # writes packages.lock.json; commit it
dotnet build                        # style, naming, StyleCop and analyzer warnings are errors
dotnet test
dotnet format --verify-no-changes   # exit 2 lists every rule that would change
CI=1 dotnet restore                 # locked mode: NU1004 if the lock file is stale
```
