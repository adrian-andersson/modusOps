# modusOps

[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/modusOps?label=PSGallery)](https://www.powershellgallery.com/packages/modusOps)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Docs](https://img.shields.io/badge/docs-modusOps-blue)](https://adrian-andersson.github.io/modusOps)
[![Built with ModuleForge](https://img.shields.io/badge/built%20with-ModuleForge-7952B3)](https://adrian-andersson.github.io/ModuleForge)

Versioned, **security-prominent** pipeline automation for **Azure DevOps** and **GitHub Actions**.

Pipelines stay *thin*: they declare *what* to run and *which version* - the real logic lives in
version-pinned PowerShell modules and templates, pulled at runtime. Behaviour changes by **promoting a
version, not by editing YAML**. The build token is bound per-feed so it is *structurally* incapable
of reaching a public source, which makes the supply chain auditable rather than implicit.

## The bet

- **Thin operations.** A pipeline orchestrates; it carries no inline REST, parsing, or duplicated
  auth. Those live in versioned modules pulled from a private feed at runtime.
- **Version-pinned everything.** Modules are SemVer'd; the template library is a rolling-integer (N+)
  set. A new behaviour is a new version, promoted deliberately - not an edit to live YAML.
- **Contained credentials.** The build token is stored in a per-run SecretStore vault and bound to
  each internal feed via `CredentialInfo` + `-CredentialProvider None`, so it cannot reach a public
  feed. (See the [credential model](https://adrian-andersson.github.io/modusOps/concepts/).)
- **Vendored, reviewed templates.** Templates come from the public
  [`modusops-templates`](https://github.com/adrian-andersson/modusops-templates) library, vendored
  into your repo and pinned by version + SHA256 in `.modusops.lock` - nothing is fetched at pipeline
  runtime, and the source is configurable to an internal mirror.

## Install

```powershell
Install-Module Microsoft.PowerShell.PSResourceGet -Force   # if you don't have it
Install-PSResource -Name modusOps
```

> modusOps targets the PowerShell Gallery. Until the first public release lands there, install from a
> GitHub release or a local build.

## Command surface

**Scaffold (Azure DevOps)** - stand up and wire a consumer environment:

| Cmdlet | Does |
| --- | --- |
| `New-MOAzureDevOpsModusEnvironment` | Provision the project, repos, feed, and pipelines. |
| `New-MOAzureDevOpsModusPipeline` | Create/locate a pipeline from a YAML path. |
| `Push-MOAzureDevOpsModusContent` | Push vendored content into the operations repo. |
| `Add-MOAzureDevOpsModusBuildValidation` | Add a build-validation branch policy. |
| `Add-MOAzureDevOpsModusResourceAuthorization` | Authorize a pipeline against a resource. |
| `Set-MOAzureDevOpsModusRepoPermission` | Grant the build service the repo permissions it needs. |

**Templates & scaffolding** - the npm-style surface over `modusops-templates`:

| Cmdlet | Does |
| --- | --- |
| `Set-MOPlatform` / `Get-MOPlatform` | Set / read the default platform (azd\|gh) so you stop re-passing `-Platform`. |
| `Find-MOTemplate` | Discover templates in the library (scoped to your platform; `-AllPlatforms` to widen). |
| `Add-MOTemplate` | Vendor one pinned asset to its dest + record it in `.modusops.lock`. |
| `Find-MOArchetype` | Discover the **sets** (archetypes) — curated bundles or derived selectors. |
| `Add-MORepoScaffold` | Stamp a whole set in one call — vendor file members and, on azd, run allow-listed provisioning steps; each lock-pinned. |
| `Update-MOTemplate` | Re-pull at a newer version, rewriting only what changed. |
| `Test-MOTemplate` | Offline integrity check of vendored files against the lockfile (file SHA or tree hash). |
| `Get-MOTemplate` | List installed templates + their archetype (reads the lockfile). |

> **Platform defaulting.** Pass `-Platform` once (or `Set-MOPlatform gh`) and it's seeded into
> `.modusops.lock`; every later command resolves it from there (or auto-detects `.github/` vs
> `azure-pipelines.yml`), so the catalog and vendoring only deal with what's relevant.

**Archetypes** are named bundles in the library — a curated list, or a derived selector over
`category`/`kind`. A step either *vendors a file* or, on azd, *runs a provisioning cmdlet* (branch
policy, repo permission) bound from `-With` + context. Provisioning is gated by a fixed **allow-list**,
so a vendored manifest can never invoke an arbitrary command.

## Quick start

> **Two repositories, recommended.** modusOps keeps *orchestration* and *reusable steps* apart:
>
> - an **operations repo** - your pipelines (what runs, and which versions), and
> - a **templates repo** - the local, vendored copies of templates (pinned in `.modusops.lock`), library plus your own.
>
> Operations reference the templates; the actual logic resolves from a **private feed** as
> version-pinned modules. That separation of concerns is what lets you change behaviour by promoting a
> version instead of editing a pipeline.
>
> You *can* keep both in a single repo, but it is **not the recommended approach** - splitting them
> keeps the operations repo thin and lets the privileged templates be reviewed and versioned on their
> own cadence.

```powershell
# In your TEMPLATES repo: set the platform default once, then vendor pinned assets into .modusops.lock
Set-MOPlatform gh                                 # seeded into .modusops.lock; later commands inherit it
Find-MOTemplate                                   # browse the library (scoped to gh)
Add-MOTemplate -Name registerModusOpsFeeds        # one asset (platform inferred, latest pinned explicitly)

# Stamp whole-repo furniture (CI workflows + PR/issue templates) in one call:
Find-MOArchetype                                  # templateLibrary (curated) · workflowSet (selector)
Add-MORepoScaffold -Archetype templateLibrary     # vendors every member, lock-pinned under the archetype
Test-MOTemplate                                   # offline integrity check of everything vendored
```

See **[Getting Started](https://adrian-andersson.github.io/modusOps/getting-started.html)** for the
full Azure DevOps scaffold and GitHub Actions paths.

## Documentation

Full docs - concepts, the credential model, the template library, tutorials, and the cmdlet
reference - live at **[adrian-andersson.github.io/modusOps](https://adrian-andersson.github.io/modusOps)**.

## Built with ModuleForge

modusOps is scaffolded, versioned, and released with
[ModuleForge](https://adrian-andersson.github.io/ModuleForge) - the same SemVer, release-integrity,
and comment-help-as-docs conventions apply.

## License

MIT - see [LICENSE](LICENSE).
