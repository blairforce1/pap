# Invariants: PAP

Constraints no change may violate. Spec review checks every change against the invariants its intent declares it touches. Each entry: the constraint, the reason, and the record that established it.

pap keeps its decision records in `decisions/` at the repository root, not in `product/decisions/`. Every invariant below comes from an accepted record there; none is new.

Last reviewed: 2026-09-25

## Architectural boundaries

- **INV-001** A template layer adds files and never replaces, edits or overrides a file another layer owns.
  Reason: additive composition is the only rule under which sync can refuse a collision mechanically. ADR: decisions/0003-template-layers-compose-additively.md
- **INV-002** Templates are copied, never rendered; adopting and syncing is a per-file three-way merge with `git merge-file`.
  Reason: nothing in a layer varies per repository, so a template engine would exist only to switch rendering off. ADR: decisions/0008-template-sync-by-assemble-and-merge-file.md
- **INV-003** Hooks, and anything `pap init` runs before `mise install`, are POSIX shell.
  Reason: they run before any other runtime is installed. ADR: decisions/0009-cli-language-deferred.md

## Security posture

- **INV-004** Main changes only by squash-merged pull request with linear history, resolved threads and required checks passing.
  Reason: without a pull request there is no review record, and the process cannot see its own inputs. ADR: decisions/0002-skills-stop-at-draft-pr.md
- **INV-005** An agent session never bypasses a git hook in a repository that adopts PAP.
  Reason: a check the checked party can switch off is not a check. ADR: decisions/0005-agent-sessions-do-not-bypass-hooks.md
- **INV-006** A skill that writes a phase artefact stops at a draft pull request and never merges.
  Reason: acceptance is a human merge, and the merge is the phase event. ADR: decisions/0002-skills-stop-at-draft-pr.md

## Compliance

Compliance here means evidence that the process was followed and can be measured.

- **INV-007** A change under `process/` ships only in a tagged release; adopting repositories pin the tag.
  Reason: the tag is the only boundary both the process and the measures agree on. ADR: decisions/0001-process-changes-are-measured-interventions.md
- **INV-008** Every intervention has a decision record with a PIP, at least one expected effect and a typed revisit trigger.
  Reason: post-hoc stories always fit; attribution needs the prediction first. ADR: decisions/0001-process-changes-are-measured-interventions.md, decisions/0010-revisits-are-typed-and-counted.md
- **INV-009** Every pull request answers its Checks section and declares generated content.
  Reason: an answer nobody checks is not an answer. ADR: decisions/0004-pull-request-checks-are-answered.md

## Data model

- **INV-010** Every emitted event carries the pinned process version.
  Reason: without it no outcome can be attributed to a process version. ADR: decisions/0001-process-changes-are-measured-interventions.md
- **INV-011** An adopting repository records the applied template version and layers in `.config/pap.toml`, separately from the installed pap pin.
  Reason: what is installed and what is applied differ between a bump and the sync that follows it. ADR: decisions/0008-template-sync-by-assemble-and-merge-file.md

## Operational

- **INV-012** Every version a template layer pins is read by Renovate or named in the base README as updated by hand.
  Reason: an unread pin goes stale silently, and the mise pins are the toolchain of every layer. ADR: decisions/0007-dependency-updates-by-renovate.md

## Protected paths

No agent may change these without a human approval recorded on the change.

Proposed, not yet confirmed: see the first open question.

- `process/**`
- `decisions/**`
- `rules.md`
- `product/**`
- `CLAUDE.md`
- `.github/rulesets/**`
- `.github/workflows/**`
- `plugins/pap/hooks/**`
- `scripts/guard-branch.sh`
- `lefthook.yml`
- `tests/**`

## Open questions

Candidate invariants not yet confirmed. Each becomes an invariant, a convention, or is dropped.

- Protected paths: confirm or trim the list above. Raised because envision requires the section. Today a protected path is labelled and noted by `pr-checks`, not refused; settled by deciding whether a missing approval should fail the check.
- Change identity: proposed in decision 0011: the id is the slug (`change/<slug>`, `changes/<slug>/`), and events carry `<owner>/<repo>:<slug>`. Becomes an invariant when 0011 is accepted.
- Events: are outer-loop events derived from the GitHub timeline after the fact, or emitted live by `pap emit`? Raised because INV-010 assumes an emitter. Settled by the first derivation slice (backlog H-004).
- Rules index: must `rules.md` match what the ruleset and workflows actually enforce, checked mechanically? Raised because its enforcement column for 4.1 and 4.2 no longer matches the ruleset. Settled with H-001.
- Coverage: must every principle and section of the process document map to a rule, a backlog item or an explicit deferral? Raised because unbuilt parts went unreported until a manual review. Settled with H-001.
- Findings reach the product layer: must a closed change's findings update the backlog, an invariant or a convention? Candidate from process principle 8 and section 5.11; nothing carries it yet.
