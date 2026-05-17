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

> **Note on `${PORT}`.** The postgres job exports `PORT` into the hook
> script's environment from the `databases.port` property (default
> `5432`). You don't need a `${PORT:-5432}` fallback here; if `PORT` is
> ever unset that's an upstream postgres-release bug worth investigating
> rather than silently papering over.

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
 vector | 0.8.2   | public | vector data type and ivfflat and hnsw access methods
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

## Consuming via a service broker

The `databases.hooks.post_start` pattern above provisions databases at
deploy time. For CF apps that want self-service (`cf create-service ...`),
deploy a service broker in front of the postgres VM. This release does
not bundle one — use the broker your foundation already runs, or pick up
[`cf-local-service-broker`](https://github.com/williamzujkowski/cf-local-service-broker),
a small OSBAPI v2 broker (Go binary, deployable as a `cf push` app) that
already ships a `postgresql-local` service offering with a `pgvector`
plan that runs `CREATE EXTENSION vector` on each provisioned database.

### Operator flow

```bash
# 1. Deploy bosh-pgvector-release as a standalone BOSH deployment.
#    Use the manifest pattern in the sections above (single 'admin'
#    role suffices; the broker creates per-binding roles itself).
bosh -d pgvector deploy manifest.yml

# 2. cf push the broker binary (built from cf-local-service-broker),
#    pointing PG_HOST / PG_PORT / PG_ADMIN_USER / PG_ADMIN_PASSWORD at
#    the postgres VM.
cf push postgres-broker -b binary_buildpack -c './postgres-broker' -m 64M
cf set-env postgres-broker BROKER_USERNAME admin
cf set-env postgres-broker BROKER_PASSWORD "$(openssl rand -hex 16)"
cf set-env postgres-broker PG_HOST       10.0.x.y
cf set-env postgres-broker PG_PORT       5524
cf set-env postgres-broker PG_ADMIN_USER vcap
cf set-env postgres-broker PG_ADMIN_PASSWORD "$(credhub get -n /pgvector/admin_password -j | jq -r .value)"
cf restage postgres-broker

# 3. Register the broker with CF and enable the pgvector plan.
cf create-service-broker postgres-broker admin "${BROKER_PASSWORD}" \
  "https://postgres-broker.${CF_APPS_DOMAIN}"
cf enable-service-access postgresql-local -p pgvector

# 4. Apps now self-serve.
cf create-service postgresql-local pgvector my-vector-db
cf bind-service my-app my-vector-db
cf restage my-app
```

### What the binding gives the app

The broker exposes credentials via `VCAP_SERVICES` in the standard
shape:

```json
{
  "host":     "10.0.x.y",
  "port":     "5524",
  "database": "cf_<instance_id>",
  "username": "cf_<binding_id>",
  "password": "<generated>",
  "uri":      "postgres://cf_<binding_id>:<password>@10.0.x.y:5524/cf_<instance_id>"
}
```

The vector extension is already installed in the database (the broker
runs `CREATE EXTENSION vector` on provision), so apps can immediately
`CREATE TABLE items (id bigint, embedding vector(1536))` without
needing extra privileges.

### When to use which approach

| Need                                          | Use                                                                 |
| --------------------------------------------- | ------------------------------------------------------------------- |
| Self-service for many CF apps                 | Service broker                                                      |
| One known set of DBs, fixed at deploy time    | `databases.hooks.post_start` (above)                                |
| External (non-CF) clients connecting directly | `databases` + roles in the manifest; no broker needed               |
| A mix                                         | Both. Declare known DBs in the manifest *and* run a broker for the rest — they don't conflict. |
