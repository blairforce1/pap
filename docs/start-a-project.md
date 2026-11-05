# Start a project

Before the first change, write the product layer: the four files in
`product/` that every later change traces back to (process
[section 3](../process/personal-agentic-process.md#3-product-layer)). The
product layer is the human's artefact (process section 7); `/envision`
gets it out of your head and into the files.

## `/envision`

In Claude Code, in the repository, on a `change/<slug>` branch:

```text
/envision
```

It is an interview, one question at a time, in the main session. Expect
to be pushed back on: "users should find it easy" is not an outcome, and
a feature list is not a vision. It will not invent an invariant you did
not confirm. If `product/` already exists, it reads what is there and runs
as a review.

Five parts, in order:

1. **Vision**: the problem and who has it, what "done enough to matter"
   looks like, non-goals, how success is recognised, constraints on the
   effort. One page.
2. **Invariants**: the constraints no change may violate, by category
   (architectural boundaries, security posture, compliance, data model,
   operational), each with its reason and whether an ADR exists or needs
   a stub. Five to twelve is the target. **Protected paths** are
   mandatory: the files no agent may change without a recorded human
   approval, with an `Owner:` line naming the GitHub user or team who
   approves.
3. **Hypothesis backlog**: every feature rewritten as "We believe
   **[change]** will produce **[outcome]**, measured by **[observable
   signal]**", ranked by value and risk.
4. **The first slice**: the thinnest vertical slice that exercises the
   riskiest invariant end to end, marked in the backlog as the starting
   point.
5. **Conventions skeleton**: headings, plus what the codebase already
   makes obvious (build and test commands, versions). It grows from
   reviews.

It writes `product/vision.md`, `product/invariants.md`,
`product/backlog.md`, `product/conventions.md` and ADR stubs under
`decisions/`, then stops. It does not write an intent; that is your next
step, per change.

## After `/envision`

```sh
pap codeowners
```

writes `.github/CODEOWNERS` from the protected paths and their `Owner:`
line ([Adopt a repository](adopt-a-repo.md#pap-codeowners)); the
pre-commit hook fails if the two drift. Commit the product layer, push,
open a pull request. In risk mode, `product/invariants.md` is always
`risk:high`, so this and every later edit to it waits for your
`owner-reviewed` label ([Make a change](make-a-change.md)).

## The product layer in use

| File                     | Read by                                                       | Changed by                                                                                   |
| ------------------------ | ------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| `product/vision.md`      | `/intent`, `/spec` (the product's name and outcomes)          | You, rarely                                                                                  |
| `product/invariants.md`  | `/intent` (what the change touches, so its risk), spec review | You, with an ADR; `pap codeowners` regenerates CODEOWNERS                                    |
| `product/backlog.md`     | `/intent` (which `H-NNN` the change serves)                   | You, when findings come back. An item exists once it is merged here (decision 0011)          |
| `product/conventions.md` | Every agent session, at the start                             | A review that catches the same mistake twice adds the correction (process 3.4)               |
| `product/domain.md`      | `/spec` (the words its scenarios use)                         | `/spec`, which defines a new term in the same diff as the spec that needs it (decision 0017) |

`product/domain.md`, the domain vocabulary, is the fifth file. Today
`/spec` starts it when a repository has none; `/envision` seeding it is a
planned slice of backlog item H-011.

Protected paths usually include `product/` itself, so an agent cannot
quietly rewrite the vision to fit the code. A change to the product layer
goes through a pull request you review like any other.
