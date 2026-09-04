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


def compact_inbox_status_notes(root: Path, max_note_chars: int = 300) -> None:
    """Collapse verbose '> 처리 상황 ...' note blocks in pending items to one line."""
    path = root / "docs" / "feedback" / "INBOX.md"
    original = path.read_text(encoding="utf-8")
    header, pend_marker, rest = original.partition("## 처리 대기")
    if not pend_marker:
        return
    pending_section, done_marker, done_section = rest.partition("## 처리 완료")

    lines = pending_section.splitlines(keepends=True)
    out: list[str] = []
    in_note = False
    note_first_line = ""
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("> 처리 상황") or stripped.startswith(">  처리 상황"):
            in_note = True
            note_first_line = line.rstrip()[:max_note_chars]
            continue
        if in_note:
            if stripped.startswith(">") or stripped == "":
                continue
            else:
                out.append(note_first_line + " …(압축됨)\n")
                in_note = False
                out.append(line)
        else:
            out.append(line)
    if in_note:
        out.append(note_first_line + " …(압축됨)\n")

    new_text = header + pend_marker + "".join(out) + done_marker + done_section
    if len(new_text) >= len(original):
        return
    path.write_text(new_text, encoding="utf-8")
    print(f"[preflight] INBOX 처리 상황 주석 압축: -{len(original)-len(new_text):,} chars 절감", flush=True)




MAX_PENDING_PROMPT_ITEMS = 4
MAX_PENDING_PROMPT_CHARS = 220


def compact_pending_feedback(pending: list[str]) -> list[str]:
    """Keep only short titles in the cycle prompt; the agent reads INBOX.md."""
    titles: list[str] = []
    for line in pending:
        stripped = line.strip()
        if stripped.startswith("-"):
            content = stripped[1:].strip()
        elif stripped and stripped[0].isdigit() and ". " in stripped:
            content = stripped.split(". ", 1)[1].strip()
        else:
            continue
        cut = content
        for marker in (":**", ":"):
            index = content.find(marker)
            if 0 < index <= MAX_PENDING_PROMPT_CHARS:
                cut = content[: index + (1 if marker == ":" else 3)]
                break
        else:
            cut = content[:MAX_PENDING_PROMPT_CHARS].rstrip()
        titles.append(f"- {cut}")
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
DOC_ONLY_STREAK_THRESHOLD = 5


def recent_commits_doc_only_streak(root: Path, n: int = DOC_ONLY_STREAK_THRESHOLD) -> bool:
    """True if the last n commits touched only doc/status-report files.

    Deterministic signature of a loop stuck re-confirming out-of-scope or
    already-done INBOX items every cycle with no real product change.
    Requires at least n commits of history to fire.
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


def warn_large_source_files(root: Path, min_bytes: int = 80_000) -> None:
    """Remind the agent not to read_file huge sources without offset/limit."""
    hits = []
    for rel in ("game/self_test.lua", "game/scenes/play.lua", "game/expedition.lua"):
        path = root / rel
        try:
            size = path.stat().st_size
        except OSError:
            continue
        if size >= min_bytes:
            hits.append(f"{rel} ({size // 1024}KB)")
    if hits:
        print(
            "TOKEN HINT: these files are ≥80KB — search_files + offset/limit ≤80 lines, "
            "never full read_file: " + ", ".join(hits),
            flush=True,
        )


def main() -> int:
    root = Path(os.environ.get("LOOP_ROOT", Path(__file__).resolve().parents[1])).resolve()
    try:
        compact_inbox_status_notes(root)
    except Exception:
        pass
    warn_large_source_files(root)
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
        try:
            dirty = subprocess.run(
                ["git", "status", "--porcelain"],
                cwd=root, text=True,
                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                timeout=10, check=False,
            ).stdout.strip()
        except Exception:
            dirty = ""
        print("PREFLIGHT_RESULT=FAIL")
        if dirty:
            print(
                "⚠️  DIRTY WORKING TREE + FAIL: A previous cycle left uncommitted changes that "
                "are breaking tests. YOUR ONLY JOB THIS CYCLE: fix the failing tests, then "
                "commit ALL modified files. Do NOT start any new INBOX work until the tree is "
                "clean and all tests pass. Do NOT abandon the uncommitted changes — finish them."
            )
            print(f"Dirty files:\n{dirty}")
        print("\n\n".join(failures))
        return CHECK_FAILED
    pending = pending_feedback(root)
    if pending and recent_commits_doc_only_streak(root):
        reason = (
            f"last {DOC_ONLY_STREAK_THRESHOLD} commits touched only docs/STATUS*/INBOX.md "
            "-- no real product work is happening even though INBOX.md still has "
            "pending items. Auto-stopping to avoid burning tokens on repeat no-op cycles."
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
