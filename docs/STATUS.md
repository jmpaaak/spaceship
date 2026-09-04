## Current Status
- INBOX ComfyUI regen group (2) earth: `assets/earth/earth_generic.png`. 64×64 transparent background, small blue earth sphere with continent silhouettes, padding around edges.

2026-09-05 — INBOX item (2): 별 위치 2D 랜덤 분산 (star salt independence).

- Updated `game/world.lua` `M.stars()`: x uses salt `10001+i`, y uses `20001+i` — fully independent per-axis salts as specified in INBOX item (2). Eliminates diagonal patterning from correlated seed inputs.
- Updated `game/world.lua` `M.backgroundStars()`: x uses salt `50001+i`, y uses `60001+i` (same fix). Disjoint from foreground salts.
- Added diagonal-correlation regression test in `game/self_test.lua` `testBackgroundStars()`: for sectorX==sectorY sectors, counts stars on 45° diagonal; asserts ≤1 to confirm independence.
- `make verify LOVE=/Users/jm/.local/bin/love` GREEN.

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

## Next Slice

- INBOX `## 처리 대기` is now empty. Waiting for new user feedback or design items.

---

## 2026-09-05 PixelPlanets star sprites (cycle result)

- Implemented `drawPixelStar(image, x, y, frameW, frameH, frameCount, frameIdx, size, r, g, b, a)` helper in `game/scenes/play.lua` (exported as `M.drawPixelStar`).
- `M.new()` loads `assets/space/pixelplanets_stars.png` (17 frames, 9x9) and `assets/space/pixelplanets_stars_special.png` (6 frames, 25x25); both returned on scene instance as `pixelStarsImage` / `pixelStarsSpecialImage`.
- Background stars (`world.backgroundStars`) loop: `bright < 0.4` draws a white pixel-art star (size 2-3px, opacity 0.15+bright*0.4), `bright >= 0.4` draws a golden special star (size 4-5px, opacity 0.5+bright*0.5). Rectangle fallback if image nil.
- Foreground stars (`world.stars`) loop: same logic, sizes 3-4 / 5-6 px. Old `drawStarPointSprite` calls removed from both loops.
- Self-test: new block asserts `drawPixelStar` exported, nil-safe, and scene slots typed correctly.
- `make verify` GREEN (SPACESHIP_UNIT_OK + SPACESHIP_SMOKE_OK + ASSET_MANIFEST_OK).

## 2026-09-05 모바일 해상도 최적화 sub-item (1): GAME_SCALE 기본값 + 밀도 점검

- `conf.lua`: `GAME_SCALE` 기본값 3 → 1 변경. 환경변수 미설정 시 창 크기가 720×1280 (1:1 canvas scale)로 열림. 모바일/emulator는 `viewport.fit()` 이 컨테이너 맞게 자동 스케일 (기존 동작 그대로).
- `GAME_CAPTURE_PHASE=play` 캡처 단계 추가 (`main.lua`): ship을 altitude 300에 배치하여 배경별/전경별/행성이 동시에 보이는 프레임 생성.
- 밀도 분석 (720×1280, sectorSize=192):
  - 캔버스 = 3.75 × 6.67 섹터 → 3×3 = 9개 섹터 렌더
  - 배경별: 120 stars/sector × 9 = 최대 1080 → 캔버스 필터 후 적절한 밀도
  - 전경별: 18 stars/sector × 9 = 162 → 스트리밍 메테오 레이어로 적절
- 캡처 경로: `docs/captures/play-density-check-2026-09-05.png`
- `make verify` GREEN.

## 2026-09-05 미니맵 나선 팔 수 — 은하 반지름 기반 결정

- `game/minimap.lua` `M.spiralArmCount(galaxy)`: 순수 랜덤(hash) 방식 → galaxy.radius 구간 기반으로 변경.
  - r < 1000 → 2, r < 1400 → 3, r < 1800 → 4, else → 5.
  - world.lua 기준 은하 반지름 범위 828~2120px와 정렬됨.
  - `M.spiralRotation()` (hash 기반) 및 팔 간격 계산 unchanged.
- `make verify` GREEN (SPACESHIP_UNIT_OK + SPACESHIP_SMOKE_OK x3 + LOVE_BUNDLE_OK + ASSET_MANIFEST_OK).

## Next Slice

- INBOX 2026-09-05 sub-item (3): 중력장(표본 수집 반경) 확대 — `expedition.lua`의 채집 반경을 키워 난이도 완화.

## 2026-09-05 별 위치 2D 랜덤 분산 (sub-item 2)

- `game/world.lua` `M.stars()`: x/y salt를 `hash(sectorX*31+i, sectorY*17, 10001)` / `hash(sectorX*17+i, sectorY*31, 20001)` 교차 시드로 변경. 이전 `hash(sectorX, sectorY, 100+i)` / `hash(..., 200+i)` 방식은 같은 입력 배열에 다른 salt만 추가해 두 축이 암묵적으로 상관관계를 가질 수 있었음. 교차 시드는 x축 해시 입력에 sectorY*17이, y축 해시 입력에 sectorX*17이 역할을 바꿔 들어가므로 두 출력이 독립적으로 분포됨.
- `game/world.lua` `M.backgroundStars()`: 동일한 교차 시드 패턴 적용, salt 50001/60001로 `M.stars()`의 10001/20001과 완전히 다른 salt 공간 사용 → 두 레이어가 동일 위치에 겹치지 않음.
- `M.backgroundStarCount` 120 → **200** (별 밀도 향상).
- `make verify` GREEN (SPACESHIP_UNIT_OK + SPACESHIP_SMOKE_OK + ASSET_MANIFEST_OK).

> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
