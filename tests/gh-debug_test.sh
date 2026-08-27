#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

FAKE_BIN="$TMP_DIR/bin"
OUTPUT_DIR="$TMP_DIR/reports"
WORK_DIR="$TMP_DIR/work"
mkdir -p "$FAKE_BIN" "$OUTPUT_DIR" "$WORK_DIR"

cat > "$FAKE_BIN/git" <<'STUB'
#!/usr/bin/env bash
case "$*" in
  "clone https://github.com/github/debug-repo "*)
    if [ "${GIT_TRACE:-}" != "1" ] || [ "${GIT_TRANSFER_TRACE:-}" != "1" ] || [ "${GIT_CURL_VERBOSE:-}" != "1" ]; then
      printf 'missing git trace environment\n' >&2
      exit 65
    fi
    printf 'Cloning into %s over HTTPS\n' "${*: -1}"
    ;;
  "clone git@github.com:github/debug-repo "*)
    if [ "${GIT_TRACE:-}" != "1" ] || [ "${GIT_TRANSFER_TRACE:-}" != "1" ] || [ "${GIT_CURL_VERBOSE:-}" != "1" ]; then
      printf 'missing git trace environment\n' >&2
      exit 65
    fi
    printf 'Cloning into %s over SSH\n' "${*: -1}"
    ;;
  *)
    printf 'unexpected git args: %s\n' "$*" >&2
    exit 64
    ;;
esac
STUB
chmod +x "$FAKE_BIN/git"

cat > "$FAKE_BIN/ping" <<'STUB'
#!/usr/bin/env bash
if [ "$*" != "-c 10 github.com" ]; then
  printf 'unexpected ping args: %s\n' "$*" >&2
  exit 64
fi
printf '10 packets transmitted, 10 received\n'
STUB
chmod +x "$FAKE_BIN/ping"

cat > "$FAKE_BIN/traceroute" <<'STUB'
#!/usr/bin/env bash
if [ "$*" != "github.com" ]; then
  printf 'unexpected traceroute args: %s\n' "$*" >&2
  exit 64
fi
printf 'traceroute to github.com\n'
STUB
chmod +x "$FAKE_BIN/traceroute"

cat > "$FAKE_BIN/curl" <<'STUB'
#!/usr/bin/env bash
last_arg=${!#}
case "$last_arg" in
  https://github.com)
    printf 'downloadspeed: 12345 | dnslookup: 0.001 | connect: 0.002 | appconnect: 0.003 | pretransfer: 0.004 | starttransfer: 0.005 | total: 0.006 | size: 123\n'
    ;;
  https://github-debug.com/api)
    printf '{"ip":"127.0.0.1","user_agent":"test","served_by":"stub","request_id":"abc"}\n'
    ;;
  https://github.com/images/github-debug-test.jpg\?n=*|https://github.githubassets.com/images/github-debug-test.jpg\?n=*|https://*/github-debug-test.jpg\?n=*)
    printf 'asset download ok\n'
    ;;
  *)
    printf 'unexpected curl url: %s\nargs: %s\n' "$last_arg" "$*" >&2
    exit 64
    ;;
esac
STUB
chmod +x "$FAKE_BIN/curl"

STDOUT_FILE="$TMP_DIR/stdout.txt"
PATH="$FAKE_BIN:$PATH" "$ROOT_DIR/gh-debug" --output-dir "$OUTPUT_DIR" --work-dir "$WORK_DIR" > "$STDOUT_FILE"

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

connection_count=$(grep -c '^## Connection data:' "$REPORT_FILE")
if [ "$connection_count" -ne 20 ]; then
  printf 'expected 20 connection data checks, found %s\n' "$connection_count" >&2
  exit 1
fi

assert_contains "$STDOUT_FILE" '# GitHub Debug Report'
assert_contains "$STDOUT_FILE" 'GIT_TRACE=1 GIT_TRANSFER_TRACE=1 GIT_CURL_VERBOSE=1 git clone https://github.com/github/debug-repo'
assert_contains "$REPORT_FILE" '## Git clone over HTTPS'
assert_contains "$REPORT_FILE" '## Git clone over SSH'
assert_contains "$REPORT_FILE" '## Ping github.com'
assert_contains "$REPORT_FILE" '## Traceroute github.com'
assert_contains "$REPORT_FILE" '## Curl timing for github.com'
assert_contains "$REPORT_FILE" '## github-debug.com API data'
assert_contains "$REPORT_FILE" '## Connection data: github.githubassets.com'
assert_contains "$REPORT_FILE" 'https://github.githubassets.com/images/github-debug-test.jpg?n='
assert_contains "$REPORT_FILE" '## Connection data: github-cloud.s3.amazonaws.com'
assert_contains "$REPORT_FILE" 'https://github-cloud.s3.amazonaws.com/github-debug-test.jpg?n='
assert_contains "$REPORT_FILE" '2507998 bytes downloaded from github-cloud.s3.amazonaws.com at '
assert_not_contains "$REPORT_FILE" 'api/testconnect'
assert_contains "$STDOUT_FILE" "Report written to $REPORT_FILE"
assert_not_contains "$REPORT_FILE" 'secret-token'
assert_not_contains "$STDOUT_FILE" 'secret-token'

printf 'gh-debug tests passed\n'
