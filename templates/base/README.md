# Base template

The files every repository that adopts PAP receives, copied to the repository
root as they are. They are generic: nothing in them names a project, a
framework version or a person.

| File | What it does |
|---|---|
| `.editorconfig` | The single source of style. The `[*]` section sets encoding, line endings, final newline, trailing whitespace and two-space indentation for every file. The `[*.cs]` section sets four-space indentation and the full set of `dotnet_` and `csharp_` style rules, each with a severity, so `dotnet format` applies them and `dotnet format --verify-no-changes` fails when they are broken. `[*.go]` and `[{Makefile,*.mk}]` switch to tabs because gofmt and make require them. Rules at `suggestion` are taste calls the IDE offers and nothing enforces; naming rules are there too, because `dotnet format` cannot rename and aborts on a naming warning. |
| `.gitattributes` | Makes git agree with the editor: LF on every platform, C# hunks headed by the enclosing method, binary types marked so they are never normalised, lock files marked generated so GitHub collapses them, `CHANGELOG.md` merged as a union so parallel entries do not conflict, and `.devcontainer` and `.github` left out of archives. |
| `.gitignore` | OS, editor, .NET, Go and node artefacts, in commented sections. Go binaries have no fixed extension, so the Go section ignores test binaries, coverage profiles and pprof output, and relies on `bin/` for `go build -o bin/`. Editor settings are ignored: `.idea/` and `.vs/` whole, `.vscode/` by content, so that `.vscode/extensions.json` can be let back in (git cannot re-include a file under an ignored directory). |
| `.git-blame-ignore-revs` | Formatting-only commits, one hash per line, that `git blame` and GitHub skip. Starts empty; the first repository-wide `dotnet format` commit goes in first. Needs `git config blame.ignoreRevsFile .git-blame-ignore-revs` once per clone, which `mise run setup` does. |
| `.config/mise/conf.d/base.toml` | Exact pins for lefthook, dprint, gitleaks, shellcheck and editorconfig-checker, and the `setup`, `check` and `fmt` tasks. mise reads every file in `conf.d/`, so a language layer ships its own file beside this one and nothing is merged. `setup` installs the git hooks and sets `blame.ignoreRevsFile`; it is a task, not a mise `postinstall` hook, because mise hooks need `experimental = true` and that would switch experimental features on for the whole repository. `check` runs every `check:*` task and `fmt` every `fmt:*` task, with `--continue-on-error` so one run reports every failure; a language layer adds its steps as `check:<lang>` and `fmt:<lang>`. Before the formatters, `fmt` strips a UTF-8 byte-order mark from every text file git tracks or would track, since `charset = utf-8` covers all of them and some generators, `dotnet new` among them, write one. editorconfig-checker is pinned through the deprecated `ubi` backend: the aqua entry asks for an asset the release does not ship, and the `github` backend fails its attestation check on mise 2026.5.12. `ubi` is removed in mise 2027.1.0. |
| `lefthook.yml` | The git hooks. pre-commit, on staged files only, fixing nothing: `dprint check`, editorconfig-checker, `gitleaks git --pre-commit --staged` (the gitleaks 8.30 form; `protect` is gone) and shellcheck on staged `.sh` files. pre-push: `scripts/guard-branch.sh push`, as a `script` job with `use_stdin`, because lefthook v2 skips `run` jobs when HEAD has no diff against its upstream and `git push origin HEAD:main` from an already-pushed branch would get through. `rc: ./.lefthookrc` runs before every job (the `./` is needed: POSIX `.` looks a slash-less name up on PATH). `extends: .config/lefthook/*.yml` pulls in each language layer's jobs; with no language layer the glob matches nothing and that is fine. |
| `.lefthookrc` | Puts mise's shims first on PATH before every hook job, so the hooks find the pinned tools from a shell, GUI client or agent session that has not activated mise. A shim resolves the version this repository pins and works without `mise` itself on PATH. The hook script sources this file too, before it looks for lefthook, so it finds lefthook through the shim; the absolute path `lefthook install` writes is only a fallback. That is why hooks installed in the devcontainer work on the host and the reverse: the path names one side's home directory, the shim exists on both. Where no lefthook is reachable, the hook script prints "Can't find lefthook in PATH" and exits 0, letting the commit through unchecked; this file refuses the commit instead and names the command to run. `LEFTHOOK=0` still skips the hooks. |
| `scripts/guard-branch.sh` | Refuses a push from any branch but `change/<id>`, and any push to `main` (decision 0002). In this repository it is a symlink to pap's own `scripts/guard-branch.sh`, so there is one copy; the sync tool copies the file it points at. |
| `scripts/gen-codeowners.sh` | Writes `.github/CODEOWNERS` from the "Protected paths" section of `product/invariants.md`, each path owned by `@blairforce1`, so GitHub and the `pr-checks` workflow see the same protected paths the invariants name. `mise run check:codeowners` fails when the tracked file is stale and passes where `product/invariants.md` does not exist yet. A symlink to pap's own copy, like `guard-branch.sh`. |
| `dprint.json` | Formats JSON, YAML, Markdown, TOML and Dockerfiles, at pinned plugin versions. Sets no indentation, tab or line-ending option: its defaults match the `[*]` section, and the comment in the file names each pair. Excludes lock files and `artifacts/`. |
| `.editorconfig-checker.json` | Excludes the types dprint formats, so each file has one checker. Turns off only the indent-size check: it refuses any line whose leading spaces are not a multiple of `indent_size`, which rejects aligned continuation lines such as the XML comments in the .NET layer. Indent style, line endings, final newline, trailing whitespace and charset are still checked. |
| `.devcontainer/devcontainer.json` | One container for every language layer. mise installs every toolchain from `.config/mise/conf.d/`, so the image is plain Debian (`mcr.microsoft.com/devcontainers/base`, trixie), not a language image, and there are no language features; adding a layer changes nothing here. The container runs as the image's non-root `vscode` user, adds the git and GitHub CLI features, and forwards no ports, auto-forwarding included. The image and both features are pinned by digest, with the version in a comment beside each. mise is installed by `onCreateCommand` from its versioned `install.sh` release asset, checked against a sha256; that script carries the checksum of every mise binary it fetches. There is no official mise feature, and the community one fetches unpinned helpers at build time. The same command first restores `/tmp` to mode 1777 if it is not writable: a feature build under podman leaves it root-owned 0755. `postCreateCommand` is the clone setup, `mise trust && mise install && mise run setup`. `remoteEnv` puts mise and its shims on PATH for terminals and extensions. The extension list is the one in `.vscode/extensions.json`. |
| `.vscode/extensions.json` | The recommended extensions: EditorConfig, C# Dev Kit, Go, dprint, YAML, markdownlint and ShellCheck. No settings: style lives in `.editorconfig`. The list covers every supported language, not the ones a repository uses, because the file cannot be split per layer and a recommendation for an absent language is harmless. This is decision 0003 rule 3, the treatment `.gitignore` gets, and the only editor file that gets it: every other layer-specific file is contributed per layer. `devcontainer.json` repeats the list under `customizations.vscode`; change both together. |
| `.gitleaks.toml` | The gitleaks default rules, plus an allowlist of paths whose content is generated hashes: `packages.lock.json`, `*-lock.json`, `.git-blame-ignore-revs`. A false positive in a hand-written file takes a `gitleaks:allow` comment on that line, not a path here. |

