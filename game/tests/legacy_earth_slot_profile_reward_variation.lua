local M = {}

-- Earth-slot reward profiles preserve the solar/fringe/void reward gradient,
-- expose the active profile to the UI, and keep void misses no safer than solar.
function M.run()
    local expedition = require("game.expedition")

    local fringeGalaxy, voidGalaxy
    local candidates = {
        "andromeda", "triangulum", "ngc1300", "sombrero", "pinwheel",
        "sculptor", "circinus", "bode", "centaurus", "whirlpool",
    }
    for _, galaxyId in ipairs(candidates) do
        local profile = expedition.galaxySlotOddsProfile(galaxyId)
        if profile == "fringe" and not fringeGalaxy then fringeGalaxy = galaxyId end
        if profile == "void" and not voidGalaxy then voidGalaxy = galaxyId end
        if fringeGalaxy and voidGalaxy then break end
    end
    assert(fringeGalaxy, "need at least one fringe galaxy in candidates")
    assert(voidGalaxy, "need at least one void galaxy in candidates")

    local run = expedition.new()
    local solarWeights = expedition.earthSlotWeights(nil)
    local solarTotal = solarWeights.MONEY + solarWeights.PART + solarWeights.SPEED
        + solarWeights.DURABILITY + solarWeights.HARVEST
    local starRoll = solarTotal - 0.5

    local solarSpin = expedition.earthSlotSpin(run, nil, {
        reels = { starRoll, starRoll, starRoll },
    })
    assert(solarSpin.symbols[1] == "HARVEST" and solarSpin.symbols[2] == "HARVEST"
        and solarSpin.symbols[3] == "HARVEST",
        "starRoll must select HARVEST for solar profile, got: "
            .. table.concat(solarSpin.symbols, "-"))
    assert(solarSpin.rewardType == "harvest" and solarSpin.reward == 0,
        "solar triple-HARVEST must be harvest type (not money), got: "
            .. tostring(solarSpin.reward))

    local voidWeights = expedition.earthSlotWeights(voidGalaxy)
    local voidTotal = voidWeights.MONEY + voidWeights.PART + voidWeights.SPEED
        + voidWeights.DURABILITY + voidWeights.HARVEST
    local voidStarRoll = voidTotal - 0.5
    local voidSpin = expedition.earthSlotSpin(run, voidGalaxy, {
        reels = { voidStarRoll, voidStarRoll, voidStarRoll },
    })
    assert(voidSpin.symbols[1] == "HARVEST",
        "voidStarRoll must select HARVEST for void profile, got: "
            .. table.concat(voidSpin.symbols, "-"))
    assert(voidSpin.rewardType == "harvest",
        "void triple-HARVEST must be harvest type, got " .. tostring(voidSpin.rewardType))

    local fringeWeights = expedition.earthSlotWeights(fringeGalaxy)
    local fringeTotal = fringeWeights.MONEY + fringeWeights.PART + fringeWeights.SPEED
        + fringeWeights.DURABILITY + fringeWeights.HARVEST
    local fringeStarRoll = fringeTotal - 0.5
    local fringeSpin = expedition.earthSlotSpin(run, fringeGalaxy, {
        reels = { fringeStarRoll, fringeStarRoll, fringeStarRoll },
    })
    assert(fringeSpin.symbols[1] == "HARVEST",
        "fringeStarRoll must select HARVEST for fringe profile, got: "
            .. table.concat(fringeSpin.symbols, "-"))
    assert(fringeSpin.rewardType == "harvest",
        "fringe triple-HARVEST must be harvest type, got " .. tostring(fringeSpin.rewardType))
    assert(fringeSpin.rewardType == voidSpin.rewardType,
        "fringe and void must have same rewardType, got " .. tostring(fringeSpin.rewardType))

    assert(solarSpin.rewardProfile == "solar",
        "solar spin must expose rewardProfile='solar', got: "
            .. tostring(solarSpin.rewardProfile))
    assert(voidSpin.rewardProfile == "void",
        "void spin must expose rewardProfile='void', got: "
            .. tostring(voidSpin.rewardProfile))
    assert(fringeSpin.rewardProfile == "fringe",
        "fringe spin must expose rewardProfile='fringe', got: "
            .. tostring(fringeSpin.rewardProfile))

    local moneyRoll = 0.5
    local partRoll = solarWeights.MONEY + 0.5
    local solarMiss = expedition.earthSlotSpin(run, nil, {
        reels = { moneyRoll, partRoll, moneyRoll },
    })
    local voidPlanetRoll = voidWeights.MONEY + 0.5
    local voidMiss = expedition.earthSlotSpin(run, voidGalaxy, {
        reels = { moneyRoll, voidPlanetRoll, moneyRoll },
    })
    assert(voidMiss.reward <= solarMiss.reward,
        "void no-match reward (" .. tostring(voidMiss.reward)
            .. ") must be <= solar no-match (" .. tostring(solarMiss.reward)
            .. ") - risk tradeoff")
end

return M
