# 0009. The pap CLI stays POSIX shell until a component needs more

- **Status:** accepted
- **Date:** 2026-09-24
- **Deciders:** blairforce1, with Claude Code
- **Supersedes:** none
- **PIP:** none; this is a structural record, not an intervention under 0001
- **Expected effect:** not applicable
- **Introduced in:** v0.5.0
- **Revisit:** when the first component needs structured data and unit tests beyond what shell tests give; expected to be the event emitter (`pap emit`)

## Context

`pap` now has an entrypoint, `bin/pap`, dispatching `init`, `sync`,
`repo`, `codeowners` and `doctor`. Everything it runs is shell:
`assemble.sh`, `gen-codeowners.sh`, `guard-branch.sh` and `repo-sync.sh`.
Some of it has to be. `init` runs before `mise install`, so it can rely on
nothing mise provides, and the git hooks run in whatever shell a GUI
client or agent session gives them. The event emitter planned by decision
[0001](0001-process-changes-are-measured-interventions.md) is different in
kind: it builds CDEvents JSON, reads configuration, and is exactly the
code whose edge cases want unit tests. Choosing its language now would be
choosing before the requirement exists.

## Decision

This is a deferral, not a choice. The scripts stay POSIX shell, and
`repo-sync.sh` stays bash for its arrays. The hooks and anything `pap
init` runs before `mise install` stay shell after any revisit. The CLI's
language is chosen when the first component needs structured data and
unit tests beyond what `tests/*.test.sh` gives, expected to be `pap emit`.
Until then no compiled component is added.

The two candidates, and what each costs a consuming repository:

- **.NET global tool.** Distributed on NuGet, pinned in `.config/mise/`
  or a `dotnet-tools.json` manifest. Costs consumers a .NET SDK or
  runtime of the tool's major version on every machine and CI runner that
  runs it, including Go-only repositories that otherwise have none, plus
  runtime start-up on every hook-adjacent call. Fits the .NET-first
  origin and the maintainer's tooling.
- **Go single binary.** Distributed as release archives per OS and
  architecture, pinned through mise's `github` backend exactly as
  `bin/pap` is (decision
  [0008](0008-template-sync-by-assemble-and-merge-file.md)). Costs
  consumers nothing at run time: one static file, no runtime. Costs pap a
  cross-compiling release job and a platform matrix to maintain.

The reason that carried it: the constraint that forces shell (runs before
anything is installed) is known; the requirement that would justify a
compiled language (the emitter's data handling) is not yet written.

## Considered options

- **Choose Go now.** Lost: a build and release matrix for code that is,
  today, file copying and `git merge-file`.
- **Choose .NET now.** Lost: a runtime requirement on every adopting
  repository before any component needs it.
- **Rewrite the scripts in the chosen language when it is chosen.**
  Rejected in advance for the hooks and pre-install steps, which stay
  shell whatever is chosen.

## Consequences

- Easier: `pap` runs on any machine with git and a POSIX shell, before
  mise or any SDK.
- Harder: structured data in shell is `sed` and `awk` over fixed shapes,
  as `bin/pap` does with `.config/pap.toml` and `mise ls --json`. Every new
  instance is a nudge toward the revisit.
- Follow-up: the revisit records the choice as its own decision, with the
  distribution named in 0008 as the default path for a Go binary.

## Where it is taught or enforced

Taught here and in the header of [`bin/pap`](../bin/pap). Enforced by
nothing: a compiled component would arrive by pull request, and this
record is what that pull request must supersede. The status lifecycle
follows [0001](0001-process-changes-are-measured-interventions.md).
