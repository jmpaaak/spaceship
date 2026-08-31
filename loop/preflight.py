#!/usr/bin/env python3
"""Deterministic gate for each Spaceship autonomous cycle."""

from __future__ import annotations

import os
from pathlib import Path
import subprocess
import sys

READY = 0
CHECK_FAILED = 1
INTERNAL_ERROR = 2
IDLE = 3


def pending_feedback(root: Path) -> list[str]:
    path = root / "docs" / "feedback" / "INBOX.md"
    text = path.read_text(encoding="utf-8")
    before, marker, after = text.partition("## 처리 대기")
    if not marker or "## 처리 완료" not in after:
        raise RuntimeError("feedback inbox must contain one pending and completed section")
    section = after.split("## 처리 완료", 1)[0]
    return [line for line in section.splitlines() if line.strip().startswith("-")]


def check(label: str, command: list[str], root: Path, env: dict[str, str], timeout: int) -> tuple[bool, str]:
    try:
        result = subprocess.run(
            command,
            cwd=root,
            env=env,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout,
            check=False,
        )
    except (OSError, subprocess.SubprocessError) as exc:
        return False, str(exc)
    return result.returncode == 0, result.stdout.strip()


def main() -> int:
    root = Path(os.environ.get("LOOP_ROOT", Path(__file__).resolve().parents[1])).resolve()
    env = os.environ.copy()
    love = "/Users/jm/.local/bin/love"
    checks = [
        ("engine tests and package", ["make", "verify", f"LOVE={love}"], 120),
        ("git diff check", ["git", "diff", "--check"], 20),
    ]
    failures = []
    for label, command, timeout in checks:
        passed, output = check(label, command, root, env, timeout)
        print(f"[preflight] {label}: {'PASS' if passed else 'FAIL'}", flush=True)
        if not passed:
            failures.append(f"### {label}\n{output[-3000:] or 'no output'}")
    if failures:
        print("PREFLIGHT_RESULT=FAIL")
        print("\n\n".join(failures))
        return CHECK_FAILED
    pending = pending_feedback(root)
    if pending:
        print("PREFLIGHT_RESULT=READY")
        print("PENDING_FEEDBACK:")
        print("\n".join(pending))
        return READY
    print("PREFLIGHT_RESULT=IDLE")
    return IDLE


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"PREFLIGHT_RESULT=INTERNAL_ERROR\n{exc}", file=sys.stderr)
        raise SystemExit(INTERNAL_ERROR)
