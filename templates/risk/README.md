# Risk template

The opt-in to risk mode (decision
[0016](../../decisions/0016-risk-labels-and-an-owner-reviewed-label-replace-approved-by.md)):
one file, added on top of the [base layer](../base/README.md) with
`pap init base risk` and kept in step by `pap sync`. It is a layer and not
part of base because its presence changes what a pull request needs before
it merges, and a sync should not make that choice for a repository.

| File               | What it does                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.github/risk.yml` | Read from the base branch by the reusable `pr-checks` workflow. Its presence replaces the `Approved-by:` line of decisions 0012 and 0013 with a `risk:high`, `risk:medium` or `risk:low` label, a review-focus comment, and, for high only, the owner's `owner-reviewed` label, which any push removes. It holds the `default` level, the `tests` and `coverage` globs the weakened-test checks read, and the rules: paths, a level and a review question. |

## Adopting it

1. Take pap 0.9.0 or later first: its `pr-checks` caller runs on
   `pull_request_target`, so a pull request cannot edit the caller to pass
   its own risk gate. Switching the caller takes one extra step or a
   bypass, once; see "Moving pr-checks to pull_request_target" in the
   [base README](../base/README.md).
2. Run `pap init base risk` (with the repository's other layers), and
   edit `.github/risk.yml`: add a rule, with its question, for each part
   of the code where a review is worth the owner's time, and check that the
   `tests` and `coverage` globs match where the repository keeps them.
3. Merge it. Risk mode starts with the next pull request, since the check
   reads the base branch's copy.
4. `pap repo apply` creates the `risk:high`, `risk:medium`, `risk:low`
   and `owner-reviewed` labels in any repository whose `.config/pap.toml`
   names this layer; `pap init base risk` runs it when `origin` is on
   GitHub.
5. Agents never add `owner-reviewed` and never merge (rule 16.2). The
   owner reads the review-focus comment of a `risk:high` pull request and
   adds the label to its head.

## Who the label counts from

The label counts only when its latest `labeled` event is by an owner in
the base branch's `.github/CODEOWNERS`, a user login (rule 23.2, decision
[0023](../../decisions/0023-agents-act-on-github-as-their-own-app.md)).
A team owner (`@org/team`) matches no one, since the workflow's token
cannot read team membership, so name at least one owner by login. A label
added by a bot, the agent app included, or by anyone else is removed, and
the check fails naming who added it.

When a pull request closes, `pr-checks` runs again and its
`pr-checks / merge-report` job warns and comments if a bot merged it.
GitHub does not refuse such a merge; the report makes it visible. Never
make `pr-checks / merge-report` a required check: it is skipped on every
event but `closed`, so it never reports on an open pull request.
`pr-checks / checks` stays the one required pr-checks context.

Dropping the layer from `.config/pap.toml` and deleting the file returns the
repository to decisions 0012 and 0013.
