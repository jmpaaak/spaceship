local M = {}

-- Item 12/10 follow-up: the prior hull noSlotCost coverage only exercised
-- "refined" noSlotCost in the HULL category (capacity 6).
-- engine_parts.lua's occupiedSlotCount/isFull/equip are written generically
-- over `category` with no hull-specific branch, so this SHOULD already
-- hold for the independent engine category (capacity 3) too -- but that
-- had never actually been asserted. Per the STATUS.md-documented next
-- slice ("refined(noSlotCost) 에디션이 엔진 슬롯에서도 동일하게 적용되는지"),
-- this closes that untested-but-likely-true gap with an explicit
-- regression guard on the ENGINE category specifically.
function M.run()
    local enginePartsModule = require("game.engine_parts")
    local loadout = enginePartsModule.newLoadout()

    -- Fill the (smaller) engine category to its normal capacity (3) with
    -- plain, no-edition cards.
    for i = 1, enginePartsModule.engineSlotCount do
        local ok = enginePartsModule.equip(loadout, "engine", {
            id = "engine_fixture_" .. i, name = "Fixture", nameKo = "픽스처", icon = "*",
            rarity = "common", edition = nil, tags = {}, editions = {},
            effects = { { type = "boostCharge", value = 1 } },
        })
        assert(ok, "filling the engine loadout to its normal capacity must succeed")
    end
    assert(enginePartsModule.isFull(loadout, "engine"),
        "the engine loadout must report full once occupiedSlotCount reaches engineSlotCount")

    -- A normal (non-refined) engine card must still be rejected once full.
    local rejectOk, rejectErr = enginePartsModule.equip(loadout, "engine", {
        id = "engine_fixture_overflow", name = "Overflow", nameKo = "오버플로우", icon = "*",
        rarity = "common", edition = nil, tags = {}, editions = {},
        effects = { { type = "boostCharge", value = 1 } },
    })
    assert(not rejectOk and rejectErr, "a normal engine card must still be rejected once the engine loadout is at capacity")

    -- A "refined"-edition ENGINE card must be equippable PAST capacity,
    -- mirroring the hull-category guarantee, and must not itself count
    -- toward isFull for a subsequent normal-card equip check.
    local refinedOk = enginePartsModule.equip(loadout, "engine", {
        id = "engine_fixture_refined", name = "Refined Fixture", nameKo = "정제된 픽스처", icon = "*",
        rarity = "common", edition = "refined", tags = {}, editions = {},
        effects = { { type = "boostCharge", value = 1 } },
    })
    assert(refinedOk, "a noSlotCost (refined-edition) card must be equippable in the ENGINE category even when it is otherwise full")
    assert(#loadout.engine == enginePartsModule.engineSlotCount + 1,
        "the refined engine card must actually be appended to the engine slot list")
    assert(enginePartsModule.isFull(loadout, "engine") == true,
        "isFull(engine) must still report full (unaffected by the extra noSlotCost card) since the 3 normal cards still occupy all 3 slots")

    -- Unequipping one normal engine card must free exactly one slot even
    -- with the refined card present.
    assert(enginePartsModule.unequip(loadout, "engine", "engine_fixture_1"))
    assert(not enginePartsModule.isFull(loadout, "engine"),
        "removing one normal engine card must make room for exactly one more normal engine card, refined card notwithstanding")
    local refillOk = enginePartsModule.equip(loadout, "engine", {
        id = "engine_fixture_refill", name = "Refill", nameKo = "리필", icon = "*",
        rarity = "common", edition = nil, tags = {}, editions = {},
        effects = { { type = "fuelEfficiency", value = 1 } },
    })
    assert(refillOk, "a normal engine card must be able to re-fill the slot freed by unequipping")

    -- Hull-category independence must be preserved in the reverse
    -- direction too: filling engine with a refined overflow card must
    -- not affect the hull category's capacity/fullness at all.
    assert(not enginePartsModule.isFull(loadout, "hull"),
        "engine-category noSlotCost bookkeeping must never leak into the independent hull category")
end

return M