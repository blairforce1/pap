# 0022. No branch takes a force push

- **Status:** proposed
- **Date:** 2026-11-05
- **Deciders:** blairforce1, with Claude
- **Supersedes:** none; extends the `non_fast_forward` rule of [0002](0002-skills-stop-at-draft-pr.md) from main to every branch
- **PIP:** the owner's call of 2026-11-05 that no force push becomes the default on every branch, overridable only on purpose. That week a background agent force-pushed its own `change/` branch, and nothing stopped it: the `main` ruleset blocks a non-fast-forward push on the default branch only, and the agent hook had no rule for it
- **Expected effect:** force pushes by an agent session to any branch of an adopting repository ↓ to 0; no baseline exists beyond the one incident, as nothing recorded them before. Deliberate overrides are visible: every one shows as `pap repo status` drift until `pap repo apply` restores the ruleset
- **Introduced in:** not yet released; the release that ships `.github/rulesets/all-branches.json` and the `push-args` guard
- **Revisit:** after 20 change PRs from #117: if the hook refused a push that was not a force push, or a force push reached a branch through a route the hook does not follow, with each adopting repository's force-push activity read from GitHub; and at once, by hand, if an agent force push is found in an adopting repository

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
   Note (2026-11-09): amended by
   [0023](0023-agents-act-on-github-as-their-own-app.md) point 4, shipped
   in its slice d. The ruleset lists the owner as its one bypass actor,
   so the override is now the owner's own force push from their terminal,
   with nothing to disable and re-apply; an `Integration`, or any actor
   but the owner, is drift.

The reason that carried it: the credentials are shared, so the only
GitHub control that binds the agent binds the human as well, and the only
control that can tell them apart is the agent's own hook. One without the
other is either a wall the human cannot open or a door the agent can.

## Result

### Revisit of 2026-11-09

The trigger fired at #117, the 20th change pull request merged after
#90 in merge order, as `pap revisits` counts (#91 and #92 merged
before #90): #93 to #99, #101, #102 and #107 to #117. `pap measure 0022` ran (the ten merged before the start and the first ten after); the Expected
effect is a count of force pushes, not a measure column, so no
`--verdict` ran. Force pushes are read from GitHub's repository activity
(`gh api repos/<owner>/<repo>/activity?activity_type=force_push`).

| Question                                                           | Answer                                                                                                                                                                                                                                                                                                |
| ------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Force pushes by an agent session, to 0                             | 0. No force push of any kind since 2026-11-05 in pap or the two other adopting repositories. pap's last was 2026-09-24, by hand, before the record.                                                                                                                                                   |
| The hook refusing a push that was not a force push                 | Cannot measure: a refusal shows only in a session transcript. No pull request in the window reports one from the force-push guard. The SSH pushes the hook refuses (#99, #102, #107) are rule 23.1's routing, by design, not this guard misfiring. Countable if `guard-route.sh` logged its refusals. |
| A force push reaching a branch by a route the hook does not follow | None seen: the activity logs show no force push at all, so none got past the hook to meet the ruleset either.                                                                                                                                                                                         |
| An agent force push found by hand                                  | None.                                                                                                                                                                                                                                                                                                 |

The override has changed since the record. Decision
[0023](0023-agents-act-on-github-as-their-own-app.md) point 4, applied in
#116 on all three repositories on 2026-11-09, gives the owner a bypass on
`all-branches`: the deliberate override is now the owner's own force
push, not a ruleset switched off, so the Expected effect's second
sentence (an override shows as `pap repo status` drift until
`pap repo apply`) no longer describes it. The agent stays refused, by
the hook and by the ruleset.

No force push reached any branch. Over four days and 20 pull requests,
against a baseline of one incident, that is not yet falsified rather than
shown: the count would read 0 with or without the guard.

Recommendation: amend (the Expected effect's override sentence, to the
owner's force push of 0023 point 4)

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
- **Bypass actors for the Renovate and Dependabot apps instead of the
  branch exclusions.** An `Integration` bypass gives the human none, and
  closes the gap below. Lost for now: it needs each app's id per
  installation, and a self-hosted Renovate pushing with a personal token
  is the human's credentials again, so it would be refused. A later record
  can take it if the gap is used.
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
- Harder: "Update branch" with rebase on a pull request is refused; the
  merge option, which is PAP's rule anyway, still works.
- Harder: GitHub's docs say the default branch cannot be renamed while
  force pushes are blocked on it and nobody may bypass. `main.json`
  already did that; renaming it is the same deliberate override.
- Limit: the hook reads the command as written. `bash -c`, `eval`, a
  script and a push refspec in git config pass it; the ruleset still
  refuses each of them, outside `renovate/` and `dependabot/`.
- Limit: an agent that names a branch `renovate/...` or `dependabot/...`
  can force-push it past the ruleset; only the hook refuses that.
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
