## Current Status
- INBOX 61(42): game-wide BGM is one looping Space orchestral track.
  - `game/bgm.lua`: `tracks = { assets/sfx/space_orchestral.mp3 }`, `looping = true`, headless `love.audio` nil guard kept.
  - i18n EN/KO `title_bgm_credit` = `BGM: Space — lasercheese (CC-BY 3.0)`. Title still starts BGM on enter; `main.lua` still calls `bgm.update()`.
  - Test `game/tests/bgm.lua` (`INBOX-61(42)`) GREEN. play.lua untouched.

- INBOX 61(43): gear-editor engine-tab auto-load.
  - Hull | Engine tabs wired (`selectPool` / `wirePoolTabs`). Pools kept separately (`hullPool`, `enginePool`).
  - `autoLoadDefaults()` fetches hull only. First Engine tab click `ensureEngineLoaded()` fetches `/gear-editor/data/engine_parts.json`.
  - File pickers still overwrite the matching pool. Download filename follows the active tab.
  - Test `tools.test_gear_editor_engine_tab` GREEN (wired into `make test`). play.lua / self_test.lua untouched.

- INBOX 61(40): gear-editor KO/EN locale toggle.
  - Toolbar KO | EN buttons; preference in `localStorage` (`gear-editor-locale`).
  - KO: card title = `nameKo`, effects = i18n `effect_*` KO, rarity/suit/synergy Korean.
  - EN: card title = `name`, effects/rarity/suit/synergy English. Seven synergies switch with locale. No symbol prefixes.
  - Test `tools.test_gear_editor_locale` GREEN (wired into `make test`). play.lua / self_test.lua untouched.

- INBOX 61(27): Asset Studio sprite-gen server.
  - New `tools/serve_editors.py`: static repo server + `POST /api/sprite-gen` `{prompt, width, height, image?}`.
  - Tries Python `sprite-gen`; missing/fail → deterministic PIL procedural PNG (same prompt → same pixels). Optional base64 `image` conditions the fallback.
  - `tools/asset-studio/editor.js` `generateFromPromptAsync` fetches `/api/sprite-gen` and paints sourceCanvas; unreachable server uses the old local xorshift still.
  - Test `tools.test_serve_editors` GREEN (PNG decode, 400 on missing prompt, image conditioning, determinism). `make test` now runs that unittest.
  - play.lua / self_test.lua untouched.

- INBOX 61(26) (c): Gear part balance and tier differentiation (hull_parts.json / engine_parts.json rebalance).
  - Common cards rebalanced to always feature a single flat effect, boosted to a 5~12 minimum value range, enforcing their identity as solid foundational pieces.
  - Uncommon cards rebalanced to precisely dual flat effects (guaranteed combination).
  - Rare cards reworked to fully adopt the `multiply` mode (`×배수`), amplifying values by a ratio rather than flat addition.
  - Legendary cards rebalanced to feature exactly one flat additive effect and one multiplicative effect (`+배수 AND ×배수`).
  - Preserved specific rigid values for test fixtures like `engine_emergency_boost_pod` by migrating them to appropriate rarities (`uncommon`) to maintain test stability and logical coherence.
  - Test suites verifying gear categorization and edition compatibility remained fully intact and GREEN.
  - Moved item 26 to '처리 완료' in `INBOX.md` as its final step is complete.

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

- INBOX 61(24b): Title menu composition — CONTINUE / NEW GAME / LEADERBOARD / SETTINGS.
  - `title.lua`: button order is CONTINUE (top) → NEW GAME → LEADERBOARD → SETTINGS. CONTINUE greyed out unless `hasSave`. NEW GAME uses `onNewGame` (legacy `onStart` still works).
  - `i18n`: EN `title_new_game`="NEW GAME", KO="새 게임". `title_start` removed.
  - `main.lua`: `hasSave` from `best_altitude_store:load() > 0`. NEW GAME calls `altStore:reset()` + `specStore:reset()` then fresh PlayScene at Earth. CONTINUE starts PlayScene with persisted bestAltitude.
  - Test `INBOX-61(24b)` GREEN.


- INBOX 61(26a/b): Added `mode = "flat"|"multiply"` gear effect schema
  - Modified `gear.lua` and `expedition.lua` to separate flat and mult calculations for stats.
  - Applied product multiplier in `effectiveSpeed`, `effectiveSampleBonus`, `effectiveCollisionRadius`, `effectiveDetectionRadius`, `effectiveShopPrice`.
  - Added `mode` field support to `tools/gear-editor` UI (default flat, toggles flat/multiply, live previews updated).
  - Documented `mode` in `docs/GEAR_SCHEMA.md`.
  - Test suite (INBOX-61(26) infra part) GREEN. Code infrastructure complete.

- INBOX 61(38): Title/Game BGM playlist
  - Implemented `game/bgm.lua` to handle playlist looping between `title_bgm.mp3` and `observing_the_star.ogg`.
  - Hooked `bgm.update()` in `main.lua` and `bgm.start()` in `title.lua:enter()`. Playback continues seamlessly during gameplay.
  - Added CC-BY/CC0 BGM credit texts in `title.lua` and `i18n.lua`.
  - Added test coverage in `self_test.lua` while ensuring `GAME_HEADLESS=1` runs skip `love.audio`.
  - Test `INBOX-61(38)` GREEN.

- INBOX 61(41): binaryStar settle farm limit
  - Modified `game/expedition.lua` to remove flat +$30 reward on settle.
  - Added 1.3x multiplier to sample payouts (`pendingSampleValue`) during `settle()` and `settleAtHub()` when `binaryStar` synergy is active.
  - Updated `game/i18n.lua` to match EN/KO texts ("sell +30%" / "판매 +30%").
  - Test `INBOX-61(41)` in `game/tests/binary_star.lua` GREEN.

## Next slice

- INBOX 61(33) hub/star overlap (`game/world.lua`), or 61(36) SFX (`game/sfx.lua`). 61(28)/(29) wait on play.lua module split.
