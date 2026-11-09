# Set up the account

Three things live at the account or organisation level, not in any one
repository: the `.github` repository, the labels every repository shares,
and the Renovate app. Do this once per account.

## The `.github` repository

PAP is the process: rules, decisions, skills and the template a repository
adopts. It cannot hold the files GitHub reads only from an account's own
`.github` repository. For `blairforce1` that repository is
[blairforce1/.github](https://github.com/blairforce1/.github); its README,
"Why this repository is separate from PAP", is the reference for this
section.

**What lives there.** The default pull request template (with the
`Change:` and `Record:` lines, the Summary, Verification, "How to revert"
and Checks sections every PAP pull request answers), the issue templates,
`SECURITY.md`, and two reusable workflows: `pr-checks`, which checks a
pull request's title, body and labels and sets the risk label, and
`security`, which scans a pull request and re-runs `mise run check` as the
server-side backstop for the git hooks.

**Why GitHub needs it separate.** Community health files are inherited
only from the account's own `.github` repository, which must be public;
`CODEOWNERS` and `LICENSE` are not inherited and stay per repository. A
reusable workflow is called by its `owner/repo` path, so every adopting
repository's callers name it:

```yaml
uses: blairforce1/.github/.github/workflows/pr-checks.yml@main
```

Without that repository the required check `pr-checks / checks` cannot
run.

**Making your own.** To adopt PAP under your own account or organisation:

1. Create a public repository named `.github` under your account, from
   blairforce1/.github (fork it, or copy its files).
2. In each adopting repository, point the two callers the template wrote,
   `.github/workflows/pr-checks.yml` and `.github/workflows/security.yml`,
   at `<your-account>/.github` instead of `blairforce1/.github`. `pap
   sync` keeps that edit: its three-way merge treats it as a local change.
3. The pull request and issue templates are then inherited from yours.

The caller pins `@main`, so a fix in your `.github` repository reaches
every caller at once; its `main` ruleset is the only guard on it.

## Labels

`pap repo apply` creates and updates the labels in each repository; it
never deletes one. The set is pap's `.github/labels.yml`, plus
`.github/labels/<layer>.yml` for each layer the repository has adopted.

| Label                                                                                                                  | Who sets it                                                                           | What it means                                                                                                                                                                                 |
| ---------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `class:feature`, `class:infra`, `class:security-sensitive`, `class:bugfix`, `class:spike`, `class:docs`, `class:chore` | `/change`, from its argument; `/pap:accept` sets `class:docs`, Renovate `class:infra` | The task class (process section 4). Every pull request carries exactly one; `pr-checks` refuses none or two.                                                                                  |
| `phase:intent` to `phase:findings`                                                                                     | You, by hand                                                                          | The phase a change is in. Nothing sets or reads them yet.                                                                                                                                     |
| `protected-path`                                                                                                       | `pr-checks`                                                                           | The diff touches a path with an owner in the base branch's `.github/CODEOWNERS`.                                                                                                              |
| `return`                                                                                                               | You, by hand                                                                          | The pull request carries a phase return (process 5.10).                                                                                                                                       |
| `risk:high`, `risk:medium`, `risk:low` (risk layer)                                                                    | `pr-checks`                                                                           | The pull request's risk level, computed from its diff against `.github/risk.yml` on the base branch; exactly one, reset on every run. `pr-checks` creates these if the repository lacks them. |
| `owner-reviewed` (risk layer)                                                                                          | You, with `/pap:reviewed`                                                             | You reviewed this head of a `risk:high` pull request. Any push removes it. An agent never adds it (rule 16.2); the `pap` plugin's hook refuses the attempt.                                   |

[Make a change](make-a-change.md) says how the risk labels drive review.

## The Renovate app

Dependency updates come from Mend's Renovate GitHub App (decision
[0007](../decisions/0007-dependency-updates-by-renovate.md)), reading each
repository's `.github/renovate.jsonc`. An account or organisation owner
installs it once from <https://github.com/apps/renovate>, chooses "Only
select repositories", and adds each repository that adopts the template.
The first run on a repository opens an onboarding pull request; merge it
once the config file is on the default branch. The base template README's
"Installing the app" section says what the app can see and do, and how to
run the same Renovate self-hosted under a GitHub App you own.

