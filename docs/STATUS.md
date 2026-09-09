## Current Status

- INBOX 77 is complete and moved to 처리 완료. Persistent `hullRegen` now applies at exactly 1/20 of its authored rate through pure `game/recovery_effects.lua`; authored 5 restores and displays 0.25 HP/s.
- `game/expedition_run.lua` and EN/KO `game/i18n.lua` consume the same conversion. Immediate shop/docking heals remain unchanged.
- Added engine-hosted `game/tests/recovery_effects.lua` and updated the legacy relaunch/regen timing regression. RED was observed for the missing module; `make verify LOVE=/Users/jm/.local/bin/love` is GREEN.

## Next slice

- INBOX 72: add pure `game/speed_display.lua` normalization so user-facing speed starts at 0 (`effectiveSpeed - baseSpeed`) without changing movement physics or RCS calculations, then wire the HUD/shop preview with focused tests.
