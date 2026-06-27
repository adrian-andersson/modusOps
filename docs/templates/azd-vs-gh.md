---
layout: default
title: Azure DevOps vs GitHub assets
parent: Templates
nav_order: 2
---

# Azure DevOps vs GitHub assets

A template means the same thing on both planes - a reusable, versioned step - but the two platforms
package it differently, so the asset shape differs.

| | Azure DevOps | GitHub Actions |
| --- | --- | --- |
| Template kind | a `template:` include (step list) | a **composite action** |
| Source shape | one file: `templates/azd/<name>.yml` | a directory: `templates/gh/<name>/action.yml` |
| Release asset | `azd.<name>.yml` (single file) | `gh.<name>.zip` (zipped directory) |
| Integrity anchor | file SHA256 | SHA256 of the inner `action.yml` |
| Vendored as | `<name>.yml` | `<name>/action.yml` |

## Asset shapes and integrity anchors

That table is the `pipeline` case. More broadly, the integrity anchor follows the asset *shape*, not
just the platform:

| Shape | Examples | Anchor |
| --- | --- | --- |
| single file | azd template, gh workflow, PR template, one issue form | file SHA256 |
| composite action (dir with `action.yml`) | gh register / install / notify | the inner `action.yml` SHA256 |

The anchor is **always a single file SHA256** - a composite action just anchors on its inner
`action.yml`. Repo furniture that would once have been a multi-file directory (the issue-template set)
is split into one asset per file - e.g. `templatesRepoIssue` and `templatesRepoIssueConfig` - so every
asset stays on the simple lock-vs-file check and a shared dest dir never causes false drift. (The
earlier canonical tree-hash path has been retired.)

GitHub **`repoScaffold`** assets - workflows and PR/issue templates - vendor to a **fixed dest** under
`.github/` rather than a chosen templates dir. See [Repo scaffolding (archetypes)](./repo-scaffolding.md).

## Why GitHub templates are directories

A GitHub composite action is not a loose file - it is a directory whose entry file must be named
`action.yml`. A consumer references it by directory:

```yaml
uses: my-org/modusops-templates/templates/gh/registerModusOpsFeeds@v1
```

So the per-template folder is a GitHub requirement, not a modusOps choice. To ship a directory as a
single release asset it is zipped (`gh.<name>.zip`); `Add-MOTemplate` expands it back into
`<name>/action.yml` on vendor. Everything else - the lockfile, `Test-MOTemplate`, pinning - works the
same as for single-file Azure DevOps templates.

## Composite actions, not reusable workflows

The notification and credential templates are **composite actions** rather than reusable workflows for
a concrete reason: the `registerModusOpsFeeds` -> `installModusOpsModules` pair must share one job so
the per-run credential vault survives between them. A composite action runs inline in the caller's job;
a reusable workflow runs as its own job and would lose the vault. See
[the credential model](../concepts/credential-model.md).

## Self-contained by design

GitHub templates inline everything they need (for example the GitHub Packages folder-casing fix) so a
vendored action carries no runtime module dependency. That keeps each privileged template a single,
reviewable `action.yml`.
