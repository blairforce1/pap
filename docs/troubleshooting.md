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

**`pr-checks` ends in `startup_failure`: "Workflows are being blocked
due to a scheduled brownout of the default `pull_request_target`
protection".** The repository is public, and GitHub's default event policy
blocks `pull_request_target` there (brownouts now, enforced from
2026-12-02). In the repository's Settings > Actions > Policies, create
an Active policy for the workflow path `.github/workflows/pr-checks.yml`
whose allowed events are `pull_request_target` only, then push or re-run
the check; see
[Adopt a repository](adopt-a-repo.md#public-repositories-allow-pull_request_target).
`pap repo status` shows whether one applies. During a brownout window
with no policy, the failure is GitHub's, not the pull request's.

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

**`owner-reviewed` was removed straight after it was added.** The label
counts only when its latest `labeled` event is by a user whose login is
an owner in the base branch's `.github/CODEOWNERS` (rule 23.2). A bot
added it, the agent app or a workflow's token, or a user who is not a
code owner, so `pr-checks` removed it and said why in its output. Add it
yourself with `/pap:reviewed <PR#>`, signed in as a code owner.

## Skills and worktrees

**The worktree script prints `exists <path>` and the skill stops.** A
worktree for `change/<slug>` is already open, probably another session's,
and the skill will not work in it. `git worktree list` shows them. If that
session has finished, `git worktree remove <path>` (or `mise run tidy`
once the pull request has merged) and run the skill again; if it is still
running, wait or pick another slug.

**A cycle made its worktree in the wrong repository.** A cycle launched
from a PM session starts in the PM's directory; before pap 0.16.1 it ran
`/change` there and branched the PM's repository. `pap:cycle` and
`pap:cycle-mechanical` now `cd` to the repository the brief names before
any other command, and `/change` checks it before making the worktree.
For a session on an older plugin, put the `cd` as the brief's first
line. Remove the stray worktree with `git worktree remove <path>` and
delete its branch.

**`/spec` says `/intent` comes first.** It found no
`changes/<slug>/intent.md` with `accepted-by:` and `accepted-on:` on the
branch. Run `/intent <slug> <class>` and say yes to the restatement; the
file is written only on your yes.

**A plugin does not show a new skill after a release.** A plugin installed
from a local checkout loads from that checkout: `git pull` there, then
`/reload-plugins` in Claude Code. A plugin installed from the marketplace
updates with `claude plugin update pap@blairforce1-pap` (then restart the
session), or `claude plugin marketplace update` first if the marketplace
itself is behind.

**`claude plugin install pap --marketplace blairforce1/pap` fails to add
the marketplace.** The message is:

```text
✘ Failed to add marketplace: Cannot add this marketplace: it would download into the folder "blairforce1-pap", which the marketplace "blairforce1-pap" listed under extraKnownMarketplaces in your settings (from dir:/home/you/src/pap) uses, so it can't be added while that entry is listed.
```

Your Claude Code settings already list the marketplace as a directory, a
checkout of pap, and `--marketplace` would add it a second time. Leave it
out. With the plugin not installed, run
`claude plugin install pap@blairforce1-pap`. With an old one installed,
bring that checkout up to date, run
`claude plugin update pap@blairforce1-pap` and restart the session.
`pap doctor`, `pap claude` and `pap new` print the command that fits the
machine.

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
every branch but Renovate's and Dependabot's, except yours: you are its
one bypass actor (decision 0023), and the agent app never is. A branch
behind main merges main; it is never rebased. To force-push on purpose,
push from your own terminal; nothing needs disabling.

**`pap repo status` says "not visible to this token (needs
administration; run from the owner's terminal)".** An agent shell acts as
the agent app, which has no Administration permission, so GitHub hides
ruleset bypass actors and the security settings from it (Dependabot,
push protection, CodeQL). Those
items are `skipped`, not drift; the rest of each ruleset is still
compared. Run `pap repo status` from your own terminal to see them, and
`pap repo apply` there too: from an agent shell it refuses before
writing anything.

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

In a `pap claude` session, every `gh` call and every git push or fetch to
github.com, in any directory, runs through the shim, which mints a
`pap-agent` token scoped to one repository (decision 0023, rule 23.1). When it cannot, it prints one line,
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
repository selected (pap agent-setup)`.** The app has no installation on
the repository's owner. Install it on that account or organisation, with
this repository selected; `pap agent-setup` opens the page.

**`pap-agent's installation on <owner> does not cover <owner>/<name>; add
the repository on the installation's page (pap agent-setup opens it)`.**
The app is installed on the owner but not given this repository. Add it
on the installation's page (GitHub, Settings, Applications, the app,
Configure). This applies to repositories that do not adopt PAP too, such
as a private companion repository: an agent's push there is refused
until it is added. git shows it as `credential helper '!gh auth
git-credential' told us to quit`.

