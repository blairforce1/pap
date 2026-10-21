# pap: working rules for agent sessions

## Every change

- Use `/change <slug> <class> [Record: NNNN]` followed by the brief. The
  skill carries the branch, worktree, commits, checks and draft pull
  request; the brief only says what to build.
- One pull request per agent context. A context is a top-level session or a
  background sub-agent run under a project-manager session. After it opens
  its draft pull request it stops; the human runs `/clear` before the next
  change in a session, and a fresh sub-agent takes the next one. The
  project-manager session opens no change pull requests, bar process
  housekeeping when the owner asks.

## Where the rules live

- `rules.md` is the index of enforceable rules. `decisions/` holds the
  records behind them. Read the ones that bear on the files you touch; do
  not restate or summarise them here, in a pull request or in chat.
- A rule changes only with its decision record.

## Working habits

- Worktrees always: `../pap-<slug>` on `change/<slug>`. Never switch the
  branch of the main checkout; parallel sessions share it.
- Waits go in the background: CI watches, container builds, `claude -p`
  eval batches (in parallel, not one after another). Keep working, or
  report, while they run.
- `mise run test` is the test suite. Build throwaway repositories with
  `scripts/assemble.sh`, not by hand.
