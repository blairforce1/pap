---
name: intent
description: "Interview the human to write the accepted intent for one change (decision 0020): read the product layer, ask in small batches, challenge the hypothesis, the success measure, the non-goals, the invariants and the class, restate the intent in process 5.3's sections, and on the human's yes write and commit changes/<slug>/intent.md on change/<slug>, then hand on to the spec. Use when the human invokes /intent <slug> <class> followed by what they want, or asks to write, draft, sharpen or review an intent for a change in a repository that adopts PAP. Runs in the main session only; a background agent cannot interview."
argument-hint: "<slug> <feature|infra|security-sensitive|bugfix|spike|chore|docs> <ask>"
---

# Intent

Get the intent out of the human's head and into `changes/<slug>/intent.md` as half a page they have said yes to. The human owns the intent (process principle 1); you ask, challenge and restate. Decision 0020 and `rules.md` are the authority; this skill applies them.

**Main session only.** The interview talks to the human. A background agent cannot; if you are one, stop and report that `/intent` needs the main session.

## Arguments

- `<slug>`: the change's id. The branch is `change/<slug>`, the folder `changes/<slug>/`. Letters, digits, `.`, `_`, `-`.
- `<class>`: one of `feature`, `infra`, `security-sensitive`, `bugfix`, `spike`, `chore`, `docs`. Provisional: the interview confirms or changes it.
- The rest of the message is the ask, in the human's words.

Anything missing: ask once, in one question, then proceed.

## Stance

- **Small batches.** Two to four questions a turn, grouped as below; wait; follow up on the weak answer only. One question at a time is too slow for half a page; ten at once gets ten shallow answers.
- **Challenge once, then record.** Each item in the critique list is raised at most once. The human's answer stands and goes in the file, even where you would have chosen otherwise.
- **Propose from the files, do not ask cold.** You have read the product layer; offer the hypothesis, the invariants and the risk level you see, and ask the human to confirm or correct.
- **No ceremony for its own sake.** `docs` and `chore` get one batch. A question whose answer is already in the ask is not asked.
- **No yes, no file.** Nothing is written until the human accepts the restatement.

## 1. Worktree

The same worktree as `/change`, so the intent is committed on the branch the change will use:

```sh
sh "${CLAUDE_PLUGIN_ROOT}/skills/change/worktree.sh" <slug>
```

- `created <path>`: a new branch from a fresh `origin/main`.
- `resumed <path>`: the branch existed. If `changes/<slug>/intent.md` is on it with acceptance lines, run the interview as a review: show the file, ask what has changed, and go to step 5 with the edits. If `spec.md` is also there, the edit is intent churn (process 5.4): the commit message says what the spec surfaced. An `intent.md` without acceptance lines (written by hand, or before decision 0020) is a draft of the ask: show it, interview from it, and overwrite it on the yes.
- `exists <path>` (exit 3) or exit 1: stop and print the message; do not work in another session's worktree.

Every later command runs in the printed path.

## 2. Read the product layer

In the worktree, read `product/vision.md`, `product/invariants.md` (the protected paths section above all), `product/backlog.md`, `product/conventions.md`, and `product/domain.md` if present; `CLAUDE.md`; `.github/risk.yml` if present, for the level the touched paths will get; and the files the ask names. No `product/`: stop and say `/envision` comes first.

Do not summarise any of it to the human. Use it to propose: the backlog items the ask could serve, the invariants and protected paths the files it names fall under, the words `domain.md` uses for what the ask describes.

## 3. Interview

Each batch is one turn. Skip a question the ask already answers.

**Batch one: the ask and the why.**

- The ask restated in one line: is this it?
- Which backlog hypothesis it serves. Offer the `H-NNN` that fit; if none does, ask what it reacts to (an escape, a breach, a request, a finding) and from where (`source:`, an issue URL or `none`).
- Who notices when it has worked, and what they see.

**Batch two: the measure and the edges.**

- The success measure: what is observed after release, from where, and the number that would count as met, within the operation window.
- Non-goals: what someone will expect this to do that it will not.

**Batch three: the invariants, the class and the rest.**

