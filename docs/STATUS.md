## Current Status
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

- R1 (Lane C, partial): extracted `testPauseButton` into `game/tests/legacy_pause_button.lua`.
  - Preserved its 44×44 touch area, ascending-only phase gate, toggle/unpause behavior, paused update freeze, and phase-change auto-clear assertions unchanged behind `run()`.
  - Observed the expected missing-module RED, then `make test LOVE=/Users/jm/.local/bin/love` and `make verify LOVE=/Users/jm/.local/bin/love` GREEN; `game/self_test.lua` decreased from 4,485 to 4,426 lines.

- R1 (Lane C, partial): extracted `testGearPopupAndKeepPart` into `game/tests/legacy_gear_popup_and_keep_part.lua`.
  - Preserved the English i18n assertions, equipped hull-slot popup interaction, destruction snapshot, and keep-one relaunch behavior unchanged behind `run()`.
  - Observed the expected missing-module RED, then `make test LOVE=/Users/jm/.local/bin/love` GREEN; `game/self_test.lua` decreased from 4,426 to 4,382 lines.

- R1 (Lane C, partial): extracted `testSlot5SymbolWeightedRNG` into `game/tests/legacy_slot_5_symbol_weighted_rng.lua`.
  - Preserved its 200 evenly swept deterministic spins, explicit full-weight-range sweep, all-five-symbol assertions, and output unchanged behind `run()`.
  - Observed the expected missing-module RED, then `make test LOVE=/Users/jm/.local/bin/love` and `make verify LOVE=/Users/jm/.local/bin/love` GREEN; `game/self_test.lua` decreased from 4,382 to 4,348 lines.

- R1 (Lane C, partial): extracted the RCS 0–999 gradient characterization block into `game/tests/legacy_rcs_gradient.lua`.
  - Preserved pure `rcsVisual` color/radius/clamping calculations, low-/high-speed scene particle assertions, and output unchanged behind `run()`.
  - Observed the expected missing-module RED, then `make test LOVE=/Users/jm/.local/bin/love` GREEN; `game/self_test.lua` decreased from 4,257 to 4,180 lines.

- R1 (Lane C, partial): extracted the comet-system characterization block into `game/tests/legacy_comet_system.lua`.
  - Preserved comet reset, timed spawn, motion, sample value, collision damage, pruning, next-spawn interval, fresh-scene state, cleanup, and output unchanged behind `run()`.
  - Observed the expected missing-module RED, then `make test LOVE=/Users/jm/.local/bin/love` and `make verify LOVE=/Users/jm/.local/bin/love` GREEN; `game/self_test.lua` decreased from 4,180 to 4,103 lines.

- R1 (Lane C, partial): extracted the flat-$1 planet-sample characterization block into `game/tests/legacy_flat_sample_value.lua`.
  - Preserved flat sample values, distance-based sample tiers and collision damage, the 50× comet multiplier, and output unchanged behind `run()`.
  - Observed the expected missing-module RED, then `make test LOVE=/Users/jm/.local/bin/love` and `make verify LOVE=/Users/jm/.local/bin/love` GREEN; `game/self_test.lua` decreased from 4,103 to 4,085 lines.

- R1 (Lane C, partial): extracted the moon-system characterization block into `game/tests/legacy_moon_system.lua`.
  - Preserved deterministic spawn-rate coverage, orbit geometry and motion, sample value, collision damage, i18n assertion, and output unchanged behind `run()`.
  - Observed the expected missing-module RED, then `make test LOVE=/Users/jm/.local/bin/love` and `make verify LOVE=/Users/jm/.local/bin/love` GREEN; `game/self_test.lua` decreased from 4,085 to 3,996 lines.

## Next slice

- R1 (Lane C): extract the gear-slots-grid characterization block from `game/self_test.lua` into `game/tests/legacy_gear_slots_grid.lua`, preserving HUD constants, draw-call mocking/restoration, slot dimensions, and output behavior.

> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
