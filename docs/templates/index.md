---
layout: default
title: Templates
has_children: true
nav_order: 4
---

# Templates

[`modusops-templates`](https://github.com/adrian-andersson/modusops-templates) is the public,
versioned library modusOps vendors from. It is a **source, not a live dependency**: the tooling pulls
a template from a GitHub Release and writes it as a local file into your repo, pinned by version and
SHA256 in `.modusops.lock`. Nothing is fetched at pipeline compile- or run-time.

- [The library model](./library-model.md) - vendor-at-fetch, releases as the source, the lockfile as the trust anchor
- [Azure DevOps vs GitHub assets](./azd-vs-gh.md) - asset categories, shapes, and integrity anchors
- [Repo scaffolding (archetypes)](./repo-scaffolding.md) - platform defaulting, sets, and provision steps in one call
- [Authoring templates](./authoring.md) - the PR validation gates and release flow