- Invariants and protected paths touched: propose the list from the files; confirm or correct. Name the risk level that follows where `.github/risk.yml` exists.
- The class: confirm or change it, with what it buys (process section 4: the spec sections, reviews and test tiers).
- Constraints: what is fixed before the spec starts (stack, budget, deadline, compatibility, what it must not break).
- Open questions: each answered now, or carried forward with who answers it and in which phase.

**Lighter interview.** For `docs` and `chore`: batch one, with the measure (what a reader can check afterwards) and the files touched folded in. If a touched file is a protected path or a hook, say so and run the full interview; critique 5 then asks whether `docs` or `chore` still fits. For `spike`: one batch: the question it answers, the time box, and that only `findings.md` is kept; a spike has no spec and no deploy.

## 4. Critique

The list. Raise each where it applies, once, concretely, with what you would write instead; then record the human's answer.

1. **Hypothesis or reactive.** An intent names an `H-NNN` or `reactive: <what it reacts to>`. A backlog item stretched to fit is named as a stretch; a fitting item the human did not name is offered.
2. **Measure observable after release.** "Tests pass", "it works" and "it is merged" are build checks, not measures. If no measure can be written, the change is too large or too vague (principle 3): propose the split.
3. **At least one non-goal.** The nearest thing this will be mistaken for.
4. **Invariants and protected paths declared, not discovered.** A protected path usually makes the risk high (decision 0016): name the level `.github/risk.yml` gives the touched files (step 2), so the intent says it before the label does.
5. **Class fits the ceremony.** A `docs` that edits a hook is not docs; a `feature` with no user-visible behaviour may be `infra`; a `bugfix` cites the escaped defect it closes; a `spike` has no spec. Say what the class costs and ask whether that is the cost wanted.
6. **Every open question has an owner.** Answered now, or carried forward to a named phase, usually the spec.

## 5. Restate for the yes

Restate the intent as half a page in process 5.3's sections, in the human's words where they gave them, using `references/template.md`. End with the acceptance line you will record: `accepted-by: @<login>` (from `gh api user -q .login`, or the name the human gives) and today's date. Ask for a yes.

A yes goes to step 6. An adjustment is made and the changed section restated, then asked again. A no, or no answer, ends here: nothing is written. After `created`, say the branch holds no commit and how to remove it (`git worktree remove <path>`, then `git branch -D change/<slug>`); after `resumed`, say the file is unchanged, run `git worktree remove <path>` and stop.

## 6. Write and commit

Write `changes/<slug>/intent.md` from the template: the 5.3 frontmatter with `source:` (rule 11.2), the acceptance lines, and provenance (`generated-by:`, `skills:` with this plugin's version, `prompt:` as the `/intent` line the human typed). Commit it on the branch, never bypassing a hook (rule 5.1):

```sh
git add changes/<slug>/intent.md
git commit -m "intent(<slug>): <desired outcome in a few words>"
```

A review edit (step 1, `resumed`) commits as `intent(<slug>): <what changed>`, or `intent(<slug>): churn, <what the spec surfaced>` when `spec.md` exists.

Then remove the worktree, keeping the branch and its commit: `git worktree remove <path>`. `/spec` and `/change` each make their own worktree on the branch and print `resumed`; a worktree left open makes it print `exists` and stop.

No push and no pull request: `/change` pushes the branch and opens the one draft pull request that carries intent, spec and code in order (decision 0020).

## 7. Hand on, then stop

Say what is next and how: the spec. `/spec <slug>` in a fresh context (decision 0021) reads this intent, drafts `changes/<slug>/spec.md` with the sections the class requires, runs the review board and records the human's yes on the branch; then `/change <slug> <class>` with a brief, which reads both. A spike has no spec: say `/change` is next.

Stop. One intent per invocation; do not start the spec, the brief or the change.

## What not to do

- Do not write the file before the yes, and do not write a hypothesis, a class or a measure the human did not confirm.
- Do not restate the product layer to the human, or ask a question the ask already answers.
- Do not run more than three batches for a full interview or one for `docs`, `chore` and `spike`.
- Do not push, open a pull request, or edit anything outside `changes/<slug>/`.
