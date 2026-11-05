# 0022. No branch takes a force push

- **Status:** proposed
- **Date:** 2026-11-05
- **Deciders:** blairforce1, with Claude
- **Supersedes:** none; extends the `non_fast_forward` rule of [0002](0002-skills-stop-at-draft-pr.md) from main to every branch
- **PIP:** the owner's call of 2026-11-05 that no force push becomes the default on every branch, overridable only on purpose. That week a background agent force-pushed its own `change/` branch, and nothing stopped it: the `main` ruleset blocks a non-fast-forward push on the default branch only, and the agent hook had no rule for it
- **Expected effect:** force pushes by an agent session to any branch of an adopting repository ↓ to 0; no baseline exists beyond the one incident, as nothing recorded them before. Deliberate overrides are visible: every one shows as `pap repo status` drift until `pap repo apply` restores the ruleset
- **Introduced in:** not yet released; the release that ships `.github/rulesets/all-branches.json` and the `push-args` guard
- **Revisit:** after 20 change PRs from #90: if the hook refused a push that was not a force push, or a force push reached a branch through a route the hook does not follow; and at once, by hand, if an agent force push is found in an adopting repository

## Context

A force push rewrites a branch's history. On a `change/` branch it can
drop commits a reviewer has read, invalidate the head an owner reviewed
(decisions 0013 and 0016 tie review to a head), and lose another
session's work when two contexts share a branch by mistake. PAP's own
rule for a branch that falls behind main is to merge main into it, never
to rebase, so a correct change never needs one.

Until now only main was protected. `.github/rulesets/main.json` carries
`non_fast_forward` for `~DEFAULT_BRANCH`; every other branch accepts a
force push from anyone with write access. The `PreToolUse` hook
(`plugins/pap/hooks/guard-route.sh`) refused commits and pushes off a
`change/` branch, hook bypasses, the owner's label and merges, but not a
force push.

Agents push with the human's own credentials: `gh` and git are signed in
as the owner. GitHub cannot tell the two apart, so anything GitHub lets
the owner do, an agent can do too. A bypass actor for the owner on the
ruleset would be a bypass for every agent.

## Decision

1. **No branch takes a force push (rule 22.1).** Two layers enforce it.
2. **GitHub: an `all-branches` ruleset.** `.github/rulesets/all-branches.json`
   targets every branch (`~ALL`) with one rule, `non_fast_forward`, and no
   bypass actors. It does not restrict creating or deleting a branch, which
   are separate rules (`creation`, `deletion`) left out, so delete-on-merge
   and `git push --delete` keep working; `main.json` still forbids deleting
   main. Branches under `renovate/` and `dependabot/` are excluded: both
   bots rebase their own pull request branches by force push, and both are
   GitHub Apps no agent session pushes as. `pap repo apply` creates or
   restores it by name, as it does `main`; `pap repo status` reports it in
   the ruleset group, and in the enforcement group whether it is active.
3. **Agent side: the hook refuses a force push.** `scripts/guard-branch.sh`
   gains a `push-args` mode that refuses `--force`, `-f` (alone or bundled,
   as in `-uf`), `--force-with-lease`, `--force-if-includes` and a
   `+<refspec>`, naming this rule and the override. The `PreToolUse` router
   passes it the words after every `git push` an agent's Bash call makes,
   in any adopting repository, on any branch. git does not run that mode,
   so a person at a terminal is unaffected by the hook; only the ruleset
   reaches them. An adopting repository whose `guard-branch.sh` predates
   the mode lets the push through until `pap sync` brings it in.
4. **The override is deliberate, and it shows.** To force-push on purpose,
   the human disables the `all-branches` ruleset in the repository's
   settings (Rules, Rulesets), pushes from their own terminal, and runs
   `pap repo apply`, which sets it active again. Until then `pap repo
   status` reports the ruleset as drift twice: its definition differs, and
   the enforcement layer says `enforcement disabled; pap repo apply
   restores it`. A bypass actor added by hand is drift too.

The reason that carried it: the credentials are shared, so the only
GitHub control that binds the agent binds the human as well, and the only
control that can tell them apart is the agent's own hook. One without the
other is either a wall the human cannot open or a door the agent can.

## Considered options

- **The ruleset with a bypass for the owner (admin bypass).** Lost: the
  agent pushes as the owner, so the bypass is the agent's too, and the
  incident would have gone through unchanged.
- **The hook only.** Lost: it does not follow `bash -c`, `eval`, scripts
  or a refspec configured in `remote.<name>.push`, and it guards only
  Claude Code sessions with the pap plugin. The ruleset is the backstop
  for every route the hook does not see.
- **The ruleset only.** Lost as the whole answer: an agent that meets the
  refusal can disable the ruleset through `gh api` with the same
  credentials and push again. The hook stops the push before it is
  attempted and names the rule; disabling the ruleset is then a visible,
  drift-reported act, not a retry.
- **A force push refused in the git pre-push hook as well.** Lost: a
  person at a terminal is meant to be unaffected by the agent guard, and a
  pre-push hook cannot tell a person from an agent either.
- **A ruleset without the bot exclusions.** Lost: Renovate and Dependabot
  would fail to rebase their branches in every adopting repository, and
  the owner would disable the ruleset to let them, which is the override
  as routine.

## Consequences

- Easier: a branch's history is what the reviewer read. A head reviewed
  under 0016 stays reachable.
- Harder: a branch that needs history rewritten (a leaked secret, a
  wrong author) costs the human three steps and leaves drift until the
  third. That cost is the point.
- Harder: GitHub will not let the default branch be renamed while force
  pushes are blocked on it and nobody may bypass; renaming it is the same
  deliberate override.
- Limit: the hook reads the command as written. `bash -c`, `eval`, a
  script, a push refspec in git config and `git push --mirror` pass it;
  the ruleset still refuses each of them, outside `renovate/` and
  `dependabot/`.
- Limit: an agent can still disable the ruleset through `gh api`. Nothing
  refuses that call; `pap repo status` shows the result.
- Measurement: force pushes are counted from each repository's audit log
  or the push events on its pull requests; neither is in git history, so
  the revisit is read by hand.

## Where it is taught or enforced

Backs [`rules.md`](../rules.md) 22.1 (no branch takes a force push).
Enforced by the ruleset [`.github/rulesets/all-branches.json`](../.github/rulesets/all-branches.json),
applied and checked by [`scripts/repo-sync.sh`](../scripts/repo-sync.sh)
(`pap repo apply` and `pap repo status`), and by
[`scripts/guard-branch.sh`](../scripts/guard-branch.sh) `push-args`, which
[`plugins/pap/hooks/guard-route.sh`](../plugins/pap/hooks/guard-route.sh)
runs on an agent's `git push`.
