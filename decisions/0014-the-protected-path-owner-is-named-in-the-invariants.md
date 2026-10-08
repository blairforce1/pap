# 0014. The owner of the protected paths is named in the invariants

- **Status:** proposed
- **Date:** 2026-10-08
- **Deciders:** blairforce1, with Claude
- **Supersedes:** none; amends how [0012](0012-protected-paths-need-an-owners-approved-by-line.md)'s owner is chosen
- **PIP:** none; this is a structural record, not an intervention under 0001
- **Expected effect:** not applicable
- **Introduced in:** v0.7.0
- **Revisit:** when a repository needs different owners for different protected paths, or works with a code host that has no CODEOWNERS

## Context

`scripts/gen-codeowners.sh` writes `.github/CODEOWNERS` from the
"Protected paths" section of `product/invariants.md`. It took the owner
from `--owner`, else from the owner segment of the `origin` remote.

Three callers run it: `pap init` and `pap codeowners` to write the file,
and the pre-commit hook and `mise run check:codeowners` with `--check`.
The last two pass no `--owner`, and `mise run check` runs in CI as
`security / check`, a required check.

Under a personal account the origin's owner is the person, and all three
agree. In a repository an organisation owns, the origin's owner is the
organisation, which GitHub does not accept as a code owner: an owner is a
user or a team. Found adopting 0.6.0 in `arapsys/business-os` on
2026-10-08. The choices there were both wrong:

- Write the file with `--owner <person>`. The hook and the check then
  compare it with a file owned by the organisation, and fail. Once
  `product/invariants.md` exists, `security / check` fails on every pull
  request.
- Write it with no `--owner`. Everything passes, the file names an owner
  GitHub rejects, and 0012's approval is `Approved-by: @<organisation>`,
  which names nobody.

The same holds in a client's repository, where the person who approves is
theirs, not the one who ran `pap init`.

## Decision

The owner is a fact about the repository, written where the protected
paths are written: a line in the "Protected paths" section of
`product/invariants.md`.

```markdown
## Protected paths

No agent may change these without a human approval recorded on the change.

Owner: @alice

- `product/**`
```

- `Owner:` or `Owners:`, not a bullet, naming one or more users or teams,
  separated by spaces or commas. Each name starts with `@`; backticks
  around a name are allowed. Every protected path is owned by all of them,
  and 0012 needs one of them to approve.
- The generator reads the line first. `--owner` is accepted when it
  agrees and refused when it does not. With no line, `--owner` and then
  the origin's owner apply as before, so a repository under a personal
  account needs no change.
- A line it cannot read is refused, and so are two lines. It never falls
  back to the origin when a line is there.
- `pap repo status` reports what GitHub makes of the CODEOWNERS on the
  default branch, through the repository's `codeowners/errors` endpoint:
  ok, drift with each error by line, or skipped when there is no file.
  This is the check that finds an organisation's name used as an owner.

The reason that carried it: the three callers must read the owner from
the same place, and only a file in the repository is in front of all
three.

## Considered options

- **Record the owner in `.config/pap.toml`.** Lost: `pap init` and `pap
  sync` rewrite that file whole and it is marked not to be edited by
  hand. It records what pap applied, not who governs the repository.
- **A setting of its own, such as `.config/pap-owner`.** Lost: a second
  file to protect, and one more place to look. The invariants file is
  already a protected path, so the line is covered by the approval it
  governs.
- **Pass `--owner` from the hook and the task.** Lost: the value would
  live in `lefthook.yml` and `base.toml`, which are the template's files,
  identical in every repository.
- **Ask GitHub whether the origin's owner is a user.** Lost for the hook:
  a pre-commit job makes no network call (base README, "Hook speed").
  Kept where the network is already in use, as the `pap repo status`
  report.
- **An owner per path.** Not needed yet; the Revisit line names it.

## Consequences

- Easier: an organisation's repository, and a client's, name the approver
  once, and the hook, the check and `pap codeowners` agree.
- Easier: pap itself can move to another account without its owner
  changing, since its own section now names `@blairforce1`.
- Unchanged: a repository with no line behaves as before.
- Harder: one more line for `/envision` to ask for. Its template carries
  it.
- Limit: an organisation's repository that adds no line still gets the
  organisation's name as owner. Nothing refuses that locally. `pap repo
  status` reports it, and only once the file is on the default branch.
- Limit: the shape of an error for an organisation's name was not
  observed; the report prints whatever kind, line and source GitHub
  returns.

## Where it is taught or enforced

Taught in the header of `scripts/gen-codeowners.sh`, the base README and
the `/envision` skill's invariants template. Enforced by the pre-commit
`codeowners` job and `mise run check:codeowners`, which now fail a
CODEOWNERS whose owner is not the one the section names. No rule in
[`rules.md`](../rules.md) changes: 4.1 already reads the owners from
CODEOWNERS.
