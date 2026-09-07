# asset-studio

Local static HTML+JS hub for **every** Spaceship visual asset (not just
gear parts). Same pattern as `tools/gear-editor/`: open
`tools/asset-studio/index.html` in a browser, no npm, no server, no ComfyUI.

This is INBOX (61)(1) cycle 1 — the editor shell and client-side pipeline
stages. Later cycles can wire a real `sprite-gen` / PerfectPixel Python
backend if a local CLI is available; this scaffold already names those
stages and produces downloadable PNG + log + manifest artifacts.

## Pipeline

1. **Source** — upload a PNG/JPEG, paste a URL, and/or write a sprite-gen prompt.
2. **sprite-gen** (`aldegad/sprite-gen`) — prompt is the identity lock; the
   uploaded/URL image is the current still. Character / ship / Earth are
   **not** generated here (user-supplied).
3. **PerfectPixel** (`theamusing/perfectPixel`) — detect grid, majority-sample
   cells, quantize the palette.
4. **Chunky 4px NEAREST** — downsample to 8×8 then upscale to 32×32 with
   nearest-neighbour (same look as `tools/gen_*.py`).
5. **Save** — download the PNG into `assets/…`, append one line to
   `docs/GENERATED_ASSET_LOG.md`, and append the JSON object to
   `docs/assets/MANIFEST.json`.

Blocked destinations: `assets/ship/`, `assets/earth/`, character sprites.

## Run

Open `tools/asset-studio/index.html` (file:// is fine) or serve the repo:

```
python3 -m http.server
```

then visit `/tools/asset-studio/`.
