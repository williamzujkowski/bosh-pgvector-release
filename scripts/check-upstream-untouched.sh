#!/usr/bin/env bash
# Warn (not fail) when staged changes touch upstream files. The thin-fork
# policy in ADR-0001 says modifications to upstream should be rare and
# justified; this hook surfaces them in the pre-commit run so reviewers
# can sanity-check.
set -euo pipefail

# Get staged file paths. Falls back to listing all changed files if no
# staged set (e.g. when run from CI on a PR diff).
staged="$(git diff --cached --name-only 2>/dev/null || true)"
if [[ -z "${staged}" ]]; then
  # CI mode: compare to merge-base with origin/main if available.
  base="$(git merge-base HEAD origin/main 2>/dev/null || echo)"
  if [[ -n "${base}" ]]; then
    staged="$(git diff --name-only "${base}" HEAD || true)"
  fi
fi

if [[ -z "${staged}" ]]; then
  exit 0
fi

allow_re='^(packages/pgvector-(15|16|17)(/|$)|docs/|AGENTS\.md$|CLAUDE\.md$|README\.md$|NOTICE$|SECURITY\.md$|CONTRIBUTING\.md$|CHANGELOG\.md$|\.pre-commit-config\.yaml$|\.markdownlint\.json$|\.yamllint\.yml$|\.secrets\.baseline$|\.gitignore$|\.github/|scripts/fetch-blobs\.sh$|scripts/lint_specs\.py$|scripts/check-upstream-untouched\.sh$|jobs/postgres/spec$|config/blobs\.yml$)'

flagged=0
while IFS= read -r path; do
  [[ -z "${path}" ]] && continue
  if ! [[ "${path}" =~ ${allow_re} ]]; then
    if ((flagged == 0)); then
      echo "=========================================================" >&2
      echo "check-upstream-untouched: the following files are upstream" >&2
      echo "  postgres-release content. Modifying them is allowed but " >&2
      echo "  per ADR-0001 should be rare and well-justified. Confirm:" >&2
      echo "=========================================================" >&2
    fi
    echo "  WARN: ${path}" >&2
    flagged=1
  fi
done <<<"${staged}"

if ((flagged == 1)); then
  echo "" >&2
  echo "If these changes are intentional, add a note to the PR description" >&2
  echo "explaining why they can't be sent upstream first. To bypass this" >&2
  echo "check for a single commit, use:" >&2
  echo "    SKIP=no-modify-upstream git commit ..." >&2
  echo "" >&2
fi

# This hook *warns* but does not fail; we don't block commits.
exit 0
