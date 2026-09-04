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

- INBOX group (4): floating text icons — `floating_sample.png`, `floating_damage.png`, `message_banner.png`.

2026-09-04 — ComfyUI planet effect wiring (group 3 of INBOX draw-wiring item).

- Added `drawPlanetEffectSprite(image, cx, cy, diameter, r, g, b, a)` helper; exported as `M.drawPlanetEffectSprite`.
- 6 planet effect PNGs loaded in `M.new()` into `self.planetEffectImages`: glow, shadow, rim, twinkle, sampleValue, risk.
- In `draw()` planet loop:
  - Glow rings: sprite-or-poly fallback (`planet_glow.png` tinted with tier color, diameter = radius+3+glowRings*4 * 2).
  - Drop shadow: sprite-or-poly fallback (`planet_shadow.png` offset lower-right).
  - Rim circle (undiscovered): sprite-or-poly fallback (`planet_rim.png` tinted with tier color).
  - Twinkle sparkle points: each small point replaced with `planet_twinkle.png` sprite-or-1.2px-circle fallback.
  - Sample value label: `planet_sample.png` icon drawn 9px to the left when image available.
  - Risk label: `planet_risk.png` icon drawn 9px to the left when image available.
- Regression test: `drawPlanetEffectSprite` exported, nil→false no-throw, `planetEffectImages` has all 6 keys.
- `make verify` GREEN.

2026-09-04 — ComfyUI minimap marker wiring (group 2 of INBOX draw-wiring item).

- Added `drawMinimapSprite(image, cx, cy, targetDiameter)` helper to `game/scenes/play.lua`; exported as `M.drawMinimapSprite`.
- 12 minimap PNGs now loaded in `M.new()` into `self.minimapImages`: disc, player, sun, earth, earthReturn, galaxyHome, galaxyPlain, checkpointStar, checkpointArrow, spiralStar, orbitRing, galaxyRing.
- `drawMinimap()` fully sprite-wired: background disc, orbit rings, galaxy rings, sun, galaxy home/hub/plain dots, earth marker, player marker, beyond-chart earth-return arrow (rotated), off-chart checkpoint arrow (rotated). Every element falls back to original polygon if image is nil.
- `make verify` GREEN.

