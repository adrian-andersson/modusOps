---
layout: default
title: Getting Started
nav_order: 2
---

# Getting Started with modusOps

modusOps keeps pipelines thin: they declare what to run and which version, while the logic lives in
version-pinned modules and templates pulled at runtime. This page gets you from nothing to a test
pipeline in three parts. **None of it requires a Personal Access Token** unless you choose to automate
the Azure DevOps setup - the PAT is an optional convenience, covered at the end.

---

## Prerequisites

| Requirement | Minimum |
| --- | --- |
| PowerShell | 7.2+ |
| Microsoft.PowerShell.PSResourceGet | 1.1+ |
| Git | Any recent version |

```powershell
Install-Module Microsoft.PowerShell.PSResourceGet -Force   # if you don't have it
Install-PSResource -Name modusOps
```

---

## Part 1 - Get some repositories

modusOps recommends **two repositories** plus a private feed:

- an **operations repo** - your pipelines, and
- a **templates repo** - the local, vendored copies of templates (Part 2 fills this in).

> You *can* keep both in a single repo, but it is **not the recommended approach** - splitting them
> keeps the operations repo thin and lets the privileged templates be reviewed and versioned on their
> own cadence.

Set them up by hand first - a few clicks, no PAT.

### GitHub

1. Create the **operations** and **templates** repositories (an Org is recommended).
2. The private feed is **GitHub Packages**, which exists per-owner automatically - publish your
   module(s) to it. Reads use the workflow `GITHUB_TOKEN` (or a `read:packages` PAT for cross-owner).

### Azure DevOps

1. Create a **project**.
2. Create the **operations** and **templates** repositories in it.
3. Create an **Azure Artifacts feed** for the modules.

> **Optional - automate the Azure DevOps setup.** `New-MOAzureDevOpsModusEnvironment` does all three
> idempotently. It needs a PAT (see [Using a PAT](#optional---using-a-personal-access-token) below).
> There is no GitHub equivalent scaffold yet; on GitHub, Part 1 is the manual steps above.

---

## Part 2 - Get some templates

Templates are the versioned steps your pipeline runs. Run these in your **templates repo**:
`Add-MOTemplate` vendors them from the public
[`modusops-templates`](https://github.com/adrian-andersson/modusops-templates) library into local files
and pins each in `.modusops.lock`. **No PAT required.**

```powershell
Set-MOPlatform gh                              # set the default once; seeded into .modusops.lock

# the credential + install pair, plus one notification template (platform now inferred)
Add-MOTemplate -Name registerModusOpsFeeds     -Version v1
Add-MOTemplate -Name installModusOpsModules    -Version v1
Add-MOTemplate -Name sendDiscordChannelMessage -Version v1   # or sendTeamsChannelMessage
Test-MOTemplate
```

Want the repo's CI furniture too - PR-validation + release workflows, PR/issue templates? Stamp the
whole **set** in one call:

```powershell
Add-MORepoScaffold -Archetype templateLibrary  # vendors every member, lock-pinned
```

(`Set-MOPlatform azd` for Azure DevOps; library versions are rolling integers, `vN`.) The starter
templates are a **convenience, not a requirement** - author your own whenever the provided ones don't
fit. See [Templates](./templates/), [Repo scaffolding](./templates/repo-scaffolding.md), and
[Authoring templates](./templates/authoring.md).

---

## Part 3 - Write a pipeline to test

A minimal operation that registers the feed, installs a module with a contained token, runs a step, and
notifies on the result. This lives in your **operations repo** and references the composite actions in
your **templates repo** by pinned tag (`@v1`, cut by the templates repo). Pick **one** notification for
now - Discord or Teams. GitHub example:

```yaml
on: workflow_dispatch
permissions: { contents: read, packages: read }
jobs:
  run:
    runs-on: ubuntu-latest
    steps:
      - uses: my-org/ops-templates/templates/registerModusOpsFeeds@v1   # your templates repo, pinned
        with:
          feeds: '[ { "name": "modusops", "uri": "https://nuget.pkg.github.com/${{ github.repository_owner }}/index.json" } ]'
          token: ${{ secrets.GITHUB_TOKEN }}
      - uses: my-org/ops-templates/templates/installModusOpsModules@v1
        with:
          modules: '[ { "name": "ModusOps.Toolkit", "repository": "modusops", "version": "1.0.1-prev001" } ]'
      - shell: pwsh
        run: Get-MOHelloWorld                            # your operation's step
  notify:
    needs: run
    if: ${{ always() }}
    runs-on: ubuntu-latest
    steps:
      # --- Discord ---
      - uses: my-org/ops-templates/templates/sendDiscordChannelMessage@v1
        with:
          webhookUri: ${{ secrets.DISCORD_WEBHOOK }}
          type: ${{ needs.run.result == 'success' && 'Success' || 'Failure' }}
          title: 'modusOps test'
          message: 'Run ${{ needs.run.result }}'
      # --- Teams (use instead of Discord) ---
      # - uses: my-org/ops-templates/templates/sendTeamsChannelMessage@v1
      #   with:
      #     webhookUri: ${{ secrets.TEAMS_WEBHOOK }}
      #     type: ${{ needs.run.result == 'success' && 'Success' || 'Failure' }}
      #     title: 'modusOps test'
      #     message: 'Run ${{ needs.run.result }}'
```

The full Azure DevOps and GitHub walkthroughs - including the permission grants - are in
[Tutorials](./tutorials/).

---

## Optional - Using a Personal Access Token

You only need a PAT to run the **Azure DevOps scaffold cmdlets** (Part 1's optional automation).
Manual setup and every template command (`Find`/`Add`/`Update`/`Test`/`Get-MOTemplate`) need no PAT.

When you do automate Azure DevOps, create a PAT with these scopes:

| Scope | Access |
| --- | --- |
| Project and Team | Read, write & manage |
| Code | Read, write & manage |
| Packaging | Read, write & manage |
| Identity | Read |

Pass it as a `PSCredential` - the PAT is the password, the username is ignored:

```powershell
$pat = Get-Credential -UserName 'pat' -Message 'Azure DevOps PAT'
New-MOAzureDevOpsModusEnvironment -OrganizationUri 'https://dev.azure.com/myorg' -Credential $pat -Verbose
```

---

## Next steps

| Goal | Where to go |
| --- | --- |
| Understand the design and credential model | [Concepts](./concepts/) |
| How templates are versioned, vendored, and pinned | [Templates](./templates/) |
| End-to-end Azure DevOps / GitHub setup | [Tutorials](./tutorials/) |
| Full cmdlet reference | [Functions](./functions/) |
