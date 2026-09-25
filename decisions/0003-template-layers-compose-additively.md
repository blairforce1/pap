# 0003. Template layers compose additively; a language is a layer

- **Status:** accepted
- **Date:** 2026-09-23
- **Deciders:** blairforce1, with Claude
- **Supersedes:** none
- **PIP:** none; this is a structural record, not an intervention under 0001
- **Expected effect:** not applicable
- **Introduced in:** v0.5.0
- **Revisit:** when a third language needs a change to `templates/base/` that is not a new `[*.ext]` section, or two layers ever need to own the same file

## Context

PAP began .NET-first. The first template layer (`templates/base/`, change
`template-base`) turned out to contain almost nothing that is .NET-specific:
line endings, whitespace, ignore patterns, git attributes. The .NET-specific
material (SDK pin, analyzers, package management) is a separate layer. Go is
the next language, and repositories that mix languages (a Go service with
.NET tooling, a .NET API with a TypeScript front end) are expected. Without a
rule for how layers combine, each new language would either fork the base or
overwrite parts of it, and the sync mechanism (planned in change
`template-sync`) would have no way to detect a collision.

## Decision

The template is a set of layers under `templates/`. `base/` holds everything
that is language-neutral. Each language has its own layer (`dotnet/`, `go/`,
and so on) holding only what that language's toolchain needs. A repository
adopts `base` plus zero or more language layers.

Layers compose additively:

1. A layer adds files. It never replaces a file that another layer owns.
2. Two shared files may be touched by a language layer, and only additively:
   `.editorconfig` gains a `[*.ext]` section for the language's extensions,
   and `mise.toml` gains the language's tool pins. Neither may change the
   `[*]` section or another layer's entries.
3. A language layer's other files live under its own names (`global.json`,
   `.golangci.yml`) or in its own directory. Where a language needs a file
   that already exists in `base/` (`.gitignore`, `.github/renovate.jsonc`), the
   language-specific lines go in `base/` under a commented section, because
   those files cannot be split.
4. Adding a language is: one new folder, its `[*.ext]` section, its mise
   pins, its `.gitignore` section, its section in `.github/renovate.jsonc`, its
   security-scanning rules, and its extension id to
   `.vscode/extensions.json` and the devcontainer customizations list.
   Nothing else changes.

The reason that carried it: multi-language repositories are the expected
case, not the exception, and additive composition is the only rule under
which the sync tool can refuse a collision mechanically rather than by
judgement.

## Considered options

- **One template per language pairing** (`dotnet`, `dotnet-go`, `go-ts`).
  Lost: combinatorial, and every base fix is applied N times.
- **One monolithic template with language toggles.** Lost: every file
  carries every language's conditionals; a Go-only repo ships .NET noise.
- **Base owns everything shared; languages own nothing shared.** Lost:
  `.editorconfig` and `mise.toml` genuinely need per-language entries, and
  forcing them into base means base changes with every language.

## Consequences

- Easier: adding Go is a bounded change with a known list of touch points.
- Easier: the sync mechanism has a mechanical collision rule to enforce.
- Easier: `base/` stays small and stable; language churn stays in its layer.
- Harder: `.gitignore` and `.github/renovate.jsonc` carry sections for languages the
  repo may not use. Accepted: an unused ignore pattern is harmless.
- Harder: `mise.toml` must be merged, not copied, by the sync tool. That is
  the one piece of real logic the rule imposes.
- Follow-up: `templates/go/` (change `template-go`) is the first test of the
  rule; the second language is where the rule earns or loses its keep.
- Follow-up: the sync tool (change `template-sync`) must refuse a layer that
  writes a file another layer owns, and must merge `mise.toml`.
- 2026-09-24: the sync tool no longer needs to merge `mise.toml`. mise
  2026.5.12 reads every file in `.config/mise/conf.d/`, and lefthook 2.1.14's
  `extends` takes a glob, so each layer ships its own
  `.config/mise/conf.d/<layer>.toml` and `.config/lefthook/<layer>.yml`, and
  its own `check:<layer>` and `fmt:<layer>` tasks. Measured in a repository
  built from `base` plus `dotnet` (change `template-tooling`). Of the two
  shared files rule 2 names, a language layer now touches only
  `.editorconfig`; the collision check is unchanged.
- 2026-09-24: #26 added `.vscode/extensions.json` and the devcontainer's
  extension list to `templates/base/`, both listing every language's
  extension, as rule 3 does for `.gitignore`. Rule 4 now names the
  extension id as a touch point; it said "nothing else changes" while
  missing it.
- 2026-09-24: [0007](0007-dependency-updates-by-renovate.md) chose Renovate
  over Dependabot, so rules 3 and 4 and the consequence above name
  `.github/renovate.jsonc` where they named `dependabot.yml` and the
  Dependabot ecosystem. A language's section there covers what Renovate's
  managers read of its manifests; a pin they cannot read takes a custom
  manager in the same section, as the mise `dotnet` pin does.

- 2026-09-24: the sync tool is built ([0008](0008-template-sync-by-assemble-and-merge-file.md)).
  `pap init` and `pap sync` assemble layers with `scripts/assemble.sh`,
  which refuses a collision, so rule 3.1 is enforced wherever the
  template is applied.

## Where it is taught or enforced

Backs [`rules.md`](../rules.md) 3.1 (layers add, never replace). Taught in
`templates/base/README.md` ("Adding a language"). Enforced by
`scripts/assemble.sh`, which `pap init` and `pap sync` run. The status
lifecycle follows [0001](0001-process-changes-are-measured-interventions.md).
