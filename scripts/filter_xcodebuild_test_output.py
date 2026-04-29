#!/usr/bin/env python3

from __future__ import annotations

from pathlib import Path
import re
import sys
from typing import Iterable, List


NOISE_PATTERNS = [
    re.compile(r"^note: Removed stale file '.*'$"),
    re.compile(
        r"^warning: Stale file '.*' is located outside of the allowed root paths\.$"
    ),
    re.compile(
        r"^\d{4}-\d{2}-\d{2} .*appintentsmetadataprocessor.*Starting appintentsmetadataprocessor export$"
    ),
    re.compile(
        r"^\d{4}-\d{2}-\d{2} .*appintentsmetadataprocessor.*warning: Metadata extraction skipped\. No AppIntents\.framework dependency found\.$"
    ),
    re.compile(
        r"^\d{4}-\d{2}-\d{2} .*IDETestOperationsObserverDebug: .* Testing started completed\.$"
    ),
    re.compile(r"^\d{4}-\d{2}-\d{2} .*IDETestOperationsObserverDebug: .* -- start$"),
    re.compile(r"^\d{4}-\d{2}-\d{2} .*IDETestOperationsObserverDebug: .* -- end$"),
]


def filter_lines(lines: Iterable[str]) -> List[str]:
    filtered: List[str] = []
    for line in lines:
        if any(pattern.match(line) for pattern in NOISE_PATTERNS):
            continue
        filtered.append(line)
    return filtered


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: filter_xcodebuild_test_output.py <logfile>", file=sys.stderr)
        return 2

    log_path = Path(sys.argv[1])
    lines = log_path.read_text().splitlines()
    filtered = filter_lines(lines)
    for line in filtered:
        print(line)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
