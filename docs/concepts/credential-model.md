---
layout: default
title: The credential model
parent: Concepts
nav_order: 2
---

# The credential model - a contained build token

The build token that authenticates to your private feed is made **structurally incapable** of reaching a public source, rather than merely *configured* not to. This is the load-bearing design decision to prevent as much as possible, accidentally sending the wrong credentials to the wrong feed.

## The mechanism

Two templates run in the same job:

1. **`registerModusOpsFeeds`** sets up a per-run [SecretStore](https://learn.microsoft.com/powershell/module/microsoft.powershell.secretstore)
   vault, stores the build token in it, registers the package sources, and **binds each internal feed
   to the token via `CredentialInfo`**:

   ```powershell
   $credInfo = [Microsoft.PowerShell.PSResourceGet.UtilClasses.PSCredentialInfo]::new($vaultName, $secretName)
   Register-PSResourceRepository -Name $feed.name -Uri $repoUrl -Trusted `
       -CredentialProvider None -CredentialInfo $credInfo
   ```

2. **`installModusOpsModules`** installs the modules with **no `-Credential` argument at all**. Each
   feed already knows how to authenticate (its bound `CredentialInfo`); public sources carry no
   binding, so the token cannot travel to them.

The two flags that make this work:

- **`-CredentialInfo`** binds the vault secret to *that feed only*. The token is reachable when
  resolving that feed and nowhere else.
- **`-CredentialProvider None`** disables the auto-engaged Azure Artifacts credential provider, so
  resolution falls through to the per-feed `CredentialInfo` instead of a global, ambient credential.

The result: an install that passes no token can still authenticate to internal feeds, while the token
has no path to a public feed. Public sources (PSGallery) are typically unregistered entirely once the
bootstrap is done; Microsoft Artifact Registry (MAR) is used for trusted Microsoft modules and needs
no token.

## Why "structurally", not "by configuration"

A configuration that *omits* a public feed can be edited to add one back. Here, the token lives in a
vault and is bound to specific feeds; there is no ambient credential for a public resolution to pick
up. Adding a public feed does not grant it the token. The containment is a property of how the
credential is wired, not of a setting someone must remember to keep.

## How it ports across platforms

The pattern is identical on both planes; only the inputs differ:

| | Azure DevOps | GitHub Actions |
| --- | --- | --- |
| Token source | `$(System.AccessToken)` | `GITHUB_TOKEN` or a `read:packages` PAT |
| Feed | Azure Artifacts NuGet v3 | GitHub Packages (`nuget.pkg.github.com/OWNER`) |
| Same-job requirement | steps in one job | a **composite action** (not a reusable workflow) |
| Trusted Microsoft modules | MAR (no token) | MAR (no token) |

The vault + `CredentialInfo` + `-CredentialProvider None` core is unchanged. See
[Templates](../templates/) for how the two planes package these steps.

## Secrets on the runner

Be clear-eyed about this: the vault is a real, file-based store, so while the job runs the build token
is written - encrypted - to the runner's disk for PSResourceGet to read back when resolving a feed. The
token is briefly materialised on the machine; it is not a pure in-memory secret. Two things keep that
acceptable:

- **Teardown.** The install template's `always()` step wipes the SecretStore and unregisters the
  sources, so the material is removed even if an earlier step failed.
- **Ephemerality.** On hosted runners (GitHub-hosted `ubuntu-latest`, Microsoft-hosted agents) the
  whole machine is discarded after the job, so nothing persists regardless of teardown.

> **Self-hosted / non-ephemeral runners.** A self-hosted runner persists between jobs, so the on-disk
> store is only as safe as the teardown that removes it. Prefer **ephemeral** self-hosted runners
> (provisioned per job, destroyed after). If you must run a persistent one, make sure the `always()`
> teardown runs - and treat a runner where it didn't as a potential credential exposure.

## Trusting the modules themselves

- **Code signing is declined for now.** Installing only from a **private feed you control** - plus
  trusted Microsoft modules from **MAR**, which need no token - constrains provenance to sources you
  already trust, which does much of what signing would. The residual risk is accepted, not closed with
  signatures; see [the security-prominent stance](./security-model.md).
