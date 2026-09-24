# Go template

The files a repository that builds Go code receives at its root, on top of
the [base layer](../base/README.md). They are copied as they are; nothing in
them names a project or a person.

This layer adds files and never replaces, edits or overrides anything in
`templates/base/` or another language layer: rule 3.1 of
[decision 0003](../../decisions/0003-template-layers-compose-additively.md).
Its shared-file entries live in base, as the decision requires: the `[*.go]`
tab section of `.editorconfig` and the Go section of `.gitignore`.

| File                          | What it does                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.config/mise/conf.d/go.toml` | Pins Go 1.27.1, golangci-lint 2.14.0 and govulncheck 1.8.0. govulncheck is not in mise's registry, so the `go` backend builds it from `golang.org/x/vuln/cmd/govulncheck`. golangci-lint 2.14.0 is built with go1.27.0 and refuses a module whose `go` directive is newer than that, so it is raised with Go. `check:go` runs `gofmt -l`, `go vet ./...`, `golangci-lint run` and `govulncheck ./...`, every step even after one fails, as one script so `check:*` does not pick the parts up twice. `fmt:go` runs `gofmt -w .`. The base `check` and `fmt` tasks pick both up. |
| `.config/lefthook/go.yml`     | pre-commit: `gofmt -l` on staged `.go` files, failing on any file it lists or on a syntax error (`gofmt -l` itself exits 0 when it lists files). pre-push: `golangci-lint run` when the push changes a `.go` file (it runs `govet`, so there is no separate `go vet` job), and `govulncheck ./...` when it changes a `.go` file, `go.mod` or `go.sum`, since a version bump alone can bring a vulnerable dependency in.                                                                                                                                                         |
| `.golangci.yml`               | golangci-lint v2 configuration, `default: none` and every linter named, so the set changes only when this file does. Groups, each commented in the file: correctness (errcheck, govet, ineffassign, staticcheck, unused, which is golangci-lint's standard set), security (gosec, off in `_test.go`), error handling (errorlint, nilerr), resource leaks (bodyclose, rowserrcheck, sqlclosecheck), context (noctx), hygiene (unconvert, misspell). No formatters. Every finding is reported, not the first few per linter.                                                      |

## gofmt, not gofumpt

gofmt is the formatter every Go editor and `gopls` run by default, and it
ships with the toolchain. gofumpt is stricter and a superset, so code it
accepts gofmt accepts, but not the other way round: a contributor whose
editor runs plain gofmt would write code the hook refuses, and fix it by
hand or by learning a second tool. One formatter that editors already agree
with is worth more than the extra rules. Revisit if the team adopts gofumpt
in `gopls` everywhere.

## What the hooks refuse and when

Measured with Go 1.27.1 in a repository built from `base` plus this layer
and a `go mod init` module, from a shell with no mise, Go or linter on PATH
(the base `.lefthookrc` finds them).

- An unformatted `.go` file: refused on commit by `gofmt`, in under 0.01 s.
- An unchecked error and a `go vet` violation (`%d` with a string): the
  commit passes, since pre-commit formats only; the push is refused by
  `golangci-lint` (0.2 s), which reports `errcheck`, `govet` and `unused`.
- `golang.org/x/text` v0.3.0 with `language.ParseAcceptLanguage` called:
  the push is refused by `govulncheck` (0.9 s) with GO-2022-1059 and
  GO-2021-0113. govulncheck reports a vulnerability only when the code can
  reach it; a vulnerable module that is required but not called is listed
  and does not fail.
- `mise run check` reports all of the above in one run; `mise run fmt`
  fixes the formatting and nothing else.

govulncheck fetches the vulnerability database from `vuln.go.dev`, so a
push with no network fails at that job. `LEFTHOOK_EXCLUDE=govulncheck git
push` skips it for one push; CI still runs it.

## Modules

`go.mod` and `go.sum` are per module and not templated: `go mod init`
writes them, and the `go` directive it writes is the Go version installed,
which mise pins. The two must agree; when they differ, the go command
downloads the toolchain `go.mod` names instead of using the pinned one.
Renovate moves the directive and the mise `go` pin in one pull request.

Every Go command in the hooks and tasks runs from the repository root, so
the root holds `go.mod`, or a `go.work` that lists every module. A
repository with modules in subdirectories and no `go.work` would have
`./...` match nothing.

`go.mod` indents its `require` block with tabs while `.editorconfig`'s `[*]`
section says spaces. editorconfig-checker accepts it (measured), and the go
command rewrites the file anyway, so there is no `.editorconfig` entry for it.

## What other tools must not duplicate

- **golangci-lint formatters**: none. gofmt is the one formatter; enabling
  `gofmt`, `gofumpt` or `goimports` under `formatters:` would be a second
  copy of the same decision, and they would disagree the day one is
  configured differently.
- **`go vet` and golangci-lint's `govet`**: pre-push runs only
  golangci-lint, whose `govet` covers `go vet`. `check:go` still runs both,
  and `go vet` there takes the toolchain's default analysers with no flags;
  any analyser setting goes under `linters.settings.govet` in
  `.golangci.yml` and nowhere else.
- **gopls and editor settings**: do not set `gopls.gofumpt`, `gopls.staticcheck`
  or `go.lintTool` in workspace settings. The linters run from
  `.golangci.yml`, and there is no committed editor settings directory.
- **Environment**: `GOFLAGS`, `GOTOOLCHAIN` and `GOPROXY` unset in the
  repository. mise pins the toolchain; a `GOTOOLCHAIN` override would make
  the pin a suggestion.
- **CI**: `mise run check`, nothing else. No separate lint, vet or
  vulnerability step with its own flags.

## Checking a repository

```sh
mise run check                      # gofmt -l, go vet, golangci-lint, govulncheck, and every other layer's checks
mise run fmt                        # gofmt -w, and every other layer's formatters
golangci-lint run                   # the linters alone
govulncheck ./...                   # reachable vulnerabilities; -show verbose lists the unreachable ones too
```
