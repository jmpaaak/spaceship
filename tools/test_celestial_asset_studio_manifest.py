#!/usr/bin/env python3
"""Validate photo-derived celestial Asset Studio provenance and artifacts."""

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "docs/assets/CELESTIAL_ASSET_STUDIO.json"
EXPECTED_ENDPOINT = "http://127.0.0.1:4176/api/pixel-perfect"
REQUIRED_IDS = {
    "pp_bare_nasa_pia00405",
    "pp_gas_nasa_pia01518",
    "pp_dry_nasa_pia00407",
    "pp_ice_nasa_pia00353",
    "pp_lava_nasa_pia00703",
    "pp_earth_nasa_as17_148_22727",
    "star_sun_nasa_gsfc_20171208_archive_e002035",
    "star_filament_nasa_gsfc_20171208_archive_e002069",
    "star_cme_nasa_gsfc_20171208_archive_e001770",
    "star_flare_nasa_gsfc_20171208_archive_e001058",
    "hub_neptune_nasa_pia00046",
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def test_manifest() -> None:
    data = json.loads(MANIFEST.read_text())
    assert data["schema_version"] == 1
    assert data["assets"], "at least one generated celestial asset is required"
    assert REQUIRED_IDS <= {item["id"] for item in data["assets"]}
    for item in data["assets"]:
        assert item["endpoint"] == EXPECTED_ENDPOINT
        assert item["source"]["url"].startswith("https://images-assets.nasa.gov/")
        assert item["source"]["license_url"] == "https://www.nasa.gov/nasa-brand-center/images-and-media/"
        assert item["request"]["pixel_block"] >= 2
        assert item["request"]["palette_limit"] <= 64
        assert item["response"]["http_status"] == 200
        assert item["response"]["report_valid"] is True

        source = ROOT / item["source"]["path"]
        master = ROOT / item["master"]["path"]
        runtime = ROOT / item["runtime"]["path"]
        request_log = ROOT / item["request"]["log_path"]
        response_log = ROOT / item["response"]["log_path"]
        for artifact in (source, master, runtime, request_log, response_log):
            assert artifact.is_file(), f"missing artifact: {artifact.relative_to(ROOT)}"
        for label, path in (("source", source), ("master", master), ("runtime", runtime)):
            assert sha256(path) == item[label]["sha256"]

        with Image.open(source) as image:
            assert list(image.size) == item["source"]["dimensions"]
            assert min(image.size) >= item["request"]["target_width"]
        with Image.open(master) as image:
            master_rgba = image.convert("RGBA")
            assert image.mode == "RGBA"
            assert list(image.size) == item["master"]["dimensions"]
        with Image.open(runtime) as image:
            runtime_rgba = image.convert("RGBA")
            assert image.mode == "RGBA"
            assert list(image.size) == item["runtime"]["dimensions"]

        alpha = master_rgba.getchannel("A")
        lo, hi = alpha.getextrema()
        assert lo == 0 and hi == 255, "master must preserve a transparent boundary and opaque body"
        expected = master_rgba.resize(runtime_rgba.size, Image.Resampling.NEAREST)
        assert ImageChops.difference(expected, runtime_rgba).getbbox() is None
        restored_grid = runtime_rgba.resize(master_rgba.size, Image.Resampling.NEAREST)
        assert ImageChops.difference(restored_grid, master_rgba).getbbox() is None, "master must use a hard 4px grid"

        request = json.loads(request_log.read_text())
        response = json.loads(response_log.read_text())
        assert request["payload_sha256"] == item["request"]["payload_sha256"]
        assert len(item["response"]["body_sha256"]) == 64
        assert response["report"]["valid"] is True
        rgba_sha256 = hashlib.sha256(master_rgba.tobytes()).hexdigest()
        assert rgba_sha256 == item["response"]["image_rgba_sha256"]


if __name__ == "__main__":
    test_manifest()
    print("celestial Asset Studio manifest: ok")
