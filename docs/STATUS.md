## Current Status

- INBOX 62 is complete: `slot_spin` SFX plays at 0.3 (half of the global 0.6).
- `sfx.defs.slot_spin` now has `volume = 0.3`; `sfx.play` uses `volume or def.volume or 0.6`. Other SFX defs have no `volume` field and stay at 0.6.
- `play_slot.lua` still has a single `sfx.play("slot_spin")` line (no per-call volume arg). `game/tests/sfx.lua` is GREEN.

## Next slice

- INBOX 63: rotating abandoned space-station docking (`game/world.lua` + `game/stations.lua` + `game/scenes/play_station.lua`).
