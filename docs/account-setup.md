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
repositories (`gh auth login`), on every machine that runs them.

## The `pap-agent` app

Decision 0023 gives agent sessions their own GitHub identity, a GitHub App
called `pap-agent`, so a push, pull request, label or comment an agent
makes shows as `pap-agent[bot]` and not as you. You register it once, under
your personal account, and install it wherever PAP is adopted. It costs
nothing on GitHub's side and takes about half an hour.

1. **Register the app.** On GitHub: Settings, Developer settings, GitHub
   Apps, New GitHub App, under your personal account.
   - Name `pap-agent`; any homepage URL, such as the pap repository's.
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

From then on, in an agent session in an adopting repository, the `gh` shim
the base layer puts first on `PATH` (`scripts/shim/gh`) mints a token
through `pap agent-token` and runs `gh` with it; git's pushes go through
the same shim. When the token cannot be minted it says why and stops; it
never falls back to your sign-in. Your own terminal is unaffected: the
shim acts only when Claude Code's `CLAUDECODE` is set. A dev container has
no key, so there the shim steps aside and the container keeps your sign-in,
by decision 0023. [Troubleshooting](troubleshooting.md#the-gh-shim-and-pap-agent)
has each message the shim prints.
