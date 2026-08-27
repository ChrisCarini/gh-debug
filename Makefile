.PHONY: lint test

lint:
	bash -n gh-debug tests/gh-debug_test.sh tests/github_debug_snapshot_test.sh tests/workflow_pinning_test.sh
	python3 -m py_compile scripts/github_debug_snapshot.py
	if command -v shellcheck >/dev/null 2>&1; then shellcheck gh-debug tests/gh-debug_test.sh tests/github_debug_snapshot_test.sh tests/workflow_pinning_test.sh; else echo "shellcheck not installed; skipping"; fi

test:
	bash tests/gh-debug_test.sh
	bash tests/github_debug_snapshot_test.sh
	bash tests/workflow_pinning_test.sh
