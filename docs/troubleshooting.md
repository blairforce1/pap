# Troubleshooting

What refuses, why, and what to do. Each entry is a symptom you see, the
rule or mechanism behind it, and the fix. The hooks and checks are doing
their job when they refuse; the fix is rarely to get round them.

## First, run `pap doctor`

From the repository, `pap doctor` checks this machine: git, mise and its
activation, `gh` and its sign-in, `jq`, the `claude` CLI and the PAP
plugins, `flock`, the git hooks, every pinned tool and, in an adopting
repository, what the `pap-agent` app needs. Each failing item
names the command that fixes it on your platform. `pap doctor --fix` runs
the fixes mise can make (`mise trust`, `mise install`) and prints the
rest, which need you: a package manager, `sudo` or `gh auth login`.

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
and worktree once its upstream is gone.

**The guard hook refuses `git push --force` (or `-f`,
`--force-with-lease`, `+<refspec>`).** No branch takes a force push
(decision 0022, proposed): the hook refuses an agent's, and the
`all-branches` ruleset `pap repo apply` creates refuses everyone's on
every branch but Renovate's and Dependabot's, with no bypass actors,
because agents push with your credentials. A branch
behind main merges main; it is never rebased. To force-push on purpose,
disable the `all-branches` ruleset (repository settings, Rules, Rulesets),
push from your own terminal, then run `pap repo apply`, which restores it;
until then `pap repo status` reports it as drift.

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

## The `gh` shim and `pap-agent`

In an agent session in an adopting repository, `gh` and git's pushes run
through the base layer's shim, which mints a `pap-agent` token (decision
0023, rule 23.1). When it cannot, it prints one line,
`gh (pap shim): <reason>. Not falling back to a stored sign-in (rule
23.1)`, and exits 1 without running `gh`. The reasons, and the fix for
each, done by you at a terminal:

**`no pap-agent key in the keyring`.** This machine has no key. Import
it: `pap agent-key import <pem> --client-id <id>` ([account
setup](account-setup.md#the-pap-agent-app)). If the key was imported, the
keyring may be locked; unlock it (log in to the desktop session) and retry.

**`no client id in <path>`.** The key is there but the config is not.
Run the import again with `--client-id <id>`, from the app's settings page.

**`pap-agent is not installed on <owner>; install it there with this
repository selected`.** The app has no installation on the repository's
owner. Install it on that account or organisation, with this repository
selected. If it is installed but this repository is not selected, the
token mints and the push or call fails with 403 or 404: add the
repository to the installation.

**`GitHub unreachable at https://api.github.com; check the network and
try again`.** curl could not reach the API. Check the network or a proxy;
nothing is cached past a token's hour.

**`GitHub refused an installation token for <owner> (HTTP 401: ...)`.**
GitHub rejected the JWT: the machine's clock is off by minutes (fix the
clock; the JWT allows one minute of drift), the client id in the config is
not this app's, or the key was regenerated on the app and this machine has
the old one (import the new key).

**`no --owner, and origin is not a GitHub remote`.** The shim names the
token's owner from `origin`. Point `origin` at
`https://github.com/<owner>/<repo>.git`.

**`openssl is not on PATH`, `curl is not on PATH`, `jq is not on PATH`,
`secret-tool is not on PATH`.** `pap agent-token` needs them; `pap doctor`
prints the install command for this platform (`jq` comes from `mise
install`; openssl, curl and secret-tool from the machine).

**`openssl could not sign with the key in the keyring; re-import it`.**
What the keyring returned is not a usable private key. Import the key
again.

**`<dir> is not this user's own directory; remove it`.** The token cache,
`$XDG_RUNTIME_DIR/pap-agent-<uid>` (`$TMPDIR` on macOS), is a symlink or
owned by someone else. Remove it; `pap agent-token` recreates it at mode
0700.

**`pap is not on PATH, so no pap-agent token; run mise install`** or
**`this pap has no agent-token; run mise install to get the pinned pap`.**
The shim calls `pap agent-token`; the pap mise installs at the repository's
pin carries it.

**`gh (pap shim): no gh on PATH besides this shim; run mise install`.**
The shim found no real `gh` after itself. `mise install` provides the
pinned one.

**`pap agent-setup`: `python3 is needed for the browser hand-off`.**
Install python3, or register the app by hand ([account
setup](account-setup.md#by-hand)).

**`pap agent-setup`: `no answer from GitHub in time; run pap agent-setup
again`.** The browser never came back to the loopback port with the
right `state` (the page was closed, the app not created, or another tab
answered). Run it again; nothing was stored.

**`pap agent-setup`: `GitHub refused the manifest conversion (HTTP
<n>)`.** The code had expired (it lasts an hour) or was used. Run it
again. If GitHub kept an app from the first attempt, delete it on the
app's settings page or pass `--name` for a new one.

**`pap agent-setup`: `GitHub has no account <owner>`.** `--owner`, or
`origin`'s owner, is not a GitHub login.

**`pap agent-setup`: `the global git config (...) is not writable here;
it is managed elsewhere`.** You answered yes to the SSH-to-HTTPS rewrite,
but git could not write your global config: it is read-only, such as
home-manager's link into `/nix/store`. Setup carries on. Add the printed
`[url "https://github.com/"]` lines where the file is generated; with
home-manager, `programs.git.settings.url."https://github.com/".insteadOf =
[ "git@github.com:" "ssh://git@github.com/" ];`, then switch generations.
`pap doctor` shows the rewrite ok once it is in effect.

**The guard hook refuses `git push` to an SSH remote.** An agent pushes
over HTTPS, as the app (rule 23.1). Switch the clone once, from your
terminal: `git remote set-url origin https://github.com/<owner>/<repo>.git`.
The refusal prints the exact command.

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

**`pap codeowners` exits 1.** It found no "Protected paths" section or no
backticked path in `product/invariants.md`, no owner at all, two `Owner:`
lines, an `Owner:` line it cannot read (every name starts with `@`), or a
`--owner` that disagrees with the line. Fix the section and run it again.

**`pap repo status` reports an owner GitHub does not accept.** An
organisation's own name is not a valid code owner, and `pap codeowners`
falls back to the origin remote's owner when the section has no `Owner:`
line. Put a user (`@login`) or team (`@org/team`) on the `Owner:` line and
regenerate.
