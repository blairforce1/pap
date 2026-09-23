Rules at `suggestion` are taste calls the IDE offers and nothing enforces; naming rules are there too, because `dotnet format` cannot rename and aborts on a naming warning. |# Base template

The files every repository that adopts PAP receives, copied to the repository
root as they are. They are generic: nothing in them names a project, a
framework version or a person.

| File | What it does |
|---|---|
| `.editorconfig` | The single source of style. The `[*]` section sets encoding, line endings, final newline, trailing whitespace and two-space indentation for every file. The `[*.cs]` section sets four-space indentation and the full set of `dotnet_` and `csharp_` style rules, each with a severity, so `dotnet format` applies them and `dotnet format --verify-no-changes` fails when they are broken. Rules at `suggestion` are taste calls the IDE offers and nothing enforces. |
| `.gitattributes` | Makes git agree with the editor: LF on every platform, binary types marked so they are never normalised, lock files marked generated so GitHub collapses them, `CHANGELOG.md` merged as a union so parallel entries do not conflict, and `.devcontainer` and `.github` left out of archives. |
| `.gitignore` | OS, editor, .NET and node artefacts, in commented sections. Editor settings directories are ignored whole. |

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

## Checking a repository

```sh
dotnet format --verify-no-changes   # exit 2 lists every file and rule that would change
dotnet format                       # applies them
```
