# Contributing

This is a thin fork of [`cloudfoundry/postgres-release`](https://github.com/cloudfoundry/postgres-release).
The diff against upstream is intentionally small. Most contributions
should be small too.

## Before you start

1. Read [AGENTS.md](./AGENTS.md) — the constraints (don't modify
   upstream files unnecessarily, preserve attribution, rebase rather
   than drift) apply to humans too.
2. If your change is to upstream PostgreSQL behavior, **send it
   upstream** (`cloudfoundry/postgres-release` for the BOSH packaging,
   `pgvector/pgvector` for the extension itself, `postgresql.org` for
   PostgreSQL). This repo is only for the integration glue.
3. Check open issues. Look for `good-first-issue`.

## Development setup

```bash
# Prereqs: bosh CLI v7.x (https://github.com/cloudfoundry/bosh-cli/releases)
git clone https://github.com/williamzujkowski/bosh-pgvector-release
cd bosh-pgvector-release
git remote add upstream https://github.com/cloudfoundry/postgres-release.git

./scripts/fetch-blobs.sh
bosh create-release --force \
  --name=bosh-pgvector-release --version=0.1.0-dev \
  --tarball=/tmp/bosh-pgvector-release-0.1.0-dev.tgz
```

Install pre-commit hooks:

```bash
pip install pre-commit
pre-commit install
```

## What kinds of changes are welcome

- **Bug reports** with a reproducer (deployment manifest + the error
  you saw).
- **Documentation** improvements — especially "I deployed this on X
  director and hit Y" notes.
- **Adding a new postgres major** if upstream postgres-release adds
  one. Ship `pgvector-N` alongside.
- **pgvector version bumps** — track upstream pgvector releases.
- **CI improvements** — more rigorous packaging-script lints, SHA pins,
  signed release tarballs.
- **Operator examples** — sample BOSH deployment manifests for common
  configurations (single-instance, replicated, etc.).

## What kinds of changes are NOT welcome (here)

- Changes to upstream PostgreSQL behavior. Send those upstream.
- Adding a service broker. Out of scope. Use your existing CF broker.
- Adding non-pgvector extensions (PostGIS, pg_trgm, etc.). If there's
  demand, fork this repo or open an issue to discuss a sibling release
  pattern.

## PR process

1. Open or comment on an issue first if the change is non-trivial.
2. Branch from `main`. Branch names: `feat/<slug>`, `fix/<slug>`,
   `chore/<slug>`, `docs/<slug>`, `chore(rebase)/<upstream-version>`.
3. Commit messages: imperative present, ≤72 char subject.
4. PR description must include a Test plan (at minimum, `bosh
   create-release --force` succeeded locally).
5. CI runs `bosh create-release --force` + pre-commit. Both must pass.

## Rebase against upstream

See [`AGENTS.md` → "Rebase against upstream"](./AGENTS.md#rebase-against-upstream).
Rebases are PRs like any other change, but the commit message starts
with `chore(rebase): postgres-release vXX.Y.Z`.

## License

By contributing you agree your contributions will be licensed under
the Apache License 2.0 (matches upstream postgres-release). See
[LICENSE](./LICENSE).
