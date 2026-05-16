# AGENTS.md — bosh-pgvector-release

Canonical instructions for AI coding agents (Claude Code, Cursor, Codex, OpenCode, Aider) working in this repo. `CLAUDE.md` is a symlink to this file.

**Project:** BOSH release for PostgreSQL with pgvector. Fork of `cloudfoundry/postgres-release`.
**Repository:** github.com/williamzujkowski/bosh-pgvector-release
**Owner:** @williamzujkowski
**License:** Apache 2.0 (matches upstream)

---

## What you must know before changing anything

This repo is a **thin fork** of `cloudfoundry/postgres-release`. The diff against upstream is intentionally small: three packages (`pgvector-{15,16,17}`), a job-spec patch adding them to the postgres job's package list, the pgvector blob, and fork-specific docs/CI/scripts. **Nothing else.**

If you find yourself modifying upstream files (jobs/, src/, packages/postgres-*, config/*), stop and ask: would this change be better proposed upstream? If the answer is yes, send it there. If the answer is "no, this is pgvector-specific", make sure the change is contained and clearly justified — every divergence from upstream costs us at the next rebase.

## Prime directive

```text
correctness > simplicity > performance > cleverness
```

## Hard constraints

- **No license re-licensing.** Apache 2.0 stays. The bundled PostgreSQL and pgvector are PostgreSQL License (BSD-style).
- **Preserve upstream attribution.** NOTICE and README both call out the postgres-release fork relationship. Don't strip it.
- **No secrets in git.** No AWS creds, no BOSH director endpoints, no real deployment manifests with real hostnames.
- **No blobs in git.** `blobs/` is gitignored. Source tarballs are fetched via `scripts/fetch-blobs.sh`.
- **Rebase, don't drift.** When upstream postgres-release releases a new version, follow the rebase policy in [`docs/adr/0001-fork-and-rebase-policy.md`](./docs/adr/0001-fork-and-rebase-policy.md).
- **Three Postgres majors, three pgvector packages.** If upstream adds a postgres-18 package, we add pgvector-18 in the same rebase PR. If upstream drops postgres-15, we drop pgvector-15.

## Quick reference

```bash
# Set up your local environment for a build
./scripts/fetch-blobs.sh          # ~95 MB on first run, idempotent after
bosh add-blob blobs/pgvector/pgvector-X.Y.Z.tar.gz pgvector/pgvector-X.Y.Z.tar.gz

# Build a dev release tarball
bosh create-release --force --name=bosh-pgvector-release --version=0.1.0-dev \
  --tarball=/tmp/bosh-pgvector-release-0.1.0-dev.tgz

# Inspect what's in it
tar -tzf /tmp/bosh-pgvector-release-0.1.0-dev.tgz | head -30

# Sync with upstream
git fetch upstream
git rebase upstream/master       # see ADR-0001 for the policy
./scripts/fetch-blobs.sh         # may need to update postgres version pins

# Lint
pre-commit run --all-files

# CI runs `bosh create-release --force` as a smoke test on PRs.
```

## Layout

```text
.
├── README.md                    fork prepend + upstream README verbatim
├── AGENTS.md                    this file (CLAUDE.md symlinks here)
├── NOTICE                       attribution to upstream + bundled software
├── LICENSE                      Apache 2.0 (unchanged from upstream)
├── SECURITY.md                  disclosure policy
├── CONTRIBUTING.md              how to contribute
├── docs/
│   └── adr/                     ADRs documenting fork-specific decisions
├── jobs/                        UPSTREAM (one patch: postgres/spec adds pgvector-N)
├── packages/
│   ├── postgres-*               UPSTREAM (do not modify here; PRs go upstream)
│   ├── pgvector-15/             FORK ADDITION
│   ├── pgvector-16/             FORK ADDITION
│   └── pgvector-17/             FORK ADDITION
├── src/                         UPSTREAM (do not modify)
├── config/
│   ├── blobs.yml                upstream entries + our pgvector entry
│   └── final.yml                if/when we set up our own blobstore
├── scripts/
│   ├── fetch-blobs.sh           FORK ADDITION (replaces upstream's S3 pull)
│   └── <upstream scripts>       UPSTREAM (do not modify)
└── .github/workflows/           UPSTREAM may have a Concourse pipeline at ci/;
                                 we add GitHub Actions for cheap PR validation
```

## TDD / verification

BOSH releases are mostly declarative (specs + bash packaging scripts). The way we "test" them:

1. `bosh create-release --force` must complete successfully — this is the CI smoke test.
2. The packaging scripts run on the BOSH director's compilation VMs during deploy, not locally. We can't unit-test them here; integration is via a real director.
3. Once a director is wired up, run a smoke deployment and verify `CREATE EXTENSION vector` works on each Postgres major.

If you change a packaging script, run the build locally and inspect the resulting tarball.

## Rebase against upstream

When `cloudfoundry/postgres-release` ships a new version:

1. `git fetch upstream`
2. `git rebase upstream/master`
3. Resolve conflicts in `jobs/postgres/spec` (we have a patch there adding pgvector packages — keep both upstream's changes and ours).
4. Bump the postgres version pins in `scripts/fetch-blobs.sh` if upstream's `config/blobs.yml` moved to new postgres minor versions.
5. Bump our `pgvector-N` packages to match if a Postgres major was added/removed.
6. `./scripts/fetch-blobs.sh && bosh create-release --force` to confirm the build still works.
7. Update the version table in README.
8. Commit with a clear `chore(rebase): postgres-release vXX.Y.Z` message.

## Discovered issues

If you find a bug **outside your current task**, file a GitHub issue. Don't fix it inline. If the bug is in upstream code (`packages/postgres-*`, `src/`, `jobs/postgres/templates/*` other than the spec), the issue title should start with `[upstream]` and the body should link the upstream file.

## Self-check before completing any task

- [ ] Build succeeds: `bosh create-release --force` produces a tarball.
- [ ] Tarball contents include all three pgvector packages.
- [ ] No upstream files modified that weren't strictly necessary.
- [ ] README's "What's added vs upstream" table still accurate.
- [ ] NOTICE still credits the fork relationship.
- [ ] pre-commit clean.

## File references

| Need to...                              | Go to                                                |
| --------------------------------------- | ---------------------------------------------------- |
| Understand the fork relationship        | [README.md](./README.md), [NOTICE](./NOTICE)         |
| See the upstream README                 | [README.md](./README.md) (second half)               |
| Fork + rebase policy                    | [docs/adr/0001-fork-and-rebase-policy.md](./docs/adr/0001-fork-and-rebase-policy.md) |
| Packaging design                        | [docs/adr/0002-pgvector-packaging.md](./docs/adr/0002-pgvector-packaging.md)         |
| Enable extension on each database       | [docs/deployment.md](./docs/deployment.md)           |
| Build a release locally                 | [`scripts/fetch-blobs.sh`](./scripts/fetch-blobs.sh) |

---

*Standards governance: this AGENTS.md is the single source of truth.*
