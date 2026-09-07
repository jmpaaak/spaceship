## Current Status
- INBOX 61(24): Game-over → last-checkpoint respawn (part a: checkpoint persistence).
  - `expedition.lua`: added `lastCheckpointX/Y` to run state. `settle()` saves Earth or hub position. `destroy()` intentionally preserves checkpoint. `lastCheckpointOrEarth(run)` helper returns respawn coordinates.
  - `play.lua`: after destruction, relaunch uses `lastCheckpointOrEarth()` instead of always spawning at Earth. Hub checkpoint → spawn near hub. Earth/nil → standard launch spawn.
  - Test `INBOX-61(24)`: Earth settle checkpoint, hub settle checkpoint, destroy preserves checkpoint, helper default, launch preserves checkpoint. All GREEN.
  - `make verify LOVE=…` GREEN.

## Next slice

- INBOX 61(24) part b: Title menu composition — `이어서 하기` / `새 게임` / `리더보드` / `설정`. `새 게임` = full reset + Earth start. `이어서 하기` = resume with last checkpoint.

## Previous
- INBOX 61(23b): Leaderboard score auto-POST on settle/destroy.
  - New `game/leaderboard_client.lua`: `submitScore(name, bestAltitude)` fire-and-forget POST via `love.thread`+luasocket. `isNewBest(run)` helper.
  - `play.lua:persistBestAltitude()` now calls `leaderboardClient.submitScore` when `isNewBest` is true. Since both settle and destroy (via `expedition.damage`) route through `persistBestAltitude()`, both paths are covered.
  - Headless/test mode: silent skip (no love.thread). Server unreachable: silent skip.
  - Test `INBOX-61(23b)` verifies: module API, isNewBest logic (true/false/equal), headless safety, PlayScene loads with require.
  - `make verify LOVE=…` GREEN.
