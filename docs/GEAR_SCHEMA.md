# Gear part data schema

`docs/feedback/INBOX.md` item 13 ("선체/엔진 부품 데이터를 별도 config로
외부화 + 전용 웹 에디터 제공"). This document defines the JSON schema for
the hull-part and engine-part card pool files consumed by
`game/gear.lua` and edited with `tools/gear-editor/`.

## Files

- `game/data/hull_parts.json` — hull ("선체") parts: always-equipped,
  passive/synergy cards (item 9, Balatro-joker-like).
- `game/data/engine_parts.json` — engine ("엔진") parts: a second, separate
  slot category (item 10). Same card schema as hull parts; the game keeps
  the two pools and equipped-slot lists independent.

Both files share the exact same document/card schema below.

## Document shape

```json
{
  "schemaVersion": 1,
  "parts": [ { ...card... }, ... ]
}
```

- `schemaVersion` (number, currently `1`) — reserved for future format
  migrations; not currently enforced by the loader but should be bumped if
  the shape of a card changes incompatibly.
- `parts` (array, required) — the card pool. Order in the file has no
  gameplay meaning; it only affects display order in the editor/game.

## Card shape

```json
{
  "id": "hull_scrap_plate",
  "name": "Scrap Plate",
  "nameKo": "고철 장갑판",
  "icon": "▭",
  "rarity": "common",
  "tags": ["defense"],
  "editions": [],
  "galaxyExclusive": false,
  "effects": [
    { "type": "hullDurability", "value": 1 }
  ]
}
```

| field      | type              | required | notes |
|------------|-------------------|----------|-------|
| `id`       | string            | yes      | Non-empty, unique across the whole pool file. Stable identifier — do not reuse an id for a different card. Convention: `hull_*` / `engine_*` snake_case. |
| `name`     | string            | yes      | Non-empty English display name. |
| `nameKo`   | string            | no       | Korean display name; falls back to `name` if omitted/empty. |
| `icon`     | string            | yes      | Non-empty. A single emoji or short symbol/glyph used as the card's silhouette in the editor and (eventually) in-game UI. Per the AetherAI-only asset rule in `loop/PROMPT.md`, this remains a placeholder glyph, not a final visual asset, until official art exists. |
| `rarity`   | string enum       | yes      | One of `common`, `uncommon`, `rare`, `legendary` (item 12's rarity axis). |
| `tags`     | array of strings  | no       | Free-form synergy/category tags (e.g. `"speed"`, `"economy"`, `"defense"`, `"altitude"`). Reserved for the item 9 synergy engine to match combos against. |
| `editions` | array of strings  | no       | Item 12's "부수 효과" (edition) pool this specific card can roll into (e.g. `"radioactive"`). Empty array means no editions defined yet. |
| `galaxyExclusive` | boolean     | no       | Item 7 acquisition path. When `true`, `gear.earthShopPool` (Earth shop) excludes the card and `expedition.exploreHub` can grant it as a once-per-galaxy hub drop. Omitted or `false` means the card is generic and may appear in Earth shop. `game/gear.lua`'s `validatePart` treats any non-`true` value as `false`. |
| `effects`  | array of Effect   | yes      | At least one entry. See below. |

## Effect shape

```json
{ "type": "speed", "value": 5 }
```

| field   | type   | required | notes |
|---------|--------|----------|-------|
| `type`  | string enum | yes | One of the known effect types (see below). |
| `value` | number | yes | Must be in the range `[-100, 100]` (enforced by both `game/gear.lua` and the web editor). |

### Known effect types

Categories per item 14 ("부품 효과 종류(effect schema) 확장"). All are
implemented in `game/gear.lua`'s `M.knownEffectTypes` whitelist and mirrored
in `tools/gear-editor/editor.js`'s `EFFECT_TYPE_GROUPS`/`KNOWN_EFFECT_TYPES`.
Any new type must be added to both in the same change, so the editor's
validator/dropdown stays exactly in sync with the Lua loader's rules — see
"Effect schema categories A~F (item 14)" below for how each category's raw
`value` is interpreted and combined.

- **(A) additive** — `speed`, `sampleSellValue`, `money`, `climbSpeed`,
  `hullDurability`.
- **(B) multiplicative** — `sellMultiplier`, `streakMultiplier`.
- **(C) trigger/probability** — `luck`, `chainTrigger`, `rerollBonus`.
- **(D) survival/risk-mitigation** — `insurance`, `collisionRadius`.
- **(E) scouting/information** — `detectionRadius`, `autoCollect`.
- **(F) economy** — `shopDiscount`.
- **(G) propulsion specialization (engine parts)** — `fuelEfficiency`,
  `steeringResponsiveness`, `boostCharge` (item 10b).

## Validation rules (enforced identically by `game/gear.lua` and the editor)

1. The document must be an object with a `parts` array.
2. Every card must have a non-empty `id`, `name`, and `icon`.
3. `rarity` must be one of the known rarity enum values.
4. Every card must have at least one effect.
5. Every effect's `type` must be a known effect type.
6. Every effect's `value` must be a finite number within `[-100, 100]`.
7. No two cards in the same file may share an `id`.

`game/gear.lua`'s loader (`M.loadPool` / `M.loadHullParts` /
`M.loadEngineParts`) raises a descriptive error for any violation instead
of silently accepting malformed data — see `game/self_test.lua`'s
`testGearJsonLoader` for the exact behavior on missing files, malformed
JSON, and each of the above rule violations.

## Tag-based synergy engine (item 9)

`game/gear.lua` also exposes a small set of pure functions implementing
item 9's core design goal — "부품들의 조합(시너지)이 고도 상승 속도/효율에
배가 효과를 내는 것" (part combinations should multiply, not just add, the
altitude/climb-rate payoff), mirroring Balatro's joker-combo philosophy:

- `M.aggregateEffects(parts)` — sums every effect value across a list of
  equipped parts by effect `type`, with no synergy applied. This is the
  raw additive baseline.
- `M.tagSynergyMultiplier(parts)` — for every unordered pair of distinct
  equipped parts that share at least one tag, adds
  `M.synergyBonusPerSharedPair` (currently `0.15`) to a multiplier that
  starts at `1`. Two parts sharing a tag → `x1.15`; three mutually-sharing
  parts → `x1.45` (3 pairs); parts with no shared tags stay at `x1` (no
  bonus).
- `M.equippedTotals(parts)` — combines the two: additive totals are
  computed first, then the tag-synergy multiplier is applied **only to
  `climbSpeed`** (the altitude/score-gain stat item 9 calls out as the
  combo payoff). Every other effect type (`money`, `sampleSellValue`,
  `speed`, `hullDurability`) stays purely additive this cycle. The
  returned table also carries `synergyMultiplier` so UI/tests can surface
  the current combo strength directly.

The bundled `game/data/hull_parts.json` pool now has 24 cards (item 9's
"최소 20~30종" target), each tagged with at least one synergy tag —
including a dedicated `azure`/`ember`/`void` tag per hue family (matching
`world.hueFamilies`) plus cross-cutting `speed`/`altitude`/`defense`/
`economy`/`control` tags — so a wide variety of 2-3 card tag-overlap combos
are available to build around. `game/self_test.lua`'s
`testGearSynergyEngine` verifies the pool size, that every card has a tag,
and the multiply-vs-add behavior of the engine itself.

`game/gear.lua` does not yet wire this into `run.equippedGear`/gameplay —
that connection (and the actual equip/unequip UI) is deferred to a
follow-up slice per `loop/PROMPT.md`'s scope (this lane may only touch
`game/scenes/play.lua`/`game/expedition.lua` for the minimal loader-call
exception, not full gameplay wiring).

## Engine part slot separation (item 10)

