# Base template

The files every repository that adopts PAP receives, copied to the repository
root as they are. They are generic: nothing in them names a project, a
framework version or a person.

| File | What it does |
|---|---|
| `.editorconfig` | The single source of style. The `[*]` section sets encoding, line endings, final newline, trailing whitespace and two-space indentation for every file. The `[*.cs]` section sets four-space indentation and the full set of `dotnet_` and `csharp_` style rules, each with a severity, so `dotnet format` applies them and `dotnet format --verify-no-changes` fails when they are broken. `[*.go]` and `[{Makefile,*.mk}]` switch to tabs because gofmt and make require them. Rules at `suggestion` are taste calls the IDE offers and nothing enforces; naming rules are there too, because `dotnet format` cannot rename and aborts on a naming warning. |
| `.gitattributes` | Makes git agree with the editor: LF on every platform, C# hunks headed by the enclosing method, binary types marked so they are never normalised, lock files marked generated so GitHub collapses them, `CHANGELOG.md` merged as a union so parallel entries do not conflict, and `.devcontainer` and `.github` left out of archives. |
| `.gitignore` | OS, editor, .NET and node artefacts, in commented sections. Editor settings directories are ignored whole. |
| `.git-blame-ignore-revs` | Formatting-only commits, one hash per line, that `git blame` and GitHub skip. Starts empty; the first repository-wide `dotnet format` commit goes in first. Needs `git config blame.ignoreRevsFile .git-blame-ignore-revs` once per clone, which `mise run setup` does. |
| `.config/mise/conf.d/base.toml` | Exact pins for lefthook, dprint, gitleaks, shellcheck and editorconfig-checker, and the `setup`, `check` and `fmt` tasks. mise reads every file in `conf.d/`, so a language layer ships its own file beside this one and nothing is merged. `setup` installs the git hooks and sets `blame.ignoreRevsFile`; it is a task, not a mise `postinstall` hook, because mise hooks need `experimental = true` and that would switch experimental features on for the whole repository. `check` runs every `check:*` task and `fmt` every `fmt:*` task, with `--continue-on-error` so one run reports every failure; a language layer adds its steps as `check:<lang>` and `fmt:<lang>`. Before the formatters, `fmt` strips a UTF-8 byte-order mark from every text file git tracks or would track, since `charset = utf-8` covers all of them and some generators, `dotnet new` among them, write one. editorconfig-checker is pinned through the deprecated `ubi` backend: the aqua entry asks for an asset the release does not ship, and the `github` backend fails its attestation check on mise 2026.5.12. `ubi` is removed in mise 2027.1.0. |
| `lefthook.yml` | The git hooks. pre-commit, on staged files only, fixing nothing: `dprint check`, editorconfig-checker, `gitleaks git --pre-commit --staged` (the gitleaks 8.30 form; `protect` is gone) and shellcheck on staged `.sh` files. pre-push: `scripts/guard-branch.sh push`, as a `script` job with `use_stdin`, because lefthook v2 skips `run` jobs when HEAD has no diff against its upstream and `git push origin HEAD:main` from an already-pushed branch would get through. `rc: ./.lefthookrc` runs before every job (the `./` is needed: POSIX `.` looks a slash-less name up on PATH). `extends: .config/lefthook/*.yml` pulls in each language layer's jobs; with no language layer the glob matches nothing and that is fine. |
| `.lefthookrc` | Puts mise's shims first on PATH before every hook job, so the hooks find the pinned tools from a shell, GUI client or agent session that has not activated mise. A shim resolves the version this repository pins and works without `mise` itself on PATH. The hook script finds lefthook by the absolute path `lefthook install` wrote into it. |
| `scripts/guard-branch.sh` | Refuses a push from any branch but `change/<id>`, and any push to `main` (decision 0002). In this repository it is a symlink to pap's own `scripts/guard-branch.sh`, so there is one copy; the sync tool copies the file it points at. |
| `dprint.json` | Formats JSON, YAML, Markdown, TOML and Dockerfiles, at pinned plugin versions. Sets no indentation, tab or line-ending option: its defaults match the `[*]` section, and the comment in the file names each pair. Excludes lock files and `artifacts/`. |
| `.editorconfig-checker.json` | Excludes the types dprint formats, so each file has one checker. Turns off only the indent-size check: it refuses any line whose leading spaces are not a multiple of `indent_size`, which rejects aligned continuation lines such as the XML comments in the .NET layer. Indent style, line endings, final newline, trailing whitespace and charset are still checked. |
| `.gitleaks.toml` | The gitleaks default rules, plus an allowlist of paths whose content is generated hashes: `packages.lock.json`, `*-lock.json`, `.git-blame-ignore-revs`. A false positive in a hand-written file takes a `gitleaks:allow` comment on that line, not a path here. |

## Adding a language

A language layer adds its own `[*.ext]` section to this `.editorconfig`,
its own `.config/mise/conf.d/<lang>.toml` for tool pins and `check:<lang>` and
`fmt:<lang>` tasks, and its own `.config/lefthook/<lang>.yml` for hook jobs,
and stops there. It never overrides the
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
  is no `.vscode/settings.json` in the template and the directory is ignored.
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
