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


def compact_inbox_status_notes(root: Path, max_note_chars: int = 300) -> None:
    """Collapse verbose '> 처리 상황 ...' note blocks in pending items to one line.

    Each '> 처리 상황' block can grow to thousands of words. We keep only
    the first max_note_chars chars of the first line, which carries the
    essential 'what was done / what's next' summary. This runs deterministically
    before the agent starts so every cycle begins with a compact INBOX.
    Writes only when actual changes are made (size-gated to avoid no-op commits).
    """
    import re
    path = root / "docs" / "feedback" / "INBOX.md"
    original = path.read_text(encoding="utf-8")

    # Split on pending/done boundary; only compress the pending section
    header, pend_marker, rest = original.partition("## 처리 대기")
    if not pend_marker:
        return
    pending_section, done_marker, done_section = rest.partition("## 처리 완료")

    def collapse_notes(text: str) -> str:
        lines = text.splitlines(keepends=True)
        out = []
        in_note = False
        note_first_line = ""
        for line in lines:
            stripped = line.strip()
            # Start of a note block
            if stripped.startswith("> 처리 상황") or stripped.startswith(">  처리 상황"):
                in_note = True
                note_first_line = line.rstrip()[:max_note_chars]
                continue
            # Continuation of note block (lines starting with ">")
            if in_note:
                if stripped.startswith(">") or stripped == "":
                    continue  # skip verbose continuation
                else:
                    # End of note block — emit compressed version
                    out.append(note_first_line + " …(압축됨)\n")
                    in_note = False
                    out.append(line)
            else:
                out.append(line)
        if in_note:
            out.append(note_first_line + " …(압축됨)\n")
        return "".join(out)

    compacted_pending = collapse_notes(pending_section)
    if compacted_pending == pending_section:
        return  # nothing changed

    new_text = header + pend_marker + compacted_pending + done_marker + done_section
    if len(new_text) >= len(original):
        return  # sanity check: must be smaller

    path.write_text(new_text, encoding="utf-8")
    saved = len(original) - len(new_text)
    print(f"[preflight] INBOX 처리 상황 주석 압축: -{saved:,} chars 절감", flush=True)


MAX_PENDING_PROMPT_ITEMS = 4
MAX_PENDING_PROMPT_CHARS = 220


def compact_pending_feedback(pending: list[str]) -> list[str]:
    """Keep only short titles in the cycle prompt; the agent reads INBOX.md."""
    titles: list[str] = []
    for line in pending:
        stripped = line.strip()
        # support both "- **title" and "7. **title" formats
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
    # Compact verbose status-note blocks before checks so agent sees slim INBOX
    try:
        compact_inbox_status_notes(root)
    except Exception:
        pass  # non-fatal
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
