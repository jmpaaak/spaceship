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

### Known effect types (this cycle)

This cycle implements category (A), the additive stat effects proposed in
item 14:

- `speed` — steering/lateral speed bonus.
- `sampleSellValue` — additive bonus to sample sell value.
- `money` — direct money delta.
- `climbSpeed` — additive bonus to ascent/altitude gain rate.
- `hullDurability` — additive bonus to max hull durability.

Item 14 will extend this enum with multiplicative (B: `sellMultiplier`,
`streakMultiplier`), trigger/probability (C: `luck`, `chainTrigger`,
`rerollBonus`), survival (D: `insurance`, `collisionRadius`), scouting
(E: `detectionRadius`, `autoCollect`), and economy (F: `shopDiscount`)
categories. Any new type must be added to `game/gear.lua`'s
`M.knownEffectTypes` whitelist and to `tools/gear-editor/editor.js`'s
`KNOWN_EFFECT_TYPES` list together, in the same change, so the two stay in
sync (the editor's validator intentionally mirrors the Lua loader's rules
exactly).

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
