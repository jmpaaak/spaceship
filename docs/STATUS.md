## Current Status
- R1 lane C: extracted hub-proximity settlement regression coverage from `game/self_test.lua` into `game/tests/legacy_hub_proximity_settle.lua`.
  - Preserved normal-planet non-settlement, hub settlement payout, and floating-text assertions; production behavior is unchanged.
  - Observed the expected missing-module RED; `make test LOVE=/Users/jm/.local/bin/love` is GREEN.
  - `game/self_test.lua` shrank from 4,798 to 4,755 lines. Next slice: extract `testReentryShake` into `game/tests/legacy_reentry_shake.lua`.

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

- INBOX 61(33): hub/star overlap fix
  - `game/world.lua` `hubPlanet()`: minDist = starRadius + hubRadius + 41 (was max(80, radius*0.18)).
  - Ensures hub disk never overlaps the central star in any galaxy.
  - Star sprite green-X bug was already fixed in (14) (pngColorType + sheet rotation center).
  - Test INBOX-61(33) in `game/self_test.lua` checks all galaxies in -10..10 range: GREEN.

- INBOX 61(30): confirmed already complete
  - title.lua already has 22px "Jimmy's" + 44px title + i18n keys from prior cycle.

- INBOX 61(35): slot weighted random fix
  - Bug: `play.lua` generated reel rolls with `math.random(1,10)` but totalWeight is 20 (6+3+4+3+4). Only MONEY/PART/SPEED were ever chosen; DURABILITY and HARVEST were unreachable.
  - Fix: added `expedition.earthSlotTotalWeight(run, galaxyId)` helper (luck-aware) to compute effective totalWeight. `play.lua` now uses `math.random(0, tw-1)` for proper uniform distribution over all 5 symbols.
  - Test INBOX-61(35) in `game/self_test.lua`: sweeps all roll values 0..tw-1 and asserts all 5 symbols reachable. Also verifies luck increases totalWeight. GREEN.

- INBOX 61(36): SFX 3종 module
  - Created `game/sfx.lua` — standalone SFX module with headless-safe API (no-op when `love.audio` is nil).
  - Three effects: `galaxy_discover` (oneshot, dedup by galaxy id), `star_sample` (loop while in star well), `collision` (oneshot on planet hit).
  - Lazy source creation, uniqueKey dedup for galaxy_discover, `resetGuards()`/`releaseAll()` cleanup API.
  - `play.lua` integration: 1 require + 4 one-liner calls (galaxy discover, star_sample play/stop, collision).
  - Test `game/tests/sfx.lua` registered in self_test: defs validation, headless safety, dedup guards, reset. GREEN.


- INBOX 61(32) (partial): finish play_shop.lua extraction.
  - Codex rate-limit cutoff left `play_shop.lua` partially extracted (only overlays).
  - Completed the extraction of `shopModalLayout`, `shopModalButtonRects`, `hitShopModalGearSlot`, and `drawShopModal` into `play_shop.lua`.
  - `play.lua` now purely delegates all shop/settlement/destroyed overlay logic to `play_shop.lua`.
  - Tests pass (`make verify LOVE=...` GREEN).

- INBOX 61(28): Boost button UI & Boost FX
  - Created `game/scenes/play_boost.lua` to extract boost logic and avoid bloating `play.lua`.
  - Added BOOST button UI in bottom-right corner with charge counter.
  - Enhanced RCS particles during boost (golden color, 2.5x radius, faster spawn).
  - Added vertical speed lines visual effect during boost.

- INBOX 61(32): play_gameover.lua extraction
  - Created `game/scenes/play_gameover.lua` — gameover/destroyed-phase layout module.
  - Extracted: `destroyedTouchArea`, `destroyedPanelY/H`, `destroyedRestartTextY`, `destroyedKeepPartRects`, `keepConfirmPopupW/H/BtnH`, `keepConfirmButtons`, `rarityRgb`, `drawBalatroCard`, `handleDestroyedTouch`.
  - `play.lua` inline destroyed touch handling replaced with single `M.handleDestroyedTouch(self, x, y)` delegation.
  - play.lua 4169→4037 lines (~132 lines removed).
  - Test `INBOX-61(32) play_gameover.lua extraction` GREEN. All existing tests pass unchanged.

- R1-A1 (Lane A): Extracted  and its comprehensive test .
  - Enforced rigorous input consumption contract (popup -> overlay -> phase UI -> joystick).
  - Fixed the shop relaunch button bug where touches were bleeding into world coordinates.

- R1 (Lane B, partial): Extracted slot machine logic to .
  - Moved , , ,  etc., from .
  - Reduced  by ~250 lines.
  - Retained  API wrappers in  ensuring all tests and caller modules work transparently.

- R1-A1 (Lane A): Extracted `game/scenes/play_input.lua` and its comprehensive test `game/tests/play_input.lua`.
  - Enforced rigorous input consumption contract (popup -> overlay -> phase UI -> joystick).
  - Fixed the shop relaunch button bug where touches were bleeding into world coordinates.

- R1 (Lane B, partial): Extracted slot machine logic to `game/expedition_slot.lua`.
  - Moved `loadSlotConfig`, `earthSlotSpin`, `slotTier`, `slotReward` etc., from `game/expedition.lua`.
  - Reduced `game/expedition.lua` by ~250 lines.
  - Retained `M.*` API wrappers in `game/expedition.lua` ensuring all tests and caller modules work transparently.

- R1-METHOD: added reusable repository-local Hermes skills for behavior-preserving refactors.
  - `.hermes/skills/love2d-behavior-preserving-refactor/SKILL.md` preserves pure-rule/`love.*` boundaries, callback consumption order, module state, and determinism.
  - `.hermes/skills/flutter-flame-behavior-preserving-refactor/SKILL.md` preserves `FlameGame`/component lifecycle, input propagation, state, and determinism.
  - Added `tools.test_project_skills` to `make test`; observed missing-skill RED, then GREEN after both skills were added.
  - Trusted this repository and verified an actual Hermes invocation preloaded both skills and returned both exact names.
  - R1 lanes now follow the documented scan → one responsibility/one pattern → existing tests → reference update sequence.

- R1 (Lane C, partial): extracted `testEarthSlotSpinPartRarityGate` from `game/self_test.lua` into `game/tests/legacy_earth_slot_part_rarity_gate.lua`.
  - Preserved the engine-hosted two-/three-match rarity gates and combined hull/engine PART-pool coverage unchanged behind `run()`.
  - Observed missing-module RED, then `make test LOVE=/Users/jm/.local/bin/love` GREEN; `game/self_test.lua` decreased from 4,979 to 4,883 lines.

- R1 (Lane C, partial): extracted `testSlotEditorWebUi` into `game/tests/legacy_slot_editor_web_ui.lua`.
  - Preserved the runtime JSON defaults, profile fallback/override, and slot-editor source assertions unchanged behind `run()`.
  - Observed the expected missing-module RED, then `make test LOVE=/Users/jm/.local/bin/love` GREEN; `game/self_test.lua` decreased from 4,883 to 4,798 lines.

## Next slice

- R1 (Lane C): extract `testItem15DeadSlotConstantsRemoved` from `game/self_test.lua` to `game/tests/legacy_item15_dead_slot_constants_removed.lua`, preserving the dead constant/control/state-field assertions.

> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
