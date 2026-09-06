## Current Status

- INBOX (39) complete: Moved "Tap to Launch" text and rocket icon above the loadout panel.
  - messageY for launch phase now uses `M.launchLoadoutBoxTop - 50` instead of `viewport.height - 30`.
  - Added `sin(self.time * 2) * 4` float animation for gentle vertical bobbing.
  - Text color changed to gray `(0.6, 0.6, 0.6, 0.7)`.
  - Rocket icon moves together with the text (same messageY base).
  - `make verify` GREEN.

## Next slice

- INBOX (40): Ship stats summary fixed below minimap during ascending phase.

## Previous

- INBOX (38) complete: HUD text 2x scaling, one stat per line, durability blocks, and best record.
- INBOX (37) complete: Moon system implementation.
- INBOX (36) complete: flat $1 planet sample value.
