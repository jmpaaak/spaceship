## Current Status
- INBOX 61(25): Slot cost/rewards scale with galaxy distance.
  - `expedition.slotTier(run, galaxyId)` = `1 + floor(galaxyDistance / galaxyCellSize)`.
  - Named ids `galaxy:gx:gy` use hypot(gx, gy)*cellSize; home/nil → tier 1. Fallback: lastHubX/Y distance.
  - `slotSpinCostFor` = `$10 * slotTier`. MONEY already `spinCost * multiplier`.
  - Non-money: SPEED `(5*tier)/(20*tier)`, DURABILITY `(3*tier)/(10*tier)`, HARVEST `(0.04*tier)/(0.20*tier)`.
  - `earthSlotSpin` returns `spinCost` + `slotTier`. `tripleMultiplier` still stacks on MONEY triples.
  - `play.lua` HUD / spin charge / duplicate-part refund use `slotSpinCostFor`.
  - Test `INBOX-61(25)` GREEN. `make verify LOVE=…` GREEN.

- INBOX 61(31): Hub relaunch does not full-heal; hullRegen ticks HP.
  - Hub checkpoint `checkpoint_hint_repair` removed, Earth is unchanged.
  - `launch()` skipping `durability = maxDurability` when from hub.
  - New effect `hullRegen` implemented in `expedition.update` to tick durability over time.
  - Added 3 new hull parts (`hull_nano_mesh`, `hull_repair_drone`, `hull_auto_welder`) with `hullRegen`.
  - Added `i18n` lines for `effect_hullRegen`.
  - Added `hullRegen` to `EFFECT_TYPE_GROUPS` in `tools/gear-editor/editor.js`.
  - Generated and verified PIL icons for the new parts in `assets/part_icons` and updated `MANIFEST.json`.
  - Test `INBOX-61(31)` GREEN. `make verify LOVE=...` GREEN.

## Next slice

- INBOX 61(26): Part balance — common min 5, uncommon+ Balatro flat/mult system.

## Previous
- INBOX 61(24b): Title menu composition — CONTINUE / NEW GAME / LEADERBOARD / SETTINGS.
  - `title.lua`: button order is CONTINUE (top) → NEW GAME → LEADERBOARD → SETTINGS. CONTINUE greyed out unless `hasSave`. NEW GAME uses `onNewGame` (legacy `onStart` still works).
  - `i18n`: EN `title_new_game`="NEW GAME", KO="새 게임". `title_start` removed.
  - `main.lua`: `hasSave` from `best_altitude_store:load() > 0`. NEW GAME calls `altStore:reset()` + `specStore:reset()` then fresh PlayScene at Earth. CONTINUE starts PlayScene with persisted bestAltitude.
  - Test `INBOX-61(24b)` GREEN.

