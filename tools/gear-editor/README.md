# gear-editor

A small, dependency-free static web tool for viewing and editing the
spaceship game's hull/engine part card data
(`game/data/hull_parts.json`, `game/data/engine_parts.json`).

This implements `docs/feedback/INBOX.md` item 13's "웹 에디터" requirement:
a visual tool to list/add/edit/delete part cards without hand-editing JSON,
so a human can iterate on the game's ~20-30+ card pool without touching Lua.

## Running it

No build step, no server-side dependency, no npm install. Two ways to use it:

1. **Directly**: open `tools/gear-editor/index.html` in a browser. Then use
   "Open hull_parts.json" / "Open engine_parts.json" to load a file from
   disk (any modern browser supports `<input type=file>`), edit cards in
   the form/grid, and click "Download JSON" to save your edits back to
   `game/data/hull_parts.json` (overwrite the file when your browser
   downloads it, or move the downloaded file into place manually).

2. **With File System Access API** (Chrome/Edge): click "Open + enable
   direct save" to pick the JSON file via the native file picker. Edits can
   then be saved straight back to the same file on disk with "Save to disk"
   (no download-and-move step) — this is the smoothest workflow if your
   browser supports it. Firefox/Safari fall back to the download-only flow
   above automatically.

Optionally, serve the folder with any static file server (e.g.
`python3 -m http.server` from the repo root) if you prefer not to use
`file://` URLs — everything works the same either way.

## What it does

- Loads a `{ "schemaVersion": 1, "parts": [...] }` JSON document matching
  the schema documented in `docs/GEAR_SCHEMA.md`.
- Renders a Balatro-style card grid (icon, name, rarity-colored border,
  effect summary) plus a form to add/edit/delete a card:
  id, name (en/ko), icon, rarity (with live color preview), tags,
  editions, and a repeatable effect list (type + numeric value, validated
  client-side against the same known-type/rarity/range rules the Lua
  loader (`game/gear.lua`) enforces).
- Validates before allowing a save: no duplicate ids, no empty
  name/icon/id, at least one effect per card, effect values within the
  documented range, rarity/effect-type must be one of the known enums.
- Exports the edited pool back to indented JSON matching the file layout
  the game reads.

## Scope note

This tool only edits data files under `game/data/`. It does not touch any
`.lua` game code and has no runtime dependency on LÖVE — it is a pure
authoring aid.
