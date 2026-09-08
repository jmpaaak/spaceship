"""INBOX 61(27): POST /api/sprite-gen on tools/serve_editors.py."""
import base64
import io
import json
import os
import sys
import threading
import unittest
from http.server import ThreadingHTTPServer
from unittest.mock import patch
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

    def test_prompt_without_generator_is_503_not_fake_shape(self):
        with patch.object(se, "try_sprite_gen", return_value=None):
            with self.assertRaises(HTTPError) as ctx:
                self._post({"prompt": "gold asteroid", "width": 32, "height": 32})
        self.assertEqual(ctx.exception.code, 503)
        body = json.loads(ctx.exception.read().decode("utf-8"))
        self.assertIn("generator unavailable", body["error"])

    def test_missing_prompt_is_400(self):
        body = json.dumps({"width": 32}).encode("utf-8")
        req = Request(self.url, data=body, headers={"Content-Type": "application/json"})
        with self.assertRaises(HTTPError) as ctx:
            urlopen(req, timeout=5)
        self.assertEqual(ctx.exception.code, 400)

    @staticmethod
    def _png_b64(color, size=(8, 8)):
        tiny = Image.new("RGBA", size, color)
        buf = io.BytesIO()
        tiny.save(buf, format="PNG")
        return base64.b64encode(buf.getvalue()).decode("ascii")

    def test_uploaded_image_is_preserved_without_shape_overlay(self):
        color = (12, 34, 56, 255)
        with patch.object(se, "try_sprite_gen", return_value=None):
            status, data = self._post({
                "prompt": "conditioned nebula",
                "width": 16,
                "height": 16,
                "image": self._png_b64(color),
            })
        self.assertEqual(status, 200)
        self.assertEqual(data["engine"], "uploaded-image")
        img = Image.open(io.BytesIO(base64.b64decode(data["png_b64"]))).convert("RGBA")
        self.assertEqual(img.size, (16, 16))
        self.assertEqual(set(list(img.getdata())), {color})

    def test_different_uploads_produce_different_results(self):
        with patch.object(se, "try_sprite_gen", return_value=None):
            _, red = self._post({"prompt": "same", "image": self._png_b64((255, 0, 0, 255))})
            _, blue = self._post({"prompt": "same", "image": self._png_b64((0, 0, 255, 255))})
        self.assertNotEqual(red["png_b64"], blue["png_b64"])

    def test_static_assets_disable_cache(self):
        with urlopen("http://127.0.0.1:%d/tools/asset-studio/editor.js" % self.port, timeout=5) as resp:
            self.assertEqual(resp.headers.get("Cache-Control"), "no-store, max-age=0")


if __name__ == "__main__":
    unittest.main()
