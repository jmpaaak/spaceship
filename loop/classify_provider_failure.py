#!/usr/bin/env python3
"""Classify a failed primary coding cycle without broad false positives."""

from __future__ import annotations

import re
import sys
from pathlib import Path

_STRONG_CODEX_LIMIT_PATTERNS = (
    re.compile(r"\busage_limit_reached\b", re.IGNORECASE),
    re.compile(r"\brate_limit_exceeded\b", re.IGNORECASE),
    re.compile(r"\bHTTP(?:/\S+)?\s+429\b", re.IGNORECASE),
    re.compile(r"\b(?:error|status)(?:\s+code)?\s*[:=]\s*429\b", re.IGNORECASE),
    re.compile(r"\byou(?:'|’)ve hit your usage limit\b", re.IGNORECASE),
    re.compile(r"\b(?:codex|chatgpt).{0,80}\busage limit (?:reached|exceeded)\b", re.IGNORECASE),
)


def is_codex_rate_limit(output: str, exit_status: int) -> bool:
    """True only for a failed cycle with a strong upstream limit marker."""
    if exit_status == 0:
        return False
    return any(pattern.search(output) for pattern in _STRONG_CODEX_LIMIT_PATTERNS)


def main(argv: list[str] | None = None) -> int:
    arguments = list(sys.argv[1:] if argv is None else argv)
    if len(arguments) != 2:
        print("usage: classify_provider_failure.py OUTPUT_FILE EXIT_STATUS", file=sys.stderr)
        return 2
    path = Path(arguments[0])
    try:
        status = int(arguments[1])
        output = path.read_text(encoding="utf-8", errors="replace")
    except (OSError, ValueError) as error:
        print(f"provider failure classification failed: {error}", file=sys.stderr)
        return 2
    return 0 if is_codex_rate_limit(output, status) else 1


if __name__ == "__main__":
    raise SystemExit(main())
