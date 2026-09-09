## Current Status

- Resolved INBOX 70: title starter ship rest gap above Jimmy's (y=488) is now 4px (`shipLayout` y = 488 - h - 4). Nearest scale ×7 unchanged. Idle bob amplitude unchanged.
- Verified by `game/tests/title_ship_icon.lua` (gap ≤4, scale==7) and full engine unit run (`SPACESHIP_UNIT_OK`).

## Next slice

- INBOX 71: add a title Credits/만든이 menu (new `game/scenes/credits.lua` + title button + main.lua transition).
