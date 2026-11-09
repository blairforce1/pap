# Agent identity and its security

What an agent session can do on GitHub under decision 0023, what keeps it
from acting as you, and what does not. Setup is in [account
setup](account-setup.md#the-pap-agent-app); messages are in
[troubleshooting](troubleshooting.md#the-gh-shim-and-pap-agent).

## What the agent is on GitHub

In a repository that adopts PAP, an agent session acts as a GitHub App you
registered, `<owner>-pap-agent`, shown as `<owner>-pap-agent[bot]`. Its
repository permissions are exactly these, on the repositories you selected
when you installed it:

| Permission      | Access     | Lets the agent                                         |
| --------------- | ---------- | ------------------------------------------------------ |
| Contents        | read/write | push branches                                          |
| Pull requests   | read/write | open and edit pull requests, their labels and comments |
| Workflows       | read/write | push files under `.github/workflows/`                  |
| Checks          | read       | read check results                                     |
| Actions         | read       | read workflow runs, job logs, artifacts and caches     |
| Commit statuses | read       | read statuses                                          |
| Metadata        | read       | read the repository (GitHub requires it)               |

It has no Administration, Issues, Secrets, Members or organisation
permission, so GitHub refuses it any settings, ruleset or
branch-protection write. GitHub does not refuse it a merge: merging needs
only Contents and Pull requests. The guard hook refuses an agent's `gh pr
merge` (rule 16.2); a merge report in `pr-checks` comes with slice (c).
Commits stay yours: authored and SSH-signed by you, with the model in the
`Co-Authored-By` trailer.

Actions read lets a session read its own CI: the workflow runs, the job
logs, the artifacts and the caches of the repositories the app is
installed on (`gh run view --log-failed`, and `gh pr checks`' lookup of
the workflow run). It does not let it re-run, cancel or dispatch a
workflow (those need Actions write), or change Actions settings (that
needs Administration). It does
not reach secrets: GitHub exposes no secret value through the API, and
listing a repository's secret names needs the Secrets permission, which
the app does not have. The risk is what a workflow leaves behind: a log
or an artifact holding sensitive data is readable by every agent session
on that repository. GitHub masks registered secrets in logs, not in
artifacts, and not a value a step prints that was never registered as a
secret. So never upload a secret, a token or real data as an artifact;
the app covers only the repositories you selected when you installed it.

## What keeps your sign-in from an agent

Your `gh` sign-in stays where `gh auth login` puts it: gh's default
directory (`~/.config/gh`, or `$XDG_CONFIG_HOME/gh`), with the token in the
OS keyring. gh keeps it there under the service `gh:github.com` (cli/cli,
`internal/config`, through zalando/go-keyring: a Secret Service item on
Linux, a generic password in the login keychain on macOS). `pap doctor`
warns if the token is in `hosts.yml` in plain text instead.

- **`pap claude`** starts Claude Code with `GH_CONFIG_DIR` set to an agent
  directory (`${XDG_CONFIG_HOME:-~/.config}/gh-agent`; on macOS without `XDG_CONFIG_HOME` `~/Library/Application
  Support/gh-agent`), mode 700, that never holds a sign-in, and with
  `GH_TOKEN`, `GITHUB_TOKEN`, `GH_ENTERPRISE_TOKEN` and
  `GITHUB_ENTERPRISE_TOKEN` unset. A `gh` in an agent shell so finds no
  stored account. It also puts its own `scripts/shim` first on `PATH`:
  Claude Code's Bash tool runs commands non-interactively, so the base
  layer's mise `[env]` path, which only shells mise activates and
  `mise exec`/`mise run` get, never reaches an agent.
- **`pap shell-init`** prints a `claude` shell function that runs `pap
  claude` in an adopting repository. It is a convenience, not a control:
  a session started from a desktop app, an IDE or anything else that does
  not go through your shell skips it, and the shim and the guard hook
  then refuse its GitHub calls in an adopting repository. That is the
  safe failure; start such a session with `pap claude` instead.
- **The `gh` shim**, first on `PATH` in every shell `pap claude` starts,
  handles every `gh` call in that session, in every directory, adopting
  repository or not. It mints a `pap-agent` token scoped to the one
  repository the call names (`-R`/`--repo`, `GH_REPO`, a
  `repos/<owner>/<name>` endpoint for `gh api`, else `origin`) and runs
  the real `gh` with it as `GH_TOKEN`. For git's credential request
  (`gh auth git-credential get`, which git runs for every HTTPS push and
  fetch) it answers itself, for the repository in the request's path.
  `pap claude` gives git, at command scope, an empty github.com helper
  followed by `!gh auth git-credential`, which clears every helper your
  config files set before it (a stored credential, or gh by path as `gh
  auth setup-git` writes it), so the shim is the only one asked; and it
  sets `credential.https://github.com.useHttpPath` so git sends the
  path. A call with no repository (`gh api /user` outside a clone),
  a repository the installation does not cover, another host, or any
  failed mint is refused with the reason, and a refused credential tells
  git `quit=1` so no other helper or prompt answers. The real `gh` never
  runs from the shim in a `pap claude` session without a token, and a
  call with the agent directory but `CLAUDECODE` unset still counts as
  that session (a person's terminal never has that directory). The shim
  also refuses
  when that directory holds a sign-in (any non-empty `hosts.yml`). In an
  agent session not started by `pap claude`, it refuses in an adopting
  repository and runs the real `gh` unchanged elsewhere.
- **The guard hook** refuses an agent's command that changes
  `GH_CONFIG_DIR` (sets, exports, unsets it, or starts with `env -i`), names the agent directory or signs gh in (`gh auth login`, `switch`, `refresh`), which keeps it empty, runs `gh`
  by a path or with `PATH=` changed, reads gh's keyring entry
  (`secret-tool lookup`/`search` naming `gh:`, `security
  find-generic-password`/`find-internet-password` naming `gh:`, `security
  dump-keychain`), or asks gh for the token (`gh auth token`, `gh auth
  status -t`). In an adopting repository it also refuses an agent's `gh`,
  and git's `push`, `fetch`, `pull`, `clone`, `ls-remote` and `remote
  update` to a GitHub HTTPS remote, unless the session was started by
  `pap claude`; it refuses them in any other directory too, repository or
  not, when the session's project (`CLAUDE_PROJECT_DIR`) adopts PAP.
  Claude Code runs hooks with its own environment, the one
  `pap claude` set, so the hook asks the `gh` first on its `PATH`: it must
  be the shim, and the shim's check mode (`PAP_SHIM_CHECK=1`) must accept
  the session by the shim's own tests; a shim without that check mode
  fails it. A dev container with no key passes, as the shim steps aside
  there, judged by `pap agent-key status`, never by a shim in the working
  tree. Local git (`status`, `log`, `diff`,
  `commit`) is never refused for this.
- **`/pap:reviewed` and `/pap:accept`** are the only paths back to your
  sign-in. Their scripts run `gh` from gh's default directory with the
  tokens unset, so the label and the acceptance show you. Only you can
  invoke them: `disable-model-invocation` keeps the model from the skill,
  and the hook refuses an agent's Bash call that runs either script.
  That refusal cannot catch your own invocation, because a skill's
  preprocessing never reaches a PreToolUse hook (checked with a logging
  hook).
- **The `owner-reviewed` gate (slice c).** `pr-checks` counts the label
  only when its latest `labeled` event is by a user whose login is an
  owner in the base branch's `.github/CODEOWNERS` (rule 23.2,
  blairforce1/.github#17); a label the agent app or any other bot added is
  removed, with the reason. On close, its `merge-report` job warns and
  comments when a bot merged the pull request.
- **The owner bypass (slice d).** `pap repo apply` lists you as the one
  bypass actor of the `all-branches` ruleset, mode `always`: your `User`
  on a personal repository (or the admin role, which only you hold there,
  if GitHub refuses a user), the organisation-admin role on an
  organisation's. It lets you force-push any branch from your own
  terminal; that is now the override, with no ruleset to disable and
  re-apply. The agent app is never listed: it pushes with an installation
  token and holds no role, so `non_fast_forward` binds it, and
  `pap repo status` reports an `Integration` actor, or a missing owner, as
  drift. `main` keeps no bypass, for you included. The app cannot read
  bypass actors, so an agent's status run reports them `skipped`; only
  your own run confirms the list.

## The finding: pushes as you outside adopting repositories

In pap 0.13.0 and earlier, a `pap claude` shell pushed as you, not as `pap-agent`,
to any repository that does not adopt PAP. The Project Lead saw it on
GitHub: a `git push` from a `pap claude` shell to a non-adopting
repository where the app is not installed succeeded, and GitHub's
activity API named the owner as the actor.

The shim acted only in adopting repositories and ran the real `gh`
unchanged everywhere else. git's credential helper is `gh auth
git-credential`, and gh (v2.97.0, cli/cli at `v2.97.0`) answers it with
your token even with an empty config directory:

- `pkg/cmd/auth/gitcredential/helper.go:115` calls `ActiveToken`.
- `internal/config/config.go:237-258`, `ActiveToken`: with no token in
  the environment or `hosts.yml`, it asks for the active user; with no
  `hosts.yml` that fails, and it falls back (lines 246-253) to
  `TokenFromKeyring`, which is `keyring.Get("gh:github.com", "")`
  (lines 299-300): the unkeyed keyring entry, which is yours.
- `gh api user` says "not logged in" only because the auth check,
  `pkg/cmdutil/auth_check.go:29-39`, reads just the environment and
  `hosts.yml`. Commands that skip it reach the same token: every `gh
  auth` subcommand (`pkg/cmd/auth/auth.go:23`; `gh auth token` reads
  the keyring directly, `pkg/cmd/auth/token/token.go:75-81`), `gh
  release download` (`pkg/cmd/release/download/download.go:118`) and
  extensions, through the HTTP client (`api/http_client.go:164`).

So an empty agent directory was never enough on its own: any real `gh`
in an agent shell could reach your token. What changed:

- In a `pap claude` session the shim handles every `gh` call by name in
  every directory and never runs the real `gh` without a `pap-agent`
  token, so gh's keyring fallback is not reached through it. It answers
  git's credential requests itself, and `pap claude` makes it git's only
  credential helper for github.com, whatever your git config says.
- What is left is a real `gh` reached past the shim (a path the hook
  cannot parse, a renamed link, a script), which the threat model below
  lists.
- Tokens are scoped to one repository, so a repository the installation
  does not cover is refused by name before git or gh reach GitHub.
- The hook's `pap claude` check applies in every directory of a session
  whose project adopts PAP.
- `pap doctor` checks that the installation covers this repository.

Two behaviour changes follow:

- **One repository per token.** A `gh` call that touches two
  repositories at once, such as a fork flow (`gh repo fork`, or `gh pr
  create` from a fork's branch), carries a token for only one of them,
  and GitHub refuses the other.
- **Restart older sessions.** A session started by an older `pap claude`
  lacks `useHttpPath`, so git sends no repository path and the shim
  refuses every push and fetch to github.com. Quit and run `pap claude`
  (`pap claude --resume` keeps the conversation).

## The threat model, honestly

An agent runs as your operating-system user. This separates what each
process sees; it is not isolation. Every known way round it:

| Escape                                                                                                      | Mitigation                                                                                                                                                                                                                          | What is left                                                                                                                                                                                                                        |
| ----------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Reading the keyring by other means: a script, `python`, `bash -c`, `eval`, a name the hook cannot parse     | The hook catches the plain forms                                                                                                                                                                                                    | Any process of yours can read your keyring entry; on macOS `/usr/bin/security` reads it without a dialog                                                                                                                            |
| Claude Code started without `pap claude`                                                                    | In an adopting repository, or anywhere in a session whose project adopts PAP, the hook refuses its `gh` and its git calls to GitHub over HTTPS, naming `pap claude`; `pap doctor` reports the shell and a `gh` that is not the shim | Outside an adopting repository its `PATH` lacks the shim (Claude Code's shells never get mise's `[env]`), so a plain `gh` there is the real one with your sign-in; so is a `gh` the hook cannot parse (`bash -c`, `eval`, a script) |
| `GH_CONFIG_DIR`, `HOME` or `XDG_CONFIG_HOME` changed in a way the hook cannot parse                         | The shim refuses anything but the agent directory in an adopting repository                                                                                                                                                         | Outside one, gh can reach your directory                                                                                                                                                                                            |
| `reviewed.sh` or `accept.sh` run through `bash -c`, `eval`, a copy or a link under another name             | The hook refuses them by name and path                                                                                                                                                                                              | Those forms pass                                                                                                                                                                                                                    |
| Writing a `hosts.yml` into the agent directory, or a `gh auth login` there, by a form the hook cannot parse | The hook refuses commands naming the directory or `$GH_CONFIG_DIR` and `gh auth login`; the shim refuses a non-empty `hosts.yml` in every directory of a `pap claude` session; `pap doctor` reports it                              | A `gh` reached past the shim (`bash -c`, a script, a path) would fetch your token from the keyring                                                                                                                                  |
| `command env -i gh`, `sudo`, `xargs` or `find -exec` forms                                                  | The hook reads only the first word of a command                                                                                                                                                                                     | They pass; the shim still runs if `gh` is found by name, but `env -i` drops `GH_CONFIG_DIR` too, so the shim runs the real `gh`, which can reach your keyring token                                                                 |
| A `gh` found past the shim: by a path the hook cannot parse, a renamed link, or `bash -c`                   | The hook refuses `gh` by a path it can parse, and with `PATH=` changed                                                                                                                                                              | gh's keyring fallback (above) answers it with your token                                                                                                                                                                            |
| A git hook during your `/pap:accept` push                                                                   | The push keeps the caller's environment; only its credential helper is gh as you                                                                                                                                                    | The hook can read that helper from `GIT_CONFIG_PARAMETERS`                                                                                                                                                                          |
| An agent merging a pull request                                                                             | The hook refuses `gh pr merge` and the API merge                                                                                                                                                                                    | GitHub allows it; slice (c) reports it                                                                                                                                                                                              |
| Reading the cached installation token                                                                       | Mode 0600 in a 0700 directory, at most an hour old                                                                                                                                                                                  | A process of yours can read it while it is valid                                                                                                                                                                                    |

**A dev container** changes this. With no key in the container, the shim
steps aside and the container keeps the human sign-in it has (decision
0023 point 5). There, agents act as that sign-in.

## The private key

The app's private key is in the OS keyring under service `pap-agent`,
account `private-key` (`secret-tool` on Linux, the login keychain on
macOS), put there by `pap agent-setup` or `pap agent-key import`. It is
never written to disk by pap; delete the `.pem` after an import. GitHub
holds only the public half. The app id, client id and installation ids sit
in `agent.conf`; they are not secrets.

**Rotate:** on the app's settings page, generate a new private key; `pap
agent-key import <pem> --client-id <id>` on each machine; delete the
`.pem`; then delete the old key on the app's page.

**If you suspect a leak:** delete the key on the app's page, which stops
new tokens at once; suspend or uninstall the app's installations, which
stops the tokens already minted (they otherwise last up to an hour). Then
read what the app did: each repository's pushes, pull requests and their
`labeled` and comment events show `<owner>-pap-agent[bot]`, and an
organisation's audit log lists its acts. Register a key again and
re-import it when you are sure.

## Tokens on disk

pap writes no long-lived token anywhere. `pap agent-token` caches the
installation token it mints as a plain file, `token-<owner>`, mode 0600, in
`$XDG_RUNTIME_DIR/pap-agent-<uid>/` (without `XDG_RUNTIME_DIR`, under
`$TMPDIR`, per user on macOS, else `/tmp`), a directory of mode 0700. GitHub issues the token for one hour; pap
reuses it while more than five minutes remain. That is accepted because
the token expires within the hour, carries only the app's permissions on
the installed repositories, and a process of yours that can read the file
can also mint a fresh one with the key. Your own `gh` token stays in the
keyring.
