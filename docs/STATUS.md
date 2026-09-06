## Current Status

- Fix: asset manifest sha256 for `assets/earth/earth_generic.png` was stale after
  the INBOX-60 PIL regeneration. Updated hash to match actual file
  (7b0a977…→matches on-disk). `make verify` now passes (ASSET_MANIFEST_OK).

## Next slice

- Process next pending INBOX item.

## Previous

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
