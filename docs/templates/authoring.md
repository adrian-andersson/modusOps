---
layout: default
title: Authoring templates
parent: Templates
nav_order: 3
---

# Authoring and validating templates

[`modusops-templates`](https://github.com/adrian-andersson/modusops-templates) ships **starter
templates** for the common cases, and the modusOps tooling vendors, pins, updates, and tests them for
you - see [The library model](./library-model.md). But the starters are a starting point, not a
ceiling: **authoring your own templates is encouraged** wherever your environment needs something the
library doesn't cover. This page is how you write one well.

Templates you contribute back to the library are released as versioned assets, and two automated gates
keep the library trustworthy.

## Keep templates thin

A template orchestrates; it does not contain business logic. Real logic belongs in versioned PowerShell
modules pulled at runtime (for example `ModusOps.Toolkit`), not in the YAML. A good template is a small,
declarative wrapper around a module call.

## PR validation

Every pull request lints all distributed templates. Gating findings block the merge; advisory ones are
posted as a comment:

| Class | Gate? | Examples |
| --- | --- | --- |
| Structure | yes | must parse as YAML, no tab indentation |
| Parameters (azd) | yes | default not in `values`, undeclared `parameters.X`, missing/duplicate name |
| GH action (gh) | yes | literal `${{ secrets.* }}` in a manifest, `runs.using` not `composite`, undeclared `inputs.X` |
| Secrets | yes | a known credential **format** (token prefix, JWT, PEM, `AccountKey=`) - format-based, so GUIDs are not flagged |
| Hints / style / spacing | no (advisory) | unused params, missing types, duplicate display names, trailing whitespace |

The `${{ secrets.* }}` gate exists because GitHub evaluates that expression *everywhere* in an action
manifest - including `description:` and `run:` text - so a literal reference breaks the action before
any step runs. Tokens must arrive via an `input` the caller passes `secrets.*` into.

## Release

On merge, the next **rolling-integer** tag (`v1`, `v2`, `v3`, ...) is cut and the **full asset set is
attached** to the release (`azd.<name>.yml` and `gh.<name>.zip` for pipeline templates, the
`repoScaffold` workflow/markdown assets, plus `manifest.json` and a `checksums.txt`). Release notes
list only what actually changed since the previous tag, so an unchanged template never looks modified
even though the library version advanced. The same `vN` tag is the immutable ref GitHub consumers pin
(`...@vN`) - one tag scheme, not a separate SemVer line. (modusOps *modules* stay SemVer'd; the
*template library* is a curated set, so one monotonic coordinate is simpler.)

## The manifest is authoritative

The tooling resolves a template name to its asset through `manifest.json`, never by parsing filenames.
Each entry lists the template's platforms and per-platform asset names - which is how one name can map
to both an `azd.<name>.yml` and a `gh.<name>.zip` - plus a `category` (`pipeline` or `repoScaffold`),
the per-platform `kind`, and (for `repoScaffold`) a fixed `dest`. A top-level `sets` block declares the
archetypes that [`Add-MORepoScaffold`](./repo-scaffolding.md) applies.
