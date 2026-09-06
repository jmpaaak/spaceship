## Current Status

- INBOX (40) complete: Gear slots grid fixed below left HUD stats during ascending/returning/launch.
  - Added `drawHudGearSlots(hudHeight)` method: 32×32px slot grid (hull 6 + engine 3).
  - Filled slots show rarity-tinted background + icon overlay; empty slots show dim outline.
  - "GEAR" / "장착" label in 22px above the grid.
  - Called from draw() after HUD stats, before minimap.
  - i18n key `hud_gear_label` (EN + KO).
  - INBOX-40 test block in self_test.lua.
  - `make verify` GREEN.

## Next slice

- INBOX (41): next pending item from INBOX.md.

## Previous

- INBOX (39) complete: Moved "Tap to Launch" text and rocket icon above the loadout panel.
- INBOX (38) complete: HUD text 2x scaling, one stat per line, durability blocks, and best record.
- INBOX (37) complete: Moon system implementation.
- INBOX (36) complete: flat $1 planet sample value.
