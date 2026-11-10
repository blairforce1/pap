# Intent: pap-new

```text
id:                 pap-new
class:              feature
product:            PAP
source:             https://github.com/blairforce1/pap/pull/125
hypothesis:         reactive: the owner's own run of #125's greenfield runbook
invariants-touched: INV-001, INV-002, INV-003, INV-004, INV-005, INV-011; bin/pap, tests/**
accepted-by:        @blairforce1
accepted-on:        2026-11-10
generated-by:       Claude Fable 5.2 (claude-fable-5-2) via Claude Code
skills:             pap:intent 0.17.0
prompt:             /intent pap-new feature A `pap new <name>` command that creates a greenfield PAP repository from nothing, as the signed-in gh user, run from the owner's terminal: preflight on gh scopes, first commit and push before clone setup and pap repo apply, a pap-agent token, pap claude started at the end, and a paste-able install prompt pinned to an exact version; replaces the greenfield section of docs/agent-onboarding.md (#125).
```

## Problem

Starting a greenfield PAP repository today means following #125's nine-step runbook by hand or by agent. The owner ran it and found that the order of first push, pre-push hook and ruleset is left to prose, as are the checks on the gh sign-in and the agent app. A new adopter faces the same steps with less context.

## Desired outcome

`pap new <name>`, run from the owner's terminal as the signed-in gh user, produces a pap-enabled greenfield repository and ends in a Claude session that welcomes the user.

- **Parameters:** name, visibility, layers, owner.
- **Preflight, before anything is created:**
  - gh is signed in with the `repo` and `workflow` scopes (`X-OAuth-Scopes` on `gh api -i user`). It offers `gh auth login` or `gh auth refresh -s workflow` and rechecks. A fine-grained token with no scopes header is reported and allowed through.
  - The `pap-agent` app is registered and its key is present. If not, it says what to do and points at `pap agent-setup`.
  - It reports the kind of installation, and warns when a selected-repositories installation means one step after creation.
- **Order:** the template and a one-line README as the first commit on `main`; create the repository and push; then clone setup; then `pap repo apply`. The hook and the ruleset do not exist at the first push.
- **Token:** it mints a `pap-agent` token for the repository. On failure it prints the installation settings URL and retries on Enter.
- **End:** it starts `pap claude` pre-prompted to say what happened, where the user is, and ask what they want to do next. The choices are read from a page in pap's docs at its GitHub URL, so the list changes as pap does. `/envision` is the likely first step, not a forced one.
- **Docs:**
  - A one-line paste-able prompt has Claude install pap with mise at an exact version written into the prompt text, then tells the user to exit and run `pap new`.
  - The version bump pull request updates that version, and `scripts/release.sh` refuses a release whose prompt version does not match.
  - One line says an exact version skips mise's `minimum_release_age`.
  - Account setup recommends an all-repositories `pap-agent` installation for a personal account, and sets out both choices and their effect for an organisation.
  - This replaces the greenfield section of `docs/agent-onboarding.md`.

## Non-goals

- Brownfield adoption; a separate change.
- Converting an existing repository or set of experiments into pap format. The welcome names it only if a command for it exists.
- Registering the `pap-agent` app; `pap agent-setup` does that.
- Deleting a repository, or repairing one beyond resuming where a run stopped.
- Running `/envision` unasked.

## Constraints

- `pap init` is split so `new` can write files without finishing setup, and behaves as today for existing callers.
- POSIX shell; `gh` is the only route to GitHub; no new dependency.
- Never deletes a repository; a re-run against one that exists picks up where it stopped.
- No ruleset bypass actor and no guard exception for the first push. That push is the one direct push to `main`, made before the ruleset exists (INV-004).
- The session it starts runs as the agent, never the owner (decision 0023).
- Risk is high, from `bin/pap`.
- One change, one release.

## Success measure

The next 3 repositories the owner creates with `pap new` at the release tag reach the welcome message with 0 hand-run steps outside the ones the command prompts for (gh sign-in or scope refresh, app installation). It is observed from the terminal run and confirmed by `pap doctor` and `pap repo status` both clean, with no ruleset bypass in the repository's history.

## Open questions

- The backlog hypothesis for a one-command greenfield start: carried forward to a separate backlog change, @blairforce1.
- The new-adopter path from the pasted prompt on a clean machine is unmeasured, since no clean install is available: carried forward to the spec, @blairforce1 accepts it or names a tester.
- How a re-run knows where it stopped: carried forward to the spec.
- Defaults for visibility and layers, and whether `owner` may be an organisation: carried forward to the spec, @blairforce1.
- The welcome's list is read from pap's docs on GitHub: answered. Whether it reads `main` or the installed version's tag is carried forward to the spec; `main` can list a command the installed pap lacks.
- Whether an exact version skips mise's `minimum_release_age`: carried forward to the spec, verified against mise's docs before the line is written.
