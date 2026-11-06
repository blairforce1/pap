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
| Commit statuses | read       | read statuses                                          |
| Metadata        | read       | read the repository (GitHub requires it)               |

It has no Administration, Issues, Actions, Secrets, Members or
organisation permission, so GitHub refuses it any settings, ruleset or
branch-protection write. GitHub does not refuse it a merge: merging needs
only Contents and Pull requests. The guard hook refuses an agent's `gh pr
merge` (rule 16.2); a merge report in `pr-checks` comes with slice (c).
Commits stay yours: authored and SSH-signed by you, with the model in the
`Co-Authored-By` trailer.

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
- **The `gh` shim**, first on `PATH` in every shell `pap claude` starts,
  runs the real `gh` unchanged outside an adopting repository. In one it
  gives an agent's `gh` and git push a `pap-agent` token. It refuses when
  `GH_CONFIG_DIR` is not exactly the agent directory (a plain `claude`
  session where mise's `PATH` still puts the base layer's copy first) or when that directory holds a github.com
  sign-in (any non-empty `hosts.yml`: one naming you would make gh fetch your token from the keyring), and it never falls back to a stored one.
- **The guard hook** refuses an agent's command that changes
  `GH_CONFIG_DIR` (sets, exports, unsets it, or starts with `env -i`), names the agent directory or signs gh in (`gh auth login`, `switch`, `refresh`), which keeps it empty, runs `gh`
  by a path or with `PATH=` changed, reads gh's keyring entry
  (`secret-tool lookup`/`search` naming `gh:`, `security
  find-generic-password`/`find-internet-password` naming `gh:`, `security
  dump-keychain`), or asks gh for the token (`gh auth token`, `gh auth
  status -t`).
- **`/pap:reviewed` and `/pap:accept`** are the only paths back to your
  sign-in. Their scripts run `gh` from gh's default directory with the
  tokens unset, so the label and the acceptance show you. Only you can
  invoke them: `disable-model-invocation` keeps the model from the skill,
  and the hook refuses an agent's Bash call that runs either script.
  That refusal cannot catch your own invocation, because a skill's
  preprocessing never reaches a PreToolUse hook (checked with a logging
  hook).
- **Later slices:** the `owner-reviewed` gate in `pr-checks` counts only a
  label you added (slice c), and the `all-branches` ruleset lets only you
  bypass it (slice d).

## The threat model, honestly

An agent runs as your operating-system user. This separates what each
process sees; it is not isolation. Every known way round it:

| Escape                                                                                                      | Mitigation                                                                                                                                                                          | What is left                                                                                                                                                      |
| ----------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Reading the keyring by other means: a script, `python`, `bash -c`, `eval`, a name the hook cannot parse     | The hook catches the plain forms                                                                                                                                                    | Any process of yours can read your keyring entry; on macOS `/usr/bin/security` reads it without a dialog                                                          |
| Claude Code started without `pap claude`                                                                    | `pap doctor` reports the shell and a `gh` that is not the shim; the hook still refuses `gh` by path and the keyring forms                                                           | Its `PATH` lacks the shim, since Claude Code's shells never get mise's `[env]`: a plain `gh`, in an adopting repository or not, is the real one with your sign-in |
| `GH_CONFIG_DIR`, `HOME` or `XDG_CONFIG_HOME` changed in a way the hook cannot parse                         | The shim refuses anything but the agent directory in an adopting repository                                                                                                         | Outside one, gh can reach your directory                                                                                                                          |
| `reviewed.sh` or `accept.sh` run through `bash -c`, `eval`, a copy or a link under another name             | The hook refuses them by name and path                                                                                                                                              | Those forms pass                                                                                                                                                  |
| Writing a `hosts.yml` into the agent directory, or a `gh auth login` there, by a form the hook cannot parse | The hook refuses commands naming the directory or `$GH_CONFIG_DIR` and `gh auth login`; the shim refuses a non-empty `hosts.yml` in an adopting repository; `pap doctor` reports it | Outside an adopting repository, gh there would fetch your token from the keyring                                                                                  |
| `command env -i gh`, `sudo`, `xargs` or `find -exec` forms                                                  | The hook reads only the first word of a command                                                                                                                                     | They pass; in an adopting repository the shim still checks the directory                                                                                          |
| A git hook during your `/pap:accept` push                                                                   | The push keeps the caller's environment; only its credential helper is gh as you                                                                                                    | The hook can read that helper from `GIT_CONFIG_PARAMETERS`                                                                                                        |
| An agent merging a pull request                                                                             | The hook refuses `gh pr merge` and the API merge                                                                                                                                    | GitHub allows it; slice (c) reports it                                                                                                                            |
| Reading the cached installation token                                                                       | Mode 0600 in a 0700 directory, at most an hour old                                                                                                                                  | A process of yours can read it while it is valid                                                                                                                  |

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
