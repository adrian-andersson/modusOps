---
layout: default
title: FAQ
nav_order: 7
---

# FAQ and Troubleshooting

Common questions and fixes. This page grows as patterns emerge.

## Is modusOps tied to Azure DevOps?

No. The model is platform-agnostic: thin operations over version-pinned modules and contained
credentials. It is proven on both Azure DevOps and GitHub Actions; the two differ only in the feed,
the token source, and how templates are referenced. See [Concepts](./concepts/).

## Where do templates come from, and is that safe to pull off the public internet?

Templates are **vendored at author time** from [`modusops-templates`](https://github.com/adrian-andersson/modusops-templates)
and committed to your repo, pinned by version + SHA256 in `.modusops.lock`. Nothing is fetched at
pipeline runtime, and the library source is configurable to an internal mirror.

The library templates are **starters, not a requirement**. They cover the common cases (feed
registration, module install, notifications), but you are encouraged to **author your own** whenever
they don't fit your environment - the tooling works the same against templates you write. See
[Templates](./templates/) and [Authoring templates](./templates/authoring.md).

## How do I change pipeline behaviour?

Promote a module or template **version** - you don't edit pipeline YAML. That is the whole point.

## `Test-MOTemplate` shows entries that were renamed (or retired) upstream - how do I migrate?

When the library renames assets or retires a shape (for example, the `repoScaffold` furniture moving to
`templatesRepo*` names, or the issue-template *directory set* splitting into one asset per file), your
`.modusops.lock` still holds the **old** keys - they were pinned when you vendored. The tooling won't
silently rewrite them; you re-vendor deliberately so the change lands in a reviewable PR.

The clean reset:

```powershell
Remove-Item .modusops.lock                       # drop the stale pins
# (optionally also delete furniture being re-derived, e.g. .github/ISSUE_TEMPLATE/)
Add-MORepoScaffold -Archetype templateLibrary    # re-stamp under the current names, freshly pinned
Test-MOTemplate                                  # should be all green
```

Prefer a surgical approach? `Update-MOTemplate` re-pulls at a newer version, and you can remove a single
stale entry from the lockfile by hand. Either way the new assets are pinned by version + SHA256 exactly
as before - nothing is trusted blindly. Run `Test-MOTemplate -CheckUpdate` to see, per template, the
pinned `Version` and whether a newer release is available.
