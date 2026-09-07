## Current Status
- INBOX 61(24b): Title menu composition — CONTINUE / NEW GAME / LEADERBOARD / SETTINGS.
  - `title.lua`: button order is CONTINUE (top) → NEW GAME → LEADERBOARD → SETTINGS. CONTINUE greyed out unless `hasSave`. NEW GAME uses `onNewGame` (legacy `onStart` still works).
  - `i18n`: EN `title_new_game`="NEW GAME", KO="새 게임". `title_start` removed.
  - `main.lua`: `hasSave` from `best_altitude_store:load() > 0`. NEW GAME calls `altStore:reset()` + `specStore:reset()` then fresh PlayScene at Earth. CONTINUE starts PlayScene with persisted bestAltitude.
  - `best_altitude_store:reset()` / `collection_store:reset()` wipe persisted files.
  - Test `INBOX-61(24b)`: button order, onNewGame, onStart fallback, CONTINUE gate, store resets, i18n. GREEN.
  - `make verify LOVE=…` GREEN.

## Next slice

- INBOX 61(25): Slot cost/rewards scale with galaxy distance (`slotTier = 1 + floor(galaxyDistance / galaxyCellSize)`).

## Previous
- INBOX 61(24): Game-over → last-checkpoint respawn (part a: checkpoint persistence).
  - `expedition.lua`: added `lastCheckpointX/Y` to run state. `settle()` saves Earth or hub position. `destroy()` intentionally preserves checkpoint. `lastCheckpointOrEarth(run)` helper returns respawn coordinates.
  - `play.lua`: after destruction, relaunch uses `lastCheckpointOrEarth()` instead of always spawning at Earth. Hub checkpoint → spawn near hub. Earth/nil → standard launch spawn.
  - Test `INBOX-61(24)`: Earth settle checkpoint, hub settle checkpoint, destroy preserves checkpoint, helper default, launch preserves checkpoint. All GREEN.
  - `make verify LOVE=…` GREEN.
