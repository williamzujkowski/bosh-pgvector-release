<!-- Keep it short. Link the issue; the diff shows what; explain why. -->

## What

## Why

## Test plan

- [ ] `./scripts/fetch-blobs.sh && bosh create-release --force` succeeded locally
- [ ] pre-commit run --all-files green
- [ ] Tarball includes all pgvector-{15,16,17}.tgz
- [ ] If touching upstream files: rationale documented below

## Touches upstream?

<!-- Per ADR-0001, modifications to upstream files (anything outside
packages/pgvector-*/, docs/, our scripts, our config files) should be
rare and justified. If this PR touches upstream content, explain why
the change can't be sent to cloudfoundry/postgres-release first. -->

## Related

Closes #
