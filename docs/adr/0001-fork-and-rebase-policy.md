---
id: ADR-0001
title: Thin fork of cloudfoundry/postgres-release, periodic rebase against upstream
status: accepted
date: 2026-05-16
deciders: william
---

## Context

We need pgvector available on a BOSH-deployed PostgreSQL. Upstream
`cloudfoundry/postgres-release` doesn't ship it, and adding it as a
sidecar release would either require operators to layer two releases
manually (operationally awkward) or to maintain a separate Postgres
deployment alongside the upstream one (defeats the point).

Two reasonable structures:

1. **Sidecar release** — depend on postgres-release without forking;
   provide only the pgvector package + a thin "install into postgres
   package dirs" mechanism.
2. **Thin fork + periodic rebase** — clone the upstream repo, add
   the pgvector packages in-tree, rebase against upstream's main
   branch on each upstream release.

## Decision

We are doing **(2): a thin fork with periodic rebase**.

The diff against upstream is intentionally minimal:

- Three new packages (`pgvector-15`, `pgvector-16`, `pgvector-17`).
- Three new lines in `jobs/postgres/spec` (adding those packages to
  the postgres job's package list).
- One new entry in `config/blobs.yml` for the pgvector source.
- Fork-specific docs (README prepend, NOTICE, ADRs, this file).

Nothing in `src/`, `jobs/postgres/templates/`, `packages/postgres-*`,
or other upstream files is touched.

## Rebase policy

- **Cadence:** rebase against `cloudfoundry/postgres-release`
  `master` within one week of each upstream tagged release.
- **Mechanic:** `git rebase upstream/master`, resolve any conflict
  in `jobs/postgres/spec` (the only file with overlap risk), bump
  postgres version pins in `scripts/fetch-blobs.sh`, build, push.
- **Commit subject:** `chore(rebase): postgres-release vXX.Y.Z`.
- **Postgres-major changes:** if upstream adds postgres-18, we add
  `pgvector-18` in the same rebase PR. If upstream drops postgres-15,
  we drop `pgvector-15`.

## Why not a sidecar release

- BOSH supports cross-release package dependencies, but using them
  for "install into another release's lib dir" is unusual and brittle
  — the consuming release would have to know the package layout of
  postgres-release's artifacts, which is not a stable interface.
- A sidecar release would still need to know which Postgres major
  is in use, leading to the same `pgvector-15/16/17` package split.
- Operators would have to upload, depend on, and configure two
  releases. The thin-fork approach is one release that "just works".

## Why not vendor postgres-release into a subdirectory

- BOSH releases are not designed to be nested.
- It would obscure the upstream relationship and complicate rebases.

## Consequences

- We sign up for ongoing rebase work — bounded but real.
- Our diff is small enough that conflicts are unlikely beyond the
  postgres job spec.
- Consumers see one repo with full PostgreSQL + pgvector functionality.
- Upstream attribution is preserved (NOTICE, README, full git history
  via the upstream branch).
- We never modify upstream files. If we need to, we open an upstream
  PR first.

## Alternatives considered

- **Sidecar release**: rejected as explained above.
- **Independent re-implementation** (build PostgreSQL+pgvector from
  scratch as a clean BOSH release): rejected — we'd lose all of
  postgres-release's operational machinery (BBR backup, lifecycle
  hooks, certificate handling, role/database property model).
- **Resurrect `cloudfoundry-community/postgresql-docker-boshrelease`**:
  archived in 2019; Docker-in-BOSH is its own problem space; not worth
  it.