## `gh`

Every `pap repo` command, `pap revisits` and the skills that open pull
requests go through `gh`. Sign in as an account that administers the
repositories (`gh auth login`, keeping its default keyring storage), on
every machine that runs them, and start Claude Code with `pap claude`
([your own sign-in](#your-own-sign-in-and-pap-claude)).

## The `pap-agent` app

Decision 0023 gives agent sessions their own GitHub identity, a GitHub App
named `<owner>-pap-agent` (for example `blairforce1-pap-agent`; app names
are global, so each adopter registers its own), so a push, pull request,
label or comment an agent makes shows as `<owner>-pap-agent[bot]` and not
as you. You register it once, under
your personal account, and install it on every repository agents push
to or call `gh` for, adopting PAP or not: an organisation's private
companion repository and its `.github` repository count too. In a `pap
claude` session the gh shim mints a token scoped to the one repository a
call names, and refuses a repository the installation does not cover, by
name (`pap doctor` checks this clone's). It costs nothing on GitHub's
side.

### With `pap agent-setup`

From an adopting repository, on the machine that runs agents:

```sh
pap agent-setup [--owner <login>] [--name <app-name>]
```

It registers the app by GitHub's manifest flow
([Registering a GitHub App from a manifest](https://docs.github.com/en/apps/sharing-github-apps/registering-a-github-app-from-a-manifest),
and [the conversion endpoint](https://docs.github.com/en/rest/apps/apps?apiVersion=2022-11-28#create-a-github-app-from-a-manifest)):

1. It opens your browser on a form served from a short-lived loopback
   port, which posts `scripts/pap-agent-manifest.json` to GitHub: the
   permissions below and nothing else, no active webhook, public. The
   name defaults to `<owner>-pap-agent`, because app names are global;
   `--name` overrides it. `--owner` defaults to `origin`'s owner; an
   organisation gets its own registration page. Check the name and press
   **Create GitHub App**.
2. GitHub redirects back to the loopback port with a one-hour code; pap
   checks the `state` it sent, converts the code, and puts the returned
   private key straight into the keyring and the client id into pap's
   config. The key, the client secret and the webhook secret are never
   written to disk or printed.
3. It opens the app's install page. Install it on the owner with every
   repository agents push to selected (adopting ones, and others such as
   a private companion repository or `.github`), then press Enter; pap confirms the
   installation with the app's own token. It adds no repositories to an
   installation itself: that endpoint needs a user token from the app,
   which your `gh` sign-in is not, so a repository added later is
   selected on the installation's page.
4. If this clone's `origin` is SSH, it asks (default no) to switch it to
   `https://github.com/<owner>/<repo>.git`.
5. It asks (default no) to have git read GitHub's SSH URLs as HTTPS for
   every clone, in your global git config:

   ```sh
   git config --global --add url."https://github.com/".insteadOf git@github.com:
   git config --global --add url."https://github.com/".insteadOf ssh://git@github.com/
   ```

   It never adds a value twice. `pap doctor` reports whether the rewrite
   is in effect and prints these two commands if not; it never writes
   them, even with `--fix`.
6. It prints `pap doctor`'s agent-app items.

Run it again at any time: with the key already here it skips
registration and goes on to the installation and the checks. It needs
`python3` for the browser hand-off; without it, use the manual steps.

**The hard stop is yours.** The guard hook refuses an agent's push to an
SSH remote and the rewrite turns SSH URLs into HTTPS, but a person's or
a script's SSH push still works while your account has an SSH
authentication key. To make HTTPS the only way in, remove the
authentication key from your GitHub account (Settings, SSH and GPG keys)
and keep the signing key, which signs commits and is a separate entry.
GitHub then refuses every SSH push. `pap agent-setup` never touches
GitHub keys; that is your own act.

### By hand

The same, step by step, when `pap agent-setup` cannot run:

1. **Register the app.** On GitHub: Settings, Developer settings, GitHub
   Apps, New GitHub App, under your personal account.
   - Name `<owner>-pap-agent`; any homepage URL, such as the pap repository's.
   - Webhook: untick **Active**. The app takes no webhook.
   - Repository permissions, exactly these and nothing else: **Contents**
     read and write, **Pull requests** read and write, **Workflows** read
     and write, **Checks** read-only, **Commit statuses** read-only,
     **Metadata** read-only (GitHub sets it). No Issues, no
     Administration, no Actions, no Secrets, no organisation or account
     permissions.
   - "Where can this GitHub App be installed?": **Any account**. A private
     app installs only on the account that owns it, and the organisations
     that adopt PAP need it too. Public exposes the name and description;
     nobody can act as the app without its key.
2. **Note the client id** on the app's General page (it starts `Iv`). It
   is not a secret.
3. **Generate a private key** on the same page. The browser downloads a
   `.pem` file.
4. **Install the app** (the app's page, Install App) on your account and on
   each organisation that adopts PAP, with **Only select repositories** and
   the adopting repositories selected. A repository added later is added
   to the installation by hand.
5. **Import the key** on every machine that runs agents:

   ```sh
   pap agent-key import ~/Downloads/<app>.<date>.private-key.pem --client-id <client id>
   rm ~/Downloads/<app>.<date>.private-key.pem
   ```

   The key goes into the OS keyring (`secret-tool` on Linux, which needs
   `libsecret-tools` on Debian and Ubuntu or `libsecret` on Fedora; the
   login keychain on macOS) and nowhere else. The client id, and the
   installation ids `pap agent-token` finds on first use, go in
   `~/.config/pap/agent.conf` (`$XDG_CONFIG_HOME` if set; on macOS
   `~/Library/Application Support/pap/agent.conf` unless it is). Delete
   the file once imported; a lost key is regenerated on the app and
   imported again, then the old one is deleted on the app. `pap agent-key
   status` says what is there without printing the key.
6. **Switch each clone's `origin` to HTTPS.** The agent pushes over HTTPS
   with the app's token, and the guard hook refuses an agent's push to an
   SSH remote:

   ```sh
   git remote set-url origin https://github.com/<owner>/<repo>.git
   ```

   Git then signs in through `gh auth git-credential`. If `pap doctor`
   says gh is not git's credential helper, or calls it by path, run the
   two commands it prints: the helper must call `gh` by name, so the base
   layer's shim answers it.
7. **Run `pap doctor`** in each adopting repository. Its "agent app"
   section checks openssl and curl, the key, the client id, the HTTPS
   origin, the credential helper, and that a token mints for the
   repository's owner.

From then on, in an agent session started with `pap claude` in an adopting
repository, the `gh` shim `pap claude` puts first on `PATH` (pap's own
`scripts/shim/gh`; the base layer's mise `[env]` path reaches only shells
mise activates and `mise exec`/`mise run`, never Claude Code's) mints a token
through `pap agent-token` and runs `gh` with it; git's pushes go through
the same shim. When the token cannot be minted it says why and stops; it
never falls back to your sign-in. Your own terminal is unaffected: the
shim acts only when Claude Code's `CLAUDECODE` is set. A dev container has
no key, so there the shim steps aside and the container keeps your sign-in,
by decision 0023. [Troubleshooting](troubleshooting.md#the-gh-shim-and-pap-agent)
has each message the shim prints.

## Your own sign-in and `pap claude`

Your `gh` sign-in stays where `gh auth login` puts it, gh's default
directory with the token in the keyring; nothing moves. What changes is
how you start Claude Code: **always with `pap claude`** (any `claude`
arguments pass through; `alias claude='pap claude'` saves remembering). It
sets `GH_CONFIG_DIR` to an empty agent directory and unsets the GitHub
token variables, so an agent shell finds no stored account and only the
shim's `pap-agent` token works (rule 23.4). In an adopting repository the
shim refuses every `gh` in a session started any other way.

Then run `pap doctor`. Its "sign-ins" section checks your sign-in and that
its token is in the keyring (sign in again without `--insecure-storage` if
it warns), the agent directory, and whether the shell it runs in is an
agent shell started by `pap claude`. `/pap:reviewed` and `/pap:accept`
act as you from gh's default directory; only you can invoke them.
[Agent identity and its security](agent-identity-security.md) says what
this protects and what it does not.
