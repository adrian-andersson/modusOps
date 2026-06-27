---
layout: default
title: The library model
parent: Templates
nav_order: 1
---

# The library model - vendor-at-fetch

[`modusops-templates`](https://github.com/adrian-andersson/modusops-templates) is a **source, not a
live dependency**. The tooling pulls a template from a GitHub Release and writes it into your repo as
a committed, pinned file. Think npm, but the package is vendored and reviewed in your own PR.

| npm | modusOps templates |
| --- | --- |
| registry | `modusops-templates` releases |
| `npm install <pkg>` | `Add-MOTemplate` |
| `npm update` | `Update-MOTemplate` |
| `package-lock.json` | `.modusops.lock` |
| `npm ci` integrity check | `Test-MOTemplate` (offline) |
| editing `node_modules` (don't) | editing a vendored template (managed; reported as drift) |

## Why releases, not a package feed

YAML has no package ecosystem, and PSResourceGet is module/script-centric - you cannot cleanly put raw
YAML in a NuGet feed and pull it without wrapping it as a module, which would conflate module-install
with template-fetch and lose the vendored-file + lockfile-SHA + PR-review properties. GitHub Release
assets + vendor-at-fetch keeps all three.

## The lockfile is the trust anchor

`.modusops.lock` records, per template: the source URL, the version/tag, the asset name, and a SHA256.
That hash - not the release tag - is the integrity anchor, because release assets are mutable.

```jsonc
{
  "lockfileVersion": 1,
  "source": "https://github.com/adrian-andersson/modusops-templates",
  "defaults": { "platform": "gh" },          // set once; commands stop re-taking -Platform
  "templates": {
    "registerModusOpsFeeds": {               // a pipeline building block
      "version": "v1", "platform": "gh", "category": "pipeline", "kind": "compositeAction",
      "asset": "gh.registerModusOpsFeeds.zip",
      "path": "templates/registerModusOpsFeeds/action.yml",
      "integrity": "file", "sha256": "....",
      "url": "https://github.com/.../gh.registerModusOpsFeeds.zip"
    },
    "prValidation": {                         // repo furniture, vendored to a fixed dest
      "version": "v1", "platform": "gh", "category": "repoScaffold", "kind": "workflow",
      "asset": "gh.workflow.prValidation.yml",
      "path": ".github/workflows/prValidation.yml",
      "integrity": "file", "sha256": "....",
      "archetype": "templateLibrary", "archetypeVersion": "v1"
    }
  }
}
```

`integrity` says how the anchor is recomputed (`file` SHA256, or `tree` for a multi-file directory set);
`Test-MOTemplate` recomputes each vendored file's hash that way and compares it to the lock - entirely
offline, so it is a cheap CI gate. (Versions are rolling integers, `vN` - see
[Authoring templates](./authoring.md#release).)

## The verbs

| Verb | Does |
| --- | --- |
| `Find-MOTemplate` | Discover templates / versions in a release. |
| `Add-MOTemplate` | Vendor a pinned template + record it in the lockfile (always pin; never blind "latest"). |
| `Update-MOTemplate` | Re-pull at a newer version, rewriting only files whose bytes changed. |
| `Test-MOTemplate` | Offline integrity check against the lockfile. |
| `Get-MOTemplate` | List installed templates (reads the lockfile). |

To set a default platform once (`Set-MOPlatform`), or stamp a whole **set** of furniture in one call
(`Find-MOArchetype` / `Add-MORepoScaffold`), see [Repo scaffolding (archetypes)](./repo-scaffolding.md).

## Configurable source

The library defaults to the public repo but accepts an override URL, so an enterprise can vendor from
an internal mirror it controls - the same code path, no public fetch. See
[The security-prominent stance](../concepts/security-model.md).
