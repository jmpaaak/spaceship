## Current Status

- INBOX (44) complete: Ship stats summary below minimap right side during ascending.
  - `drawShipStatsSummary()` method added to `play.lua`: shows ship name, speed LV, hull LV, harvest LV.
  - 22px font, right-aligned, positioned below minimap disc with 8px gap.
  - Only visible during ascending phase (hidden in settlement/destroyed/launch).
  - i18n keys added: `ship_stats_ship`, `ship_stats_speed`, `ship_stats_hull`, `ship_stats_harvest` (EN + KO).
  - Test: INBOX-44 block verifies 4 right-aligned lines, correct content, correct x position, no draw during settlement.
  - `make verify` GREEN.

## Next slice

- INBOX (45): Minimap hide non-containing galaxies + reduce ring opacity.

## Previous

- INBOX (43) complete: PIL-generated 16×16 HUD icons for distance/cash/durability.
- INBOX (42) complete: gear slots layout changed from horizontal row to vertical column.
- INBOX (41) complete: HUD font size unified across all phases (launch = ascending).
- INBOX (40) complete: Gear slots grid fixed below left HUD stats during ascending/returning/launch.
- INBOX (36) complete: flat $1 planet sample value.
