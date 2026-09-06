## Current Status

- INBOX (41) complete: HUD font size unified across all phases (launch = ascending).
  - `M.hudFontSize` 44→22, `M.hudLineStep` 52→30, icons 32→16px, background max 500→280px.
  - Removed launch-only font override (`previousHudFont` / `isLaunchHud` font branch).
  - Removed unused `M.launchHudHeight`.
  - All phases now use the default 22px font set at init — no per-phase branching.
  - Updated self_test assertions (hudHeight values, font size range).
  - `make verify` GREEN.

## Next slice

- INBOX (42): gear slot layout change from horizontal to vertical column.

## Previous

- INBOX (40) complete: Gear slots grid fixed below left HUD stats during ascending/returning/launch.
- INBOX (36) complete: flat $1 planet sample value.
