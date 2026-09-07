## Current Status
- INBOX 61(21): Pause menu restart/main-menu buttons + title scene.
  - Pause overlay now shows RESTART and MAIN MENU buttons (centered, below "PAUSED" label).
  - RESTART: resets expedition to launch phase, repositions ship.
  - MAIN MENU: fires `onMainMenu` callback → switches to TitleScene.
  - New `game/scenes/title.lua`: starfield background + game title + START/CONTINUE/SETTINGS buttons.
  - CONTINUE greyed out when `hasSave=false`.
  - `main.lua` starts with TitleScene (capture modes bypass to PlayScene directly).
  - i18n keys: `pause_restart`, `pause_main_menu`, `title_game_name`, `title_start`, `title_continue`, `title_settings` (EN+KO).
  - Test `INBOX-61(21)` verifies i18n, rect layout, restart tap, main-menu callback, title scene buttons, continue gating.
  - `make verify LOVE=…` GREEN.

## Next slice

- Process next pending INBOX item (22: DANGER text near sun + sun asset).

## Previous
- INBOX 61(20): Removed `[B]:` keyboard prefix from gear offer text.
  - Slot speed rewards (+5/+20) now accumulate in `slotSpeedBonus` field.
  - `effectiveSpeed()` sums `slotSpeedBonus` alongside base + shop upgrades.
  - `steeringUpgradeLevel` stays shop-only, so `upgradeCost` stays sane.
  - `slotSpeedBonus` resets on meta wipe (destruction) like other upgrade fields.
  - Test `INBOX-61(19)` verifies cost isolation, speed inclusion, and wipe reset.
  - Test `INBOX-61(18)` verifies row3 < 100px, contiguity, panel bounds.
  - `make verify LOVE=…` GREEN.
- INBOX 61(14): Planet fallback sprite loading fix.
  - Replaced `love.filesystem.read(path)` with `love.filesystem.newFile` and `file:read(33)` in `pngColorType`. This fixes memory/large string issues on mobile Android devices that caused `pngColorType` to return nil, triggering the green circle fallback for perfectly valid RGBA planet sheets.
  - Fixed a rotation bug in planet sheet rendering: `love.graphics.draw` now correctly rotates around the sheet center (`sw / 2, frameH / 2`) instead of wildly swinging around the top-left corner.
  - Added test coverage in `self_test.lua` to mock `love.filesystem.read` and `io.open` failures (simulating the mobile environment) to guarantee `pngColorType` successfully loads planet sheets using `love.filesystem.newFile`.
  - Verified tests pass (`make verify LOVE=...`).
- INBOX 61(16): hub restock gear button.
  - `expedition.hubRestock(run, pool, rolls)`: pay $5 to re-roll gear offer at
    hub settlement shops only (lastVisitedGalaxyId required, Earth excluded).
  - `expedition.hubRestockCost = 5` constant.
  - i18n keys `hub_restock_btn` (EN/KO).
  - play.lua: key "r" triggers restock; gear touch button routes to restock when
    at hub with no active gear offer; draw shows restock button text with
    green/red color based on affordability.
  - Test `INBOX-61(16)`: verifies success, Earth rejection, insufficient money
    rejection, and i18n key existence.
  - `make verify LOVE=…` GREEN: SPACESHIP_UNIT_OK, SPACESHIP_SMOKE_OK,
    ASSET_MANIFEST_OK.
- INBOX 61(12): keep-one confirm popup + card text fix.
  - drawBalatroCard name text: 22px → 11px, clipped inside card via setScissor (no overflow).
  - Tapping a card no longer immediately keeps it; opens a confirm popup with:
    name, effect lines, rarity chip, suit chip, synergy hint (two lines), Yes/No buttons.
  - Yes → keptPart set, No → popup dismissed, pick again.
  - Yes/No buttons 48px tall (≥44px touch target requirement).
  - keepConfirmButtons() pure function, tested: layout fits 720×1280, buttons inside popup.
  - i18n: keep_confirm_title, keep_yes, keep_no (EN + KO).
  - Tests: INBOX-61(12) keepOne confirm popup OK.
  - (9) Both minimap rim markers now cyan `{0.3,0.9,0.95}`, second alpha 0.45, radius 2.8 (smaller).
  - (10) `self.time += dt` removed from paused/gearPopup early returns → moons/comets/debris freeze.
  - (11) Background + foreground star scan range dynamic `max(4, ceil(h/2/sectorSize)+2)` — no pop-in gaps.
  - (13) Debris: radii 8-16/5-8/5-10, continuous angle velocity, `time % 30` wrap — visible at t=300.
  - Tests: INBOX-61(9/10/11/13) all GREEN.

- INBOX 61(8): Part icons + HUD slot 48px.

- INBOX 61(6): Synergy popup two lines + prefix symbol removal + void collect +30%.

- Fix: previous cycle left uncommitted star sprite assets (`assets/star/`,
  `tools/gen_stars.py`) and partially updated collision damage formula
  (`world.collisionDamage` /2000 gentle scaling). Added 7 star PNG manifest
  entries to `docs/assets/MANIFEST.json`, fixed duplicate collision damage
  test assertion in `self_test.lua` (line 8419: y=-500→y=-2000 to match
  new /2000 formula), wired star sprites into PlayScene draw. `make verify
  LOVE=…` GREEN: SPACESHIP_UNIT_OK, SPACESHIP_SMOKE_OK, ASSET_MANIFEST_OK.

- Fix: `make verify` failed ASSET_MANIFEST_FAIL — sha256 mismatches for
  `assets/earth/earth_generic.png` and six `assets/planet/pp_*.png` sprites
  (chunky 4px regeneration left stale hashes). Updated
  `docs/assets/MANIFEST.json` to on-disk hashes.

- INBOX (59) complete: Added random rotation for debris sprites.

- INBOX (58) complete: Fixed a bug where tapping "relaunch" in a hub settlement triggered an instant re-settlement.
  - Adjusted the hub relaunch ship spawn position (`self.ship.y = hubY - 80`) to ensure it sits safely outside the hub planet's `collectOrbitRadius`.

- INBOX (52a) complete: PIL-generated slot machine symbol assets (5 symbols + machine body).
  - `tools/gen_slot_symbols.py`: generates money/part/speed/durability/harvest 32×32 RGBA PNGs.
  - `tools/gen_slot_machine.py`: generates machine body 96×48 RGBA PNG with 3 reel windows + lever.
  - All 6 PNGs registered in `docs/assets/MANIFEST.json` with SHA-256 verification.
  - Logged in `docs/GENERATED_ASSET_LOG.md`.
- INBOX (52b/52c) complete: Slot machine redesign — replaced 3-symbol legacy system with 5-symbol system (MONEY, PART, SPEED, DURABILITY, HARVEST), touch-to-stop reel logic, new payouts (miss=0, pair=3x, triple=10x), and PIL-generated machine frame and symbols.
- INBOX (47) complete: Hub planets now open full settlement shop (same as Earth).
- INBOX (45) complete: Minimap galaxy density + ring opacity adjustments.
- INBOX (44) complete: Ship stats summary below minimap right side during ascending.
- INBOX (43) complete: PIL-generated 16×16 HUD icons for distance/cash/durability.
- INBOX (42) complete: gear slots layout changed from horizontal row to vertical column.
- INBOX (41) complete: HUD font size unified across all phases (launch = ascending).
