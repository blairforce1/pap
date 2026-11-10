---
name: change
description: "Run one change end to end under decision 0002: a worktree on change/<slug> from a fresh main, commits as you go, local checks, a cold review, and a draft pull request with every Checks box answered, then stop. Use when the human invokes /change <slug> <class> [Record: NNNN] followed by a brief, or asks to make a change, open a PR for a task, or work on a change branch in a repository that adopts PAP. It replaces the re-typed per-change preamble; the brief says only what to build."
argument-hint: "<slug> <feature|infra|security-sensitive|bugfix|spike|chore|docs> [Record: NNNN] <brief>"
---

# Change

One change, one worktree, one draft pull request, then stop. The brief says what to build; this skill is how every change is carried. Decision 0002 and the rules in `rules.md` are the authority; this skill applies them and does not restate them.

## Arguments

- `<slug>`: the change name. The branch is `change/<slug>`. Letters, digits, `.`, `_`, `-`.
- `<class>`: one of `feature`, `infra`, `security-sensitive`, `bugfix`, `spike`, `chore`, `docs`. It becomes the `class:<class>` label.
- `Record: NNNN`: required when the title type will be `process:`, and names the decision record the pull request ships. Otherwise `Record: none`.
- The rest of the message is the brief.

Anything missing or invalid: ask once, in one question, then proceed.

## 1. Worktree

Always a worktree; never switch the main checkout's branch, because parallel sessions share it.

worktree.sh takes the repository from the current directory, which for a launched cycle may be its launcher's. First check `git rev-parse --show-toplevel` against the repository the brief names; if they differ, `cd` there before running it.

```sh
sh "${CLAUDE_PLUGIN_ROOT}/skills/change/worktree.sh" <slug>
```

It prints one line:

- `created <path>`: no `change/<slug>` existed; a new branch from a freshly fetched `origin/main`.
- `resumed <path>`: `change/<slug>` existed, locally or on origin; it is checked out as it was, never recreated or reset. Say so in the report.
- `exists <path>` (exit 3): a worktree for the branch is already open, probably another session's. Stop and print the path; do not work in it.
- Exit 1: a bad slug, no `origin/main`, or the path taken by something else. Report the message and stop.

Every later command runs in the printed path (`cd` into it, or `git -C`).

## 2. Read, then report only contradictions

Read what the brief names, plus `rules.md` and the decision records it cites for the files you will touch. Do not summarise what you read. Report only what contradicts the brief: a file or task that does not exist, a rule the brief would break, an instruction that conflicts with another. One line each, with the resolution you are taking. None found: say "No contradictions" and proceed.

If `changes/<slug>/intent.md` exists on the branch (written by `/intent`, decision 0020), read it first: it is the brief's intent, and its `class` and `hypothesis` stand. A `<class>` argument or a brief that differs from it is a contradiction to report.

## 3. Build

- Commit each logical step as it lands, conventional commit subject, with the co-author trailer for generated content. Never bypass a hook (rule 5.1); a failing hook is fixed or handed to the human.
- Stay in scope. Protected paths the brief names are not touched; `tests/` may gain tests unless the brief says otherwise.
- Where the branch has `changes/<slug>/spec.md` with its acceptance lines filled (written by `/spec`, decision 0021), build to it: its scenarios are the acceptance criteria, its Non-functional rows the thresholds, and its Undo the pull request's "How to revert". A `spec.md` without acceptance lines is a draft the human has not accepted: a contradiction to report. A test made to pass by rewriting a scenario is a return to spec (rule 17.3), not a fix.
- Build Debug unless the change concerns Release behaviour. A Release, AOT, Android, iOS or Mac Catalyst build is a heavy build (rule 15.1): run it through the repository's `scripts/heavy-build.sh`, which takes the machine's one heavy-build lock and caps MSBuild on battery, because parallel sessions share one machine's cores and power. A repository without the script (it has not taken the .NET layer) runs `flock -o "${XDG_RUNTIME_DIR:-/tmp}/pap-heavy-build.lock" dotnet <verb> <arguments>`, adding `-m:2` on battery; `-o` keeps the lock from the build servers that outlive the build.
- Slow waits go in the background: CI (`gh pr checks --watch` with `run_in_background`, or `Monitor`), and any batch of `claude -p` eval runs, which run in parallel (`xargs -P`, or background jobs), never one after another.
- A judgement call beyond the brief (design, taste, a tradeoff with no clear answer) goes to a Fable subagent with the context it needs; the main session keeps executing.

## 4. Check locally

Run `mise run check` and `mise run test` in the worktree before opening the pull request. A task that does not exist is named in the report and in the Checks answer, not invented. A failure is fixed before the pull request is opened, or opened with the failure stated in Verification and the box unticked.

## 5. Review cold

