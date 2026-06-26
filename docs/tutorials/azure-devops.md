---
layout: default
title: Azure DevOps
parent: Tutorials
nav_order: 1
---

# Azure DevOps walkthrough

This sets up a modusOps environment in an Azure DevOps organisation end-to-end: project, repos, feed,
vendored templates, and the pipelines that run them.

## Prerequisites

- An Azure DevOps organisation (modern `https://dev.azure.com/{org}` form).
- Permission to create a project, repository, and Artifacts feed in it.

Every step below can be done **by hand in the portal** with no Personal Access Token. modusOps also
automates the setup with cmdlets; that path needs a PAT, given as the second option in each step.

## 1. Create the project, repo, and feed

### Manual (portal)

1. Create a **project**.
2. Create a **repository** in it for your operation.
3. Create an **Azure Artifacts feed** for the modules, and add the project **Build Service** as a
   reader on it.

### Automated (requires a PAT)

`New-MOAzureDevOpsModusEnvironment` does all three idempotently (get-or-create). The PAT needs:

| Scope | Access |
| --- | --- |
| Project and Team | Read, write & manage |
| Code | Read, write & manage |
| Packaging | Read, write & manage |
| Identity | Read |

```powershell
$pat = Get-Credential -UserName 'pat' -Message 'Azure DevOps PAT'   # the PAT is the password
New-MOAzureDevOpsModusEnvironment -OrganizationUri 'https://dev.azure.com/myorg' -Credential $pat -Verbose
```

The remaining cmdlet-driven steps reuse this `$pat`. Each can also be done in the portal if you prefer
to stay fully manual.

## 2. Vendor the templates

Vendor the two default templates into a staging tree, pinned in `.modusops.lock`:

```powershell
Add-MOTemplate -Name registerModusOpsFeeds  -Platform azd -Version v0.1.1 -Path ./staging/templates
Add-MOTemplate -Name installModusOpsModules -Platform azd -Version v0.1.1 -Path ./staging/templates
Test-MOTemplate -ProjectPath ./staging
```

## 3. Seed the operations repo

Stage your starter pipeline alongside the vendored templates, then push the folder as the repo's first
commit:

```powershell
Push-MOAzureDevOpsModusContent -OrganizationUri 'https://dev.azure.com/myorg' -Credential $pat `
    -RepositoryName modusOps -SourcePath ./staging -Verbose
```

## 4. Create the pipelines

```powershell
New-MOAzureDevOpsModusPipeline -OrganizationUri 'https://dev.azure.com/myorg' -Credential $pat `
    -RepositoryName modusOps -Name 'modusOps Example' -YamlPath '/example.yml'
```

## 5. Wire policies and permissions

```powershell
# Make a pipeline a required PR check
Add-MOAzureDevOpsModusBuildValidation -OrganizationUri 'https://dev.azure.com/myorg' -Credential $pat `
    -RepositoryName modusOps -BuildDefinitionId <id> -DisplayName 'PR Validation'

# Let the build service push tags and post PR comments
Set-MOAzureDevOpsModusRepoPermission -OrganizationUri 'https://dev.azure.com/myorg' -Credential $pat `
    -RepositoryName modusOps

# Authorize a pipeline to use a referenced repo resource (if any)
Add-MOAzureDevOpsModusResourceAuthorization -OrganizationUri 'https://dev.azure.com/myorg' -Credential $pat `
    -RepositoryName modusOpsTemplates -PipelineId <id>
```

## Manual grants to confirm

A few permissions are surfaced as terminal warnings rather than set silently - confirm them in the
portal:

- **Artifacts -> Feed -> Settings:** add the project **Build Service** as a **Feed Publisher** (if your
  pipelines publish modules).
- **Project Settings -> Repositories -> Security:** the **Build Service** has Contribute, Contribute to
  PRs, Create Tag, and Read (`Set-MOAzureDevOpsModusRepoPermission` covers the first two).

From here, a run uses the [credential model](../concepts/credential-model.md) to install version-pinned
modules with a contained token.
