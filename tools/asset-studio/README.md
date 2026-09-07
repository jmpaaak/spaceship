# asset-studio

Local static HTML+JS hub for **every** Spaceship visual asset (not just
gear parts). Same pattern as `tools/gear-editor/`: open
`tools/asset-studio/index.html` in a browser, no npm, no server, no ComfyUI.

This is INBOX (61)(1) plus (61)(27): the editor shell, client-side
pipeline stages, and `POST /api/sprite-gen` via `tools/serve_editors.py`.
The Python server tries the `sprite-gen` package and falls back to
deterministic PIL shapes when it is missing.

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

Open `tools/asset-studio/index.html` (file:// is fine for the static
pipeline; prompt generation needs the local server) or:

```
python3 tools/serve_editors.py
```

then visit `http://127.0.0.1:8765/tools/asset-studio/`.
`Generate from prompt` POSTs `{"prompt","width","height"}` (and optional
`image` base64 for upload conditioning) to `/api/sprite-gen`.
