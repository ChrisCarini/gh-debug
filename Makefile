.PHONY: lint test

lint:
	bash -n gh-debug tests/gh-debug_test.sh
	if command -v shellcheck >/dev/null 2>&1; then shellcheck gh-debug tests/gh-debug_test.sh; else echo "shellcheck not installed; skipping"; fi

test:
	bash tests/gh-debug_test.sh
