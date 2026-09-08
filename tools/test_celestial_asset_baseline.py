import hashlib
import json
import struct
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BASELINE = ROOT / "docs/assets/CELESTIAL_BASELINE.json"


class CelestialAssetBaselineTest(unittest.TestCase):
    def test_inventory_matches_every_runtime_celestial_png(self):
        data = json.loads(BASELINE.read_text(encoding="utf-8"))
        self.assertEqual(data["canvas"], {"width": 720, "height": 1280})
        entries = {entry["path"]: entry for entry in data["assets"]}
        actual_paths = {
            str(path.relative_to(ROOT))
            for folder in (ROOT / "assets/planet", ROOT / "assets/star")
            for path in folder.glob("*.png")
        }
        self.assertEqual(set(entries), actual_paths)

        for relative_path, entry in entries.items():
            contents = (ROOT / relative_path).read_bytes()
            self.assertEqual(contents[:8], b"\x89PNG\r\n\x1a\n", relative_path)
            width, height = struct.unpack(">II", contents[16:24])
            self.assertEqual(entry["file"], {"width": width, "height": height})
            self.assertEqual(entry["sha256"], hashlib.sha256(contents).hexdigest())
            expected_frames = height // width if relative_path.endswith("_sheet.png") else 1
            self.assertEqual(entry["frame"], {
                "width": width,
                "height": width if expected_frames > 1 else height,
                "count": expected_frames,
            })

    def test_runtime_measurements_record_current_draw_contracts(self):
        data = json.loads(BASELINE.read_text(encoding="utf-8"))
        self.assertEqual(data["runtime_draw"]["ordinary_planet"]["radius_px"], [14, 33])
        self.assertEqual(data["runtime_draw"]["shop_planet"]["radius_px"], [14, 19])
        self.assertEqual(data["runtime_draw"]["hub_planet"]["radius_px"], [40, 55])
        self.assertEqual(data["runtime_draw"]["central_star"]["diameter_px"], 160)
        self.assertEqual(data["runtime_draw"]["planet_variation_scale"], [0.85, 1.15])
        self.assertEqual(data["runtime_draw"]["filter"], "nearest")


if __name__ == "__main__":
    unittest.main()