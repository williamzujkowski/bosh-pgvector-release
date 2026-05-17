#!/usr/bin/env bash
# Assert that packages/pgvector-{15,16,17}/packaging differ only by the
# POSTGRES_VERSION= line — i.e. all executable logic is identical across
# the three Postgres majors.
#
# Why: the three packaging scripts are a 3-way copy of the same logic.
# A fix made to one can silently miss the other two on a version bump.
# We considered extracting a shared helper into a `pgvector-common`
# package that each pgvector-N depends on (the BOSH-idiomatic answer),
# but the thin-fork policy prefers the smaller-surface alternative:
# a CI check that asserts parity. See issue #2 (item #20) + ADR-0002.
#
# What the check does: strip comments and blank lines from each script,
# then replace the lone `POSTGRES_VERSION=<n>` line with a sentinel
# (`POSTGRES_VERSION=<NORMALIZED>`). The three normalized streams must
# have an identical sha256. On mismatch we print a diff and exit 1.
#
# We strip comments because pgvector-15/packaging carries the design-doc
# block (DESTDIR rationale, OPTFLAGS rationale, manifest rationale) and
# pgvector-16/17/packaging carry only a pointer back to it. That is
# intentional — comment drift is not a correctness risk; executable-line
# drift is.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

PACKAGES=(
  packages/pgvector-15/packaging
  packages/pgvector-16/packaging
  packages/pgvector-17/packaging
)

# Sanity: every input file must exist.
for f in "${PACKAGES[@]}"; do
  if [[ ! -f "${f}" ]]; then
    echo "ERROR: ${f} not found" >&2
    exit 1
  fi
done

# normalize: strip full-line comments (lines whose first non-whitespace
# char is `#`, except the shebang on line 1 which we drop too), strip
# blank lines, and replace the POSTGRES_VERSION= line with a sentinel.
# We deliberately do NOT strip trailing inline comments — bash inline
# comments after a command are uncommon in these scripts and tooling
# (shfmt) would normalize them anyway.
normalize() {
  local f="$1"
  # sed: drop the shebang (line 1), drop any line that is whitespace
  # followed by `#` (full-line comment), drop blank lines, and rewrite
  # `POSTGRES_VERSION=<digits>` to the sentinel.
  sed -E \
    -e '1{/^#!/d;}' \
    -e '/^[[:space:]]*#/d' \
    -e '/^[[:space:]]*$/d' \
    -e 's/^POSTGRES_VERSION=[0-9]+$/POSTGRES_VERSION=<NORMALIZED>/' \
    "${f}"
}

# Hash each normalized stream.
declare -a HASHES=()
declare -a NORMALIZED_TMP=()
trap 'rm -f "${NORMALIZED_TMP[@]}"' EXIT

for f in "${PACKAGES[@]}"; do
  tmp="$(mktemp)"
  NORMALIZED_TMP+=("${tmp}")
  normalize "${f}" >"${tmp}"
  HASHES+=("$(sha256sum "${tmp}" | awk '{print $1}')")
done

# Compare: every hash must equal the first.
mismatch=0
for i in 1 2; do
  if [[ "${HASHES[$i]}" != "${HASHES[0]}" ]]; then
    mismatch=1
  fi
done

if [[ "${mismatch}" -eq 0 ]]; then
  echo "OK: packages/pgvector-{15,16,17}/packaging differ only by POSTGRES_VERSION="
  echo "  sha256(normalized) = ${HASHES[0]}"
  exit 0
fi

echo "ERROR: packages/pgvector-{15,16,17}/packaging diverge beyond POSTGRES_VERSION=" >&2
echo "" >&2
for i in 0 1 2; do
  echo "  ${PACKAGES[$i]}  sha256(normalized) = ${HASHES[$i]}" >&2
done
echo "" >&2
echo "Diff of normalized streams (pgvector-15 vs pgvector-16):" >&2
diff -u "${NORMALIZED_TMP[0]}" "${NORMALIZED_TMP[1]}" >&2 || true
echo "" >&2
echo "Diff of normalized streams (pgvector-16 vs pgvector-17):" >&2
diff -u "${NORMALIZED_TMP[1]}" "${NORMALIZED_TMP[2]}" >&2 || true
echo "" >&2
echo "If the divergence is intentional (e.g. a version-specific workaround)," >&2
echo "update this check or move the shared logic into a pgvector-common package." >&2
exit 1
