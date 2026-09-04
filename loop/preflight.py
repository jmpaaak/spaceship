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
    return [
        line for line in section.splitlines()
        if line.strip().startswith("-") or (line.strip() and line.strip()[0].isdigit() and "." in line.strip())
    ]


MAX_PENDING_PROMPT_ITEMS = 4
MAX_PENDING_PROMPT_CHARS = 220


def compact_pending_feedback(pending: list[str]) -> list[str]:
    """Keep only short titles in the cycle prompt; the agent reads INBOX.md."""
    titles: list[str] = []
    for line in pending:
        stripped = line.strip()
        if not stripped.startswith("-"):
            continue
        cut = stripped
        for marker in (":**", ":"):
            index = stripped.find(marker)
            if 0 < index <= MAX_PENDING_PROMPT_CHARS:
                cut = stripped[: index + (1 if marker == ":" else 3)]
                break
        else:
            cut = stripped[:MAX_PENDING_PROMPT_CHARS].rstrip()
        titles.append(cut)
    if not titles:
        return pending
    header = [
        "PENDING_FEEDBACK titles only. Read docs/feedback/INBOX.md 처리 대기 for the full text of the one item this cycle will finish.",
    ]
    shown = titles[:MAX_PENDING_PROMPT_ITEMS]
    omitted = len(titles) - len(shown)
    if omitted:
        shown.append(f"- ({omitted} more pending items omitted from this cycle prompt)")
    return header + shown


DOC_ONLY_PATHS = {"docs/STATUS.md", "docs/STATUS_HISTORY.md", "docs/feedback/INBOX.md"}
DOC_ONLY_STREAK_THRESHOLD = 3


def recent_commits_doc_only_streak(root: Path, n: int = DOC_ONLY_STREAK_THRESHOLD) -> bool:
    """True if the last n commits touched only doc/status-report files.

    This is the deterministic signature of a lane stuck re-confirming
    out-of-scope INBOX items every cycle with no real product change --
    e.g. 10+ consecutive "lane reconfirms scope, no code changes"
    commits. Requires at least n commits of history to fire (avoids a
    false positive on a freshly scaffolded lane).
    """
    try:
        result = subprocess.run(
            ["git", "log", f"-n{n}", "--name-only", "--pretty=format:__COMMIT__"],
            cwd=root,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            timeout=15,
            check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return False
    if result.returncode != 0 or not result.stdout.strip():
        return False
    commits = [c for c in result.stdout.split("__COMMIT__") if c.strip()]
    if len(commits) < n:
        return False
    for commit in commits:
        files = {line.strip() for line in commit.splitlines() if line.strip()}
        if not files or not files.issubset(DOC_ONLY_PATHS):
            return False
    return True


def write_auto_stop(root: Path, reason: str) -> None:
    stop_path = root / "loop" / "STOP"
    try:
        stop_path.write_text(
            f"Auto-stopped by preflight.py: {reason}\n"
            "Remove this file to resume the loop.\n",
            encoding="utf-8",
        )
    except OSError:
        pass


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
    if pending and recent_commits_doc_only_streak(root):
        reason = (
            f"last {DOC_ONLY_STREAK_THRESHOLD} commits touched only docs/STATUS*/INBOX.md "
            "-- this lane has no real product work left in its scope even though "
            "INBOX.md still has pending items (likely owned by another lane)."
        )
        print("PREFLIGHT_RESULT=IDLE")
        print(reason)
        write_auto_stop(root, reason)
        return IDLE
    if pending:
        print("PREFLIGHT_RESULT=READY")
        print("PENDING_FEEDBACK:")
        print("\n".join(compact_pending_feedback(pending)))
        return READY
    print("PREFLIGHT_RESULT=IDLE")
    return IDLE


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"PREFLIGHT_RESULT=INTERNAL_ERROR\n{exc}", file=sys.stderr)
        raise SystemExit(INTERNAL_ERROR)
