# Intent template

Use it exactly, in this order; write "none" rather than removing a line or a heading. Half a page: a section is one to three sentences or a short list.

The same text, without the acceptance lines and the provenance, is the restatement the human says yes to.

````markdown
# Intent: <slug>

```text
id:                 <slug>
class:              <feature | infra | security-sensitive | bugfix | spike | chore | docs>
product:            <product name, as product/vision.md has it>
source:             <issue URL, or none>
hypothesis:         <H-NNN, or reactive: <what it reacts to>>
invariants-touched: <INV-NNN, ...; protected paths by path; or none>
accepted-by:        @<login>
accepted-on:        <YYYY-MM-DD>
generated-by:       <model and version> via Claude Code
skills:             pap:intent <plugin version>
prompt:             /intent <slug> <class> <the ask, in one line>
```

## Problem

<Who cannot do what today, and what it costs them.>

## Desired outcome

<What is true after the change that is not true now. Behaviour, not implementation.>

## Non-goals

- <What this will be expected to do and will not, one line each.>

## Constraints

- <What is fixed before the spec starts: stack, budget, deadline, compatibility, what it must not break.>

## Success measure

<What is observed after release, from where, and the number that counts as met, within the operation window.>

## Open questions

- <Question>: answered, <answer>. | carried forward to <phase>, <who answers>.
````

A review edit after the yes keeps `accepted-by:` and `accepted-on:` and adds one line under the frontmatter block: `Edited <YYYY-MM-DD>: <what changed and why>`. A change of class or hypothesis is a new yes: the acceptance lines are rewritten with it.
