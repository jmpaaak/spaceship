#!/usr/bin/env python3
"""Enforce docs/GAME_DESIGN.md's AetherAI-only final-asset policy at
build/verify time.

Any image asset placed under assets/ must have a matching entry in
docs/assets/MANIFEST.json recording the official AetherForgeAI/AetherAI
provenance loop/PROMPT.md requires: source/terms URL, generation/asset ID,
prompt/model/style/settings, download timestamp, original SHA-256,
dimensions, and a runtime QA note -- and the recorded sha256 must match the
file's real contents (catching stale/edited entries and Lua-shape or
Pillow-authored images being smuggled in as "final art").

Until an official AetherAI export exists there is nothing to import, so an
empty assets/ (plus non-image files such as bundled fonts) and an empty
manifest validate cleanly with zero errors -- this script is a guardrail
for the day credentials/export become available, not a requirement to
fabricate assets now.
"""
from __future__ import annotations

import hashlib
import json
import os
import sys

IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp", ".tga"}

REQUIRED_FIELDS = [
    "source_url", "terms_url", "asset_id", "prompt", "model", "style",
    "settings", "downloaded_at", "sha256", "width", "height", "qa",
]

OFFICIAL_SOURCE_PREFIXES = (
    "https://aetherforgeai.com/",
    "https://www.aetherforgeai.com/",
    "https://aetherai.com/",
    "https://www.aetherai.com/",
    "https://api.aetherforgeai.com/",
    "https://api.aetherai.com/",
    # 2026-09-03: local ComfyUI is an equally official generation path
    # (user-approved, human-gate removed) -- its manifest terms_url
    # records the local instance + workflow id instead of a public URL.
    "http://127.0.0.1:8188/",
    # 2026-09-03: ComfyUI moved to a remote GPU server -- keep both the old
    # local URL (already-recorded manifest entries) and the new one.
    "http://222.238.86.132:8188/",
)

# Fields still required even for user_supplied entries (provenance + QA
# integrity; source/terms URL checks are relaxed for open-source MIT assets
# explicitly confirmed by the user).
USER_SUPPLIED_REQUIRED_FIELDS = [
    "source_url", "terms_url", "asset_id", "prompt", "model",
    "downloaded_at", "sha256", "width", "height", "qa",
]


def find_image_files(assets_dir: str) -> list[str]:
    found = []
    for dirpath, _dirnames, filenames in os.walk(assets_dir):
        for name in filenames:
            ext = os.path.splitext(name)[1].lower()
            if ext in IMAGE_EXTENSIONS:
                full = os.path.join(dirpath, name)
                rel = os.path.relpath(full, os.path.dirname(assets_dir) or ".")
                found.append(rel.replace(os.sep, "/"))
    return sorted(found)


def load_manifest(manifest_path: str) -> list[dict]:
    if not os.path.exists(manifest_path):
        return []
    with open(manifest_path, "r", encoding="utf-8") as fh:
        contents = fh.read().strip()
    if not contents:
        return []
    data = json.loads(contents)
    if not isinstance(data, list):
        raise ValueError("MANIFEST.json must contain a JSON array of entries")
    return data


def validate(assets_dir: str, manifest_path: str) -> list[str]:
    errors: list[str] = []
    images = find_image_files(assets_dir)
    entries = load_manifest(manifest_path)
    by_path = {}
    for entry in entries:
        path = entry.get("path")
        if not path:
            errors.append("manifest entry missing required field: path")
            continue
        by_path[path] = entry

    for image_path in images:
        entry = by_path.get(image_path)
        if entry is None:
            errors.append(f"{image_path}: no manifest entry in docs/assets/MANIFEST.json")
            continue
        user_supplied = bool(entry.get("user_supplied"))
        fields_to_check = USER_SUPPLIED_REQUIRED_FIELDS if user_supplied else REQUIRED_FIELDS
        for field in fields_to_check:
            if not entry.get(field) and entry.get(field) != 0:
                errors.append(f"{image_path}: manifest entry missing required field '{field}'")
        if not user_supplied:
            source_url = entry.get("source_url") or ""
            if source_url and not source_url.startswith(OFFICIAL_SOURCE_PREFIXES):
                errors.append(
                    f"{image_path}: source_url must be an official AetherForgeAI/AetherAI URL, got '{source_url}'"
                )
            terms_url = entry.get("terms_url") or ""
            if terms_url and not terms_url.startswith(OFFICIAL_SOURCE_PREFIXES):
                errors.append(
                    f"{image_path}: terms_url must be an official AetherForgeAI/AetherAI URL, got '{terms_url}'"
                )
        expected_sha = entry.get("sha256")
        root = os.path.dirname(assets_dir) or "."
        full_path = os.path.join(root, image_path)
        if os.path.exists(full_path) and expected_sha:
            with open(full_path, "rb") as fh:
                actual_sha = hashlib.sha256(fh.read()).hexdigest()
            if actual_sha != expected_sha:
                errors.append(
                    f"{image_path}: sha256 mismatch (manifest={expected_sha}, actual={actual_sha})"
                )

    for path, entry in by_path.items():
        root = os.path.dirname(assets_dir) or "."
        full_path = os.path.join(root, path)
        if not os.path.exists(full_path):
            errors.append(f"{path}: manifest entry references a file that does not exist")

    return errors


def main() -> int:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    assets_dir = os.path.join(root, "assets")
    manifest_path = os.path.join(root, "docs", "assets", "MANIFEST.json")
    errors = validate(assets_dir, manifest_path)
    if errors:
        print("ASSET_MANIFEST_FAIL")
        for error in errors:
            print(f"  - {error}")
        return 1
    print("ASSET_MANIFEST_OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
