#!/usr/bin/env python3
"""Generate final visual assets for spaceship via the local ComfyUI API.

This is the ComfyUI-equal-to-AetherAI path documented in
docs/feedback/INBOX.md and loop/PROMPT.md's "AetherAI-only asset rule"
(2026-09-03 update). It drives the running ComfyUI instance at
http://222.238.86.132:8188 with the "base pixel factory" workflow
(id 7a3eb820-f17d-47ce-a337-da2358c2a0d5) using stdlib-only HTTP calls
(no extra pip deps), saves the resulting PNG under assets/, and writes
a matching docs/assets/MANIFEST.json entry with full provenance
(workflow id, checkpoint/LoRA, prompt, seed, sampler settings,
generation timestamp, output SHA-256, dimensions).

Usage:
    python3 tools/comfyui_asset_pipeline.py \
        --asset-path assets/ship/ship_default.png \
        --prompt "pixel art, 16-bit, small top-down spaceship sprite, ..." \
        --width 128 --height 128 --seed 42 --qa "runtime placement pending"

This is a quality-gate tool, not an approval gate: generated images
must still pass `tools/verify_asset_manifest.py` (source/terms url,
hash match, required fields) and, once wired into the game, actual
LOVE runtime QA before being treated as final.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid

COMFY_HOST = "http://222.238.86.132:8188"
WORKFLOW_ID = "7a3eb820-f17d-47ce-a337-da2358c2a0d5"
CHECKPOINT = "Juggernaut-XL_v9.safetensors"
LORA = "RW_pixelart_XL_v1.safetensors"
NEGATIVE_PROMPT = (
    "3d render, realistic, painting, drawing, anime, blurry, low quality, "
    "text, watermark, cropped, out of frame, complex background"
)
SAMPLER = "dpmpp_2m"
SCHEDULER = "karras"
STEPS = 30
CFG = 7
DENOISE = 1

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST_PATH = os.path.join(ROOT, "docs", "assets", "MANIFEST.json")


def build_prompt_graph(prompt: str, seed: int, width: int, height: int) -> dict:
    """Build the ComfyUI /prompt API graph matching the 'base pixel
    factory' workflow's SDXL+pixel-art-LoRA chain (checkpoint 72/lora
    81/ksampler 70/vaedecode 65/saveimage 9 in the saved workflow)."""
    return {
        "1": {
            "class_type": "CheckpointLoaderSimple",
            "inputs": {"ckpt_name": CHECKPOINT},
        },
        "2": {
            "class_type": "LoraLoader",
            "inputs": {
                "model": ["1", 0],
                "clip": ["1", 1],
                "lora_name": LORA,
                "strength_model": 1,
                "strength_clip": 1,
            },
        },
        "3": {
            "class_type": "CLIPTextEncode",
            "inputs": {"clip": ["2", 1], "text": prompt},
        },
        "4": {
            "class_type": "CLIPTextEncode",
            "inputs": {"clip": ["2", 1], "text": NEGATIVE_PROMPT},
        },
        "5": {
            "class_type": "EmptyLatentImage",
            "inputs": {"width": width, "height": height, "batch_size": 1},
        },
        "6": {
            "class_type": "KSampler",
            "inputs": {
                "model": ["2", 0],
                "positive": ["3", 0],
                "negative": ["4", 0],
                "latent_image": ["5", 0],
                "seed": seed,
                "steps": STEPS,
                "cfg": CFG,
                "sampler_name": SAMPLER,
                "scheduler": SCHEDULER,
                "denoise": DENOISE,
            },
        },
        "7": {
            "class_type": "VAEDecode",
            "inputs": {"samples": ["6", 0], "vae": ["1", 2]},
        },
        "8": {
            "class_type": "SaveImage",
            "inputs": {"images": ["7", 0], "filename_prefix": "spaceship_asset"},
        },
    }


def http_json(method: str, path: str, payload: dict | None = None) -> dict:
    url = COMFY_HOST + path
    data = json.dumps(payload).encode("utf-8") if payload is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    if data is not None:
        req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.loads(resp.read().decode("utf-8"))


def queue_prompt(graph: dict) -> str:
    client_id = str(uuid.uuid4())
    result = http_json("POST", "/prompt", {"prompt": graph, "client_id": client_id})
    prompt_id = result.get("prompt_id")
    if not prompt_id:
        raise RuntimeError(f"ComfyUI did not return a prompt_id: {result}")
    return prompt_id


def wait_for_history(prompt_id: str, timeout_s: int = 180) -> dict:
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        try:
            history = http_json("GET", f"/history/{prompt_id}")
        except urllib.error.URLError:
            history = {}
        if prompt_id in history:
            return history[prompt_id]
        time.sleep(2)
    raise TimeoutError(f"ComfyUI did not finish prompt {prompt_id} within {timeout_s}s")


def fetch_image(filename: str, subfolder: str, folder_type: str) -> bytes:
    from urllib.parse import urlencode

    query = urlencode(
        {"filename": filename, "subfolder": subfolder, "type": folder_type}
    )
    url = f"{COMFY_HOST}/view?{query}"
    with urllib.request.urlopen(url, timeout=60) as resp:
        return resp.read()


def load_manifest() -> list:
    if not os.path.exists(MANIFEST_PATH):
        return []
    with open(MANIFEST_PATH, "r", encoding="utf-8") as fh:
        text = fh.read().strip()
    return json.loads(text) if text else []


def save_manifest(entries: list) -> None:
    os.makedirs(os.path.dirname(MANIFEST_PATH), exist_ok=True)
    with open(MANIFEST_PATH, "w", encoding="utf-8") as fh:
        json.dump(entries, fh, indent=2, ensure_ascii=False)
        fh.write("\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--asset-path", required=True, help="assets/... relative path to save PNG")
    parser.add_argument("--prompt", required=True)
    parser.add_argument("--width", type=int, default=512)
    parser.add_argument("--height", type=int, default=512)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--qa", default="pending runtime QA")
    args = parser.parse_args()

    graph = build_prompt_graph(args.prompt, args.seed, args.width, args.height)
    prompt_id = queue_prompt(graph)
    print(f"queued prompt_id={prompt_id}, waiting for ComfyUI...")
    result = wait_for_history(prompt_id)

    outputs = result.get("outputs", {})
    images = outputs.get("8", {}).get("images", [])
    if not images:
        print("ERROR: no images produced", json.dumps(result)[:2000])
        return 1
    image_info = images[0]
    image_bytes = fetch_image(
        image_info["filename"], image_info.get("subfolder", ""), image_info.get("type", "output")
    )

    full_out_path = os.path.join(ROOT, args.asset_path)
    os.makedirs(os.path.dirname(full_out_path), exist_ok=True)
    with open(full_out_path, "wb") as fh:
        fh.write(image_bytes)

    sha256 = hashlib.sha256(image_bytes).hexdigest()

    entries = load_manifest()
    entries = [e for e in entries if e.get("path") != args.asset_path]
    entries.append(
        {
            "path": args.asset_path,
            "source_url": f"{COMFY_HOST}/#{WORKFLOW_ID}",
            "terms_url": f"{COMFY_HOST}/#{WORKFLOW_ID}",
            "asset_id": prompt_id,
            "prompt": args.prompt,
            "model": CHECKPOINT,
            "style": LORA,
            "settings": {
                "seed": args.seed,
                "steps": STEPS,
                "cfg": CFG,
                "sampler": SAMPLER,
                "scheduler": SCHEDULER,
                "denoise": DENOISE,
                "width": args.width,
                "height": args.height,
                "workflow_id": WORKFLOW_ID,
            },
            "downloaded_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "sha256": sha256,
            "width": args.width,
            "height": args.height,
            "qa": args.qa,
        }
    )
    save_manifest(entries)

    print(f"OK: saved {args.asset_path} sha256={sha256}")
    print(f"manifest updated: {MANIFEST_PATH}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