**`git sent no repository path, so no token can be scoped to one`.** The
session was started by a `pap claude` from pap 0.13.0 or earlier, which did not set
`credential.https://github.com.useHttpPath`. Quit and run `pap claude`
(`pap claude --resume` keeps the conversation), or set it with `git
config --global credential.https://github.com.useHttpPath true`.

**`no repository to act for: not in a clone with an origin, and no -R
<owner>/<name>`.** A `gh` call outside a clone, such as `gh api /user` or
`gh search`, names no repository, and a `pap-agent` token is scoped to
one. Run it inside the clone it is about, or pass `-R <owner>/<name>`.

**`origin (<url>) is not on github.com`**, **`'<repo>' is not a repository
on github.com`**, **`GH_HOST is <host>`** or **`git asked for <url>;
pap-agent answers only for https://github.com`.** `pap-agent` acts only
on github.com, and gh would read the keyring for any other host. Point
the call at a github.com repository, or run it from your own terminal.

**A fork flow fails with 403 or 404.** Each token covers one repository,
so a call that touches two (`gh repo fork`, `gh pr create` from a fork's
branch) is refused by GitHub for the other one. Do that step from your
own terminal.

**`guard-route: refusing gh ... this Claude Code session was not started
by pap claude`, outside an adopting repository.** When the session's
project adopts PAP, the hook needs `pap claude` for `gh` and git to
GitHub in any directory. Quit and run `pap claude`.

