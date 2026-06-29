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

## A worked example: a SharePoint data round-trip

Beyond the two load-bearing templates, the library has step templates for connecting to Microsoft
Graph and moving SharePoint files - enough to build a real pipeline. Vendor them alongside the others:

```powershell
Add-MOTemplate -Name connectMicrosoftGraph -Platform azd -Path ./staging/templates
Add-MOTemplate -Name getSharePointFile     -Platform azd -Path ./staging/templates
Add-MOTemplate -Name setSharePointFile     -Platform azd -Path ./staging/templates
```

A thin operation that downloads a workbook, runs a module against it, and writes it back -
`example.yml` in your operations repo:

```yaml
trigger: none
pool: { vmImage: 'ubuntu-latest' }
variables:
  - group: modusOps          # supplies clientId, tenantId, and the secret variable 'clientSecret'
jobs:
  - job: run
    variables:
      SYSTEM_ACCESSTOKEN: $(System.AccessToken)
    steps:
      - template: templates/registerModusOpsFeeds.yml
        parameters:
          feeds: [ { name: 'modusops' } ]
      - template: templates/installModusOpsModules.yml
        parameters:
          modules:                              # public modules resolve from MAR (or an allowed PSGallery)
            - { name: 'Microsoft.Graph.Authentication', repository: 'MAR' }
            - { name: 'YourBusinessModule', repository: 'modusops', version: '1.0.0' }
      - template: templates/connectMicrosoftGraph.yml
        parameters:
          clientId: $(clientId)
          tenantId: $(tenantId)               # clientSecretVariable defaults to 'clientSecret'
      - template: templates/getSharePointFile.yml
        parameters:
          sharePointSite: 'MySite'
          sharePointFile: 'Reports/workbook.xlsx'
          localFile: '$(Pipeline.Workspace)/workbook.xlsx'
      - pwsh: |
          Import-Module YourBusinessModule
          # ... transform $(Pipeline.Workspace)/workbook.xlsx ...
        displayName: 'Run business logic'
      - template: templates/setSharePointFile.yml
        parameters:
          sharePointSite: 'MySite'
          sharePointFile: 'Reports/workbook.xlsx'
          localFile: '$(Pipeline.Workspace)/workbook.xlsx'
```

> **Connect once per job.** `connectMicrosoftGraph` establishes the Graph connection; the
> `get`/`setSharePointFile` steps carry **no credentials** and inherit it (they fail with a directive
> error if no connection is found). The connection persists across **steps within a job** - the agent is
> shared - but **not across jobs**, which is the same boundary the register/install vault relies on. So
> keep connect + the SharePoint steps in one job; a separate notification job is cleanly isolated and
> would re-connect if it needed Graph.