`game/engine_parts.json` (bundled via `game/gear.lua`'s generic
`M.loadPool`/`M.loadEngineParts`) shares the exact same card schema as
`game/data/hull_parts.json` documented above — no schema changes were
needed for item 10, since the "이원화" (separation) item 10 calls for is
purely a *slot-tracking* concern, not a card-data concern. The pool
currently has 12 cards (own initial size; independent of hull's 24), all
with at least one synergy tag so `gear.aggregateEffects` /
`gear.tagSynergyMultiplier` / `gear.equippedTotals` (which already operate
generically on any list of parts) work identically for engine loadouts.

`game/engine_parts.lua` (new) owns ONLY the independent slot-list
bookkeeping item 10(a) requires:

- `M.newLoadout()` returns `{ hull = {}, engine = {} }` — two separate
  arrays.
- `M.hullSlotCount = 6` (matches the existing "슬롯 6개" hull loadout
  ceiling) and `M.engineSlotCount = 3` (a smaller, independent capacity for
  the propulsion-specialist category).
- `M.equip(loadout, category, part)` / `M.unequip(loadout, category, id)` /
  `M.isFull(loadout, category)` operate on exactly one of the two lists
  (`category` is `"hull"` or `"engine"`) and never touch the other list —
  filling the engine category to capacity has zero effect on hull slot
  availability, and vice versa. Duplicate ids within the same category and
  equipping past a category's capacity are both rejected with a
  false, error-message return (no silent corruption).

This module still does not wire into `run.equippedGear`/
`run.equippedEngineParts` gameplay state — that remains deferred per
`loop/PROMPT.md`'s lane scope (see above), same as the hull synergy engine.
`game/self_test.lua`'s `testEnginePartsSlotSeparation` verifies the pool
size/tags, independent fill/empty behavior in both directions, and the two
rejection paths (capacity, duplicate id).

### Propulsion specialization effect category (item 10b)

Item 10(b) required engine parts to focus on "추진/기동 계열에 특화된
효과(상승 가속, 연료 효율, 조종 반응성, 긴급 부스트/1회성 소모 아이템
등)" so they read as mechanically distinct from the hull pool's generic
durability/collection/synergy focus. `game/gear.lua`'s `M.knownEffectTypes`
now includes a new **(G) propulsion** category — `fuelEfficiency`,
`steeringResponsiveness`, `boostCharge` — with matching pure conversion
functions:

- `M.effectiveFuelBurnRate(baseRate, parts)` — percentage reduction of a
  base fuel/maneuver-cost burn rate, clamped at zero.
- `M.effectiveSteeringRate(baseRate, parts)` — percentage growth of a base
  turn/steering rate ("조종 반응성/급회전 판정 향상").
- `M.boostChargeCount(parts)` — a discrete non-negative charge count for
  "긴급 부스트/1회성 소모 아이템", same shape as `chainTriggerCount`/
  `rerollCount`.

`game/data/engine_parts.json` now has 14 cards (up from 12), several of
which carry `fuelEfficiency`/`steeringResponsiveness`/`boostCharge` effects
(`engine_ion_drive`, `engine_vector_nozzle`, `engine_gyro_stabilizer`,
plus two new cards `engine_emergency_boost_pod` and `engine_cryo_fuel_cell`)
alongside their existing speed/climbSpeed/money effects, so the engine pool
is now mechanically distinct from `game/data/hull_parts.json`, which
`game/self_test.lua`'s `testEnginePropulsionSpecialization` regression-
checks stays entirely free of the (G) category (no hull card uses
`fuelEfficiency`/`steeringResponsiveness`/`boostCharge`). This class of
effect is schema-agnostic like every other category (nothing in the loader
enforces "only engine pools may use (G) types" — the regression instead
asserts the *bundled* pools' actual content), matching the existing (A)~(F)
category pattern. `tools/gear-editor/editor.js`'s `EFFECT_TYPE_GROUPS` gained
a `"G: propulsion (engine parts)"` group so the web editor's effect-type
dropdown and `game/self_test.lua`'s existing editor-sync check both cover
the new types automatically.

As with (C)~(F), (G)'s conversion functions were not initially wired into
actual `run` state. This lane's follow-up slice closed that gap within the
"최소한의 로더 호출" exception (`game/expedition.lua` already requires
`game.gear`/`game.engine_parts` for item 9's climbSpeed synergy):

- `M.effectiveFuelBurnRate(run)` applies equipped engine parts'
  `fuelEfficiency` to `run.fuelBurnRate`; `M.launchForecast(run, maxFuel)`
  now uses this effective rate instead of the raw `run.fuelBurnRate`, so
  fuel-efficiency cards visibly raise the forecast altitude shown before
  launch.
- `M.steeringSpeed(run)` now applies equipped engine parts'
  `steeringResponsiveness` on top of the existing base/upgrade formula, so
  `game/scenes/play.lua`'s joystick/tap-steering code (which already calls
  `expedition.steeringSpeed(run)`) automatically benefits without any
  play.lua change.
- `M.boostChargeCount(run)` exposes the equipped engine parts' total
  `boostCharge` count for a run. Actual consumption/UI for spending a
  charge (e.g. a tap-to-boost button) remains out of this lane's scope
  (`play.lua`) and is deferred to a future slice; this only establishes the
  single source of truth a future consumer will read from.

### Engine card content-coverage gap (item 10/14 follow-up slice)

A deeper audit than the existing "every effect type appears somewhere"
`testGearEffectTypeContentCoverage` check found that 9 of
`game/data/engine_parts.json`'s 14 cards (`engine_basic_thruster`,
`engine_afterburner`, `engine_fusion_core`, `engine_azure_coolant_jet`,
`engine_ember_burst_valve`, `engine_void_phase_thruster`,
`engine_solar_sail_flap`, `engine_burst_capacitor`,
`engine_singularity_drive` — every original pre-item-10(b) engine card)
carried ONLY effect types documented as hull-only-scoped
(`speed`/`money`/`climbSpeed`/`hullDurability`/`sampleSellValue`, per
`testGearHullSpeedRunWiring`/`testGearMoneyRunWiring`/
`testGearHullDurabilityRunWiring`'s explicit "engine-slot part must NOT
count" regressions and `M.effectiveSampleBonus`'s hull-only scope). Since
these are the ONLY legal slot for an engine card, equipping any of these 9
cards had literally zero effect on any run stat — real-looking pool
content that was actually dead the moment it left the hull card pool's
shared schema. `game/self_test.lua`'s new
`testEngineCardsHaveNonHullOnlyEffect` regression-checks that every bundled
engine card carries at least one effect type outside that hull-only set.
Fixed by adding a second, engine-scoped effect (mostly `fuelEfficiency` or
`steeringResponsiveness`, one `boostCharge`) to each of the 9 affected
cards — their original hull-only-scoped effects stay in place unchanged
(a card can and often does carry both a dead-in-engine-slot stat for
flavor/future-hull-reuse and a live engine-scoped one), so no rarity/tag
balance was altered, only new effects appended.

`game/self_test.lua`'s `testGearPropulsionRunWiring` regression-checks all
three: an equipped `engine_cryo_fuel_cell` (fuelEfficiency +25) raises
`launchForecast`'s altitude and matches the expected 25% burn-rate
reduction exactly; an equipped `engine_vector_nozzle`
(steeringResponsiveness +15) raises `steeringSpeed` by exactly 15%; a fresh
run reports zero boost charges and an equipped `engine_emergency_boost_pod`
(boostCharge +2) reports exactly 2. It also re-confirms none of these
engine-part effects leak into the independent hull gear list (item 10's
slot-independence guarantee).

## Rarity + edition farming system (item 12)

`game/gear.lua` implements item 12's two independent axes on top of the
existing `rarity`/`editions` card fields (already part of the schema since
item 13 — see "Card shape" above):

- **Rarity (A)** — `M.rarityDropWeights` is a relative-weight table
  (`common` 60 / `uncommon` 25 / `rare` 12 / `legendary` 3, i.e. rarer tiers
  are deliberately less likely). `M.rollRarity(roll, luckBonus)` picks a
  tier from an explicit `roll` in `[0, 1)` against this distribution;
  `luckBonus` (item 14's `luck` effect, target #2: "희귀 등급... 드롭 가중치를
  상위 등급 쪽으로 상향") scales `rare`/`legendary` weight up and
  `common`/`uncommon` weight down, so higher luck can only shift the result
  toward rarer tiers, never away from them, at a fixed `roll`. This function
  is pure — it does not touch `love.math.random` itself — so shop/checkpoint
  drop code (out of this lane's current scope) supplies the actual RNG
  source and this stays deterministically unit-testable.
- **Edition (B)** — every card's `editions` array (validated by the loader
  against `M.knownEditions = { irradiated, crystallized, quantum_flawed,
  refined }`, mirrored in `tools/gear-editor/editor.js`'s
  `KNOWN_EDITIONS`) lists which editions that specific card may roll into.
  `M.baseEditionChance = 0.08` (item 12's "낮은 확률, 예: 5~10%").
  `M.rollEdition(part, chanceRoll, pickRoll, luckBonus)` returns `nil` for a
  card with an empty `editions` list (editions are opt-in per card, not
  universal), otherwise triggers when `chanceRoll < baseEditionChance +
  luckBonus` (item 14's `luck` target #1: "에디션 부여 확률 상향") and
  selects one of the card's own candidate editions via `pickRoll`.
- **Edition effect transforms** — `M.editionEffects` centralizes each
  edition's mechanical effect (spaceship-themed, per item 12's request for
  "우주 방사선·희귀 합금·양자 결함" flavor):
  - `irradiated` (⚠️ 방사능처리) — effect values unchanged, but adds
    `synergyBonusAdd = 0.05` on top of the per-shared-pair tag synergy bonus
    when equipped (item 12: "시너지 태그 매칭 시 보너스 추가 증폭"), exposed
    via `M.editionSynergyBonusAdd(editionId)`.
  - `crystallized` (✨ 결정화) — doubles only `sampleSellValue` (item 12:
    "판매가 대폭 상승").
  - `quantum_flawed` (🌀 양자결함) — doubles every effect value but appends
    an extra `{ type = "hullDurability", value = -1 }` drawback effect
    (item 12: "효과가 두 배지만 부작용 하나 동반").
  - `refined` (💠 정제) — halves every effect value; `noSlotCost = true` is
    now honored by `game/engine_parts.lua`'s slot bookkeeping (see "Item
    12: noSlotCost edition wiring" below).
  - `M.applyEditionEffects(part, editionId)` returns a NEW effects array
    (never mutates the input `part`) with the edition's transform applied;
    `editionId == nil` returns an unchanged copy. An unknown edition id
    raises a Lua error, matching the loader's fail-loud posture elsewhere in
    this module.

`game/self_test.lua`'s `testGearRarityAndEditionSystem` verifies the rarity
weight ordering and luck monotonicity, that editions are gated to a card's
own candidate list, the base/luck-boosted edition chance threshold, each
edition's effect transform (including the `quantum_flawed` drawback and
that `applyEditionEffects` never mutates its input), and the unknown-edition
error path. Two bundled cards per pool (`hull_reactive_hull`/
`hull_quantum_alloy` in `hull_parts.json`, `engine_fusion_core`/
`engine_singularity_drive` in `engine_parts.json`) now declare non-empty
`editions` arrays so the loader/tests exercise real data, not just
synthetic fixtures.

As with items 9/10, this stays a pure data/math layer — `game/gear.lua`
does not roll rarity/editions during actual shop/checkpoint drops or apply
them to `run` state; that wiring (and the UI edition sparkle/border
treatment item 12 asks for) is deferred to a follow-up slice within this
lane's scope, once `game/expedition.lua`'s minimal-loader-call exception is
exercised for gear generally.

## Effect schema categories A~F (item 14)

`game/gear.lua` implements item 14's full category (A)~(F) effect-type
enum (listed under "Known effect types" above) as pure conversion
functions, each taking a list of equipped parts (hull, engine, or a mix —
these functions are category-agnostic) and returning the concrete gameplay
quantity that category controls:

- **(A) additive** — unchanged from before item 14: `M.aggregateEffects`
  sums every part's effect value by `type`; `M.equippedTotals` layers the
  item 9 tag-synergy multiplier on top of `climbSpeed` only.
- **(B) multiplicative — the synergy payoff axis** — `sellMultiplier` and
  `streakMultiplier` are percentage-shaped (`value = 25` means "+25%").
  `M.equippedTotals` sums every equipped part's `sellMultiplier` into one
  combined percentage first, THEN applies it as a single multiply pass
  against the additive `sampleSellValue` total — i.e. **additive totals
  are computed first, multiplicative totals are applied second**, and
  multiple multiplier cards stack additively with each other (two `+25%`
  cards give `+50%` total, never `+56.25%` compounding). This ordering is
  the concrete mechanism behind item 9's "조합이 곱연산으로 폭발" design
  goal for the sell-value axis (climbSpeed already had its own synergy
  multiplier from item 9). `streakMultiplier` is likewise defined in the
  schema (recognized effect type, validated range) and — as of the
  "Item 14(B) streakMultiplier run wiring" follow-up slice below — has a
  real run-state consumer: `game/gear.lua`'s `M.effectiveStreakBonusPerStep`
  converts it into a per-step percentage-point bonus that
  `game/expedition.lua`'s `M.streakBonusPerStep`/`M.streakMultiplier` apply
  to actual consecutive-collection streaks (see that section for the full
  contract; this paragraph only describes the raw schema shape).
- **(C) trigger/probability** — `M.chainTriggerCount(parts)` and
  `M.rerollCount(parts)` sum the relevant effect type and floor to a
  non-negative integer count (a fractional trigger/reroll doesn't make
  sense). `M.totalLuckBonus(parts)` sums the `luck` effect type and
  divides by 100 to produce the fractional `luckBonus` that
  `M.rollRarity`/`M.rollEdition` (item 12) already accept as a parameter —
  this is the wiring point that wasn't previously connected: any equipped
  part with a `luck` effect now has a direct, testable path into item 12's
  rarity/edition rolls once a caller supplies `gear.totalLuckBonus(equipped)`
  as `luckBonus`.
- **(D) survival/risk-mitigation** — `M.hasInsurance(parts)` is a boolean
  gate (any positive `insurance` total grants the save; multiple insurance
  effects do not stack multiple lives, per item 14's "1회 한정" framing).
  `M.effectiveCollisionRadius(baseRadius, parts)` shrinks a base hitbox
  radius by the summed `collisionRadius` percentage, clamped so it can
  never go negative.
- **(E) scouting/information** — `M.effectiveDetectionRadius(baseRadius, parts)`
  grows a base scan radius by the summed `detectionRadius` percentage.
  `M.autoCollectEnabled(parts)` is a boolean gate, same shape as
  `hasInsurance`.
- **(F) economy** — `M.effectiveShopPrice(basePrice, parts)` discounts a
  base shop price by the summed `shopDiscount` percentage, clamped at
  zero (a large discount stack can make an item free but never give money
  back).

`tools/gear-editor/editor.js`'s effect-type `<select>` in the card form is
now grouped into `<optgroup>`s by category (A~F) via a new
`EFFECT_TYPE_GROUPS` table, which is also the source of the flat
`KNOWN_EFFECT_TYPES` validation list (`Object.values(EFFECT_TYPE_GROUPS).flat()`)
— so the grouped UI and the validator can never drift apart from each
other. `game/self_test.lua`'s `testGearEffectSchemaExpansion` verifies each
category's conversion function behavior (including the B additive-then-
multiply ordering and the D/F zero-clamping), and asserts by reading
`editor.js`'s source text that every `gear.knownEffectTypes` entry appears
in its `EFFECT_TYPE_GROUPS` table, so the Lua whitelist and the editor
config can never silently drift apart.

As with items 9/10/12, none of these category (C)~(F) conversions are yet
wired into actual `run` state (`game/expedition.lua`'s luck-driven
drops/collision detection/detection radius/auto-collect/shop pricing) —
that remains deferred to a follow-up slice within this lane's
`loop/PROMPT.md` scope (minimal-loader-call exception only), same posture
as every other gear engine documented above.

### (D) insurance + (F) shopDiscount run wiring (follow-up slice)

`game/expedition.lua` now consumes two of the category (C)~(F) conversion
functions above within the "최소한의 로더 호출" exception already used for
items 9/10(b):

- **(D) insurance** — `M.damage(run, amount)` checks
  `gear.hasInsurance(run.equippedGear)` when a hit would otherwise reduce
  durability to 0. If the run hasn't already spent its one-time save this
  expedition (`run.insuranceUsed`, reset on `M.launch`/fresh `M.new`), the
  hit is absorbed (durability restored to 1, `run.insuranceUsed = true`,
  the full meta-wipe `destroy(run)` is skipped) instead of triggering
  destruction. A second lethal hit in the same expedition (insurance
  already spent) destroys normally, matching item 14's "1회 한정" framing.
  A new bundled hull card `hull_emergency_beacon` (uncommon, `insurance`
  +1, tags `defense`/`control`) exercises this in tests/gameplay.
- **(F) shopDiscount** — new `M.shopPrice(run, basePrice)` combines
  `run.equippedGear` and `run.equippedEngineParts` into one list and calls
  `gear.effectiveShopPrice(basePrice, parts)`. All five settlement-phase
  purchase functions (`M.buyFuelUpgrade`, `M.buyDurabilityUpgrade`,
  `M.buySampleYieldUpgrade`, `M.buySteeringUpgrade`, `M.buyShip`) now check
  affordability against and charge this discounted price instead of the
  raw `*Cost`/`scoutShipCost` field, so an equipped shopDiscount card
  actually reduces money spent at EARTH SHOP. A new bundled hull card
  `hull_trade_license` (uncommon, `shopDiscount` +20, tag `economy`)
  exercises this in tests/gameplay.

`game/self_test.lua`'s `testGearSurvivalAndEconomyWiring` regression-checks
both: an insured run survives one lethal hit with money/ships/gear intact
then destroys normally on a second lethal hit; an uninsured run destroys on
the first hit (baseline unchanged); a discounted purchase charges exactly
80% of the base cost while an undiscounted run still pays full price.

Still deferred (at the time of this slice): (C) `chainTrigger`/`rerollBonus`
and (E) `detectionRadius`/`autoCollect` run wiring, plus the actual
shop/checkpoint UI call sites that decide when to offer a roll (out of
this lane's current scope) — see "Item 14 (C)/(E) run wiring" below for
the (C)/(E) follow-up.

### Item 12 drop RNG run wiring — `M.rollGearOffer` (follow-up slice)

`game/expedition.lua` now exposes `M.rollGearOffer(run, pool, rolls)`,
wiring item 12's `gear.rollRarity`/`gear.rollEdition` (previously pure
functions with no real caller) into an actual run for the first time,
within the same "최소한의 로더 호출" exception:

- `rolls` is an explicit table (`rarity`, `pick`, `editionChance`,
  `editionPick`, all `[0, 1)`) — the real RNG source (shop/checkpoint code,
  still out of this lane's scope) is entirely the caller's responsibility,
  same explicit-roll design `gear.lua`'s own functions already use.
- The target rarity tier is resolved via `gear.rollRarity(rolls.rarity,
  luckBonus)`, where `luckBonus` is now automatically sourced from
  `gear.totalLuckBonus(run.equippedGear)` instead of being a
  caller-supplied literal — this is the (C) `luck` target #2 wiring
  ("희귀 등급... 드롭 가중치를 상위 등급 쪽으로 상향") actually taking
  effect on a real run's equipped gear.
- A candidate card matching that tier is picked from `pool` (in
  `rolls.pick` order); if `pool` has no card of that tier, it falls back to
  picking from the full `pool` instead of returning nil, so callers never
  need to special-case an "empty tier" result.
- `gear.rollEdition(part, rolls.editionChance, rolls.editionPick,
  luckBonus)` (same auto-sourced `luckBonus` — (C) `luck` target #1) decides
  whether an edition attaches, and if so `gear.applyEditionEffects` is
  applied so the returned offer's `effects` are the *actual* post-edition
  numbers, not the raw card data.
- Returns a plain offer table (`id`, `name`, `nameKo`, `icon`, `rarity`,
  `tags`, `edition`, `effects`) — not a loadout entry. Equipping an accepted
  offer is still the caller's job via the existing `M.equipGear`.

`game/self_test.lua`'s `testGearOfferRolling` regression-checks: roll=0
resolves common with no edition; a forced-legendary roll on a
single-edition-carrying-card pool attaches an edition and the returned
effects differ numerically from the card's raw effects; an equipped `luck`
card raises (never lowers) the resolved rarity tier for the same probe
roll versus the zero-luck baseline; an empty-tier pool still falls back to
returning some card.

Still deferred: the actual shop/checkpoint UI screen that calls
`M.rollGearOffer` with real dice and presents the offer to the player
(`play.lua`, out of this lane's scope) — see "Item 14 (C)/(E) run wiring"
below for the (C)/(E) follow-up (now closed).

### Item 14 (C)/(E) run wiring — chainTrigger/rerollBonus/detectionRadius/autoCollect (follow-up slice)

`game/expedition.lua` closes the last remaining gap named above: the (C)
and (E) conversion functions now have run-facing wrappers, using the same
"최소한의 로더 호출" exception as every other gear wiring slice in this
lane.

- New private helper `combinedGearList(run)` concatenates
  `run.equippedGear` and `run.equippedEngineParts` into one list. Unlike
  `M.effectiveClimbSpeed` (hull-only, item 9 synergy) or
  `M.boostChargeCount` (engine-only, item 10b), (C)/(E) effect types are
  gear-category-agnostic in the schema (any card, hull or engine, can
  legally carry `chainTrigger`/`rerollBonus`/`detectionRadius`/
  `autoCollect`), so both equip slots count toward these totals even
  though item 10 keeps hull/engine capacity/slot-count independent.
- `M.chainTriggerCount(run)` / `M.rerollCount(run)` thinly wrap
  `gear.chainTriggerCount`/`gear.rerollCount` over `combinedGearList(run)`.
- `M.detectionRadius(run, baseRadius)` wraps
  `gear.effectiveDetectionRadius(baseRadius, combinedGearList(run))` —
  callers (e.g. a future `minimap.lua` integration for
  `M.viewRadius`/`M.checkpointSearchCellRadius`) can pass either constant
  as `baseRadius` once that UI wiring happens; this slice only guarantees
  the run-level conversion path exists and is tested.
- `M.autoCollectEnabled(run)` wraps `gear.autoCollectEnabled` the same way.

`game/self_test.lua`'s `testGearRunEffectWiring` regression-checks: an
unequipped run resolves all four to their zero/false/base-unchanged
defaults; a single hull card carrying all four effect types at once
resolves `chainTriggerCount == 1` (floored from 1.9), `rerollCount == 2`
(floored from 2.4), `detectionRadius(run, 20) == 30` (+50%), and
`autoCollectEnabled(run) == true`; a `chainTrigger` effect on an
ENGINE-slot card (not hull) also counts toward the total, confirming the
category-agnostic combined-list design.

Still deferred: the actual gameplay consumption sites for each (e.g. a
real "re-trigger a random equipped part's effect" mechanic for
`chainTriggerCount`, a free-reroll UI affordance for `rerollCount`,
`minimap.lua`/`play.lua` wiring `detectionRadius` into the actual scan
radius, and an auto-pickup code path honoring `autoCollectEnabled` while
flying) — all out of this lane's scope (`play.lua`/`world.lua`/
`minimap.lua` belong to other lanes per `loop/PROMPT.md`). With this
slice, every category (A)~(F) conversion function named in item 14 now has
at least one run-level wrapper wired in `game/expedition.lua`.

### Item 14(D) collisionRadius run wiring (follow-up slice)

A gap this file's own text above did not previously call out: unlike its
(D) sibling `insurance` (wired into `M.damage` two slices earlier) and its
(C)/(E) neighbors (`chainTriggerCount`/`rerollCount`/`detectionRadius`/
`autoCollectEnabled`, all wired in the previous slice), `game/gear.lua`'s
`M.effectiveCollisionRadius(baseRadius, parts)` had never gained a
run-facing wrapper in `game/expedition.lua`. This slice closes that last
remaining item 14 gap:

- New `M.collisionRadius(run, baseRadius)` thinly wraps
  `gear.effectiveCollisionRadius(baseRadius, combinedGearList(run))` —
  same category-agnostic combined hull+engine list as the (C)/(E)
  wrappers above (a `collisionRadius` effect can legally live on either
  slot type per the schema).
- `game/self_test.lua`'s new `testGearCollisionRadiusRunWiring` regression-
  checks: an unequipped run returns the base radius unmodified; a hull
  card with `collisionRadius = 20` shrinks a base radius of 10 to exactly
  8 through the run wrapper; an ENGINE-slot card with `collisionRadius = 50`
  also shrinks the total (base 10 → 5), confirming hull/engine
  category-agnosticism matches every other (C)/(E)/(D) wrapper.

Still deferred: the actual collision-detection call site that would pass
a real base hitbox radius into `M.collisionRadius` (lives in `play.lua`/
`world.lua`, out of this lane's scope) — this slice only establishes the
run-level source of truth, same posture as `M.boostChargeCount`.

### Item 14(B) streakMultiplier run wiring (follow-up slice)

`streakMultiplier` was the one (B) category effect type still unwired at
the end of the previous slice — `docs/GEAR_SCHEMA.md`'s own "Effect schema
categories A~F" section explicitly named it as deferred ("its consumer...
lives in gameplay code... does not yet convert it into a run-state
multiplier"). This slice closes that gap:

- `game/gear.lua`'s new `M.effectiveStreakBonusPerStep(baseBonusPerStep,
  parts)` is a pure conversion: a card's `streakMultiplier` raw value is
  interpreted as percentage POINTS added to the base per-consecutive-
  collection growth rate (`value = 10` means "+10 percentage points per
  streak step"), summed additively across every equipped part (category
  (A)/(B) totals are always additive-first, matching every other
  category's design).
- `game/expedition.lua`'s new `M.streakBonusPerStep(run)` combines this
  with `combinedGearList(run)` (the same hull+engine category-agnostic
  helper item 14 (C)/(E) already established — a streak-boosting card
  isn't restricted to one slot type in the schema). `M.streakMultiplier`
  now takes an optional second `run` argument and uses
  `M.streakBonusPerStep(run)` instead of the previous hardcoded `0.2`
  constant (calling with no `run` argument still falls back to the base
  `0.2` rate, so any other call site continues to work unmodified).
  `M.collectSample(run, value, hueKey)` passes `run` through so an
  in-flight expedition's actual equipped gear affects the awarded streak
  bonus.
- A new bundled hull card `hull_combo_matrix` (rare, `streakMultiplier`
  +10, tags `economy`/`control`) exercises this in tests/gameplay — the
  first bundled card of this effect type.

`game/self_test.lua`'s `testGearStreakMultiplierWiring` regression-checks:
an unequipped run's per-step rate and `streakMultiplier(3)` match the
pre-wiring baseline (`0.2`/`1.4`) exactly, `streakMultiplier` still works
when called with no `run` argument at all, an equipped `hull_combo_matrix`
raises the per-step rate to `0.3` and `streakMultiplier(3)` to `1.6`, an
ENGINE-slot equip of the same card also raises the rate (category-agnostic
combined-list design), and `collectSample`'s three consecutive
same-hue-family calls on a boosted run return the correctly growing
multiplier end-to-end (`1.0 → 1.3 → 1.6`).

With this slice, **every** category (A)~(F) effect type named in item 14
now has at least one real run-state consumer, not just a validated-and-
ignored schema entry.

## Item 9(c): slot-swap economy loop — `M.sellGear`

Item 9's (c) sub-goal ("슬롯 수(현재 6개)를 장비 장착 한도로 유지하되,
사용자가 매 사이클 다른 조합을 실험하고 싶어지도록 카드 획득... 과
교체가 잦아지는 루프를 설계한다") had been the one explicitly-named,
still-unaddressed part of item 9 after every other item13→9→10→12→14 slice
completed. With hull/engine slot counts fixed at 6/3 (`game/engine_parts.lua`),
the only way to try a new combination once full is to free a slot — this
slice adds that release valve as a real economic decision, not a free
swap:

- `game/gear.lua`'s new `M.raritySellValue` table (`common=4`,
  `uncommon=9`, `rare=18`, `legendary=40`) and `M.editionSellBonus = 6`
  define a pure `M.sellValue(part)` conversion — refund scales with
  rarity (Balatro's "joker sell price scales with rarity"), and any
  edition (item 12) adds a flat premium on top. Both constants are
  deliberately well below typical shop purchase prices so
  sell-to-rebuy is a lossy trade-off, not a money-printing loop. A
  part with a missing/unknown `rarity` falls back to the `common` value
  defensively rather than erroring (this is a money calculation, not
  schema validation — `validatePart` already guarantees every *loaded*
  part has a known rarity).
- `game/expedition.lua`'s new `M.sellGear(run, category, id)` is the
  run-level wiring: it looks up the equipped part by id in the given
  category's slot list, computes its sell value via `gear.sellValue`,
  removes it via `engine_parts.unequip`, and credits `run.money` — all
  atomically (no partial money-without-removal or removal-without-money
  state). Restricted to `run.phase == "settlement"`, matching every other
  money-moving action in this module (`M.buyFuelUpgrade` etc.) so it
  can't be spammed mid-flight. Returns `true, value` on success or
  `false, error-message` on failure (wrong phase, unknown/unequipped id).

`game/self_test.lua`'s new `testGearSlotSwapEconomyWiring` regression-checks:
`gear.sellValue`'s rarity/edition scaling (including the common-tier
fallback for a missing rarity), that selling outside the settlement phase
is rejected without moving money or the slot list, that a successful sell
during settlement removes the exact card and credits the exact rarity-scaled
value, that selling an ENGINE-slot card leaves the HULL slot list untouched
(and vice versa, item 10's slot-independence guarantee extended to this new
action), and that selling an unequipped/unknown id fails cleanly with no
money change.

Still deferred (out of this lane's scope per `loop/PROMPT.md` — requires
`game/scenes/play.lua` UI): an actual EARTH SHOP screen surfacing
`M.sellGear` as a tappable "sell" action per equipped card, and any visual
sell-value display on the card grid.

### Item 12: `noSlotCost` edition wiring — `refined` cards equip past capacity

Item 12's "refined" edition (`game/gear.lua`'s `M.editionEffects.refined`)
has carried a `noSlotCost = true` field since the item 12 slice, explicitly
documented above as "reserved metadata for a future no-slot-cost mechanic
... not yet wired into `game/engine_parts.lua` slot bookkeeping". This
slice closes that gap — the last remaining documented-but-unwired piece of
metadata across items 9/10/12/13/14 in this lane's scope.

- `game/gear.lua`'s new `M.isNoSlotCost(editionId)` is a pure predicate:
  `true` only for `"refined"` (or any future edition whose
  `M.editionEffects` entry sets `noSlotCost = true`), `false` for nil/any
  other edition id.
- `game/engine_parts.lua` now `require("game.gear")` (one-directional —
  `gear.lua` does not require `engine_parts.lua` back, so no circular
  dependency) and uses a new private `occupiedSlotCount(list)` helper that
  excludes any part whose `part.edition` is `gear.isNoSlotCost`-flagged
  from the count `M.isFull`/`M.equip` check against `hullSlotCount`/
  `engineSlotCount`. A `refined` card can therefore be equipped even when
  its category's normal 6/3 slots are already full — Balatro's "Negative"
  joker-slot concept item 12 asked for — while every non-`refined` card's
  behavior (including full rejection at exactly 6/3) is completely
  unchanged.
- `game/self_test.lua`'s new `testGearNoSlotCostEditionWiring` regression-
  checks: `gear.isNoSlotCost`'s truth table (`refined`→true, other
  editions/nil→false); filling a hull loadout to its normal 6-card
  capacity still works and reports full exactly as before; a further
  *normal* card is still rejected once full (baseline unchanged); a
  `refined`-edition card, however, equips successfully past that same
  full capacity and is actually appended to the slot list; `isFull`
  continues to report `true` afterward (unaffected by the extra
  no-cost card, since the 6 normal cards alone already fill it);
  unequipping one normal card frees exactly one slot for a new normal
  card regardless of the refined card's presence; and the engine
  category's fullness is completely unaffected by hull-side noSlotCost
  bookkeeping (slot-category independence, item 10, preserved).
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` both GREEN.
- Changed files: `game/gear.lua`, `game/engine_parts.lua`,
  `game/self_test.lua`, this doc, `docs/STATUS.md`,
  `docs/feedback/INBOX.md`. `git status --short` confirms
  `play.lua`/`i18n.lua`/`world.lua` were not touched, matching this
  lane's scope in `loop/PROMPT.md`.

### Item 12: `irradiated` edition synergy-bonus wiring — the edition's headline effect was previously dead

Item 12's "irradiated" edition text ("⚠️ 방사능처리(Irradiated) — 시너지 태그
매칭 시 보너스 추가 증폭") describes an edition whose entire point is
amplifying item 9's tag-synergy engine. `gear.editionSynergyBonusAdd(editionId)`
(a pure conversion returning `+0.05` for `irradiated`, `0` otherwise) has
existed since the item 12 slice, but auditing `gear.tagSynergyMultiplier`
found it never read a part's `edition` field at all — every shared-tag pair
got exactly the flat `M.synergyBonusPerSharedPair` regardless of edition, so
equipping an irradiated card produced an identical multiplier to an
un-edition'd one. The edition's one documented unique mechanical effect was
unreachable dead code from the player's perspective (only its unrelated
`applyEditionEffects` multiplier scope, shared with every "all"-scope
edition, ever did anything).

- `game/gear.lua`'s `M.tagSynergyMultiplier(parts)` now adds
  `M.editionSynergyBonusAdd(a.edition) + M.editionSynergyBonusAdd(b.edition)`
  on top of `M.synergyBonusPerSharedPair` for every shared-tag pair found —
  each side of the pair contributes its own edition bonus independently, so
  two irradiated parts sharing a tag stack both contributions. Pairs with no
  edition present behave exactly as before (both calls return `0`). Pairs
  with no shared tag still contribute nothing at all — editions amplify
  existing synergy, they never manufacture synergy between unrelated tags.
- `game/self_test.lua`'s new `testGearIrradiatedSynergyBonusWiring()`
  regression-checks: an irradiated part in a shared-tag pair produces a
  strictly higher multiplier than the same pair without the edition, the
  delta over baseline equals exactly `gear.editionSynergyBonusAdd("irradiated")`,
  an irradiated part with no tag overlap at all still yields a `1` (no
  synergy) multiplier, and two irradiated parts sharing a tag stack both
  bonus contributions on top of the flat per-pair amount (RED confirmed:
  `boosted=1.15` identical to `baseline=1.15` before the fix, GREEN after).
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` both GREEN
  (`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:55`,
  `ASSET_MANIFEST_OK`).
- Changed files: `game/gear.lua`, `game/self_test.lua`, this doc,
  `docs/STATUS.md`, `docs/feedback/INBOX.md`. `git status --short` confirms
  `play.lua`/`i18n.lua`/`world.lua`/`expedition.lua`/`engine_parts.lua` were
  not touched — this slice is a pure synergy-engine fix + regression test,
  no run-state wiring needed since `tagSynergyMultiplier` is already
  consumed by `expedition.effectiveClimbSpeed`.
- Bundled hull cards `hull_reactive_hull`/`hull_quantum_alloy` (and engine
  cards `engine_fusion_core`/`engine_singularity_drive`) already list
  `irradiated` as a candidate edition, so this bonus is reachable through
  the existing item 12 drop-RNG path (`gear.rollEdition`/
  `expedition.rollGearOffer`) without any new content needed.

### Item 14: effect-type content coverage — every A~G type now has a real card

Prior slices gave every effect type (A~G) a *run-level consumer function*
(e.g. `expedition.detectionRadius`, `expedition.chainTriggerCount`), but
`docs/STATUS.md` never actually checked whether the *shipped card data*
(`game/data/hull_parts.json` / `engine_parts.json`) contained a card using
each type. Auditing the bundled pools found seven effect types with a fully
working run-wiring path but **zero cards in either pool that could ever
trigger them**: `sellMultiplier`, `luck`, `chainTrigger`, `rerollBonus`,
`collisionRadius`, `detectionRadius`, `autoCollect`. A player could never
encounter these mechanics in actual play no matter what they equipped.

- `game/self_test.lua`'s new `testGearEffectTypeContentCoverage()`
  generalizes the existing (G)-specific "bundled pool must actually use
  this type" pattern (`testEnginePropulsionSpecialization`) to the full
  `gear.knownEffectTypes` set: it loads both bundled pools, unions every
  effect type actually present across all cards, and asserts every known
  type appears at least once. RED confirmed
  (`effect type 'detectionRadius' must be used by at least one bundled
  hull/engine part`) before the data fix.
- `game/data/hull_parts.json` gained 7 new hull cards, one per previously-
  uncovered type: `hull_market_broker` (sellMultiplier +20%),
  `hull_lucky_charm` (luck +15), `hull_echo_relay` (chainTrigger +1),
  `hull_negotiator_chip` (rerollBonus +2), `hull_slipstream_hull`
  (collisionRadius -15%), `hull_scanner_array` (detectionRadius +25%),
  `hull_collector_drone` (autoCollect). Each keeps existing tag-synergy
  conventions (economy/control/defense/speed/void families) so they
  compose with the item 9 synergy engine like any other card. Hull pool
  is now 34 cards (was 27); engine pool unchanged at 14.
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` both GREEN
  after the data addition.
- Changed files: `game/data/hull_parts.json`, `game/self_test.lua`, this
  doc, `docs/STATUS.md`, `docs/feedback/INBOX.md`. `git status --short`
  confirms `play.lua`/`i18n.lua`/`world.lua`/`expedition.lua`
  were not touched — this slice was pure data + a new regression test.

### Item 14(C) rerollBonus consumption wiring — M.rerollsRemaining / M.spendReroll (follow-up slice)

The "Item 14 (C)/(E) run wiring" section above closed the gap where
`chainTrigger`/`rerollBonus`/`detectionRadius`/`autoCollect` had no
run-facing wrapper at all, but left one asymmetry unaddressed:
`M.rerollCount(run)` (and its sibling wrappers) are pure re-derived
totals recomputed fresh from currently-equipped gear every call — fine
for `chainTriggerCount`/`detectionRadius`/`autoCollectEnabled`, which are
genuinely stateless per-tick modifiers, but meaningless for `rerollBonus`
specifically: a "free reroll count" only means something as a
per-expedition **resource that depletes when spent**, the same way
`insurance` is a one-shot boolean (`run.insuranceUsed`) rather than a pure
function of equipped gear. Until this slice, nothing could ever actually
spend a free reroll — the count existed but had no consumption path,
making `rerollBonus` dead content even though its schema/run-wiring
layers were both nominally "done".

- New `run.rerollsUsed` field (defaults to `0` in `M.new`) tracks how many
  of the current expedition's free rerolls have already been spent — same
  lifecycle shape as `run.insuranceUsed`: reset to `0` on `M.launch`'s
  relaunch branch and on the full meta-wipe `destroy(run)` path.
- New `M.rerollsRemaining(run)` returns `M.rerollCount(run) -
  run.rerollsUsed`, clamped to never go negative. Because
  `M.rerollCount(run)` is still the live equipped-gear total, gaining more
  `rerollBonus` gear mid-expedition immediately raises the remaining
  ceiling with no extra bookkeeping needed.
- New `M.spendReroll(run)` — atomic, non-throwing: returns `true` and
  increments `run.rerollsUsed` by one if `rerollsRemaining(run) > 0`,
  otherwise returns `false, "no free rerolls remaining"` and leaves state
  unchanged (same "reject, don't partial-apply" contract as
  `M.equipGear`/`M.sellGear`).
- `game/self_test.lua`'s `testGearRunEffectWiring` (extended, not new)
  regression-checks: an unequipped run has `rerollsRemaining == 0` and
  `spendReroll` refuses immediately; a run with an equipped `rerollBonus`
  card (floored total 2) starts at `rerollsRemaining == 2`, two successive
  `spendReroll` calls succeed and drain it to `0` one at a time, a third
  call is refused (`false` + message) without going negative, and
  relaunching the same run (`M.launch`) refills `rerollsRemaining` back up
  to the equipped total (RED confirmed:
  `attempt to call field 'rerollsRemaining' (a nil value)` before
  implementation).
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` both GREEN
  (`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3,
  `LOVE_BUNDLE_OK:build/game.love:55`, `ASSET_MANIFEST_OK`).
- Changed files: `game/expedition.lua`, `game/self_test.lua`, this doc,
  `docs/STATUS.md`, `docs/feedback/INBOX.md`. `git status --short`
  confirms `play.lua`/`i18n.lua`/`world.lua`/`game/gear.lua`/
  `game/engine_parts.lua` were not touched.
- This slice also fixed a stale contradiction in the "(B) multiplicative"
  paragraph earlier in this doc, which still claimed `streakMultiplier`
  had no run-state consumer even though the later "Item 14(B)
  streakMultiplier run wiring" section (added in a prior slice) already
  documents it as wired — the earlier paragraph now cross-references that
  section instead of repeating the outdated claim.
- Still deferred: the actual shop/checkpoint UI affordance that would let
  a player tap "free reroll" and call `M.spendReroll` (`play.lua`, out of
  this lane's scope) — this slice only establishes the run-level
  spend/remaining state a future consumer will read from and mutate,
  same posture as every other item 14 (C)/(E) wrapper before it.

### Item 9/14 economy-stat gap: `sampleSellValue`/`sellMultiplier` had no
### run-state consumer — `M.effectiveSampleBonus` closes it

A documentation-vs-code audit (the same pattern that found the item 12
`noSlotCost`/irradiated-synergy gaps and item 14's 7-type content-coverage
gap in earlier slices) found one more: `gear.equippedTotals` has combined a
part's flat (A) `sampleSellValue` with the (B) `sellMultiplier` percentage
(additive-sum-then-multiply, per the "Effect schema categories A~F"
section above) since item 14's very first slice, and 8 bundled hull cards
use `sampleSellValue` / 1 (`hull_market_broker`) uses `sellMultiplier` —
but **nothing in `game/expedition.lua` ever read `equippedTotals.sampleSellValue`**.
Equipping every one of those 9 cards had literally zero effect on the
money a player actually earned from collecting samples. This is item 9's
core "부품 조합이 고도 상승 *및 경제* 효율에 배가 효과" promise for the
economy half of the stat (climbSpeed synergy was already wired in an
earlier slice via `M.effectiveClimbSpeed`) — silently dead for the entire
lifetime of this lane's work on items 9/12/13/14 until this slice.

- `game/expedition.lua`'s new `M.effectiveSampleBonus(run)` reads
  `gear.equippedTotals(run.equippedGear or {}).sampleSellValue` — hull-only
  (unlike the category-agnostic (C)/(E) wrappers), matching climbSpeed
  synergy's hull-only scope immediately above it in the same file, since
  item 9 explicitly scopes the combo-synergy payoff to hull ("조커형")
  parts.
- `M.collectSample(run, value, hueKey)` now adds
  `M.effectiveSampleBonus(run)` to the awarded amount AFTER the existing
  `sampleYieldMultiplier` × `streakMultiplier` chain is applied and
  floored — gear modifies the final resolved quantity, the same posture
  `insurance`/`collisionRadius` already established, rather than being
  folded into the multiplier chain itself (so the gear bonus is not
  itself affected by the streak/yield upgrades — it's a flat top-up per
  collection, matching a card's raw effect `value` being a flat number,
  not a percentage, for the (A) `sampleSellValue` part of the combo).

`game/self_test.lua`'s `testGearRunEffectWiring` regression-checks: an
unequipped run's `effectiveSampleBonus` is exactly `0`; a hull card
combining `sampleSellValue = 10` + `sellMultiplier = 50` resolves to a
flat `+15` bonus (`10 * 1.5`, matching `equippedTotals`' existing
additive-then-multiply math verified separately in
`testGearEffectSchemaExpansion`); and an end-to-end `collectSample(run,
100)` call with that gear equipped awards exactly `115` (base
`100 * 1.0 * 1.0` floored, plus the flat `+15` gear bonus).

Still deferred at the time of that slice: engine-slot
`sellMultiplier`/`sampleSellValue` cards (the bundled `engine_parts.json`
pool then had none of either type). A later item-10/14 coverage slice
added `engine_market_thruster` (`sellMultiplier +20`) and
`engine_fusion_core`/`engine_singularity_drive` (`sampleSellValue`), but
`M.effectiveSampleBonus` still read hull-only `equippedTotals` — see the
follow-up section immediately below. Shop/checkpoint UI that visually
surfaces the gear-boosted sample value remains out of this lane's scope
(`play.lua`).

### Item 10/14 (B) `sellMultiplier` engine-slot wiring

The category-agnostic coverage slice (`testEngineCardsHaveCategoryAgnosticEffectCoverage`)
and bundled `engine_market_thruster` put a live `sellMultiplier` card on
the engine pool, but `M.effectiveSampleBonus(run)` still called
`gear.equippedTotals(run.equippedGear or {})` — hull list only — so an
engine-slot (B) multiplier never scaled the hull (A) `sampleSellValue`
total. That left `engine_market_thruster` as schema-legal dead content
for its documented run consumer, the same class of gap this lane closed
for insurance/engine-slot category-agnostic types.

- (A) `sampleSellValue` stays hull-only (item 9 scopes the additive
  payoff to hull "조커형" parts, matching climbSpeed/money/speed/
  hullDurability). An engine-slot `sampleSellValue` card still does not
  count.
- (B) `sellMultiplier` is category-agnostic: hull + engine via
  `combinedGearList(run)`. `M.effectiveSampleBonus` now does
  `hullAdditive * (1 + combinedSellMultiplier / 100)` — the same
  additive-then-multiply order `gear.equippedTotals` already used, just
  with the (B) total drawn from both slot lists. A sellMultiplier-only
  engine card with no hull `sampleSellValue` still yields `0` (the
  multiplier does not invent an additive base).

`game/self_test.lua`'s `testGearSellMultiplierEngineSlotWiring` covers
unequipped 0, hull additive +10, hull additive + engine +50% = 15,
`collectSample` 115, engine-only multiplier 0, hull-slot multiplier
regression +15, and engine-slot `sampleSellValue` remaining 0.

### Item 10(b)/14(G) `boostCharge` consumption wiring (follow-up slice)

`M.boostChargeCount(run)` (item 10(b)/14(G)) had existed since its own
wiring slice as a pure re-derived total — the equipped engine parts'
`boostCharge` effects summed and floored — but exactly like
`rerollCount(run)` before `M.spendReroll` closed that gap, a "how many
emergency boost charges do I have" COUNT is meaningless as a
per-expedition resource unless something can actually SPEND one and see
the pool deplete. This was the last documented-but-never-actually-spent
(C)-shaped resource in the (G) propulsion category (mirroring `insurance`
being a one-shot boolean and `rerollBonus` being a depleting counter,
both already closed).

- `game/expedition.lua`'s new `run.boostsUsed` field (initialized to `0`
  in `M.new`, reset to `0` in `M.launch` alongside `run.insuranceUsed`/
  `run.rerollsUsed`) tracks how many of the CURRENT expedition's boost
  charges have already been spent.
- `M.boostsRemaining(run)` returns the live `M.boostChargeCount(run)`
  minus `run.boostsUsed` (floored at zero) — re-equipping more
  `boostCharge` gear mid-run immediately raises the ceiling, identical to
  `rerollsRemaining`'s contract.
- `M.spendBoost(run)` returns `true` and decrements the remaining count by
  spending one charge, or `false, error-message` (never throws) if none
  remain — same atomic reject-don't-partial-apply shape as
  `M.spendReroll`/`M.sellGear`/`M.equipGear`.

`game/self_test.lua`'s `testGearPropulsionRunWiring` gained a new
consumption block regression-checking: a run with `engine_emergency_boost_pod`
equipped (`boostCharge +2`) starts with 2 remaining boosts; two successful
`spendBoost` calls drain it to zero; a third refuses cleanly without going
negative; an unequipped run starts at zero remaining and its `spendBoost`
call also refuses cleanly; and re-launching the expedition refills
`boostsRemaining` back to the current equipped total.

Still deferred (out of this lane's scope per `loop/PROMPT.md` — requires
`game/scenes/play.lua` UI): an actual tap-to-boost button/gameplay effect
that calls `M.spendBoost` and applies a real thrust/altitude burst while
flying.

### Item 9/14 (A) `hullDurability` run-state gap — `refreshShipStats` closes it

Same "documented but silently dead" pattern this lane's audit slices have
repeatedly found and closed for `sampleSellValue`/`sellMultiplier`,
`irradiated` synergy, `noSlotCost`, and `boostCharge` consumption:
`gear.equippedTotals(parts).hullDurability` has additively summed a part's
`hullDurability` effect since item 14's very first slice, and the bundled
`hull_parts.json` pool has carried 9 `hullDurability` cards
(`hull_scrap_plate`, `hull_titan_frame`, etc.) since item 9's 24-card
expansion — but `refreshShipStats(run)`, the *only* place `run.maxDurability`
is (re)computed (called from `M.new`/`M.launch`'s meta-wipe,
`M.buyDurabilityUpgrade`, `M.selectShip`), never read that total. All 9
cards were fully equippable with zero effect on the ship's actual maximum
hull points — the intended payoff of item 9's own `(A)` additive schema
category was dead content for the entire lifetime of this lane's work.

- New private `equippedHullDurabilityBonus(run)` (exposed as
  `M.equippedHullDurabilityBonus` for tests/future callers) reads
  `gearModule.equippedTotals(run.equippedGear or {}).hullDurability` — hull-
  only, matching `M.effectiveClimbSpeed`/`M.effectiveSampleBonus`'s scope
  (item 9 explicitly scopes the combo-synergy/stat payoff to hull "조커형"
  parts), unlike the category-agnostic `(C)`/`(E)`/`collisionRadius`
  wrappers that sum both hull and engine slots.
- `refreshShipStats(run)` now adds this bonus into the existing
  `baseDurability + shipBonus + upgradeLevel*upgradeAmount` formula, so
  gear stacks additively on top of the ship/upgrade axis rather than
  replacing it.
- Because `refreshShipStats` previously only ran from launch/shop-purchase/
  ship-select call sites (never from an equip/unequip action), `M.equipGear`/
  `M.unequipGear` now also call it immediately for the `hull` category —
  a hull-slot change can shift `maxDurability`, so the recompute can't wait
  for the next shop purchase. Before this run's very first launch
  (`run.phase == "launch"`, the pre-flight loadout screen) current
  `durability` is kept synced to the freshly recomputed max too (raised on
  equip, clamped down on unequip) — matching `M.new`'s invariant that a
  never-yet-launched run always has `durability == maxDurability`. Engine-
  category equip/unequip is untouched (no recompute, no durability sync),
  since `hullDurability` on an engine-slot card intentionally does not
  count (see the hull-only scoping above).
- `game/self_test.lua`'s new `testGearHullDurabilityRunWiring` regression-
  checks: an unequipped run's `maxDurability` is unchanged from its
  pre-wiring base+ship+upgrade value; equipping a `hullDurability +2` hull
  card and launching raises `maxDurability` from 3 to 5 and refills current
  `durability` to match; the identical card equipped into the ENGINE slot
  instead is correctly excluded (hull-only scoping, `maxDurability` stays
  at the unmodified 3); and gear `hullDurability` stacks additively with a
  purchased `durabilityUpgradeLevel` (both bonuses present simultaneously
  sum correctly on top of base).
- `make test`/`make verify LOVE=/Users/jm/.local/bin/love` both GREEN.

### Item 9/14 (A) `speed` run-state gap — `M.steeringSpeed` closes it

The previous slice found and closed the `hullDurability` run-state gap and
noted this audit pattern might still apply to other (A) additive types. It
did: `speed` (a hull card's contribution to the ship's steering/maneuvering
rate) was validated and loaded by `game/gear.lua` since item 9's original
card-pool expansion, and 7 bundled hull cards use it, but no run-state
function ever read `gearModule.equippedTotals(...).speed` — equipping any
of those 7 cards had zero effect on actual in-flight steering, another
"validated, loaded, never READ" gap.

- New `game/expedition.lua` `M.equippedHullSpeedBonus(run)` reads
  `gearModule.equippedTotals(run.equippedGear or {}).speed` — hull-only,
  matching climbSpeed/sampleSellValue/hullDurability's hull-scoped design
  (item 9 calls these the "선체(조커형)" combo payoff stats; `speed` sits in
  the same (A) category as `climbSpeed`/`hullDurability`).
- `M.steeringSpeed(run)` now adds this bonus to the existing
  `baseSteeringSpeed + steeringUpgradeLevel*steeringUpgradeAmount` sum
  BEFORE applying the engine-part `steeringResponsiveness` percentage
  multiplier (`gearModule.effectiveSteeringRate`) — additive-then-
  multiplicative, so hull `speed` cards and engine `steeringResponsiveness`
  cards stack instead of one overriding the other.
- `game/self_test.lua`'s new `testGearHullSpeedRunWiring()` regression-
  checks: an unequipped run's steeringSpeed matches the pre-wiring baseline
  exactly, a `speed +8` hull card raises it by exactly 8, the same effect on
  an ENGINE-slot card is correctly ignored (hull-only scope), and hull
  `speed` + engine `steeringResponsiveness` stack correctly (55+8=63, then
  ×1.5 = 94.5). RED confirmed before the fix (`got 55`, expected 63), GREEN
  after.
- `make test`/`make verify LOVE=/Users/jm/.local/bin/love` both GREEN.

## Item 9/14 (A) `money` run-state gap — `settle(run)` closes the last (A) additive gap

`money` was the last of the original five (A) additive effect types
(speed/sampleSellValue/money/climbSpeed/hullDurability) to still be dead
content: `gearModule.equippedTotals(...).money` has been computed since
item 14's first slice, and `hull_parts.json`/`engine_parts.json` have
carried `money` cards since item 9's expansion, but no run-state function
ever read that total. Unlike its (A) siblings (which are per-tick rates or
per-sample bonuses), `money` reads as a flat expedition-completion payout,
so it is wired into `settle(run)` — the single place a run's `money`
balance is credited after a completed expedition returns to Earth — rather
than into a per-frame/per-sample function.

- New `game/expedition.lua` `M.equippedHullMoneyBonus(run)` reads
  `gearModule.equippedTotals(run.equippedGear or {}).money` — hull-only,
  matching climbSpeed/sampleSellValue/hullDurability/speed's hull-scoped
  design (item 9 calls these the "선체(조커형)" combo payoff stats).
- `settle(run)` now adds this bonus into the settlement `payout` alongside
  `lastSampleSettlement`/`lastSlotSettlement`, so it is credited to
  `run.money` and reflected in `run.lastSettlement` exactly once per
  completed expedition.
- `game/self_test.lua`'s new `testGearMoneyRunWiring()` regression-checks:
  an unequipped run's settlement payout equals the unmodified pending
  sample+slot value (40+10=50), a `money +15` hull card raises the payout
  to exactly 65, and the same effect on an ENGINE-slot card is correctly
  ignored (hull-only scope, still 50). RED confirmed before the fix (`got
  50`, expected 65), GREEN after.
- `make test`/`make verify LOVE=/Users/jm/.local/bin/love` both GREEN.

## Item 14(C) `chainTrigger` consumption gap — `collectSample` closes the last "count exists but nothing consumes it" gap

`expedition.chainTriggerCount(run)` (see "Item 14 (C)/(E) run wiring"
above) had existed only as a stateless re-derived count since that
follow-up slice — no code path ever actually re-triggered anything with
it, matching the exact same pattern this lane already found and closed for
`rerollBonus` (`M.spendReroll`) and `boostCharge` (`M.spendBoost`). Item
14's own description frames `chainTrigger` as "특정 조건마다 다른 장착
카드 효과 재발동, 발라트로 Blueprint/Brainstorm 컨셉" (re-activating
another equipped card's effect on a condition) — the concrete payoff wired
here is the simplest faithful reading available within this lane's scope
(no UI/event-selection layer): re-applying the current sample collection's
awarded value once per chain-trigger point.

- `game/expedition.lua`'s `M.collectSample(run, value, hueKey)` now reads
  `M.chainTriggerCount(run)` (category-agnostic — both hull and engine
  slots count, same as `rerollBonus`/`detectionRadius`/`autoCollect`) after
  computing the yield/streak/hull-sample-bonus-adjusted `awarded` value, and
  multiplies it by `(1 + retriggers)` when `retriggers > 0` — i.e. 1 base
  application plus N retriggers, e.g. a `chainTrigger +1` card doubles the
  awarded value. This does **not** create additional collection events:
  `run.sampleCount` and the streak-family bookkeeping still advance exactly
  once per `collectSample` call, only the final awarded amount scales.
- `M.collectSample` now returns a 4th value, `retriggers` (the exact count
  applied), so tests/future UI can display how many times a collection was
  chain-retriggered without recomputing `chainTriggerCount` separately.
- `game/self_test.lua`'s new `testGearChainTriggerConsumptionWiring()`
  regression-checks: an unequipped run's awarded value and reported
  retrigger count are unchanged (100, 0 retriggers); a `chainTrigger +1`
  hull card doubles the awarded value (100 -> 200, 1 retrigger reported)
  without inflating `sampleCount` past 1; the same card equipped in the
  ENGINE slot doubles the value too (category-agnostic, matching
  `combinedGearList`'s existing (C)/(E) design). RED confirmed before the
  fix (`got nil` for the unequipped retrigger count, since `collectSample`
  didn't return a 4th value yet), GREEN after.
- `make test`/`make verify LOVE=/Users/jm/.local/bin/love` both GREEN
  (`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:55`,
  `ASSET_MANIFEST_OK`).
- Changed files: `game/expedition.lua`/`game/self_test.lua`/
  `docs/GEAR_SCHEMA.md`/`docs/STATUS.md`/`docs/feedback/INBOX.md` only —
  `play.lua`/`i18n.lua`/`world.lua`/`game/gear.lua`/`game/engine_parts.lua`
  untouched (`git status --short` confirms).

## Item 10/14 category-agnostic content-coverage gap — engine pool gains its first cards for 10 hull/engine-agnostic effect types

This lane's recurring "문서-코드 정합성 감사" pattern applied one level
further than the two existing content-coverage tests
(`testGearEffectTypeContentCoverage`, `testEngineCardsHaveNonHullOnlyEffect`)
had checked. `docs/GEAR_SCHEMA.md`/`docs/STATUS.md` document 10 effect
types as **category-agnostic** — `luck`, `chainTrigger`, `rerollBonus`,
`collisionRadius`, `detectionRadius`, `autoCollect`, `insurance`,
`shopDiscount`, `sellMultiplier`, `streakMultiplier` — meaning their
run-level wiring (mostly via `expedition.lua`'s `combinedGearList(run)`
helper, which sums `run.equippedGear` + `run.equippedEngineParts`
unconditionally) explicitly reads BOTH slot categories. A direct Python
audit of the bundled `game/data/engine_parts.json` (14 cards, pre-slice)
found that all 10 of these types had zero cards using them — every single
bundled card carrying one of these types lived only in `hull_parts.json`.
This meant a player who equipped only engine gear (item 10's independent
slot category) could never actually encounter luck/chain-retrigger/free
rerolls/reduced collision radius/wider detection/auto-collect/insurance/
shop discounts/sell multipliers/streak multipliers in real play, even
though every one of their run wrappers reads the engine slot list too —
schema-legal but practically dead content for that slot.

- TDD: `game/self_test.lua`'s new `testEngineCardsHaveCategoryAgnosticEffectCoverage()`
  audits the loaded engine pool directly and asserts every one of the 10
  category-agnostic types appears on at least one bundled engine card. RED
  confirmed first (`missing: luck, chainTrigger, rerollBonus,
  collisionRadius, detectionRadius, autoCollect, insurance, shopDiscount,
  sellMultiplier, streakMultiplier`), then closed by data.
- `game/data/engine_parts.json` gains 10 new cards (14 -> 24), one per
  missing type, each pairing its category-agnostic effect with a
  hull-safe/engine-appropriate secondary effect (mostly `steeringResponsiveness`/
  `fuelEfficiency`/`speed`, all already-established (G)/(A) engine-legal
  types) so every new card also independently satisfies
  `testEngineCardsHaveNonHullOnlyEffect`'s "not entirely hull-only" rule:
  `engine_probability_core` (luck), `engine_echo_thruster` (chainTrigger),
  `engine_haggler_valve` (rerollBonus), `engine_slim_nacelle`
  (collisionRadius), `engine_deep_scan_pod` (detectionRadius),
  `engine_magnet_intake` (autoCollect), `engine_escape_pod_thruster`
  (insurance), `engine_freelancer_manifold` (shopDiscount),
  `engine_market_thruster` (sellMultiplier), `engine_momentum_stabilizer`
  (streakMultiplier). Tag conventions (economy/control/defense/speed/altitude)
  reused from the existing pool so the item 9 tag-synergy engine treats them
  identically to any other card.
- `make test`/`make verify LOVE=/Users/jm/.local/bin/love` both GREEN
  (`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:55`,
  `ASSET_MANIFEST_OK`).
- Changed files: `game/data/engine_parts.json`/`game/self_test.lua`/
  `docs/GEAR_SCHEMA.md`/`docs/STATUS.md`/`docs/feedback/INBOX.md` only —
  `play.lua`/`i18n.lua`/`world.lua`/`game/gear.lua`/`game/engine_parts.lua`/
  `game/expedition.lua` untouched (`git status --short` confirms).

## Item 13/12: web editor edition/rarity whitelist sync check

`tools/gear-editor/README.md` and `editor.js`'s own header comment
("Validation rules here intentionally mirror `game/gear.lua`'s loader
exactly") have always *documented* that the editor's `KNOWN_EDITIONS`
and `KNOWN_RARITIES` arrays stay byte-for-byte in sync with `game/gear.lua`'s
`M.knownEditions`/`M.knownRarities` whitelists — exactly the same guarantee
`testGearEffectSchemaExpansion` already enforced (by reading `editor.js`'s
source text) for `M.knownEffectTypes`/`EFFECT_TYPE_GROUPS`. Auditing this
lane's own test suite found that guarantee existed only as prose for
editions/rarities: nothing ever re-read `editor.js`'s `KNOWN_EDITIONS`/
`KNOWN_RARITIES` arrays and compared them against `gear.lua`, so a future
rarity or edition added to one side but not the other would silently drift
undetected — the editor would then either reject valid game data or accept
data the Lua loader would reject.

- TDD: new `game/self_test.lua` `testGearEditorEditionAndRaritySync()`
  reads `tools/gear-editor/editor.js` via `love.filesystem.read` (same
  technique as the existing effect-type sync check) and asserts every key of
  `gear.knownEditions`/`gear.knownRarities` appears as a quoted string
  literal inside `editor.js`'s `KNOWN_EDITIONS`/`KNOWN_RARITIES` array
  literals. RED confirmed by temporarily injecting an extra
  `__test_temp_edition = true` entry into `M.knownEditions` (not committed)
  and observing the exact assertion failure
  (`editor.js KNOWN_EDITIONS must include '__test_temp_edition' to stay in
  sync with gear.lua`); reverting restored GREEN, then the real sync
  discovery: current `editor.js` was already byte-for-byte in sync with
  `gear.lua` (4 editions, 4 rarities, both sides matching) — this slice adds
  the missing regression guard rather than fixing an existing drift.
- `make test`/`make verify LOVE=/Users/jm/.local/bin/love` both GREEN
  (`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3,
  `LOVE_BUNDLE_OK:build/game.love:58`, `ASSET_MANIFEST_OK`).
- Changed files: `game/self_test.lua`/`docs/GEAR_SCHEMA.md`/
  `docs/STATUS.md`/`docs/feedback/INBOX.md` only — `play.lua`/`i18n.lua`/
  `world.lua`/`game/gear.lua`/`game/engine_parts.lua`/`game/expedition.lua`/
  `tools/gear-editor/editor.js` untouched (`git status --short` confirms).

### Item 7: Galaxy-exclusive gear (shop/hub logic)

Added `galaxyExclusive` boolean to the `gear.lua` schema. Gears marked as such are omitted from `gear.earthShopPool` and instead guaranteed to drop exactly once per run when players visit a specific galaxy's hub planet via `expedition.exploreHub(run, galaxyId, pool)`. A deterministic shop planet per galaxy is also generated via `world.shopPlanet(galaxy)`.

### Item 7 follow-up: engine pool had zero `galaxyExclusive` content

The first item-7 slice only marked one hull card (`hull_combo_matrix`) as
`galaxyExclusive`, leaving `game/data/engine_parts.json` with 0 such cards.
`expedition.exploreHub(run, galaxyId, enginePool)` silently fell back to
the full (non-exclusive) engine pool in that case, so a player exploring a
galaxy hub could never receive an engine-exclusive reward and the Earth
shop's engine pool never excluded anything -- the guaranteed-drop mechanic
was effectively hull-only despite item 10(c) requiring the engine pool
reuse the same 3-way acquisition structure. Fixed by marking the existing
legendary `engine_singularity_drive` card `galaxyExclusive: true` (no
balance change, pure metadata addition). `run.hubExplored` is confirmed
shared by galaxy id across both hull and engine pools (exploring a hub
once locks out re-exploration via either pool, matching item 8's
one-settlement-per-checkpoint design), so calling `exploreHub` with the
hull pool after already exploring with the engine pool (or vice versa)
correctly returns `nil`. `game/self_test.lua`'s
`testGearGalaxyExclusiveEnginePoolWiring()` covers this.

### Item 13 follow-up: web editor round-trips `galaxyExclusive`

`gear.validatePart` already persisted `galaxyExclusive` on loaded cards,
but `tools/gear-editor/` had no form control and `collectFormPart()`
omitted the field. Opening `hull_parts.json` / `engine_parts.json`,
editing any other field, and saving would silently strip the flag from
`hull_combo_matrix` / `engine_singularity_drive` and undo the Earth-shop
filter / hub-drop wiring. The editor now has a "Galaxy exclusive"
checkbox, `openForm` restores it, `collectFormPart` writes it, and the
grid labels exclusive cards. `testGearEditorGalaxyExclusiveFieldSync()`
locks the HTML id + collect/open round-trip.

### Item 13 follow-up: Card-shape table documents `galaxyExclusive`

The Card-shape example JSON and field table at the top of this document
now include optional `galaxyExclusive` (boolean, default false). Authors
reading only the published schema can mark a card as Earth-shop-excluded /
hub-drop-only without hunting later item-7 notes. `game/self_test.lua`'s
`testGearSchemaDocumentsGalaxyExclusive()` locks the Card-shape section
(example JSON + table row + Earth-shop / hub-drop notes).

