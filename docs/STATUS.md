## Current Status

- INBOX 61(5): solarSystem synergy settle effect changed from +1 HP heal to +1 maxDurability.
  - `expedition.settle()`: solarSystem now does `maxDurability += 1` (persists through launch's full heal).
  - i18n EN: "3+ SOLAR: +1 max HP on land", KO: "솔라 3+: 착지 시 최대내구 +1".
  - Updated existing synergy settle test (maxDurability 5→6 assertion).
  - Added testINBOX61_5: verifies i18n copy, maxDurability increase on settle, persistence through launch.
  - Moved items (3), (4), (5) from 처리 대기 to 처리 완료 in INBOX.md.
- `make verify LOVE=…` GREEN: SPACESHIP_UNIT_OK, SPACESHIP_SMOKE_OK, ASSET_MANIFEST_OK.

## Next slice

- Process next pending INBOX item (61.6 or next sub-item).

## Previous

- INBOX 61(4): Shop card 4-line layout, vertical centering, copy fixes.

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
