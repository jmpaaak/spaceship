"""INBOX 78 lane A: the superseded standalone Asset Studio stays removed."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class LegacyAssetStudioRemovalTests(unittest.TestCase):
    def test_standalone_studio_and_server_are_absent(self):
        obsolete = (
            ROOT / "tools" / "asset-studio",
            ROOT / "tools" / "serve_editors.py",
            ROOT / "tools" / "test_serve_editors.py",
            ROOT / "game" / "tests" / "legacy_asset_studio_web_hub.lua",
        )
        self.assertEqual([], [str(path.relative_to(ROOT)) for path in obsolete if path.exists()])

    def test_test_runners_do_not_link_obsolete_studio(self):
        makefile = (ROOT / "Makefile").read_text(encoding="utf-8")
        self_test = (ROOT / "game" / "self_test.lua").read_text(encoding="utf-8")
        self.assertNotIn("tools.test_serve_editors", makefile)
        self.assertNotIn("legacy_asset_studio_web_hub", self_test)


if __name__ == "__main__":
    unittest.main()