## Adding a language

A language layer adds its own `[*.ext]` section to this `.editorconfig`,
its own `.config/mise/conf.d/<lang>.toml` for tool pins and `check:<lang>` and
`fmt:<lang>` tasks, and its own `.config/lefthook/<lang>.yml` for hook jobs,
and adds its editor extension to `.vscode/extensions.json` and
`.devcontainer/devcontainer.json`, and stops there. It never overrides the
`[*]` section and never edits another layer's files. The base settings are
the contract every layer builds on. A language that needs different
indentation, as Go and make do, says so in its own section, where the
exception is visible and scoped to its files.

## Hook speed

A hook that is slow gets skipped, and a skipped hook checks nothing. So:

- **pre-commit** runs formatter checks and file-local checks on staged files
  only: nothing that compiles, restores packages, resolves dependencies or
  analyses more than the file in front of it. The hook as a whole finishes in
  under two seconds. The base jobs qualify: dprint, editorconfig-checker and
  shellcheck read one file at a time, and gitleaks reads the staged diff and
  must run before a secret is in a commit.
- **pre-push** runs anything that compiles or analyses a program: builds,
  analyzers, linters that type-check, vulnerability scans.
- **CI is the gate.** Hooks can be skipped (`--no-verify`, `LEFTHOOK=0`) and
  run only on what changed; CI runs `mise run check` on everything.

