# 0011. Git is the source of truth; issues are sources that link to it

- **Status:** proposed
- **Date:** 2026-09-25
- **Deciders:** blairforce1, with Claude
- **Supersedes:** none
- **PIP:** none; this is a structural record, not an intervention under 0001
- **Expected effect:** not applicable
- **Introduced in:** v0.6.0
- **Revisit:** when a change id collides with an earlier one, or a measure needs a join that a slug cannot give

## Context

pap's own backlog was drafted as `product/backlog.md` in #46. The question
that followed was whether the backlog, and the change id, should live in
GitHub Issues and Projects instead: an issue number is minted by GitHub,
its timeline is recorded for free, and a pull request can be checked for a
linked issue. Against that, process section 3.4 says the product layer is
version controlled and reviewed like code, an issue edit has no pull
request, diff review or provenance, and agent sessions read files, not
issue trackers. A hypothesis reworded in an issue after its data came in
would leave no trace, which defeats `measured:refuted`.

The change id was an open question in `product/invariants.md`. The
`/change` skill already treats it as the slug: the branch is
`change/<slug>` and the pull request's `Change:` line names `<slug>` when
`changes/<slug>/` exists.

## Decision

Git holds everything actionable: vision, invariants, backlog, conventions,
decision records, and each change's `intent.md`, `spec.md` and
`findings.md`. GitHub Issues, Projects, chats and other tools are sources:
a bug report or an idea may start there, and may hold a first draft, but
work starts from what is merged in git, and nothing reads a source as
canonical. A source links to the git file that absorbed it; the git file
names its source.

A change's id is its slug, minted when `intent.md` is written: the branch
is `change/<slug>`, the folder is `changes/<slug>/`, and events carry the
repository with it (`<owner>/<repo>:<slug>`). Git refuses a second branch
or folder with the same name, so the id is unique without a service to
mint it. `intent.md` records its source (an issue URL, or `none`) and its
hypothesis (`H-NNN` from `product/backlog.md`, or `reactive: <reason>`).

A GitHub Project, where one is used, is a view over issues and pull
requests grouped by their labels. It records nothing the process reads.

The reason that carried it: the process can only measure and review what
passes through a pull request.

## Considered options

- **Backlog and change id in Issues and Projects.** Lost: edits skip
  review and provenance, sessions need the network to know what they are
  building toward, and the process would depend on one hosting service
  for its core records.
- **Issue number as change id, content in git.** Lost: not every change
  starts from an issue, so the id would need a second minting rule; and
  it ties the id to GitHub where a slug does not.
- **Mirror the backlog both ways.** Lost: two copies of one record drift,
  and nothing says which one is right.

## Consequences

- Easier: every record the measures read is reviewed, versioned and
  readable offline; a refuted hypothesis cannot be quietly reworded.
- Easier: issue templates (`intent.yml`, `escape.yml` in
  `blairforce1/.github`) stay useful as intake, without becoming a second
  backlog.
- Harder: moving an item from an issue into git is a manual step. It is
  part of writing `intent.md`, which is already one of the six manual
  items in process section 7, so the count does not grow.
- Harder: a slug is chosen by a person and can be unclear; nothing checks
  its quality.
- Follow-up: `pr-checks` checks that `intent.md` names a source and a
  hypothesis, and that the hypothesis exists in `product/backlog.md`.
- Follow-up: the envision skill writes `product/backlog.md` already; the
  intent skill, when built, writes the source and hypothesis lines.

## Where it is taught or enforced

Backs [`rules.md`](../rules.md) 11.1 and 11.2. Taught here, in
`product/invariants.md` and in the `/change` skill's `Change:` line. Not
yet enforced; the checks are the follow-ups above.
