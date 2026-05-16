#!/usr/bin/env bash
# fetch-blobs.sh — download all source tarballs needed for
# `bosh create-release`.
#
# Upstream postgres-release uses an S3 blobstore we don't have access
# to; this script pulls the same sources from their canonical public
# origins (postgresql.org FTP for Postgres, GitHub Releases for yq and
# pgvector) into the local `blobs/` tree where bosh can find them.
#
# Idempotent: skips files already present with the right size.
# Bandwidth: ~95 MB on first run, zero on subsequent runs.
#
# Supply-chain integrity: every fetched file is verified against an
# expected SHA-256 BEFORE being placed in blobs/. A failed verification
# deletes the temp download and exits non-zero. SHAs for upstream files
# are taken from config/blobs.yml (which postgres-release maintains).
# The pgvector SHA is pinned here and reviewed at each version bump.

set -euo pipefail

# Pinned versions — keep README + CI cache keys + this script in sync.
PG15_VERSION="${PG15_VERSION:-15.18}"
PG16_VERSION="${PG16_VERSION:-16.14}"
PG17_VERSION="${PG17_VERSION:-17.10}"
YQ_VERSION="${YQ_VERSION:-4.53.2}"
PGVECTOR_VERSION="${PGVECTOR_VERSION:-0.8.0}"

# Expected SHA-256 hashes. For PostgreSQL these come from
# https://www.postgresql.org/ftp/source/ release pages. For yq from
# the GitHub release. For pgvector from the GitHub release SHA we
# verified at pin time. Update these when version pins change.
PG15_SHA256="${PG15_SHA256:-d32a533516edc688ebbb96ae221b605be2712edd94d7428b42a4af5644250943}"
PG16_SHA256="${PG16_SHA256:-ca18d43510bbb09a271383e1aa705b05b76bc8e9400f9857178ba8ec54cf461a}"
PG17_SHA256="${PG17_SHA256:-e4b43025f32ea3d271be64365d284c8462cffd41d80db0c3df6fc62417a2d9dc}"
YQ_SHA256="${YQ_SHA256:-d56bf5c6819e8e696340c312bd70f849dc1678a7cda9c2ad63eebd906371d56b}"
PGVECTOR_SHA256="${PGVECTOR_SHA256:-867a2c328d4928a5a9d6f052cd3bc78c7d60228a9b914ad32aa3db88e9de27b0}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

mkdir -p blobs/postgres blobs/yq blobs/pgvector

# fetch_and_verify <url> <dest> <expected-sha256>
#
# If dest already exists with a matching SHA, skips the download. If
# present but SHA mismatches, fails loudly (operator decides whether
# to delete and re-fetch). Downloads to a .tmp file first, verifies,
# then atomically renames.
fetch_and_verify() {
  local url="$1" dest="$2" want_sha="$3"
  local tmp="${dest}.tmp"

  if [[ -s "${dest}" ]]; then
    local have_sha
    have_sha="$(sha256sum "${dest}" | awk '{print $1}')"
    if [[ "${have_sha}" == "${want_sha}" ]]; then
      echo "ok:     ${dest}  (sha matches)"
      return 0
    fi
    echo "MISMATCH at ${dest}" >&2
    echo "  expected: ${want_sha}" >&2
    echo "  have:     ${have_sha}" >&2
    echo "  Delete the file and re-run to re-fetch." >&2
    return 1
  fi

  echo "fetch:  ${dest}"
  curl -fsSL --retry 3 -o "${tmp}" "${url}"

  local have_sha
  have_sha="$(sha256sum "${tmp}" | awk '{print $1}')"
  if [[ "${have_sha}" != "${want_sha}" ]]; then
    echo "SHA VERIFICATION FAILED for ${url}" >&2
    echo "  expected: ${want_sha}" >&2
    echo "  got:      ${have_sha}" >&2
    rm -f "${tmp}"
    return 1
  fi

  mv "${tmp}" "${dest}"
  echo "ok:     ${dest}  (sha verified)"
}

fetch_and_verify \
  "https://ftp.postgresql.org/pub/source/v${PG15_VERSION}/postgresql-${PG15_VERSION}.tar.gz" \
  "blobs/postgres/postgresql-${PG15_VERSION}.tar.gz" \
  "${PG15_SHA256}"

fetch_and_verify \
  "https://ftp.postgresql.org/pub/source/v${PG16_VERSION}/postgresql-${PG16_VERSION}.tar.gz" \
  "blobs/postgres/postgresql-${PG16_VERSION}.tar.gz" \
  "${PG16_SHA256}"

fetch_and_verify \
  "https://ftp.postgresql.org/pub/source/v${PG17_VERSION}/postgresql-${PG17_VERSION}.tar.gz" \
  "blobs/postgres/postgresql-${PG17_VERSION}.tar.gz" \
  "${PG17_SHA256}"

fetch_and_verify \
  "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64" \
  "blobs/yq/postgres-yq-${YQ_VERSION}" \
  "${YQ_SHA256}"

fetch_and_verify \
  "https://github.com/pgvector/pgvector/archive/refs/tags/v${PGVECTOR_VERSION}.tar.gz" \
  "blobs/pgvector/pgvector-${PGVECTOR_VERSION}.tar.gz" \
  "${PGVECTOR_SHA256}"

echo ""
echo "All blobs fetched and verified. If this is a fresh checkout, run:"
echo "  bosh add-blob blobs/pgvector/pgvector-${PGVECTOR_VERSION}.tar.gz \\"
echo "    pgvector/pgvector-${PGVECTOR_VERSION}.tar.gz"
echo "to register the pgvector blob in config/blobs.yml, then:"
echo "  bosh create-release --force"