**`Resource not accessible by integration` (HTTP 403) from `gh run view`,
`gh run view --log-failed` or `gh pr checks`.** The app's installation on
that owner lacks Actions read: the app was registered before the
manifest asked for it, or the installation's owner has not accepted the
new permission. Add it and
accept it ([account
setup](account-setup.md#adding-a-permission-to-an-existing-app)). A token
cached from before the acceptance keeps the old permissions for its hour;
wait it out, or remove the token cache, `$XDG_RUNTIME_DIR/pap-agent-<uid>`
(`$TMPDIR` on macOS), so the next call mints afresh.

**`GitHub unreachable at https://api.github.com; check the network and
try again`.** curl could not reach the API. Check the network or a proxy;
nothing is cached past a token's hour.

**`GitHub refused an installation token for <owner> (HTTP 401: ...)`.**
GitHub rejected the JWT: the machine's clock is off by minutes (fix the
clock; the JWT allows one minute of drift), the client id in the config is
not this app's, or the key was regenerated on the app and this machine has
the old one (import the new key).

**`no --owner, and origin is not a GitHub remote`.** `pap agent-token`
with no `--owner` or `--repo` names the owner from `origin`. Point
`origin` at `https://github.com/<owner>/<repo>.git`, or pass one.

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
**`this pap has no agent-token --repo; run mise install to get the pinned
pap`.**
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

## Your own sign-in and `pap claude`

Rule 23.4 keeps your `gh` sign-in out of agent shells: Claude Code is
started with `pap claude`, which points `GH_CONFIG_DIR` at an empty agent
directory. [Agent identity and its security](agent-identity-security.md)
has the whole picture.

**`gh (pap shim): this Claude Code session was not started with pap claude
(GH_CONFIG_DIR is <x>, not <agent dir>), so gh could reach your own
sign-in; quit and run pap claude (rule 23.4)`.** Quit the session and start
it with `pap claude`, with the same arguments (`pap claude --resume`
resumes).

**`guard-route: refusing gh in <repo>: this Claude Code session was not
started by pap claude, so it could act as your own GitHub sign-in`** (or
`refusing git fetch`, `git push` and the like). The guard hook's check of
the same thing, made before the command runs: the `gh` first on the
session's `PATH` is not the pap shim, or the shim does not accept the
session. Quit and start it with `pap claude` (`pap claude --resume` keeps
the conversation). To make plain `claude` do this in every PAP
repository, add `eval "$(pap shell-init bash)"` (or `zsh`) to your shell's
startup file; `pap doctor` says whether this shell has it ([Account
setup](account-setup.md#your-own-sign-in-and-pap-claude)). A project-manager
session started as plain `claude`
passes this to every cycle it starts, since they inherit its environment:
restart the PM session with `pap claude`.

**`gh (pap shim): <agent dir>/hosts.yml holds a github.com sign-in`.**
Something signed in inside the agent directory, which must stay empty.
Remove that `hosts.yml` from your own terminal.

**The guard hook refuses `GH_CONFIG_DIR set in an agent's command`.** An
agent's command set, exported or unset `GH_CONFIG_DIR`, or ran `env -i`,
any of which moves gh off the agent directory. Nothing an agent does needs
it. A mention elsewhere, such as `grep GH_CONFIG_DIR= docs`, passes; a
heredoc line that assigns it is read as a command and refused.

**The guard hook refuses `a read of gh's keyring entry or token`.** An
agent's command looked up gh's keyring entry (service `gh:github.com`)
with `secret-tool` or `security`, dumped the keychain, or ran `gh auth
token` or `gh auth status -t`. An agent never needs your token; it acts
as `pap-agent` through the shim.

**The guard hook refuses `reviewed.sh` or `accept.sh` `run from an agent's
command`.** Those scripts act as you. Invoke `/pap:reviewed` or
`/pap:accept` yourself; the skill runs its script directly, out of the
hook's sight.

**The guard hook refuses `gh run as <path>, past the pap gh shim`.** In
an adopting repository an agent ran `gh` by a path (`/usr/bin/gh`,
`./gh`) or with `PATH=` set, which skips the shim. Run `gh` by name.
`command gh` and `env gh` pass: they find the shim on `PATH`.

**`refused: gh has no default directory at <path>, so this cannot act as
you`.** `/pap:reviewed` or `/pap:accept` found no gh directory to act
from. Sign in from your own terminal with `gh auth login`.

**`pap doctor` items under "sign-ins (rule 23.4)":**

- `missing your gh sign-in`: run `gh auth login` in your own terminal.
  From an agent shell it is `skipped`, never read.
- `warn your gh token in the keyring`: the token is in plain text in
  gh's `hosts.yml`. Run `gh auth logout --hostname github.com`, then `gh
  auth login` without `--insecure-storage`.
- `missing`, `drift` on `agent gh directory`: start Claude Code with `pap
  claude`, which creates it at mode 700; `chmod 700` it, or remove a
  `hosts.yml` in it, as printed.
- `drift this shell`: an agent shell not started by `pap claude`; quit
  and restart the session with it.

## The `pap` command

**`pap init` or `pap sync`: "the working tree has uncommitted changes".**
Commit or stash first; both refuse a dirty tree so that their changes can
be undone with `git diff`.

**`pap sync` exits 1 with conflict markers.** The template and your
repository changed the same lines. Resolve each `<<<<<<< <path> (here)` /
`>>>>>>> template v<version>` block, then commit; the version is already
recorded.

**`pap version` prints an old version, or `pap repo status` lacks lines the
changelog promises.** Your shell found a stale `pap` first on `PATH`,
often from an old install directory. `type -a pap` lists every `pap` in
order; remove or reorder the stale one. To run a known version whatever
`PATH` holds, pin it:
`mise exec github:blairforce1/pap@<version> -- pap repo status`.

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
