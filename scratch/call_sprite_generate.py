#!/usr/bin/env python3
"""Call the live 4176 /api/sprite-generate endpoint with a local PNG base image."""
from __future__ import annotations

import argparse
import base64
import json
import time
import urllib.error
import urllib.request
from pathlib import Path

ENDPOINT = "http://127.0.0.1:4176/api/sprite-generate"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--id", required=True)
    parser.add_argument("--image", required=True)
    parser.add_argument("--asset-type", default="planet")
    parser.add_argument("--provider", default="grok")
    parser.add_argument("--cell-size", type=int, default=128)
    parser.add_argument("--chroma-key", default="magenta")
    parser.add_argument("--state-id", default="rotate")
    parser.add_argument("--frames", type=int, default=8)
    parser.add_argument("--fps", type=int, default=8)
    parser.add_argument("--action", required=True)
    parser.add_argument("--description", required=True)
    parser.add_argument("--out-dir", required=True)
    args = parser.parse_args()

    image_path = Path(args.image)
    data = image_path.read_bytes()
    data_url = "data:image/png;base64," + base64.b64encode(data).decode("ascii")
    payload = {
        "characterId": args.id,
        "description": args.description,
        "assetType": args.asset_type,
        "provider": args.provider,
        "cellSize": args.cell_size,
        "chromaKey": args.chroma_key,
        "states": [
            {
                "id": args.state_id,
                "action": args.action,
                "frames": args.frames,
                "fps": args.fps,
                "loop": True,
            }
        ],
        "baseImageDataUrl": data_url,
    }
    body = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        ENDPOINT,
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    print(f"POST {args.id} {args.provider} {args.cell_size}px {args.frames}f", flush=True)
    started = time.time()
    try:
        with urllib.request.urlopen(req, timeout=540) as response:
            raw = response.read()
            status = response.status
    except urllib.error.HTTPError as exc:
        raw = exc.read()
        status = exc.code
        print(f"FAIL {status} {raw.decode('utf-8', 'replace')}")
        return 1
    elapsed = time.time() - started
    parsed = json.loads(raw)
    print(f"OK {status} {parsed.get('runId')} {elapsed:.1f}s")
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / f"{args.id}.json").write_text(json.dumps(parsed, indent=2), encoding="utf-8")
    atlas = parsed.get("atlas")
    manifest = parsed.get("manifest")
    for kind, url in (("atlas", atlas), ("manifest", manifest)):
        if not url:
            continue
        dest_name = f"{args.id}-sprite-sheet-alpha.png" if kind == "atlas" else f"{args.id}-manifest.json"
        dest = out_dir / dest_name
        with urllib.request.urlopen("http://127.0.0.1:4176" + url) as response:
            dest.write_bytes(response.read())
        print(f" saved {dest} {dest.stat().st_size}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
