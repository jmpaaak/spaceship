# STATUS

2026-09-05 — INBOX ComfyUI regen item (0): stop `drawPanelSprite` stretching 64×64 panels to 720px.

- Launch was a full-bleed red/cyan blur because `drawPanelSprite` did `love.graphics.draw(image, x, y, 0, w/iw, h/ih)` so 64×64 RGB HUD/loadout/shop panels filled `viewport.width` (720).
- `game/scenes/play.lua` now draws panel sprites at native pixel size (`love.graphics.draw(image, x, y)`). Nil image still returns false so callers keep the original rectangle fallback. Dest `w,h` stay in the signature for a later 9-slice/tile path.
- HUD icons still use `drawHudSpriteOrPoly` `size` (8–14px). Earth diameter stays 116px; ship logical size stays 64px. Unchanged.
- RED then GREEN: `game/self_test.lua` fake 64×64 image + dest 720×32 now asserts `sx==1, sy==1` (was `sx=11.25 sy=0.5`).
- `make verify LOVE=/Users/jm/.local/bin/love` GREEN (`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:169`, `ASSET_MANIFEST_OK`).
- Launch capture (not committed): `GAME_CAPTURE=1 GAME_CAPTURE_PHASE=launch` → `/Users/jm/Library/Application Support/LOVE/spaceship/spaceship-runtime-preview.png` copied locally to `build/spaceship-runtime-preview-launch-nostretch.png` (gitignored). Downsample 180×320: 82 saturated-red / 122 cyan pixels vs 56165 dark — no full-bleed stretch.

## Next Slice

- INBOX ComfyUI regen group (2) earth: `assets/earth/earth_generic.png`. 64×64 transparent background, small blue earth sphere with continent silhouettes, padding around edges.

2026-09-05 — INBOX ComfyUI regen group (1) ships.

- Generated `assets/ship/ship_default.png` (standard shape) and `assets/ship/ship_scout.png` (swept wings) using ComfyUI asset pipeline.
- Post-processed images to remove black backgrounds (made transparent), crop, and resize nearest-neighbor to ~38x38 centered within a 64x64 transparent canvas.
- Updated `docs/assets/MANIFEST.json` with correct sizes and SHA-256 hashes.
- Appended entries to `docs/GENERATED_ASSET_LOG.md`.
- `make verify` GREEN.

2026-09-04 — ComfyUI shop panels and action backgrounds wiring (group 8 of INBOX draw-wiring item).

- Finished wiring `shopEffectImages` in `game/scenes/play.lua` (loaded as Group 8).
- Settlement phase now uses `shopTouchRow` as backgrounds for tappable rows.
- Wired `shopTitle` behind the shop title and `shopStats` behind the stats box.
- Action, status, and preview rows in the shop for Hull, Steering, Yield, and Ship now have sprite backgrounds (`hullAction`, `hullStatus`, `hullPreview`, etc.).
- Wired `shopNextShip` panel behind the next ship details section.
- Added `GAME_CAPTURE=1 GAME_CAPTURE_PHASE=launch` and `settlement` test captures.
- Updated `docs/feedback/INBOX.md` to mark the top-level ComfyUI draw wiring task as completely finished.
- `make verify` GREEN.

## Next Slice

- The ComfyUI draw wiring item is now fully completed (all 69 assets wired). Read `docs/feedback/INBOX.md` for the next top priority pending item.

2026-09-04 — merged `spaceship-gear` into `main`.

- Gear lane had emptied INBOX (items 7/8/11/15 newly completed; 9/10/12/13/14 already done) and was STOP'd to stop idle watchdog restarts.
- Merge took gear gameplay (`expedition.lua`, `play.lua`, `self_test.lua`, `i18n.lua`, `world.lua`, `main.lua`) plus gear JSON/editor (`game/gear.lua`, `game/data/*`, `tools/gear-editor/`).\n- Kept main analog 8-way `game/ship.lua`, main loop PROMPT/env/preflight (TOKEN HINT, WAIT=10), and main ComfyUI URL prefixes in `tools/verify_asset_manifest.py`.

2026-09-04 — ComfyUI HUD icon wiring (group 1 of INBOX draw-wiring item).

- Added `drawHudSpriteOrPoly(image, pointsFn, cx, cy, size)` helper to `game/scenes/play.lua`; exported as `M.drawHudSpriteOrPoly`.
- 9 HUD PNGs now loaded in `M.new()` into `self.hudIconImages`: cash (hud_coin.png), hull (hud_shield.png), speed (hud_speed.png), distance (hud_distance.png), best (hud_best.png), samples (hud_samples.png), galaxy (hud_galaxy.png), returnIc (hud_return.png), earth (hud_earth.png).
- In `draw()`: galaxy name row, distance/cash row, hull-status row, samples row, earth/return rows, best-altitude row all use sprite-or-poly fallback.
- `make verify` GREEN.

## Next Slice

- INBOX group (6): shop icons — `shop_icons/hull.png`, `steering.png`, `yield.png`, `ship.png` wired into settlement shop rows; joystick sprite wiring (`joystick_knob.png`, `joystick_pad.png`); `star_point.png` and `specimen_banner.png`.

