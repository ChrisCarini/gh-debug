#!/usr/bin/env python3
"""Extract and compare meaningful github-debug.com diagnostics inputs."""

from __future__ import annotations

import argparse
import difflib
import html.parser
import json
import re
import sys
import urllib.request
from pathlib import Path
from typing import Iterable


class PreExtractor(html.parser.HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self._depth = 0
        self._chunks: list[str] = []
        self.blocks: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag == "pre":
            self._depth += 1
            if self._depth == 1:
                self._chunks = []

    def handle_endtag(self, tag: str) -> None:
        if tag == "pre" and self._depth:
            self._depth -= 1
            if self._depth == 0:
                self.blocks.append("".join(self._chunks))

    def handle_data(self, data: str) -> None:
        if self._depth:
            self._chunks.append(data)


def read_source(source: str) -> str:
    if source.startswith(("http://", "https://")):
        request = urllib.request.Request(source, headers={"User-Agent": "gh-debug-snapshot-check"})
        with urllib.request.urlopen(request, timeout=30) as response:
            return response.read().decode("utf-8", errors="replace")
    return Path(source).read_text(encoding="utf-8")


def extract_commands(html: str) -> dict[str, list[str]]:
    parser = PreExtractor()
    parser.feed(html)
    command_blocks = [block for block in parser.blocks if "git clone" in block]
    linux = normalize_command_block(command_blocks[0]) if command_blocks else []
    windows = normalize_command_block(command_blocks[1]) if len(command_blocks) > 1 else []
    return {"linux_macos": linux, "windows": windows}


def normalize_command_block(block: str) -> list[str]:
    commands: list[str] = []
    for raw_line in block.splitlines():
        line = " ".join(raw_line.strip().split())
        if line:
            commands.append(line)
    return commands


def extract_string_array(js: str, name: str) -> list[str]:
    match = re.search(rf"var\s+{re.escape(name)}\s*=\s*\[(.*?)\]", js, flags=re.DOTALL)
    if not match:
        return []
    return re.findall(r'["\']([^"\']+)["\']', match.group(1))


def extract_test_assets(js: str) -> dict[str, dict[str, int | str]]:
    assets: dict[str, dict[str, int | str]] = {}
    for match in re.finditer(
        r'["\']([^"\']+)["\']\s*:\s*\{\s*["\']path["\']\s*:\s*["\']([^"\']+)["\']\s*,\s*["\']bytes["\']\s*:\s*(\d+)\s*\}',
        js,
        flags=re.DOTALL,
    ):
        assets[match.group(1)] = {"path": match.group(2), "bytes": int(match.group(3))}
    return assets


def extract_var_string(js: str, name: str) -> str | None:
    match = re.search(rf"""var\s+{re.escape(name)}\s*=\s*["']([^"']+)["']""", js)
    return match.group(1) if match else None


def build_snapshot(html: str, js: str) -> dict[str, object]:
    return {
        "commands": extract_commands(html),
        "test_assets": extract_test_assets(js),
        "sites": extract_string_array(js, "sites"),
        "api_endpoint": extract_var_string(js, "url"),
        "test_connection_endpoint": extract_var_string(js, "testconnection"),
    }


def unified_diff(expected: dict[str, object], actual: dict[str, object]) -> str:
    expected_json = json.dumps(expected, indent=2, sort_keys=True).splitlines(keepends=True)
    actual_json = json.dumps(actual, indent=2, sort_keys=True).splitlines(keepends=True)
    return "".join(
        difflib.unified_diff(
            expected_json,
            actual_json,
            fromfile="expected github-debug snapshot",
            tofile="actual github-debug snapshot",
        )
    )


def parse_args(argv: Iterable[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--html", help="HTML file or URL to inspect")
    parser.add_argument("--js", help="JavaScript file or URL to inspect")
    parser.add_argument("--live", action="store_true", help="Fetch https://github-debug.com/ and /js/main.js")
    parser.add_argument("--expected", help="Expected snapshot JSON file")
    parser.add_argument("--write", help="Write extracted snapshot JSON to this file")
    parser.add_argument("--check", action="store_true", help="Compare extracted snapshot with --expected")
    return parser.parse_args(list(argv))


def main(argv: Iterable[str] = sys.argv[1:]) -> int:
    args = parse_args(argv)
    if args.live:
        html_source = "https://github-debug.com/"
        js_source = "https://github-debug.com/js/main.js"
    elif args.html and args.js:
        html_source = args.html
        js_source = args.js
    else:
        raise SystemExit("provide --live or both --html and --js")

    snapshot = build_snapshot(read_source(html_source), read_source(js_source))

    if args.write:
        Path(args.write).write_text(json.dumps(snapshot, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    if args.check:
        if not args.expected:
            raise SystemExit("--check requires --expected")
        expected = json.loads(Path(args.expected).read_text(encoding="utf-8"))
        if snapshot != expected:
            print("github-debug.com meaningful diagnostics changed")
            print(unified_diff(expected, snapshot))
            return 1
        print("github-debug.com meaningful diagnostics match expected snapshot")

    if not args.check:
        print(json.dumps(snapshot, indent=2, sort_keys=True))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
