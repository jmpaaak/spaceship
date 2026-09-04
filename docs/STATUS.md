# STATUS

2026-09-04 — merged `spaceship-gear` into `main`.

- Gear lane had emptied INBOX (items 7/8/11/15 newly completed; 9/10/12/13/14 already done) and was STOP'd to stop idle watchdog restarts.
- Merge took gear gameplay (`expedition.lua`, `play.lua`, `self_test.lua`, `i18n.lua`, `world.lua`, `main.lua`) plus gear JSON/editor (`game/gear.lua`, `game/data/*`, `tools/gear-editor/`).\n- Kept main analog 8-way `game/ship.lua`, main loop PROMPT/env/preflight (TOKEN HINT, WAIT=10), and main ComfyUI URL prefixes in `tools/verify_asset_manifest.py`.

2026-09-04 — ComfyUI HUD icon wiring (group 1 of INBOX draw-wiring item).

- Added `drawHudSpriteOrPoly(image, pointsFn, cx, cy, size)` helper to `game/scenes/play.lua`; exported as `M.drawHudSpriteOrPoly`.
- 9 HUD PNGs now loaded in `M.new()` into `self.hudIconImages`: cash (hud_coin.png), hull (hud_shield.png), speed (hud_speed.png), distance (hud_distance.png), best (hud_best.png), samples (hud_samples.png), galaxy (hud_galaxy.png), returnIc (hud_return.png), earth (hud_earth.png).
- In `draw()`: galaxy name row, distance/cash row, hull-status row, samples row, earth/return rows, best-altitude row all use sprite-or-poly fallback.
- `make verify` GREEN.

## Next Slice

- INBOX group (2): minimap marker PNGs (minimap_disc.png, minimap_player.png, minimap_sun.png, etc.) wired into `drawMinimap()`.
