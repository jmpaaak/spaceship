## Current Status

- Resolved INBOX 68: removed the three admin HUD buttons (speed+/hull+/yield+) under pause/help.
- `play_layout.lua` no longer defines `adminButtons` / `adminButtonRect`. `play_scene_draw.lua` no longer draws that stack. `play_input.lua` no longer hit-tests it. `play.lua` does not pass those deps.
- `expedition.adminUpgrade` remains as a test helper. (67) streak HUD (`self:drawStreakHud()`) still draws under pause/help.
- Verified by `game/tests/admin_buttons_gone.lua` (engine unit GREEN).

## Next slice

- INBOX 69: remap specimen hue families to the four gear suits (solar / nebula / void / pulsar).
