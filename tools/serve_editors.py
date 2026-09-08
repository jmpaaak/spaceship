#!/usr/bin/env python3
"""Local static editor server + POST /api/sprite-gen (INBOX 61(27)).

Serves the repo so asset-studio / gear-editor work over HTTP, and generates
32x32 (default) PNG sprites from a prompt. Uses the `sprite-gen` Python
package when available. Uploaded images fall back to overlay-free pixel resize;
prompt-only requests fail explicitly rather than returning a fake shape.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import io
import json
import math
import os
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAX_BODY = 8 * 1024 * 1024
MAX_SIZE = 256
MIN_SIZE = 8


def _clamp_size(value, default=32):
    try:
        n = int(value)
    except (TypeError, ValueError):
        n = default
    return max(MIN_SIZE, min(MAX_SIZE, n))


def _prompt_seed(prompt: str) -> int:
    digest = hashlib.sha256((prompt or "spaceship-asset").encode("utf-8")).digest()
    return int.from_bytes(digest[:4], "big") or 1


def _xorshift(state: int):
    x = state & 0xFFFFFFFF

    def rnd():
        nonlocal x
        x ^= (x << 13) & 0xFFFFFFFF
        x ^= (x >> 17) & 0xFFFFFFFF
        x ^= (x << 5) & 0xFFFFFFFF
        x &= 0xFFFFFFFF
        return x / 4294967296.0

    return rnd


def prepare_uploaded_image(width: int, height: int, image_bytes=None):
    """Pixel-resize an upload without adding generated shapes or overlays."""
    if not image_bytes:
        return None
    from PIL import Image, ImageOps

    width = _clamp_size(width)
    height = _clamp_size(height)
    try:
        src = Image.open(io.BytesIO(image_bytes)).convert("RGBA")
    except Exception as error:
        raise ValueError("invalid uploaded image") from error
    fitted = ImageOps.contain(src, (width, height), Image.Resampling.NEAREST)
    result = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    result.alpha_composite(fitted, ((width - fitted.width) // 2, (height - fitted.height) // 2))
    return result


def try_sprite_gen(prompt: str, width: int, height: int, image_bytes=None):
    try:
        import sprite_gen  # type: ignore
    except Exception:
        return None
    for name in ("generate", "run", "create"):
        fn = getattr(sprite_gen, name, None)
        if not callable(fn):
            continue
        try:
            result = fn(prompt=prompt, width=width, height=height, image=image_bytes)
        except TypeError:
            try:
                result = fn(prompt, width, height)
            except Exception:
                continue
        except Exception:
            continue
        if result is None:
            continue
        from PIL import Image
        nearest = Image.Resampling.NEAREST
        if isinstance(result, Image.Image):
            return result.convert("RGBA").resize((width, height), nearest)
        if isinstance(result, (bytes, bytearray)):
            return Image.open(io.BytesIO(result)).convert("RGBA").resize(
                (width, height), nearest
            )
    return None


def generate_sprite(prompt: str, width=32, height=32, image_bytes=None):
    width = _clamp_size(width)
    height = _clamp_size(height)
    img = try_sprite_gen(prompt, width, height, image_bytes)
    engine = "sprite-gen"
    if img is None and image_bytes:
        img = prepare_uploaded_image(width, height, image_bytes)
        engine = "uploaded-image"
    if img is None:
        raise RuntimeError("sprite generator unavailable; upload an image or install sprite-gen")
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    png = buf.getvalue()
    return {
        "png_b64": base64.b64encode(png).decode("ascii"),
        "width": img.size[0],
        "height": img.size[1],
        "engine": engine,
        "mime": "image/png",
    }


def decode_image_field(value):
    if not value:
        return None
    if isinstance(value, bytes):
        return value
    text = str(value).strip()
    if "," in text and text.lower().startswith("data:"):
        text = text.split(",", 1)[1]
    try:
        return base64.b64decode(text)
    except Exception:
        return None


class EditorHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Cache-Control", "no-store, max-age=0")
        super().end_headers()

    def do_OPTIONS(self):
        parsed = urlparse(self.path)
        if parsed.path == "/api/sprite-gen":
            self.send_response(204)
            self.end_headers()
            return
        self.send_response(204)
        self.end_headers()

    def do_POST(self):
        parsed = urlparse(self.path)
        if parsed.path != "/api/sprite-gen":
            self.send_error(404, "not found")
            return
        length = int(self.headers.get("Content-Length", "0") or 0)
        if length > MAX_BODY:
            self._json(413, {"error": "body too large"})
            return
        raw = self.rfile.read(length) if length else b"{}"
        try:
            data = json.loads(raw.decode("utf-8") or "{}")
        except json.JSONDecodeError:
            self._json(400, {"error": "invalid json"})
            return
        if not isinstance(data, dict):
            self._json(400, {"error": "expected object"})
            return
        prompt = str(data.get("prompt") or "").strip()
        if not prompt:
            self._json(400, {"error": "prompt required"})
            return
        width = _clamp_size(data.get("width", 32))
        height = _clamp_size(data.get("height", 32))
        image_bytes = decode_image_field(data.get("image"))
        try:
            result = generate_sprite(prompt, width, height, image_bytes)
        except (RuntimeError, ValueError) as error:
            self._json(503, {"error": str(error)})
            return
        self._json(200, result)

    def _json(self, code, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), format % args))


def main(argv=None):
    parser = argparse.ArgumentParser(description="Serve editors + /api/sprite-gen")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args(argv)
    httpd = ThreadingHTTPServer((args.host, args.port), EditorHandler)
    print("serving %s on http://%s:%d  (POST /api/sprite-gen)" % (ROOT, args.host, args.port))
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nbye")
    finally:
        httpd.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
