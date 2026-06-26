---
layout: default
title: The security-prominent stance
parent: Concepts
nav_order: 3
---

# The security-prominent stance

modusOps aims to be "security-prominent": the security properties are front-and-centre design goals, not
afterthoughts. This page states what is contained, what is deliberately accepted, and the upgrade
path for teams that want more.

## What is contained

- **The build token** cannot reach a public feed - it is bound per-feed via `CredentialInfo`, with no
  ambient credential to leak. See [the credential model](./credential-model.md).
- **Templates are vendored and reviewed**, not fetched at runtime. A privileged template is committed
  to your repo and reviewed in your own PR before it can run, and pinned by version + SHA256 in
  `.modusops.lock`. Nothing privileged is pulled off the public internet at pipeline time.
- **The library source is configurable.** An enterprise can point the tooling at an internal mirror of
  [`modusops-templates`](https://github.com/adrian-andersson/modusops-templates) and vet its own copy -
  same code path - which defuses the "pulling pipeline YAML off the public internet" objection.
- **Provenance is observable.** Each install reports which feed every module actually resolved from -
  a de-facto SBOM for the run.

## Integrity ladder

Supply-chain integrity is a set of opt-in rungs; modusOps sits on the first and pre-defines the rest:

| Rung | Mechanism | Status |
| --- | --- | --- |
| 1 | **SHA256 in `.modusops.lock`**, verified offline by `Test-MOTemplate` | **Default** |
| 2 | Signed `checksums.txt` (Cosign / minisign) | Defined, optional |
| 3 | SLSA provenance | Future |
| 4 | GitHub Artifact Attestation (Sigstore-keyless) | Future |

The lockfile checksum is the trust anchor - not the release tag - because release assets are mutable.
A pinned version plus a locked hash makes a silent re-upload a non-event: `Test-MOTemplate` flags any
drift between the vendored file and its pinned hash.

## Deliberately accepted

Security-prominent does not mean maximal. Some choices are explicit risk-acceptances, recorded as
decisions rather than gaps:

- **Code signing of the modules is declined** for now - a recorded risk-acceptance, revisited if the
  threat model changes.
- **Attestation is deferred.** Checksums are the floor; attestation is the ceiling, added when a team
  crosses the trust boundary from public artifact to privileged context and wants more than a hash.

## Managed, not hand-edited

Vendored templates are a *managed* directory (the `node_modules` model): `Update-MOTemplate`
overwrites them and `Test-MOTemplate` reports any local edit as drift. Treat a vendored template as
generated input you review, not as a file you maintain by hand.
