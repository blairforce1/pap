# 0024. Cycles run as slim agents the pap plugin ships

- **Status:** proposed
- **Date:** 2026-11-09
- **Deciders:** blairforce1, with Claude
- **Supersedes:** none; amends [0019](0019-a-cold-review-runs-before-every-draft-pr.md)
  (point 1: the reviewer is spawned as `pap:reviewer`, and a mechanical
  change skips it) and
  [0018](0018-a-project-manager-session-launches-cycles-and-keeps-the-tracker.md)
  (the planned `pap:member` agent ships as `pap:cycle`, with a mechanical
  variant)
- **PIP:** the Project Lead's ask of 2026-11-09, after a day's cycles
  overran their budgets on context they did not use. A `general-purpose`
  sub-agent starts at about 50.4k tokens before it does any work: every
  MCP tool schema the session has, the full skills list, CLAUDE.md and
  memory. Four cycles that day (a `.github` change, the 0.15.0 bump, two
  0.15.0 syncs) ended at 76-91k against budgets of 30-35k; the work itself
  was 26-40k each. `/change`'s cold review spawns its own sub-agent, which
  paid the same floor again, about 64k per review on the two syncs, and
  both returned no result. A user-level agent with
  `tools: Bash, Read, Edit, Write, Grep, Glob, Skill, Agent` and
  `model: inherit` started at 22.7k (31.4k after one tool call)
- **Expected effect:** a cycle's first-turn context ↓ from about 50.4k to
  about 23k; the cold reviewer's total tokens ↓ from about 64k on a sync to 0 on a
  mechanical change (point 5), and ↓ on the rest;
  cycles that end over their budget ↓ from 4 of 4 on 2026-11-09; reviews
  that return no result ↓ from 2 of 2 on the syncs. All read from each
  task's usage (first and last turn context) in the PM tracker
- **Introduced in:** not yet released; the release that ships
  `plugins/pap/agents/`
- **Revisit:** after 10 cycles launched as `pap:cycle` or
  `pap:cycle-mechanical`: the four effects; for `pap:cycle-mechanical`,
  how many of its bumps and syncs got a message after their first report
  (target 0); whether any change that skipped the review under point 5 needed
  a fix after it; on the first Haiku failure, fall back to Sonnet by a dated note here

## Context

Claude Code gives a sub-agent the tools its agent type allows. The
general-purpose type allows all of them, so it carries the schema of every
MCP server the parent has: mail, accounting, browser, database and build
logs in the adopting repository that measured this. A cycle uses none of
them. It reads files, runs git, gh and mise, edits, and may spawn the cold
reviewer. Each tool schema it does not use is context paid on every turn.