2026-09-04 — ComfyUI shop icons / joystick / star-point / specimen-banner wiring (group 6 of INBOX draw-wiring item).

- Added `drawShopIconSprite(image, cx, cy, size)` and `drawStarPointSprite(image, x, y, size)` helpers; exported on PlayScene.
- 4 new images loaded in `M.new()`: `joystickPadImage`, `joystickKnobImage`, `specimenBannerImage`, `starPointImage`.
- `drawJoystickStick()`: pad circle → `joystickPadImage` sprite; knob circle → `joystickKnobImage` sprite (both fall back to circles when nil).
- Background/foreground star `love.graphics.points` → `drawStarPointSprite(starPointImage, ...)` with size 2/3 px; fallback kept.
- `newSpecimenBanner` fill-rect → `drawPanelSprite(specimenBannerImage, ...)` behind the discovery text; fallback kept.
- Settlement shop rows: `shopIconImages.hull/steering/yield/ship` drawn as 7px badge left of each action sub-column text.
- Regression test: `drawShopIconSprite`/`drawStarPointSprite` exported, nil→false no-throw; scene has `joystickPadImage`, `joystickKnobImage`, `specimenBannerImage`, `starPointImage`; `shopIconImages` map has hull/steering/yield/ship keys.
- `make verify` GREEN.

## Next Slice (group 7)

2026-09-04 — ComfyUI panel/overlay wiring (group 5 of INBOX draw-wiring item).

- Added `drawPanelSprite(image, x, y, w, h)` helper to `game/scenes/play.lua`; exported as `M.drawPanelSprite`.
- 8 panel PNGs loaded in `M.new()`: `launchRocketIconImage` (launch_rocket.png), `loadoutPanelImage` (loadout_panel.png), `loadoutShipImage` (loadout_ship.png), `settlementPanelImage` (settlement_summary_panel.png), `destroyedPanelImage` (destroyed_panel.png), `relaunChImage` (relaunch.png), `slotResultPanelImage` (slot_result_panel.png), `slotSpinButtonImage` (slot_spin_button.png).
- In `draw()`: launch rocket polygon → sprite-or-poly fallback (`launch_rocket.png`); launch loadout box → `loadoutPanelImage` sprite-or-rect; settlement panel → `settlementPanelImage` sprite-or-rect; slot result area → `slotResultPanelImage` behind result text; spin prompt → `slotSpinButtonImage` behind text; relaunch button → `relaunChImage` behind text; destroyed panel → `destroyedPanelImage` sprite-or-rect.
- Regression test: `drawPanelSprite` exported, nil→false no-throw, scene has all 8 panel image slots.
- `make verify` GREEN.

2026-09-04 — ComfyUI floating text icon wiring (group 4 of INBOX draw-wiring item).

- Added `drawFloatingIconSprite(image, cx, cy, size, alpha)` helper; exported as `M.drawFloatingIconSprite`.
- 3 floating-text PNGs loaded in `M.new()`: floatingSampleIconImage (floating_sample.png), floatingDamageIconImage (floating_damage.png), messageBannerIconImage (message_banner.png).
- In `draw()` floating text loop: sample-gain floats (kind != "damage") show cyan plus-badge icon 8px left of +$N label; damage floats show red minus-badge icon 8px left of -N label. Falls back to original centered printf when image is nil.
- In `draw()` message row (non-launch phases): amber burst-star icon drawn 10px to the left of self.message. Launch phase unchanged (rocket polygon still shown).
- Regression test: `drawFloatingIconSprite` exported, nil->false no-throw, scene has all 3 image slots.
- `make verify` GREEN.

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

2026-09-04 — ComfyUI destroyed-phase row icon wiring (group 7 of INBOX draw-wiring item).

- 9 destroyed-phase PNGs loaded in `M.new()`: destroyedTitleIconImage, destroyedLostTotalIconImage, destroyedSamplesSettlementIconImage, destroyedSpinsSettlementIconImage, destroyedPeakDistIconImage, destroyedNewBestIconImage, destroyedMetaResetIconImage, destroyedNextShipIconImage, destroyedTapStartOverIconImage.
- In `draw()` destroyed phase: each printf row now prefixed with a 9px icon via `drawHudSpriteOrPoly`; text shifted right by icon+gap (11px) so icons never overlap text; upgrades line kept full-width (no icon).
- `make verify` GREEN.

## Next Slice (group 8)

- Remaining un-drawn assets: `hud_panel.png`, `shop_panel.png`, `shop_touch_row.png`, `shop_title.png`, `shop_hull_action.png`, `shop_steering_action.png`, `shop_yield_action.png`, `shop_ship_action.png`, `shop_stats.png`, `shop_hull_status.png`, `shop_steering_status.png`, `shop_yield_status.png`, `shop_ship_status.png`, `shop_hull_preview.png`, `shop_steering_preview.png`, `shop_yield_preview.png`, `shop_ship_preview.png`, `shop_next_ship.png`, `loadout_ship.png`, `destroyed_next_ship.png`, `destroyed_tap_start_over.png` — these are the settlement shop text-icon rows; load, store, wire per-row.

