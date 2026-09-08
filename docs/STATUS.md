## Current Status
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

- R1 (Lane C, partial): extracted the gear-slots-grid characterization block into `game/tests/legacy_gear_slots_grid.lua`.
  - Preserved HUD constants, i18n coverage, draw-call mocking/restoration, nine-slot and 48×48 dimensions, and output unchanged behind `run()`.
  - Observed the expected missing-module RED, then `make test LOVE=/Users/jm/.local/bin/love` and `make verify LOVE=/Users/jm/.local/bin/love` GREEN; `game/self_test.lua` decreased from 3,996 to 3,928 lines.

- R1 (Lane C, partial): extracted the part-icon infrastructure characterization block into `game/tests/legacy_part_icon_infrastructure.lua`.
  - Preserved the `getPartIcon` helper, 48px HUD gear-slot assertion, and output unchanged behind `run()`.
  - Observed the expected missing-module RED, then `make test LOVE=/Users/jm/.local/bin/love` and `make verify LOVE=/Users/jm/.local/bin/love` GREEN; `game/self_test.lua` decreased from 3,928 to 3,918 lines.

- R1 (Lane C, partial): extracted the ship-stats-summary characterization block into `game/tests/legacy_ship_stats_summary.lua`.
  - Preserved graphics restoration, ascending/settlement visibility, localized ship/speed/hull/harvest lines, right alignment and positioning, and output unchanged behind `run()`.
  - Observed the expected missing-module RED, then `make test LOVE=/Users/jm/.local/bin/love` and `make verify LOVE=/Users/jm/.local/bin/love` GREEN; `game/self_test.lua` decreased from 3,918 to 3,820 lines.

- R1 (Lane C, partial): extracted the galaxy-ring-opacity characterization block into `game/tests/legacy_galaxy_ring_opacity.lua`.
  - Preserved the chart-line alpha threshold, the existing minimap-rim coverage note, and output unchanged behind `run()`.
  - Observed the expected missing-module RED, then `make test LOVE=/Users/jm/.local/bin/love` GREEN; `game/self_test.lua` decreased from 3,820 to 3,810 lines.

- R1 (Lane C, partial): extracted the hub-full-settlement-shop characterization block into `game/tests/legacy_hub_full_settlement_shop.lua`.
  - Preserved settlement payout/state, hub-position survival and lifecycle clearing, bilingual i18n assertions, and output unchanged behind `run()`.
  - Observed the expected missing-module RED, then `make test LOVE=/Users/jm/.local/bin/love` GREEN; `game/self_test.lua` decreased from 3,810 to 3,746 lines.

- R1 (Lane C, partial): extracted the hub-shop-relaunch-touch characterization block into `game/tests/legacy_hub_shop_relaunch_touch.lua`.
  - Preserved touch/keyboard relaunch behavior, stored hub spawn coordinates, hub-coordinate clearing, `hasLeftEarth`, and output unchanged behind `run()`.
  - Observed the expected missing-module RED, then `make test LOVE=/Users/jm/.local/bin/love` GREEN; `game/self_test.lua` decreased from 3,746 to 3,678 lines.

- R1 (Lane C, partial): extracted the local Asset Studio web-hub characterization block into `game/tests/legacy_asset_studio_web_hub.lua`.
  - Preserved file-presence, pipeline-label, blocked user-supplied ship/Earth path, no-ComfyUI, and output assertions unchanged behind `run()`.
  - Observed the expected missing-module RED, then `make test LOVE=/Users/jm/.local/bin/love` GREEN; `game/self_test.lua` decreased from 3,678 to 3,649 lines.

- R1 (Lane C, partial): extracted the INBOX 61(3) slot UI/i18n characterization block into `game/tests/legacy_slot_ui_copy.lua`.
  - Preserved the EN/KO prompt-copy, colon-free English, Korean `탭하여`, lever-reference, and output assertions unchanged behind `run()`.
  - Observed the expected missing-module RED, then `make test LOVE=/Users/jm/.local/bin/love` GREEN; `game/self_test.lua` decreased from 3,649 to 3,622 lines.

## Next slice

- R1 (Lane C): extract the INBOX 61(4) shop-card copy/layout characterization block from `game/self_test.lua` into `game/tests/legacy_shop_card_copy_layout.lua`, preserving KO durability wording, EN/KO arrow/tradeoff, and output assertions.

> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
