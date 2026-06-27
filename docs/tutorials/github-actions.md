---
layout: default
title: GitHub Actions
parent: Tutorials
nav_order: 2
---

# GitHub Actions walkthrough

The same model on GitHub: a thin workflow calls versioned **composite actions** that register a
private GitHub Packages feed with a contained token and install version-pinned modules. A GitHub Org is
recommended.

## Prerequisites

- A repository for your operation (the consumer), and the templates available from
  [`modusops-templates`](https://github.com/adrian-andersson/modusops-templates) (public, or your
  internal mirror).
- A private module published to **GitHub Packages** for the owner.
- For same-owner reads the workflow `GITHUB_TOKEN` with `packages: read` is enough; for cross-owner or
  private reads, a `read:packages` PAT.

## 1. Set the platform default

Tell the tooling you're on GitHub once, so you stop passing `-Platform gh` to every command and the
catalog only shows gh assets. It's written into `.modusops.lock` under `defaults.platform`:

```powershell
Set-MOPlatform gh          # seed the default
Get-MOPlatform             # -> gh  (Source: lockfile)
```

(The first `Add` would auto-seed it too, from whatever it resolved — this just makes it explicit.)

## 2. Vendor the templates (optional)

You can reference the composite actions cross-repo by pinned ref, or vendor them into your repo:

```powershell
Add-MOTemplate -Name registerModusOpsFeeds  -Version v1
Add-MOTemplate -Name installModusOpsModules -Version v1
Test-MOTemplate
```

Vendoring lands each as `templates/<name>/action.yml`, pinned in `.modusops.lock`. `-Platform` is no
longer needed — it resolves from the default you set above.

## 3. Scaffold repo furniture in one call (archetypes)

`Add-MOTemplate` vendors *one* asset. To stamp a whole **set** of repo furniture — the CI workflows
and PR/issue templates a repo needs — use **`Add-MORepoScaffold`** with an *archetype*. Same
vendor-at-fetch + lockfile + drift machinery, one verb:

```powershell
Find-MOArchetype                                # list the sets + member counts
Add-MORepoScaffold -Archetype templateLibrary   # vendor every member, lock-pinned under the archetype
```

The shipped `templateLibrary` archetype furnishes a **templates-library repo** (PR-validation +
rolling-integer release workflows, PR/issue templates). For a plain *operation* repo you typically just
vendor the pipeline composite actions above and write your own workflow; when you have a repeatable repo
shape of your own, author an archetype for it. On Azure DevOps an archetype step can also run an
allow-listed provisioning cmdlet (branch policy, repo permissions) — see
[Repo scaffolding (archetypes)](../templates/repo-scaffolding.md) for the full model and guardrails.

## 4. The consumer workflow

```yaml
on: workflow_dispatch
permissions: { contents: read, packages: read }
jobs:
  run:
    runs-on: ubuntu-latest
    steps:
      - uses: my-org/modusops-templates/templates/gh/registerModusOpsFeeds@v1   # composite => same-job vault
        with:
          feeds: '[ { "name": "modusops", "uri": "https://nuget.pkg.github.com/${{ github.repository_owner }}/index.json" } ]'
          token: ${{ secrets.GITHUB_TOKEN }}
      - uses: my-org/modusops-templates/templates/gh/installModusOpsModules@v1
        with:
          modules: '[ { "name": "Az.Accounts", "repository": "MAR" }, { "name": "ModusOps.Toolkit", "repository": "modusops", "version": "1.0.1-prev001" } ]'
      - shell: pwsh
        run: Get-PSResourceRepository; Get-MOHelloWorld   # your operation's steps
```

The two actions are **composite** so they share one job and the credential vault survives between them.
Object inputs (`feeds`, `modules`) are passed as JSON strings - keep them single-quoted.

## 5. Allow the consumer to use private actions

If `modusops-templates` (or your mirror) is private, allow the consumer in **Settings -> Actions ->
General -> Access**. This is the GitHub analog of Azure DevOps resource authorization.

## 6. Pin by an immutable ref

Reference composite actions by a single-integer tag (`@v1`), which the templates repo's release
workflow cuts as an immutable ref. Bumping to `@v2` is a deliberate, reviewable change - the same "promote a
version" discipline as everywhere else in modusOps.

## Notes carried over from the proof of concept

- Never put `${{ secrets.* }}` in an action manifest - GitHub evaluates it even in `description:`/`run:`
  text. Pass tokens via an `input`.
- A module installed from GitHub Packages can land in a folder whose casing differs from its manifest;
  the install action inlines the fix so it stays discoverable on Linux runners.
- Cross-*owner* private feeds need a `read:packages` PAT, not `GITHUB_TOKEN`.
