#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

found_uses=0
while IFS= read -r line; do
  found_uses=1
  if [[ ! $line =~ uses:[[:space:]]+[^[:space:]]+@[0-9a-f]{40}[[:space:]]+#[[:space:]]+v[0-9]+\.[0-9]+\.[0-9]+ ]]; then
    printf 'workflow action is not pinned to a SHA with a semver comment: %s\n' "$line" >&2
    exit 1
  fi
done < <(grep -Rh '^[[:space:]]*uses:' .github/workflows || true)

if [ "$found_uses" -ne 1 ]; then
  printf 'expected at least one workflow action use to verify\n' >&2
  exit 1
fi

if ! grep -Fq 'package-ecosystem: github-actions' .github/dependabot.yml; then
  printf 'dependabot is not configured for GitHub Actions\n' >&2
  exit 1
fi

printf 'workflow pinning tests passed\n'
