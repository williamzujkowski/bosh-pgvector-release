---
id: ADR-0002
title: pgvector packaging — one package per Postgres major
status: accepted
date: 2026-05-16
deciders: william
---

## Context

pgvector is a PostgreSQL extension built with PGXS, which means it's
compiled against a specific `pg_config` binary and gets installed into
that PostgreSQL installation's `lib/` and `share/extension/` directories.
Cross-version installation does not work: a pgvector `.so` built against
PostgreSQL 16 won't load into PostgreSQL 17.

The upstream postgres-release ships PostgreSQL 15, 16, and 17 as three
separate packages (`packages/postgres-15`, `packages/postgres-16`,
`packages/postgres-17`). The deployment manifest picks the active major
via the `databases.version` property; all three packages are compiled
into the VM, and the chosen version is symlinked at runtime.

## Decision

Mirror upstream's per-major split. Ship three packages:

- `packages/pgvector-15` — compiles pgvector against postgres-15
- `packages/pgvector-16` — compiles pgvector against postgres-16
- `packages/pgvector-17` — compiles pgvector against postgres-17

Each declares a BOSH `dependencies:` entry on the matching `postgres-N`
package so the BOSH director compiles them in order.

The packaging script compiles against postgres-N's `pg_config`, then
installs with `make install DESTDIR=${STAGING_DIR} PG_CONFIG=...` so
that all files land under `${BOSH_INSTALL_TARGET}/{lib,share/extension}/`
in this package's own blob — never into postgres-N's directory tree,
which is read-only from this package's perspective and never resynced
into postgres-N's blob (postgres-N was already compiled and finalised
before pgvector compiles). See issue #14 for the failure mode this
guards against.

At job pre-start, `bin/install_pgvector_links.sh` symlinks the pgvector
files into the active postgres-N package's `lib/` and `share/extension/`
directories so PostgreSQL's hard-coded extension search path picks them
up. The symlink step runs every pre-start, so it's idempotent and
survives BOSH redeploys.

All three pgvector packages share the same source tarball
(`pgvector-0.8.2.tar.gz`), declared via the `files: pgvector/pgvector-*.tar.gz`
glob in each package's spec.

## Why not one pgvector package serving all three Postgres majors

PGXS compiles against exactly one `pg_config`. We'd have to either:

- Build three times in one packaging script (functional, but conflates
  the dependency graph — the BOSH director would see one package with
  three postgres-N dependencies).
- Write a runtime selector that picks the right `.so` at start time
  (complicated; defeats BOSH's compile-time package model).

Three packages keeps the dependency graph honest and matches upstream's
own per-major split.

## Compile-time choices

- `OPTFLAGS=""` overrides pgvector's default `-march=native`. The BOSH
  compilation VM may not be CPU-feature-identical to the deployment
  VM, and `-march=native` would produce `.so`s that crash with SIGILL
  on a different microarchitecture. We accept slightly slower vectors
  for portability.
- `make install DESTDIR=${STAGING_DIR} PG_CONFIG=...` — PGXS computes
  install paths from `pg_config --pkglibdir` / `--sharedir`, then
  prefixes every install destination with `${DESTDIR}`. We move the
  artifacts out of staging into `${BOSH_INSTALL_TARGET}/{lib,share/extension}/`
  so they land in this package's compiled blob. The script queries
  pg_config for the staged paths rather than hard-coding
  `/var/vcap/packages/postgres-N/...`, which keeps the move logic
  invariant to whatever prefix postgres-N was configured with.

## Consequences

- The release tarball gets ~120 KB larger per Postgres major (three
  pgvector packages, each ~40 KB compiled). Negligible.
- A rebase that adds postgres-18 requires us to add `pgvector-18` in
  the same PR (per ADR-0001). The boilerplate is mechanical.
- pgvector version bumps require updating each of the three packaging
  scripts (just the source glob version) and rerunning the build.

## Alternatives considered

- **Single pgvector package, runtime selector**: rejected as explained
  above.
- **No package, install pgvector via post-start hook**: rejected. Hooks
  run at deploy time, can't compile, would need to ship pre-built
  binaries.
- **Pre-built `.so` files vendored in the package**: rejected. Brittle
  across stemcell/glibc versions. Compiling on the BOSH director's
  matching stemcell is the safer pattern.
