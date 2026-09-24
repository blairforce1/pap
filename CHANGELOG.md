# Changelog

All notable changes to the plugins in this marketplace are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Each plugin is versioned independently.

## spec-review

### [1.3.0] - 2026-09-23

#### Added

- Every skill has an `argument-hint` of `<spec path>`.
- `spec-review-full` states in its executive verdict that it is not legal
  advice, an audit or a conformity assessment whenever a regulatory
  perspective ran.
- `spec-review-soc2` asks whether a Type 1 or Type 2 report is intended,
  and over what window.
- `spec-review-ai-act` points UK-only deployments to the ICO's automated
  decision-making and profiling guidance, and notes that the statutory AI
  and ADM code required by SI 2026/425 had not been published.

#### Changed

- `spec-review-gdpr` and `spec-review-ai-act` share one Relaxed under
  vocabulary.
- `spec-review-ux` reviews for the users the spec names and states its
  professional-user assumption only when the spec names none.

#### Fixed

- `spec-review-qa` no longer flags RFC 2119 uppercase SHOULD as a weasel
  word in specs that adopt the keywords.

### [1.2.0] - 2026-09-23

#### Added

- `spec-review-security` reviews AI and agent components (prompt
  injection, excessive agency, unvalidated output, retrieval stores,
  supply chain, unbounded consumption, agent-specific threats), anchored
  to the OWASP LLM and Agentic Top 10 lists by risk name and MITRE ATLAS.
- A triggering eval suite under `evals/` for `claude plugin eval`.

#### Changed

- All five Well-Architected perspectives carry a `WAF principle` column,
  filled with the pillar's design principles by exact name.
- `spec-review-soc2` cites Trust Services Criteria IDs on every item; the
  column is now `Criteria reference`, since boundary definition sits in the
  Description Criteria.

#### Fixed

- `spec-review-ux` no longer fires on requests for feedback on mockups or
  screenshots.
- Operations, security and reliability no longer duplicate the cost, gdpr
  and performance perspectives.
- `spec-review-iso27001` names CC9.2 as the nearest match to A.5.23.

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
- `spec-review-full` keeps the highest single-perspective severity instead of
  raising it by vote, sets the overall verdict by rule, and passes each
  subagent the perspective's full text, the PAP context and its read-only
  restrictions.
- `spec-review-ai-act` continues past a prohibition not yet in application,
  and ties its UK statement to the verification date.
- `spec-review-security` words a Blocker as a design-level judgement.
- Descriptions point code requests at `/code-review`; no `code-review-*`
  skills exist.

### [1.0.0] - 2026-09-21

#### Added

- Twelve `spec-review-*` skills moved from the blairforce1 dotfiles:
  `full`, `security`, `reliability`, `operations`, `cost`, `performance`,
  `qa`, `ux`, `gdpr`, `ai-act`, `soc2`, `iso27001`.

#### Changed

- `spec-review-full` resolves perspective skills via `${CLAUDE_PLUGIN_ROOT}`
  instead of the user skills directory.

## pap

### [0.3.0] - 2026-09-24

#### Added

- The `PreToolUse` hook refuses an agent's hook bypass in a repository
  that adopts PAP (decision 0005): `LEFTHOOK` or `LEFTHOOK_EXCLUDE` set
  anywhere in the command, `git commit --no-verify` or `-n`, `git push
  --no-verify`, and `core.hooksPath` through `git config`, `-c` or
  `--config-env`. It follows `cd`, `git -C`, `env` and command sequences
  as the branch guard does. A commit message that mentions `--no-verify`
  and `git push -n` (a dry run) pass.

#### Fixed

- `env git commit` is recognised as a commit, so the branch guard no
  longer misses it.

### [0.2.0] - 2026-09-23

#### Fixed

- The branch guard hook checks the repository a command targets, not the
  session's: it follows `cd` and `git -C` and runs that repository's
  `scripts/guard-branch.sh`, only where the repository adopts decision 0002.
  A session on `main` no longer blocks commits to other repositories, a
  session elsewhere can no longer commit to a guarded `main` through `cd`,
  and `git -C <dir> commit` and `git -c key=value commit` are no longer
  missed.

### [0.1.0] - 2026-09-17

#### Added

- `envision` skill: interviews the human to produce the product layer.
