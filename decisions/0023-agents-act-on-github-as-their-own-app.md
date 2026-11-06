# 0023. Agents act on GitHub as their own GitHub App

- **Status:** proposed
- **Date:** 2026-11-06
- **Deciders:** blairforce1, with Claude
- **Supersedes:** none; amends [0022](0022-no-branch-takes-a-force-push.md)
  (points 2 and 4: the `all-branches` ruleset gains a bypass for the owner,
  and the override becomes the owner's own force push) and
  [0016](0016-risk-labels-and-an-owner-reviewed-label-replace-approved-by.md)
  (the `owner-reviewed` gate asks who added the label, not only whether it
  is there); gives [0018](0018-a-project-manager-session-launches-cycles-and-keeps-the-tracker.md)'s
  "writes no settings" an enforcer
- **PIP:** the owner's ask of 2026-11-06 that agents have their own
  identity. Every agent session acts on GitHub with the owner's own
  sign-in, so GitHub cannot tell the two apart. Seen this week: 0022
  shipped its ruleset with no bypass at all, because a bypass for the
  owner is a bypass for every agent; rules 16.2 and 18.1 are held by the
  agent hook and the briefs alone; and on PAP's own pull requests the
  `class:` label an agent adds shows as the owner (#90, #96: the issue
  events read `blairforce1 User class:infra`, while the Actions app reads
  `github-actions[bot] Bot risk:high`)
- **Expected effect:** GitHub acts by an agent session attributed to the
  owner ↓ from all of them to 0 in an adopting repository, counted from
  pull-request authors and `labeled` events (every cycle's push, pull
  request and `class:` label shows `<app>[bot]`); GitHub-enforced refusals
  of an agent's settings write and of an agent-added `owner-reviewed` ↑
  from 0 (the hook is the only refuser today) to every attempt
- **Introduced in:** not yet released; the release that ships
  `pap agent-token`, the credential routing and the `pr-checks` actor check
- **Revisit:** when 20 change PRs have merged after the first pull request
  pushed as the app: both effects; how often the token could not be minted
  or expired mid-command; any act that showed as the bot when it was the
  owner's, or the reverse

## Context

Today `gh` is signed in as the owner (keyring), and git pushes over HTTPS
through `gh auth git-credential`, so the same login signs every push,
pull request, label and comment an agent makes. The commits themselves are
authored by the owner and SSH-signed, with the model in a `Co-Authored-By`
trailer; that part is deliberate and stays. The consequence is that no
GitHub control can bind the agent without binding the owner: 0022 chose
no bypass actor for that reason, and the owner's override is to disable
a ruleset, push, and run `pap repo apply`. Rule 16.2 (no `owner-reviewed`,
no merge) and rule 18.1 (the project-manager session writes no settings)
are refused by the Claude Code hook and asked for in briefs, and by
nothing on GitHub. The history cannot say which pushes were an agent's.

GitHub gives three identities to automation: a personal access token
(the owner again, or a second "machine" account), or a GitHub App, whose
acts show as `<app-slug>[bot]` with `type: Bot` on every event ([S14],
and the Actions app's own labels above). This record chooses the app and
writes the mechanism, for review before anything is built, as 0018 was.

### What has to stay true

- The human's acts stay the human's: `/pap:reviewed` and `/pap:accept`
  show the owner, because a reviewer that reads the log must see a person.
- The local git flow does not change: worktrees, lefthook, SSH-signed
  commits by the owner, the hooks of 0005. Nothing moves to the API.
- Least privilege, a short-lived credential, and no secret in a
  repository, an env file or a brief.
- One answer for the owner's account and for an organisation that adopts
  PAP; one more thing to carry, not two.

### Sources

Every GitHub claim below is checked against these pages on 2026-11-06.

- [S1] Installation access tokens: expire after 1 hour; the request may
  narrow `repositories` and `permissions`.
  <https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app>
- [S2] Git over HTTPS with the token as the password of `x-access-token`;
  Git access needs the Contents permission.
  <https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/authenticating-as-a-github-app-installation>
- [S3] The app JWT: RS256, `iss` the client id, `exp` at most 10 minutes.
  <https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-json-web-token-jwt-for-a-github-app>
- [S4] Private keys: GitHub keeps only the public half; never hard-code
  the key; regenerate, then delete the old one.
  <https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/managing-private-keys-for-github-apps>
- [S5] Which permission each REST endpoint needs (Contents, Pull
  requests, Issues, Checks, Commit statuses, Workflows, Administration).
  <https://docs.github.com/en/rest/authentication/permissions-required-for-github-apps>
- [S6] "Select the minimum permissions required"; Workflows is for an app
  that edits files under `.github/workflows`.
  <https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/choosing-permissions-for-a-github-app>
- [S7] A private app "can only be installed on the account that owns the
  app"; a public one "any user on GitHub can install".
  <https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/making-a-github-app-public-or-private>
- [S8] An app is registered "under your personal account or under any
  organization you own".
  <https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/registering-a-github-app>
- [S9] An installation's primary rate limit: 5,000 requests an hour, more
  for large organisations.
  <https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api#primary-rate-limit-for-github-app-installations>
- [S10] GitHub's own choice: over a personal access token, "we recommend
  building a GitHub App"; it is not tied to a user and uses no seat.
  <https://docs.github.com/en/apps/creating-github-apps/about-creating-github-apps/deciding-when-to-build-a-github-app#choosing-between-a-github-app-or-a-personal-access-token>
- [S11] Ruleset `bypass_actors`: `actor_type` one of `Integration`,
  `OrganizationAdmin`, `RepositoryRole`, `Team`, `DeployKey`, `User`;
  `actor_id` required for all but the first two of those; `bypass_mode`
  `always`, `pull_request` or `exempt`; `OrganizationAdmin` not for
  personal repositories.
  <https://docs.github.com/en/rest/repos/rules?apiVersion=2022-11-28#create-a-repository-ruleset>
- [S12] The settings page grants bypass to repository admins, the
  maintain or write roles, teams, GitHub Apps and Dependabot, always or
  "for pull requests only".
  <https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/creating-rulesets-for-a-repository#granting-bypass-permissions-for-your-branch-or-tag-ruleset>
- [S13] Rulesets: bypass by role "such as repository administrator", by
  team or by GitHub App.
  <https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets>
- [S14] Issue events: each `labeled` or `unlabeled` event carries `actor`
  (`login`, `type`), `created_at` and `label.name`; "every pull request
  is an issue".
  <https://docs.github.com/en/rest/issues/events?apiVersion=2022-11-28#list-issue-events>
- [S15] Webhook payloads carry `sender`, the user who triggered the event.
  <https://docs.github.com/en/webhooks/webhook-events-and-payloads#pull_request>
- [S16] `pull_request_target` runs in the base branch's context and has
  the `labeled` and `unlabeled` types.
  <https://docs.github.com/en/actions/writing-workflows/choosing-when-your-workflow-runs/events-that-trigger-workflows#pull_request_target>
- [S17] Commit verification: an SSH signature verifies against a key on
  your account; a commit a bot makes through the API is verified when the
  request is authenticated as the app and sets no custom author,
  committer or signature.
  <https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification>
- [S18] Terms of service: one free account per person, plus at most one
  free machine account, "only be used for running a machine".
  <https://docs.github.com/en/site-policy/github-terms/github-terms-of-service#3-account-requirements>
- [S19] Machine users: a personal account no human uses; only an
  organisation can restrict one to read-only; for deployment GitHub
  recommends an app instead.
  <https://docs.github.com/en/authentication/connecting-to-github-with-ssh/managing-deploy-keys#machine-users>
- [S20] Mandatory 2FA selects any account that acts as a contributor;
  bots and service accounts are not exempt.
  <https://docs.github.com/en/authentication/securing-your-account-with-two-factor-authentication-2fa/about-mandatory-two-factor-authentication>
- [S21] Fine-grained personal access tokens may have no expiry; "for
  long-lived integrations, you should use a GitHub App".
  <https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens>
- [S22] `gh`: `GH_TOKEN` "takes precedence over previously stored
  credentials".
  <https://cli.github.com/manual/gh_help_environment>
- [S23] `gh auth setup-git` makes gh git's credential helper; the helper
  answers HTTPS only and, for a token from a `*_TOKEN` variable, sends the
  username `x-access-token`.
  <https://cli.github.com/manual/gh_auth_setup-git>,
  <https://github.com/cli/cli/blob/trunk/pkg/cmd/auth/gitcredential/helper.go>
- [S24] Audit: a personal account's security log keeps 90 days and lists
  no pushes, pull requests or labels; an organisation's audit log keeps
  180 days with the actor, and `git.push` is API-only with its own
  retention.
  <https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/reviewing-your-security-log>,
  <https://docs.github.com/en/organizations/keeping-your-organization-secure/managing-security-settings-for-your-organization/reviewing-the-audit-log-for-your-organization>
- [S25] Create a commit (git database API): the author defaults to the
  authenticated user; a signature is caller-supplied.
  <https://docs.github.com/en/rest/git/commits?apiVersion=2022-11-28#create-a-commit>

Two things the docs do not state and the first build slice confirms by
trying: that a `RepositoryRole` admin bypass on a personal repository
does not extend to an app's installation token (an installation holds
permissions, not a role, so it should not), and that a push by the app of
a commit SSH-signed by the owner shows "Verified" (verification is of the
commit's signature against the committer's account keys [S17]; the pusher
is not part of the commit).

## Decision

1. **One GitHub App, owned by the owner's personal account, public,
   installed on that account and on every organisation that adopts PAP.**
   The slug is the owner's to pick (`pap-agent` is the working name);
   GitHub shows its acts as `<slug>[bot]`. Repository permissions, the
   least that carry a change ([S5], [S6]): Contents read and write (push,
   [S2]); Pull requests read and write (open, edit, review); Issues read
   and write (labels and comments on a pull request go through the issues
   endpoints); Workflows write, because PAP's template sync pushes files
   under `.github/workflows/` and a token without it is refused there
   ([S6]); Checks read and Commit statuses read (`gh pr checks`); Metadata
   read. No Administration, no Members, no Secrets, no Actions, no
   organisation permissions, no webhook. Installed on "only select
   repositories": the adopting ones. The private key is generated once,
   imported into the machine's keyring (`pap agent-key import <pem>`, then
   the file is deleted), and lives nowhere else; the app id, client id and
   installation ids are not secrets and sit in pap's user config. A lost
   key is regenerated on the app and re-imported; GitHub holds only the
   public half ([S4]). Public, because a private app installs only on the
   account that owns it ([S7]) and the organisation's repositories need it
   too; public means anyone may install it from its URL, and nobody can act
   as it without the key. What it exposes is the app's name and
   description. The alternative is in point 6.

