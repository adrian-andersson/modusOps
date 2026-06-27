---
layout: default
title: Repo scaffolding (archetypes)
parent: Templates
nav_order: 4
---

# Repo scaffolding - archetypes

Where `Add-MOTemplate` vendors *one* asset, **`Add-MORepoScaffold`** stamps a whole **set** of them in
one call - the CI workflows, PR/issue templates, and (on Azure DevOps) the REST-side wiring a repo
needs. Same vendor-at-fetch, lockfile, and drift machinery; one verb.

## Two categories

Every library asset has a `category` that decides *how* it is consumed:

| Category | Consumed as | Vendored to |
| --- | --- | --- |
| `pipeline` | a building block composed *into* a pipeline (register / install / notify) | a templates dir you choose (`-Path`) |
| `repoScaffold` | repo *furniture* stamped *into* a repo (CI workflows, PR/issue templates) | a **fixed dest** under `.github/` |

## Platform defaulting - set it once

Pass `-Platform` once, or run `Set-MOPlatform`, and the choice is seeded into `.modusops.lock` under
`defaults.platform`. Every later command resolves it from there (or auto-detects `.github/` vs
`azure-pipelines.yml`), so you stop re-typing it and the catalog shows only what is relevant.

```powershell
Set-MOPlatform gh          # writes defaults.platform into the lockfile
Get-MOPlatform             # -> gh  (Source: lockfile)
Find-MOTemplate            # already scoped to gh; pass -AllPlatforms to widen
```

Resolution order: explicit `-Platform` > lockfile default > repo-shape detection > a directive error.
The first `Add` also seeds the default from whatever it resolved, so you rarely set it by hand.

## Sets - curated archetypes and derived selectors

A **set** is a named bundle declared in `manifest.json`, applied with `Add-MORepoScaffold`. Two shapes:

| Shape | Membership | Good for |
| --- | --- | --- |
| `archetype` (curated) | an explicit, ordered, tested-together list of steps | a coherent repo shape (e.g. a whole template-library repo) |
| `selector` (derived) | a query over `category`/`kind`, evaluated against that manifest version | "all the workflow furniture" - auto-includes new matching templates |

A selector is **late-bound but deterministic**: it resolves against the *pinned* manifest version, and
each released manifest is immutable, so `someSet@v3` always expands the same way.

```powershell
Find-MOArchetype                                      # list the sets + member counts
Add-MORepoScaffold -Archetype templateLibrary         # vendor every member, lock-pinned under the archetype
Add-MORepoScaffold -Archetype templateLibrary -Include workflow   # just the workflow members
```

Each vendored member is pinned in the lockfile exactly as `Add-MOTemplate` would, plus an `archetype`
+ `archetypeVersion` tag so `Test`/`Update` can reason about the set as a whole. Re-running at a newer
`-Version` re-applies the set (overwriting changed members) - that is also the update path.

## End-to-end: standing up a new repo (tested flow)

The ordering below is deliberate: the CI furniture goes onto `main` **first**, so that the *next* PR is
actually gated by PR-validation and merging it triggers the release workflow. Doing it the other way
round means the automation isn't on the default branch yet and the first PR sails through ungated.

1. **Create the repo with a README.** Initialising with a README gives you a real `main` branch up
   front and avoids the empty-repo / default-branch oddities you hit pushing into a bare repo.
2. **Clone it, then stamp the library furniture:**

   ```powershell
   Set-MOPlatform gh
   Add-MORepoScaffold -Archetype templateLibrary   # PR-validation + release workflows, PR/issue templates
   ```

3. **Commit and push to `main`.** Now the PR-gate and release workflows live on the default branch.
4. **Create a branch** for the actual change.
5. **Vendor the load-bearing pipeline pair on the branch:**

   ```powershell
   Add-MORepoScaffold -Archetype pipelineCore      # registerModusOpsFeeds + installModusOpsModules
   ```

6. **Add a notification template** if you want run feedback - the Discord one is the simplest to wire
   (just a channel webhook):

   ```powershell
   Add-MOTemplate -Name sendDiscordChannelMessage
   # or fold it into one call: Add-MOTemplate -Name registerModusOpsFeeds,installModusOpsModules,sendDiscordChannelMessage
   ```

7. **Open a PR.** PR-validation runs as the gate; merging it triggers the release workflow, which cuts
   the next rolling-integer tag (`vN`). Review the vendored (privileged) assets in that PR diff - this is
   where the human check happens.
8. **Authorise the consumer.** Make sure the repo is configured to be read by the pipeline/consumer repo
   that references it: on GitHub, **Settings -> Actions -> General -> Access** (allow the consumer), which
   is what lets a cross-repo `OWNER/repo/...@vN` ref resolve; on Azure DevOps the analog is resource
   authorization on the pipeline.

## Provision steps - files *and* REST (Azure DevOps)

On GitHub, repo governance *is* files in `.github/`. On Azure DevOps it is REST calls (branch policy,
repo permissions). So an archetype step is either:

- **`file`** - vendor an asset (any platform), or
- **`provision`** - run a modusOps provisioning cmdlet (Azure DevOps), its args bound from the caller's
  `-With` placeholders plus shared context (`-OrganizationUri` / `-ProjectName` / token).

```powershell
Add-MORepoScaffold -Archetype azdOpsRepo `
  -OrganizationUri https://dev.azure.com/contoso -ProjectName modusOps `
  -With @{ repo = 'modusOps'; buildId = 42 }
```

```text
Archetype 'azdOpsRepo' (azd) -> 4 steps
  file       registerModusOpsFeeds                  -> templates/registerModusOpsFeeds.yml   Vendored
  file       installModusOpsModules                 -> templates/installModusOpsModules.yml  Vendored
  provision  Add-MOAzureDevOpsModusBuildValidation  (RepositoryName=modusOps, BuildDefinitionId=42)   Applied
  provision  Set-MOAzureDevOpsModusRepoPermission   (RepositoryName=modusOps)                         Applied
```

This unifies the template library and the existing `*-MOAzureDevOpsModus*` scaffold cmdlets under one
verb: an archetype is "a list of steps, each *vendor a file* or *call a provisioning cmdlet*."

### Guardrails

- **Allow-list.** A `provision` step may name only a fixed set of modusOps `*-MOAzureDevOpsModus*`
  cmdlets - a vendored manifest can never invoke an arbitrary command.
- **Binding.** A whole-value `{placeholder}` preserves type (an int stays an int, e.g.
  `BuildDefinitionId`); shared context is threaded only into cmdlets that declare it; a missing
  placeholder throws before anything runs.
- **`-WhatIf`** previews the whole plan - "would vendor X / would call Y" - and writes nothing.
- **Lockfile.** A provision step records a marker (cmdlet + archetype + version, no SHA). It is a REST
  action, not a file, so `Test-MOTemplate` skips it.

## The verbs

| Verb | Does |
| --- | --- |
| `Set-MOPlatform` / `Get-MOPlatform` | Set / read the default platform so commands stop re-taking `-Platform`. |
| `Find-MOArchetype` | List the sets (archetypes) available in a release. |
| `Add-MORepoScaffold` | Apply a set - vendor file members, run allow-listed provision steps; each lock-pinned. |
