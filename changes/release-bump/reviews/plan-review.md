# Plan review: release-bump

planner: 94995 tokens, 4 minutes
plan-reviewer: 36863 tokens, 1 minute
told: 2026-11-13T16:15:06Z

Redraft against the spec at 0a22ab9 (the `--by` edit). The first review's register, with its dispositions, is in e989c79.

- PR-1 | conformance | Major | release-bump-4 is assigned to no increment: increment 1 only "prepares" it, and increment 3 (which makes the head) lists -2, -3 and -20. Nothing drops `@pending` from -4, and its test needs increment 3's work tree. Bind -4 to increment 3. | disposition: fixed: Increments
- PR-2 | conformance | Minor | release-bump-3's last line (the body's Verification says the date is UTC) needs the body, built in increment 4; increment 3 claims -3 without it. Split -3 across 3 and 4, or move it to 4. | disposition: fixed: Increments
- PR-3 | conformance | Minor | The row "Time a refused run takes, under 15 seconds" sits on acceptance on the next three bumps, but no test times a refusal and Observation has no signal; a correctly named bump will not refuse. Add a bounded test (a stubbed fetch that hangs, a short timeout variable), or say the row stays unproven. | disposition: fixed: Tests
- PR-4 | verification | Major | release-bump-16 is tested with TERM only; the spec names INT and HUP too and the trap is on all three, so a wrongly wired signal would pass. Add INT and HUP rows, or say why TERM stands for them. | disposition: fixed: Tests
- PR-5 | verification | Major | `with_timeout` (`set -m`, a process group per command, a `kill -TERM -<pgid>` watchdog) is the part most likely to fail and has no test; -12 to -16 exercise no hung `ssh`, `ls-remote` or `gh`. Add a stub that blocks past the timeout (exit 2, nothing left) and a fetch timeout (exit 1), and say how a backgrounded command's exit status and output come back. | disposition: fixed: Design, Tests
- PR-6 | verification | Minor | No local test runs the real `pr-checks` parser on the fixture body, so a body it rejects is found only on the first real pull request. Reuse the workflow's check on the fixture body, or say why it cannot be reused. | disposition: fixed: Tests
- PR-7 | design | Minor | Between `git worktree add` and `exec sh "$wt/..."` the caller's copy holds a work tree and branch; it is unclear whether it records and undoes them in that window, for example when the exec fails. State the trap's coverage across the exec. | disposition: fixed: Design
- PR-8 | design | Minor | Increment 8 changes the cycle's first act, but Fit names neither `docs/run-a-project.md` nor `plugins/pap/skills/pm/pap-pm.sh`, which describe `Mechanical: yes` and the first act; the release brief's four-line form is defined nowhere in the PM text. Say who writes that brief and whether the docs change. | disposition: fixed: Increments, Fit
- PR-9 | design | Observation | `--places-at` is a new flag on a `release.sh` whose argument loop dies on any `-*`; `release.test.sh` copies only it and `written-with.sh`. Works as planned; the 0024 dated note as the only record is adequate. | disposition: accepted
- PR-10 | design | Observation | The protected paths in Fit match `.github/CODEOWNERS`; the unprotected files match too; the plan embeds no instruction to its reader. | disposition: accepted
- PR-11 | security | Minor | The in-worktree script and the body template come from origin/main, so the script's own integrity rests on review of its pull requests, not on this command; state that, as the limit decision 0027 draws. | disposition: fixed: Fit
- PR-12 | security | Observation | The delete's window between `ls-remote` and the plain `--delete` is stated in the header and accepted for a drift threat model. | disposition: accepted
