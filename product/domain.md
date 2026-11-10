# Domain: PAP

The words every spec and scenario uses. A term is defined once; a state and an event belong to a term. Added by the spec that first needed it, in the same diff (decision 0017).

## Terms

- **Owner**: the human who owns a repository and its GitHub account or administers its organisation; the only party who runs `pap new`. Ready to create `<name>`: at their own terminal, with a sufficient owner sign-in, a registered agent app with an all-repositories installation on the owner, a plan that gives the repository a main ruleset, and nothing named `<name>` in the current directory or for the owner on GitHub. (spec: pap-new)
- **Owner sign-in**: the owner's own `gh` sign-in, in the owner's gh directory (gh's default one, never the agent's). States: signed out, lacks a scope (`repo` or `workflow`), reports no scopes (a fine-grained token), sufficient. (spec: pap-new)
- **Agent**: a Claude Code session acting on GitHub as the agent app, never as the owner (decision 0023). (spec: pap-new)
- **Agent shell**: a shell in which `gh` and `git` act as the agent. Known by any one of three signals: the session marker Claude Code sets, the agent's gh directory in use, or the agent's `gh` first on the path. (spec: pap-new)
- **Agent app**: the `pap-agent` GitHub App and its key on this machine. States: unregistered, registered. (spec: pap-new)
- **Agent installation**: the agent app installed on an owner. States: none, all-repositories, selected-repositories. It covers a repository or does not. (spec: pap-new)
- **Agent token**: a short-lived token of the agent installation, scoped to one repository. States: not minted, minted. (spec: pap-new)
- **Layer**: a named part of the template: base, dotnet, go, risk. (spec: pap-new)
- **Greenfield repository**: a GitHub repository and its clone that `pap new` made from nothing. It is this command's own when the first commit on `main` is the first commit as defined below, and the clone's first commit, where a clone exists, is the same commit; later commits on `main` do not change that. States, in order: absent, committed (the first commit exists in the clone only), created (the repository exists on GitHub, empty), pushed, set up, settings applied, welcomed. (spec: pap-new)
- **Recorded**: written in the repository's `.config/pap.toml`: the applied template version and the layers (INV-011). (spec: pap-new)
- **Run**: one invocation of `pap new` for one name and owner. States: in preflight, creating, stopped (at a named step), complete. (spec: pap-new)
- **Step**: one of the six parts of creation, in order: first commit, repository creation, first push, clone setup, repository settings, agent token. The first three are made once and never again; the last three are convergent, checked on every run and redone only where they are not as they should be. (spec: pap-new)
- **Preflight**: the checks a run makes before it creates anything: the name, the owner, the layers and the visibility, the shell and its terminal, the owner sign-in, the agent app and the agent installation, what the owner's plan and organisation allow, and what already exists of that name. It ends with the summary. (spec: pap-new)
- **Summary**: what preflight shows last and the owner confirms: the login acted as, the owner and name, the visibility, the layers, and the author name and email of the first commit. (spec: pap-new)
- **Prompted step**: something the run asks the owner to do and waits for or names in advance: the sign-in, a scope refresh, confirming the summary, adding a repository to the agent installation, a setting only the owner can change. Not a hand-run step. (spec: pap-new)
- **First commit**: the one commit that starts `main`: the template at the recorded version and layers, and a README whose only line is `# <name>`. The README belongs to no layer. (spec: pap-new)
- **Clone setup**: installing the pinned tools and the git hooks in a clone. It writes no tracked file. (spec: pap-new)
- **Clean**: of a working tree, no change to a tracked file and no untracked file that is not ignored; of `pap doctor` and `pap repo status`, exit 0 with no item `missing` or `drift`. (spec: pap-new)
- **Repository settings**: the GitHub side that `pap repo apply` writes: settings, the main ruleset, labels. States: not applied, applied. (spec: pap-new)
- **Main ruleset**: the ruleset on `main` in the repository settings. A bypass actor is anyone it lets past. (spec: pap-new)
- **Welcome session**: the agent session a run starts last, in the clone. It is given what the run did, where the owner is and what is installed, and is told to ask what the owner wants and start nothing. (spec: pap-new)
- **Installed**: of a skill, mod or agent, present for Claude Code on this machine from a plugin of pap's marketplace. (spec: pap-new)
- **Install prompt**: the one-line prompt in pap's docs that has Claude install pap at an exact version. (spec: pap-new)
- **Release**: a tagged version of pap, cut by `scripts/release.sh`. (spec: pap-new)

## Events

- **The owner runs pap new**: starts a run, in preflight. (spec: pap-new)
- **The owner confirms the summary**: moves the run from in preflight to creating. Declining it stops the run. (spec: pap-new)
- **The first commit is made**: moves the greenfield repository from absent to committed. It appears whole or not at all. (spec: pap-new)
- **The repository is created**: moves it from committed to created. (spec: pap-new)
- **First push**: the first commit is pushed to `main`, moving the greenfield repository from created to pushed. The one direct push to `main` in its history. (spec: pap-new)
- **The clone is set up**: moves it from pushed to set up. (spec: pap-new)
- **The repository settings are applied**: moves the greenfield repository from set up to settings applied; the main ruleset exists from here. (spec: pap-new)
- **An agent token is requested**: the run asks the agent installation for a token for the repository. (spec: pap-new)
- **An agent token is minted**: moves the agent token from not minted to minted. (spec: pap-new)
- **The welcome session starts**: moves the greenfield repository to welcomed and the run to complete. (spec: pap-new)
- **The run stops**: moves the run to stopped at a named step; nothing is undone. (spec: pap-new)
- **A release is cut**: `scripts/release.sh <version>` is run; it creates the release or refuses. (spec: pap-new)

## Rules

- Nothing is created, in the current directory or on GitHub, while a run is in preflight. (spec: pap-new)
- A run from an agent shell is refused before any sign-in is offered. (spec: pap-new)
- The first push comes before clone setup and before the repository settings are applied, so it meets no hook and no ruleset. If it meets a hook it stops; it never skips one. (spec: pap-new)
- A run never deletes a repository, never pushes to `main` twice and never makes a second first commit. (spec: pap-new)
- An agent token is requested only when the main ruleset exists with no bypass actor. (spec: pap-new)
- A welcome session starts only with a minted agent token, and never as the owner. (spec: pap-new)
- On a re-run the recorded version and layers, and the repository's own visibility and owner, stand; other values are refused. (spec: pap-new)
- A release is cut only when the install prompt names its version. (spec: pap-new)
