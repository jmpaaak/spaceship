## Current Status

- INBOX (38a) complete: HUD font 2× scaling.
  - `hudFontSize` 14→44, `hudLineStep` 22→52, `launchHudHeight` 88→176.
  - `hullIconSize` 16→32, `hullIconGap` 6→8, `cashIconSize` 16→32, `cashIconGap` 6→8.
  - `hudPrimaryStatusGap` 6→12, `hudGalaxyShift` 16→52.
  - `hudBackgroundMaxWidth` 280→500 to accommodate wider 44px text.
  - `hudHeight()` ascending: 60→120 (no best), 88→176 (with best).
  - Status/best line Y positions doubled (32→64, 60→120).
  - Tests updated to assert new 2× values.
  - `make verify` GREEN.

## Next slice
- INBOX (38b): one stat per line layout + (38c) durability HP blocks + (38d) best always visible + (38e) hudHeight recalc.

## Previous

- INBOX (36) complete: flat $1 planet sample value.
  - `world.sampleValue()` → fixed `return 1`.
  - Comet value: 50 × $1 = $50.

- INBOX (35) complete: comet system — fast, rare, high-reward celestial body.