A language layer's pre-commit job that needs a build is in the wrong hook.

## What other tools must not duplicate

Style is set once, here. A second copy of any of these values drifts, and
the drift is found by the next person whose editor disagrees with CI.

- **dprint** (`dprint.json`): do not set `indentWidth`, `useTabs`, `newLineKind`
  or `lineWidth`, globally or per plugin. dprint does not read `.editorconfig`,
  but its defaults (two spaces, LF) match the `[*]` section. If a default ever
  changes, change `.editorconfig` first and record the mismatch there.
- **Rider**: it reads `.editorconfig` and prefers it over its own settings. Do
  not enable "Override .editorconfig" and do not put code style into
  `*.sln.DotSettings` or `.idea/`. The `.idea/` tree is ignored anyway.
- **VS Code**: the EditorConfig extension and C# Dev Kit read this file. There
  is no `.vscode/settings.json` in the template, and `.gitignore` ignores
  everything in `.vscode/` but `extensions.json`.
  Do not set `editor.tabSize`, `editor.insertSpaces`, `editor.detectIndentation`,
  `files.eol`, `files.insertFinalNewline` or `files.trimTrailingWhitespace`
  in workspace settings.
- **`dotnet format`**: takes everything from `.editorconfig`. Pass no
  `--severity`; the default threshold, `warn`, is what the file is written
  against.

## Setting up a clone

Once per clone:

```sh
mise trust && mise install && mise run setup
```

`trust` because mise refuses an untrusted configuration, `install` for the
pinned tools, `setup` for the git hooks and `blame.ignoreRevsFile`. `pap
init` will run this sequence when it exists.

The devcontainer runs the same sequence as its `postCreateCommand`. Hooks
installed on either side work on both: see the `.lefthookrc` row.

## Rider and other editors

Without the devcontainer, run the clone setup above on the host: `mise trust
&& mise install && mise run setup` installs the same pinned toolchains and
the same git hooks the container gets. Rider needs nothing else: it reads
`.editorconfig` and, in a repository with the .NET layer, `.globalconfig`
natively, so style and analyzer severities match the command line. Nothing
under `.idea/` is tracked; Rider's project state stays personal. Any other
editor that reads `.editorconfig` gets the same style the same way.

## The pap repository's own tooling

pap's root `lefthook.yml` and `mise.toml` predate this layer and differ from
it. The sync tool brings them into line with this template as its first
dogfood run; they are not edited by hand in the meantime.

## Checking a repository

```sh
dotnet format --verify-no-changes   # exit 2 lists every file and rule that would change
dotnet format                       # applies them
git config blame.ignoreRevsFile .git-blame-ignore-revs   # once per clone
mise trust && mise install && mise run setup   # once per clone
mise run check                      # every hook's check on the whole repository
mise run fmt                        # byte-order marks, then every formatter
```
