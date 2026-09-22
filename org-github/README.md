# blairforce1/.github

Default community health files for every repository owned by blairforce1.
Authored in [blairforce1/pap](https://github.com/blairforce1/pap) under
`org-github/`, which mirrors this repository's layout. Edit there and push
here.

## Inheritance

A repository owned by this account that has no file of a given type uses
the one here. The file does not appear in that repository's file browser,
history, clones, or downloads. A repository with its own file of the type
keeps its own; a repository with its own issue templates shows only its
own. Lookup order, both in a repository and in here, is `.github/`, then
the root, then `docs/`.

This repository must be public. The defaults then apply to every repository
owned by the account regardless of that repository's visibility, so private
repositories on a Pro personal account inherit them. GitHub's documentation
makes no distinction by plan, or between organisations and personal
accounts.

### Inherited from here

| File | Where it must live in this repository | Provided |
|---|---|---|
| `PULL_REQUEST_TEMPLATE.md` | root, `.github/`, or `docs/` | yes, root |
| Issue forms and `config.yml` | `.github/ISSUE_TEMPLATE/` only | yes |
| `SECURITY.md` | root, `.github/`, or `docs/` | yes, root |
| `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, `SUPPORT.md` | root, `.github/`, or `docs/` | no |
| `FUNDING.yml` | `.github/` | no |
| Discussion category forms | `.github/DISCUSSION_TEMPLATE/` | no |

### Not inherited

- `CODEOWNERS`: read only from the repository being changed, from its
  `.github/`, root, or `docs/`. Each repository needs its own.
- `LICENSE`: GitHub refuses a default so that clones and downloads carry
  the licence.
- `README.md`: this file describes this repository only. The account
  profile README lives in `blairforce1/blairforce1`.
- Workflows, `dependabot.yml`, labels, rulesets, branch protection: all per
  repository. Starter workflows in `workflow-templates/` are an organisation
  feature and do not apply to a personal account.

## Verifying inheritance

Pick a private repository with no templates of its own, for example
`blairforce1/journal`. Before this repository exists the calls below return
nothing; once it is pushed they name the inherited files.

GraphQL reports both kinds of template:

```sh
gh api graphql -f query='query{repository(owner:"blairforce1",name:"journal"){issueTemplates{name filename} pullRequestTemplates{filename}}}'
```

Expected: `issueTemplates` lists Intent and Escape and
`pullRequestTemplates` lists `PULL_REQUEST_TEMPLATE.md`.

The REST community profile answers on private repositories, but for
inherited files it reports only the pull request template. Its
`issue_template` field stays null for inherited templates, as observed on
supabase and jenkinsci repositories on 2026-09-22.

```sh
gh api repos/blairforce1/journal/community/profile --jq '.files | {issue_template, pull_request_template}'
```

Expected: `pull_request_template.html_url` under
`github.com/blairforce1/.github/`.

In the browser, `https://github.com/blairforce1/journal/issues/new/choose`
lists Intent and Escape. Blank issue appears only to users with write
access, marked "Maintainers only".

## Validating the issue forms

GitHub publishes no JSON schema for issue forms. SchemaStore's schema
encodes the documented rules and check-jsonschema vendors it:

```sh
uvx check-jsonschema --builtin-schema vendor.github-issue-forms .github/ISSUE_TEMPLATE/intent.yml .github/ISSUE_TEMPLATE/escape.yml
uvx check-jsonschema --builtin-schema vendor.github-issue-config .github/ISSUE_TEMPLATE/config.yml
```

GitHub's own parser runs only once the files are on GitHub. An invalid form
shows an error banner on this repository's issue chooser.
