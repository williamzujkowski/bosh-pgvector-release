# Security Policy

## Reporting a vulnerability

Email the repository owner directly. Do not file a public GitHub issue
for security-sensitive reports.

We aim to acknowledge within 72 hours.

If the vulnerability is in the underlying PostgreSQL or pgvector code
(not in this fork's additions), please also follow upstream's
disclosure channels:

- [PostgreSQL security policy](https://www.postgresql.org/support/security/)
- [pgvector security](https://github.com/pgvector/pgvector/security)

## Threat model summary

`bosh-pgvector-release` is a build of PostgreSQL with the pgvector
extension, packaged for BOSH. Its security posture is dominated by
upstream PostgreSQL and pgvector. The fork-specific additions are:

1. Three small `packages/pgvector-N/packaging` bash scripts that
   compile pgvector against the bundled PostgreSQL. They run only
   on BOSH director compilation VMs, never at request time.
2. A `scripts/fetch-blobs.sh` that downloads source tarballs from
   `ftp.postgresql.org` and `github.com/pgvector` over HTTPS. No
   integrity check beyond TLS as of v0.1.0; tracked as a follow-up
   issue (add SHA-256 pins from upstream's `config/blobs.yml`).
3. A `jobs/postgres/spec` patch adding three lines to the package
   list. Not security-relevant.

The fork **does not** add any new network listeners, hooks, broker
endpoints, or default credentials. The `databases.hooks.post_start`
property is upstream-provided and uses the same security model.

## Supply chain

- All source comes from canonical origins via HTTPS:
  - PostgreSQL: `ftp.postgresql.org/pub/source/`
  - pgvector: `github.com/pgvector/pgvector/archive/refs/tags/`
  - yq: `github.com/mikefarah/yq/releases/`
- SHA-256 pins to come (tracked issue).
- Apache 2.0 + Apache 2.0 + BSD-style licensing, no GPL.

## Disclosure standards

- We follow [CVD](https://www.cisa.gov/coordinated-vulnerability-disclosure-process) practices.
- Releases are signed via GPG once we ship a stable tag (tracked).
- Dependency provenance is in `NOTICE`.
