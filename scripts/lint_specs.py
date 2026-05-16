#!/usr/bin/env python3
"""Validate that every packages/*/spec file is well-formed YAML and has
the required keys. Run as a pre-commit hook.

BOSH itself parses these files; this is just a cheap fail-fast check
that catches typos before `bosh create-release` does.
"""

from __future__ import annotations

import sys
from pathlib import Path

import yaml


REQUIRED_KEYS = ("name", "files")


def check(spec_path: Path) -> list[str]:
    """Return a list of error strings, or [] if the spec is valid."""
    errors: list[str] = []
    try:
        data = yaml.safe_load(spec_path.read_text())
    except yaml.YAMLError as e:
        return [f"{spec_path}: YAML parse error: {e}"]
    if not isinstance(data, dict):
        return [f"{spec_path}: top-level must be a mapping"]
    for key in REQUIRED_KEYS:
        if key not in data:
            errors.append(f"{spec_path}: missing required key '{key}'")
    name = data.get("name", "")
    if name and not isinstance(name, str):
        errors.append(f"{spec_path}: 'name' must be a string")
    if name and name != spec_path.parent.name:
        errors.append(
            f"{spec_path}: 'name' is {name!r} but parent dir is "
            f"{spec_path.parent.name!r}"
        )
    files = data.get("files", [])
    if files is None:
        files = []
    if not isinstance(files, list):
        errors.append(f"{spec_path}: 'files' must be a list")
    return errors


def main() -> int:
    spec_paths = sorted(Path("packages").glob("*/spec"))
    if not spec_paths:
        print("lint_specs: no package specs found under packages/*/spec", file=sys.stderr)
        return 0
    all_errors: list[str] = []
    for path in spec_paths:
        all_errors.extend(check(path))
    if all_errors:
        for line in all_errors:
            print(f"lint_specs: {line}", file=sys.stderr)
        return 1
    print(f"lint_specs: OK — {len(spec_paths)} package specs valid")
    return 0


if __name__ == "__main__":
    sys.exit(main())
