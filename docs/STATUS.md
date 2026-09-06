## Current Status

- INBOX (47) complete: Hub planets now open full settlement shop (same as Earth).
  - Hub collision triggers `expedition.settle(run)` → phase = "settlement" with full shop UI.
  - `exploreHub` gear drop still fires before settlement entry.
  - `lastHubX`/`lastHubY` stored on hub visit; relaunch from hub spawns ship near hub position.
  - `launch()` and `destroy()` clear `lastHubX`/`lastHubY`.
  - i18n: `hub_shop_label` = "HUB SHOP" / "HUB 상점". Settlement title distinguishes hub vs Earth.
  - `make verify` GREEN.

## Next slice

- Process next pending INBOX item (48 or later).

## Previous

- INBOX (46) complete: Removed `planet_new_discovery` floating text from draw (play.lua).
- INBOX (45) complete: Minimap galaxy density + ring opacity adjustments.
- INBOX (44) complete: Ship stats summary below minimap right side during ascending.
- INBOX (43) complete: PIL-generated 16×16 HUD icons for distance/cash/durability.
- INBOX (42) complete: gear slots layout changed from horizontal row to vertical column.
- INBOX (41) complete: HUD font size unified across all phases (launch = ascending).
- INBOX (40) complete: Gear slots grid fixed below left HUD stats during ascending/returning/launch.
- INBOX (36) complete: flat $1 planet sample value.
