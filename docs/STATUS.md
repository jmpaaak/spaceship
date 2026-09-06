## Current Status

- INBOX (32) complete: remove verticalOffset ±90 clamp so vertical steering matches horizontal.
  - Removed `verticalOffsetLimit` constant, `clampVerticalOffset()` function, `verticalOffset` field.
  - Vertical joystick/keyboard input now moves `ship.y` directly (like `ship.x`), unlimited.
  - Removed `+ extraDy` from thrust line (was needed only when verticalOffset was separate).
  - Cleaned up unused `extraDx`, `extraDy`, `extraDistance` locals and `startX`/`startY`.
  - Updated self_test.lua: checks `ship.y` movement instead of `verticalOffset`.
  - `make verify` GREEN.

## Next Slice

- INBOX (29): reduce collect zoom 1.35 → 1.12.
