local M = {}

-- Item 15(c) + Item 14(C): earthSlotSpin engine-slot luck regression guard.
-- The galaxy-odds suite verifies hull-slot luck raises effectiveStarWeight.
-- This companion verifies that earthSlotSpin also includes engine-slot gear.
function M.run()
    local expedition = require("game.expedition")
    local solarWeights = expedition.earthSlotWeights(nil)
    local rolls = { reels = { 0, 0, 0 } }

    local bareRun = expedition.new()
    local bareResult = expedition.earthSlotSpin(bareRun, nil, rolls)
    assert(bareResult.effectiveStarWeight == solarWeights.HARVEST,
        "bare run must have base STAR weight in earthSlotSpin, got: "
            .. tostring(bareResult.effectiveStarWeight))

    local luckCard = {
        id = "engine-slot-luck-fixture", name = "EngLuck", nameKo = "엔진럭",
        icon = "✦", rarity = "common", tags = {}, editions = {},
        effects = { { type = "luck", value = 50 } },
    }

    local hullLuckRun = expedition.new()
    assert(expedition.equipGear(hullLuckRun, "hull", luckCard))
    local hullResult = expedition.earthSlotSpin(hullLuckRun, nil, rolls)
    assert(hullResult.effectiveStarWeight > solarWeights.HARVEST,
        "hull-slot luck card must boost earthSlotSpin STAR weight (baseline "
            .. tostring(solarWeights.HARVEST) .. ", got "
            .. tostring(hullResult.effectiveStarWeight) .. ")")

    local engineLuckRun = expedition.new()
    local engineCard = {
        id = "engine-slot-luck-fixture2", name = "EngLuck2", nameKo = "엔진럭2",
        icon = "✦", rarity = "common", tags = {}, editions = {},
        effects = { { type = "luck", value = 50 } },
    }
    assert(expedition.equipGear(engineLuckRun, "engine", engineCard))
    local engineResult = expedition.earthSlotSpin(engineLuckRun, nil, rolls)
    assert(engineResult.effectiveStarWeight > solarWeights.HARVEST,
        "engine-slot luck card must also boost earthSlotSpin STAR weight "
            .. "(earthSlotSpin uses combinedGearList, so engine luck must feed through): "
            .. "baseline=" .. tostring(solarWeights.HARVEST)
            .. " engineResult=" .. tostring(engineResult.effectiveStarWeight))

    assert(math.abs(hullResult.effectiveStarWeight - engineResult.effectiveStarWeight) < 0.001,
        "engine-slot and hull-slot luck with same value must produce identical STAR weight boost: "
            .. "hull=" .. tostring(hullResult.effectiveStarWeight)
            .. " engine=" .. tostring(engineResult.effectiveStarWeight))
end

return M