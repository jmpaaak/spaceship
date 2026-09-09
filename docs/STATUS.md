## Current Status

- INBOX 77(3): purchased-but-inactive scout cards retain the selection action but no longer show the redundant `OWNED` status; active scout slots no longer render `SCOUT ✓` (or its unsupported-glyph `SCOUT X` fallback).
- Removed the now-unused `owned_label` translations and added `game/tests/scout_status_hidden.lua` coverage for both purchased and selected scout states.
- RED was observed on the former owned-card status label; the engine-hosted suite and `make verify LOVE=/Users/jm/.local/bin/love` pass after implementation.

## Next slice

- INBOX 77(4): reduce persistent gear recovery effects such as `hullRegen` to exactly 1/20 of their current effective rate while keeping displayed and applied rates consistent; exclude immediate shop/docking full heals.
