## Current Status

- INBOX (38b) complete: one stat per line HUD layout.
  - Distance, cash, status each on separate lines (were: dist+cash same line, status at hardcoded Y).
  - All HUD lines use sequential `hudY += hudLineStep` instead of hardcoded Y positions.
  - `hudHeight()` now counts lines dynamically: 3 base (dist/cash/status) +1 galaxy +1 best.
  - `hudBackgroundWidth()` measures each line independently (cash no longer combined with dist).
  - Tests: ascending+galaxy=212, no-galaxy=160, galaxy+best=264.
  - `make verify` GREEN.

## Next slice
- INBOX (38c): durability HP blocks + (38d) best always visible + (38e) hudHeight recalc.

## Previous

- INBOX (38a) complete: HUD font 2× scaling.
  - `hudFontSize` 14→44, `hudLineStep` 22→52, `launchHudHeight` 88→176.
  - `hullIconSize` 16→32, `hullIconGap` 6→8, `cashIconSize` 16→32, `cashIconGap` 6→8.
  - `hudPrimaryStatusGap` 6→12, `hudGalaxyShift` 16→52.
  - `hudBackgroundMaxWidth` 280→500 to accommodate wider 44px text.

- INBOX (36) complete: flat $1 planet sample value.
