# gh-debug

A GitHub CLI extension that mimics the diagnostics collected by
[github-debug.com](https://github-debug.com/).

The extension runs the local Git/network commands from the website, performs the
same sequential connection data checks against GitHub and regional debug asset
hosts, prints all diagnostic output to the terminal, and writes the same output
to an ISO-8601 timestamped markdown report.

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

Use a specific directory for clone test targets:

```sh
gh debug --work-dir /tmp
```

Reports are named like `gh-debug-2026-08-27T13-50-35Z.md`.

## Diagnostics collected

On Linux and macOS, the extension runs:

- `GIT_TRACE=1 GIT_TRANSFER_TRACE=1 GIT_CURL_VERBOSE=1 git clone https://github.com/github/debug-repo /tmp/debug-repo-http`
- `GIT_TRACE=1 GIT_TRANSFER_TRACE=1 GIT_CURL_VERBOSE=1 git clone git@github.com:github/debug-repo /tmp/debug-repo-ssh`
- `ping -c 10 github.com`
- `traceroute github.com`
- `curl -s -o/dev/null -w ... https://github.com`

On Windows-like shells, it runs the website's Windows commands:

- `git clone https://github.com/github/debug-repo debug-repo-http`
- `git clone git@github.com:github/debug-repo debug-repo-ssh`
- `ping -n 10 github.com`
- `tracert github.com`

The connection data section mirrors the webpage's automatic `/api` request and
then runs sequential download checks for the `github-debug-test.jpg` asset
against:

- `github.com`
- `cloud.githubusercontent.com`
- `avatars.githubusercontent.com`
- `github.githubassets.com`
- `australiaeast.github-debug.com`
- `brazilsouth.github-debug.com`
- `centralindia.github-debug.com`
- `fra.github-debug.com`
- `iad.github-debug.com`
- `israelcentral.github-debug.com`
- `japaneast.github-debug.com`
- `koreacentral.github-debug.com`
- `northeurope.github-debug.com`
- `sea.github-debug.com`
- `southafricanorth.github-debug.com`
- `southeastasia.github-debug.com`
- `swedencentral.github-debug.com`
- `uaenorth.github-debug.com`
- `uksouth.github-debug.com`
- `github-cloud.s3.amazonaws.com`

It does not run extra GitHub CLI/API diagnostics beyond the commands and
automatic requests represented on the webpage.

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

## Maintenance

GitHub Actions workflow actions are pinned to commit SHAs with semver comments.
Dependabot is configured to keep those GitHub Actions references up to date.

The `Monitor github-debug.com` workflow runs daily and on demand. It compares the
live webpage's meaningful diagnostics inputs (listed commands, test asset data,
hosts, and API endpoints) against `.github/github-debug-snapshot.json` and opens
an issue when the checked-in snapshot no longer matches the site.
