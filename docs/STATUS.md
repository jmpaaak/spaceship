## Current Status

- Resolved INBOX 66: Implemented Booster+ regenerative mechanic.
- Connected `expeditionGear.tickBoostRegen` inside `game/expedition_run.lua`'s `update` to recharge 1 boost every 5 seconds during ascent up to the `boostCharge` cap.
- Addressed nil altitude error in tests by properly initializing mock data via `expedition.new()`.
- Fixed locale assertions in `game/tests/boost_regen.lua` to enforce EN translations before test validation.
- Confirmed boost effect duration is correctly configured as 1.0s in `game/scenes/play_boost.lua` and UI help text `help_boost`.

## Next slice

- INBOX 67: Always display the current specimen streak multiplier below the help/pause button via `game/scenes/play_hud.lua`.
