# gh-debug

A GitHub CLI extension to mimic the diagnostics collected by github-debug.com.

The extension runs a focused set of GitHub CLI, GitHub API, and local Git checks,
prints the diagnostic output to the terminal, and writes the same output to an
ISO-8601 timestamped markdown report.

## Installation

```sh
gh extension install ChrisCarini/gh-debug
```

For local development from a clone:

```sh
gh extension install .
```

## Usage

```sh
gh debug
```

Write the markdown report to a specific directory:

```sh
gh debug --output-dir ./debug-reports
```

Reports are named like `gh-debug-2026-08-27T13-50-35Z.md`.

## Diagnostics collected

- GitHub CLI version and authentication status
- GitHub API `/user`, `/rate_limit`, and `/meta` responses
- Current repository details from `gh repo view`
- Git version, repository status, remotes, origin URL, and configured user

Potential credentials embedded in HTTPS remote URLs and common GitHub token
formats are redacted from both terminal and markdown output.

## Development

Run linting/static analysis:

```sh
make lint
```

Run tests:

```sh
make test
```
