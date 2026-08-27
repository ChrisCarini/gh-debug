#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

FAKE_BIN="$TMP_DIR/bin"
OUTPUT_DIR="$TMP_DIR/reports"
mkdir -p "$FAKE_BIN" "$OUTPUT_DIR"

cat > "$FAKE_BIN/gh" <<'STUB'
#!/usr/bin/env bash
case "$*" in
  "--version")
    printf 'gh version 9.9.9 (test)\n'
    ;;
  "auth status")
    printf 'github.com: Logged in to github.com account test-user\n'
    ;;
  "api /user")
    printf '{"login":"test-user"}\n'
    ;;
  "api /rate_limit")
    printf '{"rate":{"remaining":4999}}\n'
    ;;
  "api /meta")
    printf '{"verifiable_password_authentication":true}\n'
    ;;
  "repo view --json nameWithOwner,defaultBranchRef,viewerPermission,isPrivate")
    printf '{"nameWithOwner":"example/repo","isPrivate":false}\n'
    ;;
  *)
    printf 'unexpected gh args: %s\n' "$*" >&2
    exit 64
    ;;
esac
STUB
chmod +x "$FAKE_BIN/gh"

cat > "$FAKE_BIN/git" <<'STUB'
#!/usr/bin/env bash
case "$*" in
  "--version")
    printf 'git version 2.99.0\n'
    ;;
  "rev-parse --is-inside-work-tree")
    printf 'true\n'
    ;;
  "status --short --branch")
    printf '## main...origin/main\n'
    ;;
  "remote -v")
    printf 'origin\thttps://secret-token@github.com/example/repo.git (fetch)\n'
    printf 'origin\thttps://secret-token@github.com/example/repo.git (push)\n'
    ;;
  "config --get remote.origin.url")
    printf 'https://secret-token@github.com/example/repo.git\n'
    ;;
  "config --get user.name")
    printf 'Test User\n'
    ;;
  "config --get user.email")
    printf 'test@example.com\n'
    ;;
  *)
    printf 'unexpected git args: %s\n' "$*" >&2
    exit 64
    ;;
esac
STUB
chmod +x "$FAKE_BIN/git"

STDOUT_FILE="$TMP_DIR/stdout.txt"
PATH="$FAKE_BIN:$PATH" "$ROOT_DIR/gh-debug" --output-dir "$OUTPUT_DIR" > "$STDOUT_FILE"

mapfile -t reports < <(find "$OUTPUT_DIR" -maxdepth 1 -type f -name 'gh-debug-*.md' | sort)
if [ "${#reports[@]}" -ne 1 ]; then
  printf 'expected exactly one report, found %s\n' "${#reports[@]}" >&2
  exit 1
fi

REPORT_FILE=${reports[0]}
REPORT_NAME=$(basename "$REPORT_FILE")
if [[ ! $REPORT_NAME =~ ^gh-debug-[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}-[0-9]{2}-[0-9]{2}Z\.md$ ]]; then
  printf 'report name is not ISO-8601 timestamped: %s\n' "$REPORT_NAME" >&2
  exit 1
fi

assert_contains() {
  local file=$1
  local expected=$2
  if ! grep -Fq "$expected" "$file"; then
    printf 'expected %s to contain: %s\n' "$file" "$expected" >&2
    exit 1
  fi
}

assert_not_contains() {
  local file=$1
  local unexpected=$2
  if grep -Fq "$unexpected" "$file"; then
    printf 'expected %s not to contain: %s\n' "$file" "$unexpected" >&2
    exit 1
  fi
}

assert_contains "$STDOUT_FILE" '# GitHub Debug Report'
assert_contains "$STDOUT_FILE" 'gh version 9.9.9 (test)'
assert_contains "$STDOUT_FILE" "Report written to $REPORT_FILE"
assert_contains "$REPORT_FILE" 'Generated at:'
assert_contains "$REPORT_FILE" '## GitHub CLI Authentication'
assert_contains "$REPORT_FILE" '## GitHub API Rate Limit'
assert_contains "$REPORT_FILE" '## Git Remotes'
assert_contains "$REPORT_FILE" 'https://***@github.com/example/repo.git'
assert_not_contains "$REPORT_FILE" 'secret-token'
assert_not_contains "$STDOUT_FILE" 'secret-token'

printf 'gh-debug tests passed\n'
