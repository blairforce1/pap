# Conventions: PAP

What a new engineer needs on day one. Agents read this at the start of every session. Changes are reviewed like code. When a review catches the same class of mistake for the second time, the correction goes here as part of that review.

## Commands

- Build: none; pap is shell scripts and Claude Code plugins.
- Test: `mise run test`
- Lint: `mise run check`
- Format: `mise run fmt`

## Stack

POSIX shell for scripts and hooks (bash for `scripts/repo-sync.sh`), tools pinned with mise, git hooks by lefthook, Claude Code plugins under `plugins/`.

## Architecture in one paragraph

None yet.

## Conventions that differ from tool defaults

None yet.

## Mistakes we have seen more than once

None yet.
