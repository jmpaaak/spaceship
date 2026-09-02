"""Engine-adjacent regression test for tools/verify_asset_manifest.py.

This is tooling (not final art), so plain Python/unittest is fine per
docs/GAME_DESIGN.md's asset policy -- the policy bans Python/Pillow/Lua
shapes as a *source of final art*, not as build-time provenance tooling.

Covers the AetherAI-only pending feedback item: until an official
AetherForgeAI/AetherAI export exists, this script has nothing to validate
(no image assets under assets/ yet) and must pass cleanly. The moment any
image asset lands under assets/, this script must refuse to pass unless a
matching docs/assets/MANIFEST.json entry records the required provenance
fields (source_url, terms_url, asset_id, prompt, model, style, settings,
downloaded_at, sha256, width, height, qa) and the recorded sha256 matches
the file's real hash -- so a Lua-shape or Pillow-authored image can never
be silently accepted as "final art" by CI/preflight.
"""
import hashlib
import json
import os
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(__file__))
import verify_asset_manifest as vam  # noqa: E402

REQUIRED_FIELDS = [
    "source_url", "terms_url", "asset_id", "prompt", "model", "style",
    "settings", "downloaded_at", "sha256", "width", "height", "qa",
]


def make_png_bytes():
    # Minimal valid-looking bytes are unnecessary; the validator only
    # hashes file contents, it does not decode image data.
    return b"\x89PNG\r\n\x1a\nFAKE-BYTES-FOR-HASH-TEST"


class VerifyAssetManifestTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.assets_dir = os.path.join(self.tmp, "assets")
        self.manifest_path = os.path.join(self.tmp, "docs", "assets", "MANIFEST.json")
        os.makedirs(self.assets_dir)
        os.makedirs(os.path.dirname(self.manifest_path))

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def write_manifest(self, entries):
        with open(self.manifest_path, "w", encoding="utf-8") as fh:
            json.dump(entries, fh)

    def test_no_images_and_empty_manifest_is_clean(self):
        self.write_manifest([])
        errors = vam.validate(self.assets_dir, self.manifest_path)
        self.assertEqual(errors, [])

    def test_font_files_are_exempt_from_manifest_requirement(self):
        # Fonts are typefaces, not "final visual assets" (ship/planet/
        # sample/effect/etc image art) under docs/GAME_DESIGN.md, so a
        # bundled .ttf must not force a manifest entry.
        font_dir = os.path.join(self.assets_dir, "fonts")
        os.makedirs(font_dir)
        with open(os.path.join(font_dir, "AppleGothic.ttf"), "wb") as fh:
            fh.write(b"not-a-real-font-just-bytes")
        self.write_manifest([])
        errors = vam.validate(self.assets_dir, self.manifest_path)
        self.assertEqual(errors, [])

    def test_image_without_manifest_entry_is_rejected(self):
        with open(os.path.join(self.assets_dir, "ship.png"), "wb") as fh:
            fh.write(make_png_bytes())
        self.write_manifest([])
        errors = vam.validate(self.assets_dir, self.manifest_path)
        self.assertTrue(any("ship.png" in e and "no manifest entry" in e for e in errors))

    def test_image_with_complete_matching_entry_passes(self):
        data = make_png_bytes()
        path = os.path.join(self.assets_dir, "ship.png")
        with open(path, "wb") as fh:
            fh.write(data)
        digest = hashlib.sha256(data).hexdigest()
        entry = {
            "path": "assets/ship.png",
            "source_url": "https://aetherforgeai.com/generations/abc123",
            "terms_url": "https://aetherforgeai.com/terms",
            "asset_id": "abc123",
            "prompt": "pixel-art spaceship, top-down, portrait mobile",
            "model": "AetherAI-v1",
            "style": "pixel-portrait",
            "settings": "seed=42,steps=30",
            "downloaded_at": "2026-09-02T00:00:00Z",
            "sha256": digest,
            "width": 32,
            "height": 32,
            "qa": "Verified via real LOVE runtime capture, no overlap/clipping.",
        }
        self.write_manifest([entry])
        errors = vam.validate(self.assets_dir, self.manifest_path)
        self.assertEqual(errors, [])

    def test_entry_missing_required_field_is_rejected(self):
        data = make_png_bytes()
        path = os.path.join(self.assets_dir, "ship.png")
        with open(path, "wb") as fh:
            fh.write(data)
        digest = hashlib.sha256(data).hexdigest()
        entry = {
            "path": "assets/ship.png",
            "source_url": "https://aetherforgeai.com/generations/abc123",
            "sha256": digest,
        }
        self.write_manifest([entry])
        errors = vam.validate(self.assets_dir, self.manifest_path)
        missing_field_errors = [e for e in errors if "missing required field" in e]
        self.assertTrue(missing_field_errors)
        for field in REQUIRED_FIELDS:
            if field not in entry:
                self.assertTrue(any(field in e for e in missing_field_errors), field)

    def test_entry_with_wrong_sha256_is_rejected(self):
        data = make_png_bytes()
        path = os.path.join(self.assets_dir, "ship.png")
        with open(path, "wb") as fh:
            fh.write(data)
        entry = {
            "path": "assets/ship.png",
            "source_url": "https://aetherforgeai.com/generations/abc123",
            "terms_url": "https://aetherforgeai.com/terms",
            "asset_id": "abc123",
            "prompt": "pixel-art spaceship",
            "model": "AetherAI-v1",
            "style": "pixel-portrait",
            "settings": "seed=42,steps=30",
            "downloaded_at": "2026-09-02T00:00:00Z",
            "sha256": "0" * 64,
            "width": 32,
            "height": 32,
            "qa": "Verified via real LOVE runtime capture.",
        }
        self.write_manifest([entry])
        errors = vam.validate(self.assets_dir, self.manifest_path)
        self.assertTrue(any("sha256 mismatch" in e for e in errors))

    def test_manifest_entry_for_missing_file_is_rejected(self):
        entry = {
            "path": "assets/ghost.png",
            "source_url": "https://aetherforgeai.com/generations/abc123",
            "terms_url": "https://aetherforgeai.com/terms",
            "asset_id": "abc123",
            "prompt": "pixel-art spaceship",
            "model": "AetherAI-v1",
            "style": "pixel-portrait",
            "settings": "seed=42,steps=30",
            "downloaded_at": "2026-09-02T00:00:00Z",
            "sha256": "0" * 64,
            "width": 32,
            "height": 32,
            "qa": "Verified.",
        }
        self.write_manifest([entry])
        errors = vam.validate(self.assets_dir, self.manifest_path)
        self.assertTrue(any("ghost.png" in e and "does not exist" in e for e in errors))

    def test_non_official_source_url_is_rejected(self):
        data = make_png_bytes()
        path = os.path.join(self.assets_dir, "ship.png")
        with open(path, "wb") as fh:
            fh.write(data)
        digest = hashlib.sha256(data).hexdigest()
        entry = {
            "path": "assets/ship.png",
            "source_url": "https://example.com/not-aether",
            "terms_url": "https://aetherforgeai.com/terms",
            "asset_id": "abc123",
            "prompt": "pixel-art spaceship",
            "model": "AetherAI-v1",
            "style": "pixel-portrait",
            "settings": "seed=42,steps=30",
            "downloaded_at": "2026-09-02T00:00:00Z",
            "sha256": digest,
            "width": 32,
            "height": 32,
            "qa": "Verified.",
        }
        self.write_manifest([entry])
        errors = vam.validate(self.assets_dir, self.manifest_path)
        self.assertTrue(any("source_url must be an official AetherForgeAI/AetherAI URL" in e for e in errors))

    def test_non_official_terms_url_is_rejected(self):
        # loop/PROMPT.md requires the recorded terms_url to also be the
        # official AetherForgeAI/AetherAI terms page, not just source_url --
        # otherwise an entry could smuggle in an unrelated/fabricated terms
        # link while still pointing source_url at the real service.
        data = make_png_bytes()
        path = os.path.join(self.assets_dir, "ship.png")
        with open(path, "wb") as fh:
            fh.write(data)
        digest = hashlib.sha256(data).hexdigest()
        entry = {
            "path": "assets/ship.png",
            "source_url": "https://aetherforgeai.com/generations/abc123",
            "terms_url": "https://example.com/not-aether-terms",
            "asset_id": "abc123",
            "prompt": "pixel-art spaceship",
            "model": "AetherAI-v1",
            "style": "pixel-portrait",
            "settings": "seed=42,steps=30",
            "downloaded_at": "2026-09-02T00:00:00Z",
            "sha256": digest,
            "width": 32,
            "height": 32,
            "qa": "Verified.",
        }
        self.write_manifest([entry])
        errors = vam.validate(self.assets_dir, self.manifest_path)
        self.assertTrue(any("terms_url must be an official AetherForgeAI/AetherAI URL" in e for e in errors))


if __name__ == "__main__":
    unittest.main()
