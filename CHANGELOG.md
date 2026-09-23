# Changelog

All notable changes to the plugins in this marketplace are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Each plugin is versioned independently.

## spec-review

### [1.1.0] - 2026-09-23

#### Added

- Every perspective's findings table has `Invariant` and `Disposition`
  columns, and each perspective reads the change's `intent.md` and
  `product/invariants.md` when the spec sits in `changes/<id>/`.
- `spec-review-full` runs the perspectives the task class makes mandatory
  before adding any by content, and maps "compliance" to the applicable
  regulatory perspectives.

#### Fixed

- `spec-review-gdpr`: UK cookie consent exemptions (PECR regulation 6, in
  force 5 February 2026) listed as UK looser, not stricter; a passing
  design is no longer called compliant.
- `spec-review-reliability`: the timeout inversion is stated the right way
  round.
- `spec-review-gdpr` and `spec-review-ai-act` no longer ask for checks their
  disallowed web tools cannot perform; both carry a last-verified date.
- `spec-review-full` no longer lists the removed `SII-` prefix.

### [1.0.0] - 2026-09-21

#### Added

- Twelve `spec-review-*` skills moved from the blairforce1 dotfiles:
  `full`, `security`, `reliability`, `operations`, `cost`, `performance`,
  `qa`, `ux`, `gdpr`, `ai-act`, `soc2`, `iso27001`.

#### Changed

- `spec-review-full` resolves perspective skills via `${CLAUDE_PLUGIN_ROOT}`
  instead of the user skills directory.

## pap

### [0.1.0] - 2026-09-17

#### Added

- `envision` skill: interviews the human to produce the product layer.
