# Deployment guide

The base BOSH deployment instructions are in the [upstream README](../README.md#upstream-postgres-release-readme).
This document covers only the pgvector-specific bits.

## Enabling pgvector on each database

After the postgres job starts, the pgvector binary is installed under
`/var/vcap/packages/postgres-N/lib/` and `/var/vcap/packages/postgres-N/share/extension/`
on the VM. But `CREATE EXTENSION vector` is still a per-database
operation. Use the upstream `databases.hooks.post_start` property to
run it declaratively.

### Single database

```yaml
properties:
  databases:
    version: 16
    databases:
      - name: app_data
    roles:
      - name: app
        password: ((app_db_password))
    hooks:
      post_start: |
        set -eu
        export PATH=/var/vcap/packages/postgres-16/bin:$PATH
        psql -h 127.0.0.1 -p "${PORT}" -d app_data \
          -c "CREATE EXTENSION IF NOT EXISTS vector"
```

### Multiple databases

```yaml
properties:
  databases:
    version: 16
    databases:
      - name: kiln_chunks
      - name: another_app
      - name: third_app
    hooks:
      post_start: |
        set -eu
        export PATH=/var/vcap/packages/postgres-16/bin:$PATH
        for db in kiln_chunks another_app third_app; do
          psql -h 127.0.0.1 -p "${PORT}" -d "${db}" \
            -c "CREATE EXTENSION IF NOT EXISTS vector"
        done
```

## Verification after deploy

SSH into the postgres VM:

```bash
bosh ssh postgres/0
sudo -iu vcap

# Connect to a database and verify pgvector is available
/var/vcap/packages/postgres-16/bin/psql -p 5432 -d <dbname>
=> CREATE EXTENSION IF NOT EXISTS vector;
=> \dx vector
                            List of installed extensions
  Name  | Version | Schema |                     Description
--------+---------+--------+------------------------------------------------------
 vector | 0.8.0   | public | vector data type and ivfflat and hnsw access methods
```

If the `\dx vector` row is missing, the extension wasn't installed on
the VM. Check the postgres job's compile logs:

```bash
bosh logs postgres/0
# Or for a specific compile failure:
bosh task --debug <compile-task-id>
```

## Migrating an existing database

If you already have a database deployed via upstream postgres-release
and want to add pgvector, the migration is:

1. Update your deployment manifest to use `bosh-pgvector-release`
   instead of `postgres-release`.
2. Add the `databases.hooks.post_start` snippet above.
3. `bosh deploy` — BOSH will compile pgvector against your existing
   Postgres major version. No data migration needed; the extension is
   added to an existing database, not the server.

If your deployment uses Postgres 15 and you've planned to also move to
16, do the pgvector switch *and* the version upgrade in separate
deploys. Don't compound moving parts.

## Operational notes

- **Memory.** pgvector itself adds negligible memory. IVFFLAT or HNSW
  indexes can use significant RAM during build; size your VM
  accordingly.
- **Backups.** BBR-based backup of the postgres job works unchanged;
  pg_dump captures the extension state and the vector data.
- **Replication.** Standard streaming replication captures pgvector
  data. The extension must be installed on both primary and replicas
  (this release does that by default since it ships pgvector on every
  VM that runs the postgres job).
- **Upgrades.** Major Postgres upgrades (15→16) require the same care
  as any pgvector upgrade: dump/restore or `pg_upgrade` with the
  pgvector extension version matching on both sides.
