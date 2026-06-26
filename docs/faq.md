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
