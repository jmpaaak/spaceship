## Current Status

- INBOX (43) complete: PIL-generated 16×16 HUD icons for distance/cash/durability.
  - `tools/gen_hud_icons.py`: PIL script (≤50 lines) generates 3 RGBA icons.
  - `assets/hud/icon_distance.png`: cyan arrow with star sparkles.
  - `assets/hud/icon_cash.png`: gold coin with $ motif.
  - `assets/hud/icon_durability.png`: green shield with cross.
  - `play.lua` hudIconImages updated to load new paths.
  - Tests updated for 16×16 size + dynamic corner indices.
  - `make verify` GREEN.

## Next slice

- INBOX (44): Ship stats summary below minimap right side.

## Previous

- INBOX (42) complete: gear slots layout changed from horizontal row to vertical column.
- INBOX (41) complete: HUD font size unified across all phases (launch = ascending).
- INBOX (40) complete: Gear slots grid fixed below left HUD stats during ascending/returning/launch.
- INBOX (36) complete: flat $1 planet sample value.
