## Current Status

- INBOX 61(9)(10)(11)(13): batch fix — rim marker colours, pause time freeze, star scan, debris.
  - (9) Both minimap rim markers now cyan `{0.3,0.9,0.95}`, second alpha 0.45, radius 2.8 (smaller).
  - (10) `self.time += dt` removed from paused/gearPopup early returns → moons/comets/debris freeze.
  - (11) Background + foreground star scan range dynamic `max(4, ceil(h/2/sectorSize)+2)` — no pop-in gaps.
  - (13) Debris: radii 8-16/5-8/5-10, continuous angle velocity, `time % 30` wrap — visible at t=300.
  - Tests: INBOX-61(9/10/11/13) all GREEN.
- `make verify LOVE=…` GREEN: SPACESHIP_UNIT_OK, SPACESHIP_SMOKE_OK, ASSET_MANIFEST_OK.

## Next slice

- Process next pending INBOX item (12: game-over keep-one card overflow + confirm popup).

## Previous

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
- INBOX (40) complete: Gear slots grid fixed below left HUD stats during ascending/returning/launch.
- INBOX (36) complete: flat $1 planet sample value.
