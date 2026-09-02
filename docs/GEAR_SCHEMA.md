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
