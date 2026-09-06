## Current Status

- INBOX (38) complete: HUD text 2x scaling, one stat per line, durability blocks, and best record.
  - (38a) `hudFontSize` scaled to 44px, `hudLineStep` to 52, icons scaled proportionally.
  - (38b) One stat per line HUD layout (galaxy, best, distance, cash, durability).
  - (38c) Durability is now visually rendered as sequential 12x12 HP blocks colored green/yellow/red instead of text status.
  - (38d) Best record (`hud.best`) is always visible, including in the ascending phase, positioned immediately after the galaxy name.
  - (38e) `hudHeight()` and `hudBackgroundWidth()` correctly measure layout, accounting for dynamic lines and the block width for durability.
  - `make verify` GREEN.

## Next slice

- INBOX (39): Move "Tap to Launch" text above the launch loadout panel with float animation.

## Previous

- INBOX (37) complete: Moon system implementation.
- INBOX (36) complete: flat $1 planet sample value.
