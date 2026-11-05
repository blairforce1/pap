# Troubleshooting

What refuses, why, and what to do. Each entry is a symptom you see, the
rule or mechanism behind it, and the fix. The hooks and checks are doing
their job when they refuse; the fix is rarely to get round them.

## Pull requests and checks

**"Merging was blocked due to rule violation errors", with every check
green.** GitHub's rule evaluation sometimes fails on its own side after a
check has just reported, and the merge button shows this message although
no rule is violated. Wait a few seconds and retry, or merge from a shell:
`gh pr merge --squash <PR#>`. If it persists, `pap repo status` shows
whether the ruleset has drifted from what `pap repo apply` set.

**`pr-checks / checks` fails on a Checks box you left unticked, with a
reason.** The reason must be on the very next line after the box, with no
blank line between and not another box. Fix the body and the check re-runs
(`edited` is in its triggers).

**`pr-checks / checks` never reports on a new repository's first pull
request.** The caller runs on `pull_request_target`, from the base branch,
which has no caller yet. One-time ruleset bypass; see
[Adopt a repository](adopt-a-repo.md#the-first-pull-request).

**A coverage check fails or never runs on the first pull request.** It has
no baseline on main to compare against. Merge through the same bypass,
then `pap repo apply` from main makes it required from the next pull
request on; see [Adopt a repository](adopt-a-repo.md#the-first-pull-request).

**`pr-checks / checks` fails on the class label.** Every pull request
carries exactly one `class:*` label. `/change` adds it; if the label raced
the creation, `gh pr edit <PR#> --add-label class:<class>`.

**A `risk:high` pull request is red after a push you did not think
changed anything.** Any push, a merge from main included, removes
`owner-reviewed`. Review the new head and run `/pap:reviewed <PR#>` again.

## Skills and worktrees

**The worktree script prints `exists <path>` and the skill stops.** A
worktree for `change/<slug>` is already open, probably another session's,
and the skill will not work in it. `git worktree list` shows them. If that
session has finished, `git worktree remove <path>` (or `mise run tidy`
once the pull request has merged) and run the skill again; if it is still
running, wait or pick another slug.

**`/spec` says `/intent` comes first.** It found no
`changes/<slug>/intent.md` with `accepted-by:` and `accepted-on:` on the
branch. Run `/intent <slug> <class>` and say yes to the restatement; the
file is written only on your yes.

**A plugin does not show a new skill after a release.** A plugin installed
from a local checkout loads from that checkout: `git pull` there, then
`/reload-plugins` in Claude Code. A plugin installed from the marketplace
updates with `claude plugin update pap` (then restart the session), or
`claude plugin marketplace update` first if the marketplace itself is
behind.

**`/pap:accept` acted on the wrong repository.** Its first line,
`Repository: owner/name (path)`, says which. It acts on the current
repository unless given `--repo <path>`; from a PM session in another
project, pass the checkout whose records you mean:
`/pap:accept --repo ~/src/widgets 0007`.

**`/pap:reviewed` says `refused:`.** The reason is the whole answer: the
pull request is not open, the SHA you gave is not a prefix of its head,
it has no risk label yet (wait for `pr-checks`), or it is not `risk:high`
and needs no label.

## Hooks

**The guard hook refuses `git push` from main, or `git push --delete`.**
In an agent session, a commit or push is refused unless the current branch
is `change/<id>` (decision 0002); `git push origin --delete change/<slug>`
from main is a push from main. Delete the branch on GitHub instead (the
repository deletes a merged pull request's branch on merge; otherwise the
Branches page or `gh api -X DELETE repos/<owner>/<repo>/git/refs/heads/<branch>`
from a shell as yourself), and `mise run tidy` removes the local branch
and worktree once its upstream is gone. A force push is refused by the
hook too, and by an all-branches ruleset, as proposed in
[#90](https://github.com/blairforce1/pap/pull/90) (decision 0022).

**The hook refuses `--no-verify`, `LEFTHOOK=0` or `core.hooksPath`.** An
agent session may not bypass a git hook (rule 5.1). Fix what the hook
reports; if the hook is wrong, that is a change of its own. The hatches
are for you at a shell, not for the agent.

**The hook refuses an `Approved-by:` line, the `owner-reviewed` label or
`gh pr merge`.** Those are the owner's acts (rule 16.2). Do them yourself:
type the line, run `/pap:reviewed`, press merge.

**A commit says "Can't find lefthook in PATH" or the hooks did not run.**
The clone has not been set up: `mise trust && mise install && mise run
setup`, then `pap doctor` to confirm.

## The `pap` command

**`pap init` or `pap sync`: "the working tree has uncommitted changes".**
Commit or stash first; both refuse a dirty tree so that their changes can
be undone with `git diff`.

**`pap sync` exits 1 with conflict markers.** The template and your
repository changed the same lines. Resolve each `<<<<<<< <path> (here)` /
`>>>>>>> template v<version>` block, then commit; the version is already
recorded.

**`pap revisits` prints `unknown (gh: ...)`.** Counting change pull
requests needs `gh` signed in and the network. Sign in and run it again;
`manual` and `on <date>` triggers are counted without `gh`.

**`pap repo status` reports `unavailable-on-plan`.** Push protection and
CodeQL default setup need GitHub Advanced Security on a private
repository, which a Pro personal account does not have. They are applied
only on public repositories; the line is informational.

**`pap codeowners` refuses the owner.** An organisation's own name is not a
valid code owner. Put a user (`@login`) or team (`@org/team`) on the
`Owner:` line of the protected paths section in `product/invariants.md`.
