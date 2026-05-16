#!/usr/bin/env bash
# fetch-blobs.sh — download all source tarballs needed for `bosh create-release`.
#
# The upstream postgres-release uses an S3 blobstore for vendored source
# tarballs; we don't have that bucket. This script pulls the same
# sources from their canonical public origins (postgresql.org FTP for
# Postgres, GitHub Releases for yq and pgvector) into the local `blobs/`
# tree where `bosh create-release --force` can find them.
#
# Idempotent: skips files already present with the right size.
# Bandwidth: ~95 MB on first run, zero on subsequent runs.
set -euo pipefail

# Pin versions in one place so README, CI, and operators agree.
PG15_VERSION="${PG15_VERSION:-15.18}"
PG16_VERSION="${PG16_VERSION:-16.14}"
PG17_VERSION="${PG17_VERSION:-17.10}"
YQ_VERSION="${YQ_VERSION:-4.53.2}"
PGVECTOR_VERSION="${PGVECTOR_VERSION:-0.8.0}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

mkdir -p blobs/postgres blobs/yq blobs/pgvector

# Fetches $url to $dest only if $dest is missing or empty.
fetch_once() {
  local url="$1" dest="$2"
  if [[ -s "${dest}" ]]; then
    echo "exists: ${dest}"
    return 0
  fi
  echo "fetch:  ${dest}"
  curl -fsSL --retry 3 -o "${dest}" "${url}"
}

fetch_once \
  "https://ftp.postgresql.org/pub/source/v${PG15_VERSION}/postgresql-${PG15_VERSION}.tar.gz" \
  "blobs/postgres/postgresql-${PG15_VERSION}.tar.gz"

fetch_once \
  "https://ftp.postgresql.org/pub/source/v${PG16_VERSION}/postgresql-${PG16_VERSION}.tar.gz" \
  "blobs/postgres/postgresql-${PG16_VERSION}.tar.gz"

fetch_once \
  "https://ftp.postgresql.org/pub/source/v${PG17_VERSION}/postgresql-${PG17_VERSION}.tar.gz" \
  "blobs/postgres/postgresql-${PG17_VERSION}.tar.gz"

fetch_once \
  "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64" \
  "blobs/yq/postgres-yq-${YQ_VERSION}"

fetch_once \
  "https://github.com/pgvector/pgvector/archive/refs/tags/v${PGVECTOR_VERSION}.tar.gz" \
  "blobs/pgvector/pgvector-${PGVECTOR_VERSION}.tar.gz"

echo ""
echo "All blobs fetched. Run 'bosh add-blob <path> <target>' to register"
echo "any new blob in config/blobs.yml, then 'bosh create-release --force'."
