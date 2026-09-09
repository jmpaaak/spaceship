import urllib.request
import json
import base64

# Generate a tiny 1x1 dummy PNG
dummy_png = b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82'
b64_png = "data:image/png;base64," + base64.b64encode(dummy_png).decode("utf-8")

payload = {
    "characterId": "test_ship",
    "description": "A spaceship",
    "assetType": "ship",
    "provider": "gemini",
    "cellSize": 128,
    "chromaKey": "#00FF00",
    "states": [
        {
            "id": "idle",
            "action": "seamless rotate 8 frames",
            "frames": 8,
            "fps": 10,
            "loop": True
        }
    ],
    "baseImageDataUrl": b64_png
}

req = urllib.request.Request("http://127.0.0.1:4176/api/sprite-generate", method="POST", data=json.dumps(payload).encode("utf-8"), headers={"Content-Type": "application/json"})
try:
    with urllib.request.urlopen(req) as resp:
        print(resp.read().decode("utf-8"))
except Exception as e:
    print("Error:", e)
    if hasattr(e, "read"):
        print(e.read().decode("utf-8"))
