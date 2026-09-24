# 0008. Adopt and sync the template with assemble.sh and git merge-file

- **Status:** accepted
- **Date:** 2026-09-24
- **Deciders:** blairforce1, with Claude Code
- **Supersedes:** none
- **PIP:** none; this is a structural record, not an intervention under 0001
- **Expected effect:** not applicable
- **Introduced in:** unreleased
- **Revisit:** if a layer needs a file rendered per repository (a name, an owner, a choice), which is what copier does and this tool does not; or if per-file merging proves too coarse, for example a sync that keeps producing conflicts a tree-level merge would have avoided

## Context

A repository adopts the template once and must take later template
versions without losing its own edits. Decision
[0003](0003-template-layers-compose-additively.md) planned a sync tool that
refuses a collision and merges `mise.toml`; since then each layer ships its
own `.config/mise/conf.d/<layer>.toml` and `.config/lefthook/<layer>.yml`,
so no file is merged by the tool. What is left is copying files and
merging a repository's edits with the template's. `scripts/assemble.sh`
already copies the layers, dereferences the symlinks in `templates/base/`,
leaves out each layer's README and refuses a collision.

copier 9.18.2 and cruft 2.16.0 were run, through `uvx`, against a copy of
the layers in a scratch repository tagged at two versions:

| Need                                      | copier                                                                                                              | cruft                                                                                                                                       | `assemble.sh` plus `git merge-file`                                         |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| Several layers from one repository        | A root `copier.yml` with `_subdirectory: "templates/{{ layer }}"`, one run and one answers file per layer           | `--directory` per layer, but each layer must become a cookiecutter template: a `cookiecutter.json` and a `{{cookiecutter.slug}}/` directory | `assemble.sh base dotnet go`                                                |
| Three-way update against a pinned version | `copier update`; a local edit and a template change elsewhere in the same file both kept                            | `cruft update --checkout <tag>`; same result                                                                                                | `git merge-file` per file, the template at the recorded version as the base |
| Conflict                                  | Inline markers, but exit 0                                                                                          | Inline markers from `git apply -3`, exit 0, and "as clean as possible"                                                                      | Inline markers labelled with each version, exit 1                           |
| Symlinks out of the layer                 | Dereferenced only when the template root is the whole repository; `templates/base` alone gives `ForbiddenPathError` | Dereferenced, but the extra directory level breaks every relative link until it gains a `../`                                               | Dereferenced (`cp -L`)                                                      |
| Layer README left out                     | `-x README.md`                                                                                                      | No exclude option; restructure the layer                                                                                                    | Left out                                                                    |
| Collision between layers (decision 0003)  | Refused interactively; with `--overwrite` the last layer silently wins                                              | Not tested; one `.cruft.json` per directory                                                                                                 | Refused, naming the path and both layers, nothing written                   |
| Dependency                                | Python 3.10 or later                                                                                                | Python, cookiecutter                                                                                                                        | None beyond git and a POSIX shell                                           |
| Applied version                           | `_commit` in an answers file, written only if each layer ships a `{{ _copier_conf.answers_file }}.jinja`            | `.cruft.json`: commit SHA, tag, context                                                                                                     | `.config/pap.toml`: `version` and `layers`                                  |

## Decision

pap adopts and syncs the template itself, in POSIX shell, on
`assemble.sh` and `git merge-file`. `pap init <layer>...` and `pap sync`
share one step: assemble the recorded layers at the recorded version (the
base), assemble the target layers at the target version (theirs), and for
each path merge the repository's file (ours) with `git merge-file`. A file
the template did not change is left alone; a file the template adds is
written; a file it drops is removed if unedited and kept if edited; a
clash is left as ordinary conflict markers and the command exits 1. Each
version is assembled by its own `assemble.sh`, so a version's collision
rule is the one it shipped with. Both commands refuse a dirty working
tree, so every change they make can be read, and undone, with git.

