local expedition = require("game.expedition")

local M = {}

-- Item 9/14 (A) hullDurability gap: gear.equippedTotals has additively
-- summed a part's hullDurability effect since item 14's very first slice,
-- and the bundled hull_parts.json pool has carried 9 hullDurability cards
-- (hull_scrap_plate, hull_titan_frame, etc.) since item 9's 24-card
-- expansion -- but refreshShipStats(run) (the ONLY place run.maxDurability
-- is (re)computed, on M.new/M.launch's meta-wipe/buyDurabilityUpgrade/
-- selectShip) never read gear.equippedTotals at all, so every one of those
-- 9 cards was equippable with zero actual effect on the ship's maximum
-- hull points -- the same "documented but silently dead" gap pattern this
-- lane's audit slices have repeatedly found and closed for
-- sampleSellValue/sellMultiplier, irradiated-synergy, noSlotCost, and
-- boostCharge consumption.
function M.run()
    local bareRun = expedition.new({ durability = 3 })
    assert(bareRun.maxDurability == 3,
        "an unequipped fresh run's maxDurability must equal its base durability 3, got "
            .. tostring(bareRun.maxDurability))

    local durabilityCard = {
        id = "hull-durability-fixture", name = "Plating", nameKo = "Plating", icon = "*",
        rarity = "common", tags = {}, editions = {},
        effects = { { type = "hullDurability", value = 2 } },
    }
    local run = expedition.new({ durability = 3 })
    assert(expedition.equipGear(run, "hull", durabilityCard))
    expedition.launch(run)
    assert(run.maxDurability == 5,
        "equipping a hullDurability +2 hull card must raise maxDurability from 3 to 5 through launch's "
            .. "refreshShipStats recompute, got " .. tostring(run.maxDurability))
    assert(run.durability == 5,
        "launch must also refill current durability to the new (gear-boosted) maxDurability, got "
            .. tostring(run.durability))

    local engineRun = expedition.new({ durability = 3 })
    local engineDurabilityCard = {
        id = "engine-durability-fixture", name = "EngineDur", nameKo = "EngineDur", icon = "*",
        rarity = "common", tags = {}, editions = {},
        effects = { { type = "hullDurability", value = 2 } },
    }
    assert(expedition.equipGear(engineRun, "engine", engineDurabilityCard))
    expedition.launch(engineRun)
    assert(engineRun.maxDurability == 3,
        "hullDurability effects on an engine-slot part must NOT count toward maxDurability "
            .. "(item 9 scopes this stat to hull gear), got " .. tostring(engineRun.maxDurability))

    local stackedRun = expedition.new({ durability = 3, durabilityUpgradeAmount = 1 })
    assert(expedition.equipGear(stackedRun, "hull", durabilityCard))
    stackedRun.phase = "settlement"
    stackedRun.money = 100
    assert(expedition.buyDurabilityUpgrade(stackedRun))
    assert(stackedRun.maxDurability == 6,
        "gear hullDurability (+2) and the durability upgrade (+1) must stack on top of base 3, got "
            .. tostring(stackedRun.maxDurability))
end

return M