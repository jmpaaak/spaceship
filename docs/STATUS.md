## Current Status

- Resolved INBOX 67: specimen streak multiplier is always shown under pause/help during ascent.
- `game/scenes/play_hud.lua` owns `streakHudLabel` / `drawStreakHud`. Label uses `expedition.streakMultiplier(sampleStreakCount, run)` and never blanks: streak 0 → `x1.0`, first azure → `AZURE x1.0`, then `AZURE x1.2` / `AZURE x1.4`.
- Galmuri 11px (`fonts.get(11)`). `play.lua` one-line install comment; `play_scene_draw.lua` calls `self:drawStreakHud()` after the help button.
- Verified by `game/tests/streak_hud.lua` (engine unit GREEN).

## Next slice

- INBOX 68: remove the three admin speed+/hull+/yield+ buttons; leave the (67) streak multiplier in that stack.