Before opening the pull request, have the branch reviewed by a context that did not write it (decision 0019). A mechanical change skips this step (decision 0024): one whose every diff line is a version string changed to the version the brief names in a file that already carried the old one, output written by `pap sync` (or the generator the brief names) committed exactly as the tool wrote it, or an existing CHANGELOG entry moved under a new version heading with that heading and its date. A hand edit, a resolved conflict, a new changelog line or a file the brief did not name makes it not mechanical. A skipped review's Verification row is `cold review skipped: mechanical (decision 0024)`. Spawn one read-only subagent as `pap:reviewer` (decision 0024); where that agent type is not available, as in a session started before the plugin shipped it, spawn a general-purpose subagent and tell it to edit nothing. Give it only the brief, the worktree's absolute path and the command `git -C <worktree> diff origin/main...HEAD`, not your reasoning. It first changes into that worktree (it starts in its launcher's directory, where `/code-review` sees no diff), runs `/code-review` with args `low <worktree>` where the skill exists, reads the diff against the brief either way, edits nothing, and returns its findings; a `/code-review` that could not see the diff counts as not available. Fix each finding and commit, rerunning step 4 if the fix touched what it checks, or answer it with a reason. Verification gets one row: the review ran, its level (or that `/code-review` was not available), the findings, which were fixed, any left with the reason, and the reviewer's tokens.

## 6. Open the draft pull request

Title: conventional commit, `type(scope): description`, under 72 characters. A `process:` title needs the `Record:` line.

Body, in the template's order:

```text
Change: <slug if changes/<slug>/ exists on the branch, else none>
Record: <NNNN or none>
Route: <the brief's route and its rule 20.2 item; omit the line when the brief names none>

## Summary
One or two lines, then one bullet per file or group changed.

Decisions and tradeoffs to review:
- One bullet per deviation from the brief or open call.

## Verification
The verification table: what was run, what it showed. Every check the brief asked for, including the ones not run and why, and the cold review's row (step 5).

## How to revert
The spec's Undo where the branch has changes/<slug>/spec.md; otherwise "Revert the merge", with the steps in order for anything the change reaches outside git.

## Checks
Tick a box only if it is true. An unticked box needs a one-line reason below it, otherwise the PR is not ready.
- [x] Verification run and output shown above
- [x] No protected path touched, or the owner has approved the head: `Approved-by: @login <sha>` below, or (risk mode) the `owner-reviewed` label
- [x] Generated content carries provenance (model, skill, prompt)
Provenance: <model> via Claude Code, skill change, prompt "<one-line brief>"; recorded in the commit trailers.
```

The `Route:` line is for a cycle a project-manager session launched (rule 25.5). Its brief starts with the route, `/intent <slug> <class>` or `/change <slug> <class> [Record: NNNN]`, and its second line names the item of rule 20.2 that decided it (rule 18.8). Copy both, unchanged, onto one line joined by `; `, as in `Route: /change <slug> <class>; Rule 20.2: item 1`. A change with no such brief, one the human invoked directly, has no `Route:` line.

Answer every box. An unticked box has its reason on the next line. The protected-path box depends on the mode: the repository is in risk mode when its base branch has `.github/risk.yml` (`git cat-file -e origin/main:.github/risk.yml`, decision 0016).

Not in risk mode: if the diff touches a path in the base branch's `.github/CODEOWNERS`, leave the protected-path box unticked with `Head to approve: <short sha>` as its reason, the pushed head's first seven characters (`git rev-parse --short=7 HEAD`), and never write an `Approved-by:` line: it is the owner's, typed by hand before merge (decision 0012), and names the head it approves (decision 0013). After every later push, update that reason to the new head; the rewrite drops any `Approved-by:` line, which the push made stale anyway, and the report says the owner must re-approve.

In risk mode there is no `Approved-by:` line and no `Head to approve:` reason. Once the pull request is open, wait for the `pr-checks` run on the head (a short wait, seconds), read its `risk:*` label (`gh pr view --json labels -q '.labels[].name'`), and answer the box: for `risk:low` or `risk:medium`, tick it with `Risk: <level>` on the next line; for `risk:high`, leave it unticked with `Risk: high; the owner adds owner-reviewed after review` as its reason. After every later push, read the label again and update the answer; the push removed any `owner-reviewed` label, and the report says the owner must review the new head. Never add `owner-reviewed` and never merge (rule 16.2): the label is the owner's, as the line is.

```sh
git push -u origin "change/<slug>"
gh pr create --draft --title "<title>" --body-file <body> --label "class:<class>"
gh pr view --json labels -q '.labels[].name'   # read back: the label can race creation (#29)
gh pr edit --add-label "class:<class>"         # only if the read-back lacks it
```

Then, in risk mode, answer the protected-path box as above. Start the CI wait in the background and report without waiting for it.

## 7. Report in chat, then stop

The verification table lives in the pull request body only. The chat report is exactly:

```text
<PR URL> (draft)
Built:
  five lines at most, what exists now that did not
Deviations from the brief:
  one line each, or "none"
Decisions left to you:
  one line each, or "none"
Revisits due: <record numbers, or "none">
Once the pull request has merged, run `mise run tidy` to remove this worktree and branch.
Approved-by: @<owner> <short sha>
```

The last line depends on the mode. Not in risk mode, it is only for a pull request touching a protected path: the line for the owner to paste into the body, naming the owners from `.github/CODEOWNERS` and the head in the box's reason; omit it otherwise. In risk mode it is always there, in place of the `Approved-by:` line: `Risk: high; add owner-reviewed after review` for a `risk:high` pull request, `Risk: <level>` for the others.

The Revisits line is the records `pap revisits` prints as due (decision 0010): `pap revisits | awk '$2 == "due" { print $1 }'`, run as `bin/pap` in pap itself. If it cannot run, say so on that line.

Stop. Do not merge, do not mark the pull request ready, do not start the next change. One pull request per agent context (a top-level session, or a background sub-agent run under a project-manager session); the human runs `/clear` before the next change in a session, and a fresh sub-agent takes the next one.