Claude Code loads agent definitions at session start, and a plugin can
ship them in its `agents/` directory; they are named `<plugin>:<agent>`,
here `pap:cycle`. A definition's `tools` list limits what the agent gets,
and `model` picks its model (`inherit` takes the parent's). Shipping them
in pap gives every adopter the same three without copying a file.

## Decision

1. **pap ships three agents in `plugins/pap/agents/`.**
   - `pap:cycle`: tools Bash, Read, Edit, Write, Grep, Glob, Skill, Agent;
     model `inherit`. Bash covers git, gh, mise and the checks; Read, Edit,
     Write, Grep and Glob are the file work; Skill loads `/change`; Agent
     spawns the cold reviewer and, under `/change` step 3, a judgement
     call. No MCP tool. The PM picks the model and effort per brief, so
     the agent inherits rather than fixing one.
   - `pap:cycle-mechanical`: the same tools, model `haiku`. For version
     bumps and template syncs only: version strings, generated sync output
     and changelog moves. Anything needing judgement stops with `ASK:`.
     Haiku is tried on the next bump; if it fails, a dated note here moves
     it to `sonnet`.
   - `pap:reviewer`: tools Bash, Read, Grep, Glob, Skill; no Edit, Write
     or Agent, so it cannot change the branch it reviews or start reviewers
     of its own. Skill runs `/code-review low`. Model `sonnet`: reading a
     diff against a brief is scoped judgement, which Haiku is weakest at
     and `inherit` would pay the author's model for.
2. **A PM launches every cycle as `pap:cycle`, or `pap:cycle-mechanical`
   for a bump or a sync, and never as general-purpose.**
3. **`/change` step 5 spawns its reviewer as `pap:reviewer`.** Where the
   session cannot load it, typically one started before the plugin
   shipped it, the step falls back to today's behaviour: a general-purpose
   subagent told to edit nothing. Nothing else in 0019 changes.
4. **A specialist that needs other tools is the adopting repository's.**
   A cycle that has to read mail or post to an accounting API is defined
   in that repository's `.claude/agents/`, with exactly the MCP tools it
   needs. pap ships no agent that names an MCP server: it cannot know
   which ones an adopter has.
5. **A mechanical change skips the cold review.** Decided by the Project
   Lead on 2026-11-09, relayed by the PM. A change is mechanical only if
   every line of its diff is one of:
   - a version string changed to the version the brief names, in a file
     that already carried the old one;
   - output written by `pap sync` (or the repository's own generator the
     brief names), committed exactly as the tool wrote it;
   - an existing CHANGELOG entry moved under a new version heading, with
     that heading and its date.

   Anything else makes it not mechanical, and the review runs: a hand edit
   to generated output, a resolved conflict, a new or reworded changelog
   line, a file the brief did not name, a fix to make a check pass. The
   test is the diff, not the agent: a `pap:cycle` doing a bump may skip,
   and a `pap:cycle-mechanical` whose diff stretched may not. The skipped
   review leaves its Verification row as
   `cold review skipped: mechanical (decision 0024)`.

## Considered options

- **Keep general-purpose with a stricter brief.** Lost: a brief cannot
  remove tool schemas from the context; only the agent type can.
- **User-level agents in each machine's `~/.claude/agents/`.** Lost as the
  default: measured, it works, but every adopter would copy and maintain
  the file. Plugin agents arrive with `pap` updates.
- **One agent for cycles and reviews.** Lost: the reviewer must not edit,
  and a tool list is the only guard that holds without trusting the
  prompt.
- **MCP tools in `pap:cycle` for the repositories that need them.** Lost:
  point 4; it would put every adopter's servers in every adopter's cycles.
- **Always run the cold review, on `pap:reviewer`, mechanical changes
  included.** Put to the Project Lead with this as the recommendation, as
  the smallest model is where a second reader earns most. Lost: the
  Project Lead chose point 5; the diff-only definition is what keeps a
  judgement change from passing as mechanical.
- **Reviewer on `haiku`.** Lost for now: the cheapest, but the review's
  value is finding a brief not met, which needs judgement. It can be tried
  after the Haiku cycle shows how far the small model goes.

## Consequences

- Easier: a cycle's budget pays for its work, not for tools it never
  calls; the reviewer stops costing as much as the change.
- Harder: a session started before an update has none of the three; the
  PM falls back to general-purpose and `/change` to its old reviewer
  until restart.
- Harder: a mechanical change reaches the human with no second reader.
  The definition in point 5 is narrow so that only diffs a tool wrote or a
  version string changed can skip.
- Harder: a cycle that needs an MCP tool its brief did not foresee cannot
  reach it, and stops with `ASK:`. That is the intended cost of point 4.
- Limit: the 50.4k and 22.7k floors were measured in one adopting
  repository, with its MCP servers; another adopter's saving depends on
  how many it has.
- Measurement: each task's usage gives first- and last-turn context; the
  PM tracker records them per cycle, as 0018's baseline was recorded. The
  window is small, so the result is read as a direction.

## Where it is taught or enforced

Taught by the agent definitions in
[`plugins/pap/agents/`](../plugins/pap/agents/), `/change` step 5
([`plugins/pap/skills/change/SKILL.md`](../plugins/pap/skills/change/SKILL.md))
and [`docs/run-a-project.md`](../docs/run-a-project.md). Enforced by the
tool lists: a `pap:reviewer` has no Edit or Write, and a `pap:cycle` has
no MCP tool. `tests/plugin-agents.test.sh` checks the three files parse.
Nothing refuses a PM launch as general-purpose.
