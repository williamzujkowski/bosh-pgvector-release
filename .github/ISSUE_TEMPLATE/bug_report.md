---
name: Bug report
about: Something doesn't build, deploy, or work as expected.
labels: bug
---

## What happened

<!-- A concise description. If a build error, include the failing log. -->

## What you expected

## How to reproduce

1.
2.
3.

## Environment

- bosh CLI version (`bosh --version`):
- Stemcell (if deploying):
- Postgres major version in use:
- pgvector version (per `bosh-pgvector-release` README versioning table):
- BOSH director type (kind / vsphere / aws / Incus / etc.):

## Relevant manifest snippet

```yaml
# Trim down to the postgres job + pgvector hook only.
# Redact passwords + hostnames.
```

## Logs / output

<!-- Paste relevant output. Redact secrets. -->
