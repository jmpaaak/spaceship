local gear = require("game.gear")

local M = {}

-- Item 12's "refined" edition reserves `noSlotCost = true` metadata (a
-- Balatro-Negative-style "슬롯을 소모하지 않음" concept) that had been
-- documented in docs/GEAR_SCHEMA.md/game/gear.lua's M.editionEffects table
-- since the item 12 slice but never actually consulted by any slot
-- bookkeeping -- a "refined" card occupied a slot exactly like a normal
-- one. This regression-checks the wiring that closes that gap:
-- gear.isNoSlotCost + engine_parts.equip/isFull.
function M.run()
    -- gear.isNoSlotCost is a pure predicate over an edition id.
    assert(gear.isNoSlotCost("refined") == true,
        "the 'refined' edition must be flagged noSlotCost per its M.editionEffects entry")
    assert(gear.isNoSlotCost("irradiated") == false,
        "editions without noSlotCost=true must resolve to false")
    assert(gear.isNoSlotCost(nil) == false, "no edition must resolve to false")

    local enginePartsModule = require("game.engine_parts")
    local loadout = enginePartsModule.newLoadout()

    -- Fill the hull category to its normal capacity (6) with plain,
    -- no-edition cards -- these DO consume slots as before.
    for i = 1, enginePartsModule.hullSlotCount do
        local ok = enginePartsModule.equip(loadout, "hull", {
            id = "hull_fixture_" .. i, name = "Fixture", nameKo = "픽스처", icon = "*",
            rarity = "common", edition = nil, tags = {}, editions = {},
            effects = { { type = "hullDurability", value = 1 } },
        })
        assert(ok, "filling the hull loadout to its normal capacity must succeed")
    end
    assert(enginePartsModule.isFull(loadout, "hull"),
        "the hull loadout must report full once occupiedSlotCount reaches hullSlotCount")

    -- A normal (non-refined) card must still be rejected once full --
    -- baseline behavior must be unchanged by this slice.
    local rejectOk, rejectErr = enginePartsModule.equip(loadout, "hull", {
        id = "hull_fixture_overflow", name = "Overflow", nameKo = "오버플로우", icon = "*",
        rarity = "common", edition = nil, tags = {}, editions = {},
        effects = { { type = "hullDurability", value = 1 } },
    })
    assert(not rejectOk and rejectErr, "a normal card must still be rejected once the hull loadout is at capacity")

    -- A "refined"-edition card, however, must be equippable PAST capacity
    -- (item 12's noSlotCost concept), and must not itself count toward
    -- isFull for a SUBSEQUENT normal-card equip check.
    local refinedOk = enginePartsModule.equip(loadout, "hull", {
        id = "hull_fixture_refined", name = "Refined Fixture", nameKo = "정제된 픽스처", icon = "*",
        rarity = "common", edition = "refined", tags = {}, editions = {},
        effects = { { type = "hullDurability", value = 0.5 } },
    })
    assert(refinedOk, "a noSlotCost (refined-edition) card must be equippable even when the loadout is otherwise full")
    assert(#loadout.hull == enginePartsModule.hullSlotCount + 1,
        "the refined card must actually be appended to the slot list")
    assert(enginePartsModule.isFull(loadout, "hull") == true,
        "isFull must still report full (unaffected by the extra noSlotCost card) since the 6 normal cards still occupy all 6 slots")

    -- Unequipping one normal card must free exactly one slot even with the
    -- refined card present, confirming occupiedSlotCount excludes it from
    -- the count in both directions.
    assert(enginePartsModule.unequip(loadout, "hull", "hull_fixture_1"))
    assert(not enginePartsModule.isFull(loadout, "hull"),
        "removing one normal card must make room for exactly one more normal card, refined card notwithstanding")
    local refillOk = enginePartsModule.equip(loadout, "hull", {
        id = "hull_fixture_refill", name = "Refill", nameKo = "리필", icon = "*",
        rarity = "common", edition = nil, tags = {}, editions = {},
        effects = { { type = "hullDurability", value = 1 } },
    })
    assert(refillOk, "a normal card must be able to re-fill the slot freed by unequipping")

    -- Engine-slot independence must be preserved: filling hull with a
    -- refined overflow card must not affect the engine category's
    -- capacity/fullness at all.
    assert(not enginePartsModule.isFull(loadout, "engine"),
        "hull-category noSlotCost bookkeeping must never leak into the independent engine category")
end

return M