2. **Everything an agent session does on GitHub goes as the app; the two
   human skills switch back.** `pap agent-token` reads the key from the
   keyring, signs the JWT (RS256, `iss` the client id, ten minutes [S3])
   with `openssl`, exchanges it for an installation token for the
   repository's owner (one hour, [S1]), caches it with its expiry in the
   runtime directory at mode 0600, and prints it. One `gh` shim, first on
   the path through the base layer's mise config, carries it to both
   consumers: when `CLAUDECODE` is set (Claude Code sets it in every Bash
   call; a person's terminal never has it) and the repository adopts PAP
   (the hook's test: an executable `scripts/guard-branch.sh`), it sets
   `GH_TOKEN` from `pap agent-token` and runs the real `gh`, which then
   ignores the stored sign-in ([S22]). git needs nothing new: pushes
   already go through `gh auth git-credential`, which the shim is now in
   front of, and a token from `GH_TOKEN` is sent as `x-access-token`
   ([S23], [S2]). Outside those conditions the shim runs `gh` unchanged.
   It never falls back to the stored sign-in when minting fails: that
   failure is the shared-credential problem returning quietly, so it says
   why (no key, no installation for this owner, GitHub unreachable) and
   exits. `/pap:reviewed` and `/pap:accept` are the only code that acts as
   the person: their scripts run `gh` with `PAP_AS_HUMAN=1`, which the shim
   honours by running the real `gh` with no `GH_TOKEN`, so the label and
   the acceptance's branch, commit and pull request show the owner. Both
   skills already carry `disable-model-invocation: true`; the hook gains a
   rule refusing an agent's `PAP_AS_HUMAN` in a command, as it refuses
   `LEFTHOOK` (0005).

3. **Commits stay the owner's; the push, pull request, labels and
   comments show the app.** Author and committer stay the owner, SSH-signed
   by the owner's key, with the model in the `Co-Authored-By` trailer.
   Reasons: the local flow is where 0005's hooks run, and every commit
   keeps passing through them; the signature verifies against the owner's
   account keys and the pusher is not part of the commit ([S17]; confirmed
   in the first slice); who wrote the change is already the trailer's job;
   `git log` and `git blame` read as they do now. The alternative, commits
   created through the API as the app and signed by GitHub ([S17], [S25]:
   verified when authenticated as the app with no custom author), was
   weighed and lost: every commit would be made without the local hooks,
   which is what 0005 forbids an agent, and the `security` workflow
   catches only what those hooks would have caught, not the bypass. A
   bot committer over git is not available without a key of its own and
   was not pursued. The visible split is then exact: the commit says who
   authored and signed it, the trailer says what wrote it, the push and
   everything around the pull request say which identity did it.

4. **What GitHub then enforces.**
   - **Rulesets.** `.github/rulesets/all-branches.json` gains one bypass
     actor, the owner, mode `always`, and never an `Integration`
     ([S11], [S12]). The narrowest actor that names only the owner is
     used: `User` where the API accepts it on that repository, else the
     owner's role (`RepositoryRole` admin on a personal repository,
     `OrganizationAdmin` on an organisation's). The app pushes with an
     installation token, holds no role and is not listed, so
     `non_fast_forward` binds it; the owner at a terminal is let through.
     This amends 0022 points 2 and 4: rule 22.1 stands and the hook stays
     as the early, named refusal, but the override is now a plain force
     push from the owner's own terminal, with no ruleset to disable and
     re-apply. `pap repo apply` writes the actor and `pap repo status`
     reports an `Integration`, or a missing owner, as drift. `main.json`
     keeps no bypass: main changes by pull request for everyone, the owner
     included.
   - **The label gate.** The reusable `pr-checks` workflow reads the pull
     request's issue events ([S14]) and counts `owner-reviewed` only when
     its latest `labeled` event, after any `unlabeled`, has an actor of
     `type: User`. A label added by a Bot actor, the agent app included,
     is as if absent; the workflow removes it and says why. This narrows
     0016's rule 16.1, which checks presence. The Actions token itself is
     a Bot and only ever removes the label, as today.
   - **Settings.** The app has no Administration permission, so an agent's
     `gh api` on rulesets, branch protection or repository settings is
     refused by GitHub with 403 ([S5]). That closes the gap 0022 and 0018
     each named: "nothing refuses an agent disabling the ruleset through
     `gh api`". The hook keeps refusing first, with the rule's name.
   - **What GitHub still does not refuse.** Merging a pull request needs
     Contents write and Pull requests write, which the app has for its
     job, so an agent's `gh pr merge` is refused by the hook alone and
     would show as `<slug>[bot]` merged. It becomes detectable and
     attributable, not impossible; a narrower permission set that still
     pushes does not exist.

5. **Phasing, cost, and what breaks.**
   - **The owner, once, about half an hour:** register the app under the
     personal account ([S8]; no webhook, the permissions above, a private
     key), set it public, install it on the account and on each adopting
     organisation with the adopting repositories selected, import the key
     with `pap agent-key import`, and run `pap doctor`, which from this
     record checks the key, an installation for each adopting
     repository's owner, an HTTPS remote and `gh` as the credential helper.
     Registration and installation cost nothing on GitHub's side.
   - **PAP, as changes citing this record, in this order:** (a)
     `pap agent-token`, `pap agent-key`, the `gh` shim in the base layer's
     mise path, the `pap doctor` checks; (b) `PAP_AS_HUMAN=1` in
     `reviewed.sh` and `accept.sh`, and the hook rule refusing it from an
     agent; (c) the actor check in `pr-checks` (a pull request in the
     account's `.github` repository) and the risk layer's docs; (d) the
     bypass actor in `all-branches.json`, `pap repo apply` and `status`;
     (e) `docs/account-setup.md`, `make-a-change.md`,
     `troubleshooting.md`, and the dated notes on 0016 and 0022. The order
     matters once: (d) ships only after (a) is on every machine that runs
     agents, or the bypass is the agent's again.
   - **Per repository:** `pap sync` brings the shim; the owner adds the
     repository to the installation; `pap repo apply` writes the ruleset.
     Until the sync, a session pushes as the owner, which is today's state
     and harmless; after the sync and before the installation, an agent's
     `gh` and `git push` fail with the shim's message, and the owner
     installs the app or runs the command by hand.
   - **What breaks, and the fix:** a push of a workflow file with
     Workflows left off (403; grant it); `gh pr checks` without Checks
     read; a watch that outlives the token (`gh pr checks --watch` holds
     the token it started with, so a watch over an hour is restarted; the
     shim mints fresh on every call); a devcontainer has no keyring (the
     key is mounted read-only from the host's keyring export, or that
     container runs the human's flow; open question 7). Rate limits are
     5,000 calls an hour per installation ([S9]), far above a cycle's use.
   - **Rollback,** each step on its own and in this order: remove the
     bypass with the previous `all-branches.json` and `pap repo apply`
     (first, so no bypass stands while agents go back to the owner's
     sign-in); revert the `pr-checks` change; `pap sync` to the base layer
     without the shim, or `PAP_AS_HUMAN=1` by hand; uninstall the app and
     delete its key from the keyring.

6. **Two accounts.** The owner's personal account and the organisation
   that adopts PAP are two installation targets. A private app installs
   only on its owning account ([S7]), so the choices are one public app
   owned by the personal account and installed on both, or two private
   apps, one registered under each ([S8]), with two keys in the keyring
   and `pap agent-token` choosing by the remote's owner. Recommended: one
   public app. It is one key to keep and one registration to maintain,
   and "public" exposes a name and a description, not a capability. Two
   private apps are the fallback if the owner wants nothing listed under
   the personal account, at the cost of two of everything.

7. **The parked item does not ride on this app.** Team-owned `CODEOWNERS`
   through a private org-config repository needs an app with the Members
   read organisation permission (for `pr-checks` to resolve a team) and
   Administration (for `pap org apply` to write teams and settings). This
   app deliberately has neither, because point 4 depends on the agent's
   identity being unable to write settings. That item gets its own app
   and its own record. What it takes from this one is the pattern (a key
   in the keyring, a minted token, a `User` actor check it extends to
   "a `User` in the team") and nothing else.

The reason that carried it: the only control that can tell an agent from
the owner today is the agent's own hook. Give the agent a GitHub identity
and every GitHub control gains the distinction for free, the hook keeps
its job as the early refusal, and the log says who did what.

## Considered options

- **A machine-user account with a fine-grained personal access token.**
  Allowed: one free machine account per person, run only by a machine
  ([S18]). Wins on simplicity: `gh auth login` as normal, SSH pushes, no
  JWT. Lost: it is a second person-shaped identity, in scope for mandatory
  2FA with its own second factor ([S20]); its token is long-lived or
  non-expiring ([S21]) against the app's one hour; it needs a collaborator
  invitation per repository and holds a role, so a role bypass can reach
  it; it takes a seat on a paid organisation; and GitHub's own advice for
  a long-lived integration is the app ([S21], [S19], [S10]).
- **The owner's own fine-grained token with narrower scopes for agents.**
  Lost: still the owner on every event.
- **Shared credentials, a stronger hook.** Lost: 0022 already found the
  ceiling; the hook does not follow `bash -c`, and GitHub cannot tell.
- **Agents act through GitHub Actions workflows.** Lost: the agent works
  locally in a worktree; a round trip through a runner for every push is
  ceremony and a second place to keep rules.
- **The app as commit author through the API.** Point 3. Lost: the local
  hooks.
- **An `Integration` bypass for the app and none for the owner.** Lost: it
  is the agent that must be bound; the owner is who the override is for.
- **A bypass for the owner by role rather than by `User` everywhere.**
  Taken only where `User` is not accepted: a role can name more than one
  person on an organisation with a second admin.
- **Two private apps.** Point 6; the fallback.

## Consequences

- Easier: GitHub shows who did what. Pushes, pull requests, labels and
  comments by an agent carry `<slug>[bot]`; the owner's acts carry the
  owner. The organisation's audit log has the actor on each entry ([S24]).
- Easier: three rules gain a GitHub-side enforcer: 16.2's label (the gate
  ignores a Bot), 18.1's settings (no permission), 22.1's bypass (bound by
  the ruleset while the owner is not). The hook keeps refusing first.
- Easier: the owner's force push override is one command from a terminal
  instead of three steps and a drift report.
- Harder: a one-time setup and a key to keep. The key sits in the
  machine's keyring behind its unlock; a lost machine means regenerating
  the key on the app, which invalidates the old one ([S4]).
- Harder: an adopting repository's remote must be HTTPS with `gh` as the
  helper; an SSH remote pushes as the owner. `pap doctor` warns, and the
  hook gains a refusal of an agent's push to an SSH remote in an adopting
  repository.
- Harder: `pr-checks` makes one more API read per run, for the events.
- Limit: the app's token lets an agent do what Contents and Pull requests
  write allow, merging included; the hook refuses it and the log shows it.
- Limit: the gate checks `type: User`, not which user. In a repository
  whose only writer is the owner that is the owner; a repository with
  other collaborators decides whether the login must also be a
  `CODEOWNERS` owner (open question 4).
- Limit: the shim keys on `CLAUDECODE`. Another agent harness without that
  variable pushes as the owner; `pap doctor` cannot see it.
- Measurement: `labeled` events and pull-request authors per repository,
  read through `gh api` at the revisit; the personal security log does not
  list them ([S24]), so there is no shortcut.
- Follow-up: dated notes on 0016 and 0022 when this record is accepted;
  rules 23.1 to 23.3 are enforced by nothing until the slices ship, and
  each names its check.

## Open questions for the Project Lead

1. The app's slug and visibility: `pap-agent`, public, under the personal
   account (point 1), or two private apps (point 6)?
2. Issues write: keep it, so agents can label and comment on issues too,
   or grant Pull requests write alone and let the first slice confirm that
   labels and comments on a pull request work without it?
3. The bypass actor: `User` for the one login where accepted, falling back
   to the admin role; or the role everywhere, which also admits any later
   admin?
4. The gate: is `type: User` enough, or must the login also be an owner
   named in `.github/CODEOWNERS`?
5. Accept that merging by the app is detectable, not impossible (point 4,
   last bullet)?
6. Should the shim act in every repository that adopts PAP, or only where
   the owner has opted in (a marker file, as `.github/risk.yml` is)?
7. The devcontainer: mount the key, or keep containers on the human's
   sign-in and out of scope?

## Where it is taught or enforced

Backs [`rules.md`](../rules.md) 23.1 (an agent session acts on GitHub as
the agent app), 23.2 (`owner-reviewed` counts only from a person) and 23.3
(the owner bypasses the `all-branches` ruleset; the app never does).
Amends rule 22.1's override. Enforced by nothing yet; backlog item H-016
builds the slices in point 5, each citing this record.
