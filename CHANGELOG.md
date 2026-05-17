# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This release tracks upstream `cloudfoundry/postgres-release` versions in
the README's versioning table; this changelog covers fork-specific
changes only.

## [Unreleased]

### Added

- Service-broker consumption pattern documented in `docs/deployment.md`
  (cf-local-service-broker handoff).
- CI release-publishing workflow (`.github/workflows/release.yml`) and
  CI hardening (action SHA pinning, fly CLI integrity check in
  `validate-pipeline.yml`).
- Sanity check in `jobs/postgres/templates/install_pgvector_links.sh.erb`
  that asserts `PGVECTOR_INSTALLED_FOR_POSTGRES` from `pgvector.env`
  matches the active postgres major (fork-side defense in depth; see
  issue #2 item #22).

### Changed

- Bumped pgvector 0.8.0 -> 0.8.2 (`config/blobs.yml`,
  `scripts/fetch-blobs.sh`); CI now derives the pgvector version from
  `scripts/fetch-blobs.sh` rather than a hard-coded constant.
- Pre-commit hook minor version bumps; markdownlint MD060 disabled.

### Fixed

- pgvector packaging now installs via `DESTDIR` and the runtime
  pre-start script symlinks the artifacts into the active
  postgres-N package tree (PR #15 / issue #14). Replaces the earlier
  attempt to install directly under `/var/vcap/packages/postgres-N/`,
  which BOSH's package immutability guarantees made unreliable.

## [0.1.0] - 2026-05-16

### Added

- Initial fork from `cloudfoundry/postgres-release` v54.0.1 (upstream commit `0998b4e`, 2026-05-16).
- `packages/pgvector-15`, `packages/pgvector-16`, `packages/pgvector-17` — compile pgvector against the matching bundled PostgreSQL major.
- pgvector 0.8.0 source vendored via `config/blobs.yml` (downloaded by `scripts/fetch-blobs.sh`); bumped to 0.8.2 in a subsequent unreleased change.
- `jobs/postgres/spec` patched to include the pgvector packages in the postgres job.
- Fork-specific README prepend documenting the addition.
- `NOTICE` updated for derivative-work attribution + bundled software.
- ADRs 0001 (fork & rebase policy), 0002 (per-major package design).
- `docs/deployment.md` walking through `CREATE EXTENSION vector` via the existing `databases.hooks.post_start` property.
- `scripts/fetch-blobs.sh` to pull source tarballs from canonical origins without an S3 blobstore.
- `scripts/lint_specs.py` pre-commit hook validating `packages/*/spec` files.
- `scripts/check-upstream-untouched.sh` advisory hook flagging modifications to upstream files.
- `.pre-commit-config.yaml` with gitleaks, detect-secrets, shellcheck, shfmt, yamllint, markdownlint, generic hygiene hooks.
- `.github/workflows/ci.yml` running `bosh create-release --force` as a smoke test, plus pre-commit and gitleaks.
- AGENTS.md (+ CLAUDE.md symlink), SECURITY.md, CONTRIBUTING.md.
