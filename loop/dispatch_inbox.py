#!/usr/bin/env python3
"""Split independent INBOX items onto parallel git-worktree lanes.

A single loop cycle still does one slice. Parallelism comes from extra
worktrees, each running its own loop.sh on a disjoint file set.

Items without backtick-wrapped paths stay on main (serial). Bare path mentions do not count.
Items that share a path stay in the same connected component.

Usage:
  loop/dispatch_inbox.py              # print plan
  loop/dispatch_inbox.py --apply      # scaffold + start idle lanes
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

# Parallel lanes require backtick-owned paths. Bare path mentions are serial.
PATH_RE = re.compile(
    r"`("
    r"(?:lib|src|test|docs|assets|web|scripts|tools|loop)/[A-Za-z0-9_./-]+"
    r"|(?:product|admin|server|index|credits|how-to-use|privacy-policy|"
    r"terms-of-service|support|custom_frames)\.[A-Za-z0-9.]+"
    r"|[A-Za-z0-9_./-]+\.(?:js|mjs|css|html|dart|lua|py|md|json|plist)"
    r")`"
)
ITEM_RE = re.compile(r"^(?:-\s*)?(?:\[|\()([A-Za-z]+\d+[a-z]?)(?:\]|\))\s+.+$", re.IGNORECASE)
BULLET_RE = re.compile(r"^-\s+")
MAX_LANES = 3


def inbox_path(root: Path) -> Path:
    for rel in ("loop/INBOX", "docs/feedback/INBOX.md"):
        p = root / rel
        if p.is_file():
            return p
    return root / "loop/INBOX"


def parse_items(text: str) -> list[dict]:
    items: list[dict] = []
    if "## 처리 대기" in text and "## 처리 완료" in text:
        section = text.split("## 처리 대기", 1)[1].split("## 처리 완료", 1)[0]
        buf: list[str] = []
        for line in section.splitlines():
            if BULLET_RE.match(line) and buf:
                items.append(_item_from_block(buf))
                buf = [line]
            elif BULLET_RE.match(line) or (buf and (line.startswith("  ") or not line.strip())):
                buf.append(line)
        if buf:
            items.append(_item_from_block(buf))
        return [i for i in items if i["title"]]
    for line in text.splitlines():
        stripped = line.strip()
        if ITEM_RE.match(stripped) or stripped.startswith("[P"):
            items.append(_item_from_block([stripped]))
    return [i for i in items if i["title"]]


def _item_from_block(lines: list[str]) -> dict:
    text = "\n".join(lines).strip()
    title = text.splitlines()[0].strip()
    paths = sorted({m.group(1).lstrip("/") for m in PATH_RE.finditer(text)})
    tag_match = ITEM_RE.match(title)
    legacy_tag = re.search(r"\((U\d+|W\d+)\)", title, re.IGNORECASE)
    slug_src = (tag_match.group(1) if tag_match else "") or (legacy_tag.group(1).lower() if legacy_tag else "")
    if not slug_src:
        slug_src = re.sub(r"[^a-z0-9]+", "-", title.encode("ascii", "ignore").decode().lower()).strip("-")
    slug = (slug_src or "item")[:24]
    tag = tag_match.group(1) if tag_match else None
    dependencies: list[str] = []
    for clause in re.findall(r"\(([^)]*?(?:완료 후|after)[^)]*)\)", text, re.IGNORECASE):
        dependencies.extend(re.findall(r"[A-Za-z]+\d+[a-z]?", clause, re.IGNORECASE))
    return {
        "title": title[:180],
        "paths": paths,
        "slug": slug,
        "text": text,
        "tag": tag,
        "dependencies": sorted(set(dependencies)),
    }


def components(items: list[dict]) -> list[list[dict]]:
    n = len(items)
    parent = list(range(n))

    def find(i: int) -> int:
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    for i in range(n):
        for j in range(i + 1, n):
            a, b = set(items[i]["paths"]), set(items[j]["paths"])
            if a and b and (a & b):
                parent[find(i)] = find(j)
    groups: dict[int, list[dict]] = {}
    for i, item in enumerate(items):
        groups.setdefault(find(i), []).append(item)
    return list(groups.values())


def lane_parent(root: Path) -> Path:
    return root.parent / f"{root.name}-lanes"


def running_loop(worktree: Path) -> bool:
    try:
        out = subprocess.check_output(["pgrep", "-fl", "loop.sh"], text=True)
    except subprocess.CalledProcessError:
        return False
    return str(worktree) in out


def committed_lane_is_complete(root: Path, lane: Path, item: dict) -> bool:
    """A completed lane must not be restarted or have its INBOX overwritten."""
    if not lane.is_dir():
        return False
    try:
        ahead = int(subprocess.check_output(
            ["git", "rev-list", "--count", "main..HEAD"],
            cwd=lane,
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip() or "0")
    except (subprocess.CalledProcessError, ValueError):
        return False
    if ahead <= 0:
        return False
    try:
        committed = subprocess.check_output(
            ["git", "show", "HEAD:loop/INBOX"], cwd=lane, text=True,
            stderr=subprocess.DEVNULL,
        )
    except subprocess.CalledProcessError:
        return False
    tags = item.get("tags") or ([item.get("tag")] if item.get("tag") else [])
    return bool(tags) and all(
        f"[{tag}]" not in committed and f"({tag})" not in committed for tag in tags
    )


def scaffold_and_start(root: Path, slug: str, item: dict) -> str:
    parent = lane_parent(root)
    parent.mkdir(parents=True, exist_ok=True)
    scaffold = root / "loop" / "scaffold_lane.sh"
    desc = f"{item['title']}\nOwned files: {', '.join(item['paths']) or '(none)'}"
    if scaffold.is_file():
        subprocess.run(
            ["bash", str(scaffold), slug, str(parent), desc],
            cwd=root,
            check=False,
        )
    else:
        _minimal_worktree(root, parent, slug)
    lane = parent / slug
    if committed_lane_is_complete(root, lane, item):
        return f"completed; awaiting main merge {lane}"
    if running_loop(lane):
        return f"already running {lane}"
    try:
        dirty = subprocess.check_output(
            ["git", "status", "--porcelain", "--untracked-files=no"],
            cwd=lane, text=True, stderr=subprocess.DEVNULL,
        ).strip()
    except subprocess.CalledProcessError:
        dirty = "unknown"
    if dirty:
        return f"dirty lane preserved; manual review required {lane}"
    stop = lane / "loop" / "STOP"
    if stop.is_file():
        first = stop.read_text(encoding="utf-8", errors="replace").splitlines()[:1]
        if first and "MANUAL" in first[0].upper():
            return f"manual stop preserved {lane}"
        stop.unlink()
    inbox = lane / "loop" / "INBOX"
    inbox.parent.mkdir(parents=True, exist_ok=True)
    inbox.write_text(item["text"].rstrip() + "\n", encoding="utf-8")
    logs = lane / "logs"
    logs.mkdir(exist_ok=True)
    subprocess.Popen(
        ["bash", str(lane / "loop" / "loop.sh")],
        cwd=lane,
        stdout=open(logs / "watchdog-restart.out", "ab"),
        stderr=subprocess.STDOUT,
        start_new_session=True,
        env={**os.environ, "LOOP_ROOT": str(lane)},
    )
    return f"started {lane}"


def _minimal_worktree(root: Path, parent: Path, slug: str) -> None:
    branch = f"{root.name}-{slug}"
    dest = parent / slug
    if not dest.exists():
        exists = subprocess.run(
            ["git", "show-ref", "--verify", "--quiet", f"refs/heads/{branch}"],
            cwd=root,
        ).returncode == 0
        if not exists:
            subprocess.run(["git", "branch", branch], cwd=root, check=True)
        subprocess.run(["git", "worktree", "add", str(dest), branch], cwd=root, check=True)
    loop_src, loop_dst = root / "loop", dest / "loop"
    loop_dst.mkdir(parents=True, exist_ok=True)
    for name in ("loop.sh", "env.sh", "run_agent.py", "preflight.py",
                 "classify_provider_failure.py", "PROMPT.md"):
        src = loop_src / name
        if src.is_file():
            dest_f = loop_dst / name
            dest_f.write_bytes(src.read_bytes())
            dest_f.chmod(src.stat().st_mode)


def plan(items: list[dict]) -> tuple[list[dict], list[list[dict]]]:
    """Return (main_items, parallel_groups). First group stays on main."""
    groups = components(items)
    if not groups:
        return [], []
    main = groups[0]
    # Keep every item in an overlapping-file component. Dropping g[1:] made
    # later items (for example P45c sharing product.html with P45b) disappear.
    extra = [g for g in groups[1:] if g[0]["paths"]][:MAX_LANES]
    return main, extra


def combined_group_item(group: list[dict]) -> dict:
    if len(group) == 1:
        return group[0]
    return {
        "title": " + ".join(item["title"] for item in group)[:180],
        "paths": sorted({path for item in group for path in item["paths"]}),
        "slug": "-".join(item["slug"] for item in group)[:48],
        "text": "\n".join(item["text"].rstrip() for item in group) + "\n",
        "tag": group[0].get("tag"),
        "tags": [item["tag"] for item in group if item.get("tag")],
        "dependencies": sorted({dep for item in group for dep in item.get("dependencies", [])}),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--root", default=os.environ.get("LOOP_ROOT", ""))
    args = parser.parse_args()
    root = Path(args.root or Path(__file__).resolve().parents[1]).resolve()
    if any(parent.name.endswith("-lanes") for parent in (root, *root.parents)):
        print(f"[dispatch] lane checkout detected; nested dispatch disabled: {root}")
        return 0
    path = inbox_path(root)
    if not path.is_file():
        print(f"[dispatch] no inbox at {path}")
        return 0
    items = parse_items(path.read_text(encoding="utf-8"))
    if not items:
        print("[dispatch] inbox empty")
        return 0
    pending_tags = {item["tag"] for item in items if item.get("tag")}
    blocked = [item for item in items if set(item.get("dependencies", [])) & pending_tags]
    ready = [item for item in items if item not in blocked]
    main_items, extra = plan(ready)
    print(f"[dispatch] {len(items)} pending, {len(ready)} dependency-ready, {len(extra)} independent lane(s) possible")
    for item in blocked:
        waiting = sorted(set(item.get("dependencies", [])) & pending_tags)
        print(f"[dispatch] blocked {item.get('tag') or item['slug']}: waiting for {', '.join(waiting)}")
    print("[dispatch] main lane:")
    for item in main_items:
        print(f"  - {item['title'][:90]}  files={item['paths'] or 'unknown→serial'}")
    for group in extra:
        item = combined_group_item(group)
        tags = ", ".join(member.get("tag") or member["slug"] for member in group)
        print(f"[dispatch] parallel lane {item['slug']} ({tags}): {item['title'][:90]}  files={item['paths']}")
    if not args.apply:
        return 0
    for group in extra:
        item = combined_group_item(group)
        print("[dispatch]", scaffold_and_start(root, item["slug"], item))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
