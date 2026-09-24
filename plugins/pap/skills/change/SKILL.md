---
name: change
description: "Run one change end to end under decision 0002: a worktree on change/<slug> from a fresh main, commits as you go, local checks, and a draft pull request with every Checks box answered, then stop. Use when the human invokes /change <slug> <class> [Record: NNNN] followed by a brief, or asks to make a change, open a PR for a task, or work on a change branch in a repository that adopts PAP. It replaces the re-typed per-change preamble; the brief says only what to build."
argument-hint: "<slug> <class> [Record: NNNN] then the brief"
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

## 3. Build

- Commit each logical step as it lands, conventional commit subject, with the co-author trailer for generated content. Never bypass a hook (rule 5.1); a failing hook is fixed or handed to the human.
- Stay in scope. Protected paths the brief names are not touched; `tests/` may gain tests unless the brief says otherwise.
- Slow waits go in the background: CI (`gh pr checks --watch` with `run_in_background`, or `Monitor`), and any batch of `claude -p` eval runs, which run in parallel (`xargs -P`, or background jobs), never one after another.
- A judgement call beyond the brief (design, taste, a tradeoff with no clear answer) goes to a Fable subagent with the context it needs; the main session keeps executing.

## 4. Check locally

Run `mise run check` and `mise run test` in the worktree before opening the pull request. A task that does not exist is named in the report and in the Checks answer, not invented. A failure is fixed before the pull request is opened, or opened with the failure stated in Verification and the box unticked.

## 5. Open the draft pull request

Title: conventional commit, `type(scope): description`, under 72 characters. A `process:` title needs the `Record:` line.

Body, in the template's order:

```text
Change: <slug if changes/<slug>/ exists on the branch, else none>
Record: <NNNN or none>

## Summary
One or two lines, then one bullet per file or group changed.

Decisions and tradeoffs to review:
- One bullet per deviation from the brief or open call.

## Verification
The verification table: what was run, what it showed. Every check the brief asked for, including the ones not run and why.

## Checks
Tick a box only if it is true. An unticked box needs a one-line reason below it, otherwise the PR is not ready.
- [x] Verification run and output shown above
- [x] No protected path touched, or the approval is recorded here
- [x] Generated content carries provenance (model, skill, prompt)
Provenance: <model> via Claude Code, skill change, prompt "<one-line brief>"; recorded in the commit trailers.
```

Answer every box. An unticked box has its reason on the next line.

```sh
git push -u origin "change/<slug>"
gh pr create --draft --title "<title>" --body-file <body> --label "class:<class>"
gh pr view --json labels -q '.labels[].name'   # read back: the label can race creation (#29)
gh pr edit --add-label "class:<class>"         # only if the read-back lacks it
```

Then start the CI wait in the background and report without waiting for it.

## 6. Report in chat, then stop

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
```

The Revisits line is the records `pap revisits` prints as due (decision 0010): `pap revisits | awk '$2 == "due" { print $1 }'`, run as `bin/pap` in pap itself. If it cannot run, say so on that line.

Stop. Do not merge, do not mark the pull request ready, do not start the next change. One pull request per session; the human runs `/clear` before the next.
