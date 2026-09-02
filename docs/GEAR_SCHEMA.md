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
    reserved metadata for a future no-slot-cost mechanic (item 12's
    Balatro-negative-style concept) not yet wired into
    `game/engine_parts.lua` slot bookkeeping this cycle.
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
  multiplier from item 9). `streakMultiplier` is defined in the schema
  (recognized effect type, validated range) but its consumer — the
  "동일 계열 연속 채집 배율" streak-tracking logic itself — lives in
  gameplay code (`game/expedition.lua`) outside this lane's current scope,
  so `game/gear.lua` does not yet convert it into a run-state multiplier.
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
