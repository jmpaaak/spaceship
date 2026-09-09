## Current Status

- INBOX 63 is complete: Added abandoned space-station objects (`game/station.lua`).
- Stations spawn with the same probability/interval as comets (independent stream).
- Stations rotate slowly and have a 50-degree docking arc.
- If the ship enters the arc slowly, it docks (heals full HP, rewards 1.5x moon sample value). If it hits outside the arc or too fast, it crashes and takes damage.
- PIL-generated sprite `assets/station/station.png` added and logged. Tests added in `game/tests/station_dock.lua`.

## Next slice

- INBOX 64: Refactor planet coordinate generation to avoid grid-like layout (`game/world.lua`).
