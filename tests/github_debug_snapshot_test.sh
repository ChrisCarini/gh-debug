#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

python3 "$ROOT_DIR/scripts/github_debug_snapshot.py" \
  --html "$ROOT_DIR/tests/fixtures/github-debug.html" \
  --js "$ROOT_DIR/tests/fixtures/github-debug.js" \
  --expected "$ROOT_DIR/tests/fixtures/github-debug-expected.json" \
  --check > "$TMP_DIR/match.out"

grep -Fq 'match expected snapshot' "$TMP_DIR/match.out"

python3 "$ROOT_DIR/scripts/github_debug_snapshot.py" \
  --html "$ROOT_DIR/tests/fixtures/github-debug.html" \
  --js "$ROOT_DIR/tests/fixtures/github-debug.js" \
  --write "$TMP_DIR/generated.json" > "$TMP_DIR/generated.out"

diff -u "$ROOT_DIR/tests/fixtures/github-debug-expected.json" "$TMP_DIR/generated.json"

python3 - "$ROOT_DIR/tests/fixtures/github-debug-expected.json" "$TMP_DIR/changed.json" <<'PY'
import json
import sys
source, target = sys.argv[1:]
with open(source, encoding="utf-8") as handle:
    data = json.load(handle)
data["sites"].append("new-region.github-debug.com")
with open(target, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY

if python3 "$ROOT_DIR/scripts/github_debug_snapshot.py" \
  --html "$ROOT_DIR/tests/fixtures/github-debug.html" \
  --js "$ROOT_DIR/tests/fixtures/github-debug.js" \
  --expected "$TMP_DIR/changed.json" \
  --check > "$TMP_DIR/diff.out"; then
  printf 'expected snapshot mismatch to fail\n' >&2
  exit 1
fi

grep -Fq 'github-debug.com meaningful diagnostics changed' "$TMP_DIR/diff.out"
grep -Fq 'new-region.github-debug.com' "$TMP_DIR/diff.out"

printf 'github-debug snapshot tests passed\n'
