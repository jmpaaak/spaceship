"""INBOX 61(27): POST /api/sprite-gen on tools/serve_editors.py."""
import base64
import io
import json
import os
import sys
import threading
import unittest
from http.server import ThreadingHTTPServer
from urllib.error import HTTPError
from urllib.request import Request, urlopen

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import serve_editors as se  # noqa: E402


class SpriteGenApiTests(unittest.TestCase):
    def setUp(self):
        self.httpd = ThreadingHTTPServer(("127.0.0.1", 0), se.EditorHandler)
        self.port = self.httpd.server_address[1]
        self.thread = threading.Thread(target=self.httpd.serve_forever, daemon=True)
        self.thread.start()
        self.url = "http://127.0.0.1:%d/api/sprite-gen" % self.port

    def tearDown(self):
        self.httpd.shutdown()
        self.httpd.server_close()

    def _post(self, payload):
        body = json.dumps(payload).encode("utf-8")
        req = Request(self.url, data=body, headers={"Content-Type": "application/json"})
        with urlopen(req, timeout=5) as resp:
            return resp.status, json.loads(resp.read().decode("utf-8"))

    def test_prompt_returns_png_base64(self):
        status, data = self._post({"prompt": "gold asteroid", "width": 32, "height": 32})
        self.assertEqual(status, 200)
        self.assertIn(data["engine"], ("sprite-gen", "pil-fallback"))
        raw = base64.b64decode(data["png_b64"])
        img = Image.open(io.BytesIO(raw))
        self.assertEqual(img.size, (32, 32))
        self.assertEqual(data["width"], 32)
        self.assertEqual(data["height"], 32)
        self.assertEqual(data["mime"], "image/png")

    def test_same_prompt_is_deterministic(self):
        _, a = self._post({"prompt": "void crystal", "width": 16, "height": 16})
        _, b = self._post({"prompt": "void crystal", "width": 16, "height": 16})
        self.assertEqual(a["png_b64"], b["png_b64"])

    def test_missing_prompt_is_400(self):
        body = json.dumps({"width": 32}).encode("utf-8")
        req = Request(self.url, data=body, headers={"Content-Type": "application/json"})
        with self.assertRaises(HTTPError) as ctx:
            urlopen(req, timeout=5)
        self.assertEqual(ctx.exception.code, 400)

    def test_image_conditioning_accepted(self):
        tiny = Image.new("RGBA", (8, 8), (12, 34, 56, 255))
        buf = io.BytesIO()
        tiny.save(buf, format="PNG")
        b64 = base64.b64encode(buf.getvalue()).decode("ascii")
        status, data = self._post({
            "prompt": "conditioned nebula",
            "width": 16,
            "height": 16,
            "image": b64,
        })
        self.assertEqual(status, 200)
        raw = base64.b64decode(data["png_b64"])
        img = Image.open(io.BytesIO(raw))
        self.assertEqual(img.size, (16, 16))

    def test_generate_sprite_helper_without_http(self):
        result = se.generate_sprite("tiny moon", 24, 24)
        self.assertEqual(result["engine"], "pil-fallback")
        img = Image.open(io.BytesIO(base64.b64decode(result["png_b64"])))
        self.assertEqual(img.size, (24, 24))


if __name__ == "__main__":
    unittest.main()