The applied version and layers are recorded in `.config/pap.toml`,
tracked, two lines, for `pap sync` and the event emitter. pap itself is
pinned separately, in `.config/mise/conf.d/pap.toml`, installed by mise's
`github` backend from the release archive `pap-<version>.tar.gz`
(decision [0001](0001-process-changes-are-measured-interventions.md): app
repositories pin the tag). The pin is what is installed and the record is
what is applied; they differ between a bump and the sync that follows it.
A template version other than the running pap's own is fetched as tag
`v<version>` from GitHub.

The reason that carried it: nothing is rendered. copier and cruft are
template engines whose update is a by-product of re-rendering, and every
line of their setup here (a `copier.yml`, an answers-file template in each
layer, cookiecutter directories, rewritten symlinks) would exist only to
turn rendering off. Without rendering, the update is a per-file three-way
merge, which git already ships.

## Considered options

- **copier.** The closest fit: it merged cleanly and put conflicts inline.
  Lost: a Python runtime before the first `mise install`, an answers-file
  template added to every layer or no version is recorded, a collision
  that `--overwrite` turns into last-layer-wins, and exit 0 on a conflict.
- **cruft.** Lost: every layer restructured into a cookiecutter template,
  its symlinks re-pointed, no way to leave the README out, and a
  misleading success message on conflict.
- **A tree-level merge** (commit each version to an orphan branch and `git
  merge` it). Kept in reserve: it would also detect renames, but it puts
  template history into every adopting repository. Per-file is enough
  while the template has no renames.

## Consequences

- Easier: no dependency before mise installs anything; the same shell
  that runs the hooks runs the sync.
- Easier: rule 3.1 has a check. `assemble.sh`, run by `pap init` and
  `pap sync`, refuses a layer that writes a file another layer owns.
- Easier: a conflict is exit 1 with markers labelled `<path> (here)` and
  `template v<version>`, which a script and a person both read.
- Harder: a rename in the template reads as a drop and an add, and an
  edited file under the old name is kept beside the new one. Accepted
  until the template renames something.
- Harder: the three-way base is fetched from GitHub on every sync to a
  version other than the running pap's own; there is no offline sync
  across versions.
- Harder: `.config/pap.toml` is parsed with `sed`. It is written only by
  pap; hand edits outside its two-line shape are not supported.
- Follow-up: rule 7.1's planned check, a Renovate extract over an
  assembled repository, belongs in `pap sync` or a `pap check`. Not built
  here.
- Follow-up: whether Renovate's mise manager reads the `github:` pin in
  `.config/mise/conf.d/pap.toml` is not verified; until it is, a pap bump
  is manual.
- Recorded 2026-09-24: it does. A Renovate 44.112.3 dry run extracted the
  `github:blairforce1/pap` table pin and proposed an update for a
  `github:cli/cli` pin of the same shape, so a pap bump arrives as a
  Renovate pull request; `mise install` and `pap sync` still follow it by
  hand.
- Recorded 2026-09-24: `pap init` run from a checkout with no release tag
  records `version = "unreleased"` and a `commit` line, a third line in
  `.config/pap.toml`. `pap sync` uses that commit as the three-way base,
  from the checkout or fetched from GitHub, and refuses one it cannot find.
- Recorded 2026-09-24: that commit is the merge-base of HEAD with the
  checkout's `origin/main`, not HEAD. A squash merge discards a branch's
  own commits, so a recorded branch head stops existing on main; #38's
  record had to be corrected by hand. The merge-base is the newest commit
  sure to reach main. init still applies HEAD's templates, so a branch's
  template changes past the merge-base read as local edits on the next
  sync until main has them, and init says so. With no `origin/main` it
  records HEAD and warns.

## Where it is taught or enforced

Implemented in [`bin/pap`](../bin/pap) and
[`scripts/release.sh`](../scripts/release.sh); tested by
`tests/pap.test.sh`. Taught in `templates/base/README.md` ("Adopting and
syncing the template"). Adds the enforcement to [`rules.md`](../rules.md)
3.1 that decision 0003 planned. The status lifecycle follows
[0001](0001-process-changes-are-measured-interventions.md).
