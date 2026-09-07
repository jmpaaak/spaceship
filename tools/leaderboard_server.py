#!/usr/bin/env python3
"""Minimal leaderboard HTTP server for Spaceship.

Stores scores in a JSON file.  Runs on port 8770 by default.

API:
  POST /score   body: {"name": "...", "bestAltitude": 1234}
  GET  /scores?limit=20  -> JSON array sorted by bestAltitude desc
"""
import json, os, sys, time
from http.server import HTTPServer, BaseHTTPRequestHandler

PORT = int(os.environ.get("LEADERBOARD_PORT", "8770"))
DATA_FILE = os.path.join(os.path.dirname(__file__), "leaderboard_data.json")

def load_scores():
    if not os.path.exists(DATA_FILE):
        return []
    with open(DATA_FILE, "r") as f:
        try:
            return json.load(f)
        except json.JSONDecodeError:
            return []

def save_scores(scores):
    with open(DATA_FILE, "w") as f:
        json.dump(scores, f, indent=2, ensure_ascii=False)

class Handler(BaseHTTPRequestHandler):
    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_GET(self):
        if not self.path.startswith("/scores"):
            self.send_response(404)
            self.end_headers()
            return
        limit = 20
        if "limit=" in self.path:
            try:
                limit = int(self.path.split("limit=")[1].split("&")[0])
            except ValueError:
                pass
        scores = load_scores()
        scores.sort(key=lambda s: s.get("bestAltitude", 0), reverse=True)
        body = json.dumps(scores[:limit], ensure_ascii=False).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self._cors()
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        if self.path != "/score":
            self.send_response(404)
            self.end_headers()
            return
        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length)
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            self.send_response(400)
            self.end_headers()
            return
        name = str(data.get("name", "Anonymous"))[:32]
        alt = float(data.get("bestAltitude", 0))
        ts = data.get("timestamp") or time.strftime("%Y-%m-%dT%H:%M:%S%z")
        scores = load_scores()
        scores.append({"name": name, "bestAltitude": alt, "timestamp": ts})
        save_scores(scores)
        self.send_response(201)
        self.send_header("Content-Type", "application/json")
        self._cors()
        self.end_headers()
        self.wfile.write(b'{"ok":true}')

    def log_message(self, fmt, *args):
        sys.stderr.write(f"[leaderboard] {fmt % args}\n")

if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", PORT), Handler)
    print(f"Leaderboard server on :{PORT}  data={DATA_FILE}")
    server.serve_forever()
