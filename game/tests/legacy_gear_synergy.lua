local gear = require("game.gear")

local M = {}

-- docs/feedback/INBOX.md item 9: "부품들의 조합(시너지)이 고도(distance-from-Earth
-- 점수) 상승 속도/효율에 배가 효과를 내는 것" — combos must multiply, not just add.
-- This exercises game/gear.lua's pure tag-synergy engine: two equipped parts
-- sharing a tag must yield MORE speed than the two parts' raw additive
-- sum would give alone, and the bundled hull_parts.json card pool must have
-- grown to the 20-30 range item 9 calls for.
function M.run()
    local hullPool, hullErr = gear.loadHullParts()
    assert(hullPool, "hull parts must load: " .. tostring(hullErr))
    assert(#hullPool >= 20, "hull part pool must have at least 20 cards (item 9), got " .. #hullPool)

    -- Every card must carry at least one synergy tag so the engine has
    -- something to match against.
    for _, part in ipairs(hullPool) do
        assert(#part.tags >= 1, "hull part '" .. part.id .. "' must have at least one tag")
    end

    -- Pure aggregate: summing effect values of all equipped parts, no synergy.
    local partA = { id = "a", tags = { "altitude" }, effects = { { type = "speed", value = 4 } } }
    local partB = { id = "b", tags = { "altitude" }, effects = { { type = "speed", value = 8 } } }
    local partC = { id = "c", tags = { "economy" }, effects = { { type = "sampleSellValue", value = 5 } } }

    local rawTotals = gear.aggregateEffects({ partA, partB })
    assert(rawTotals.speed == 12, "raw additive sum must be 12, got " .. tostring(rawTotals.speed))

    -- Two parts sharing the "altitude" tag must synergize: the combined
    -- multiplier must exceed 1 (i.e. more than simple addition).
    local sharedMultiplier = gear.tagSynergyMultiplier({ partA, partB })
    assert(sharedMultiplier > 1, "shared-tag parts must produce a synergy multiplier > 1, got " .. tostring(sharedMultiplier))

    -- A single part (no partner sharing its tag) must get no synergy bonus.
    local soloMultiplier = gear.tagSynergyMultiplier({ partA, partC })
    assert(soloMultiplier == 1, "non-overlapping tags must not synergize, got " .. tostring(soloMultiplier))

    -- equippedTotals must apply the multiplier to speed specifically,
    -- so the combo total is strictly greater than the raw additive sum.
    local combo = gear.equippedTotals({ partA, partB })
    assert(combo.speed > rawTotals.speed,
        "synergized speed (" .. tostring(combo.speed) ..
        ") must exceed raw additive sum (" .. tostring(rawTotals.speed) .. ")")
    assert(combo.synergyMultiplier == sharedMultiplier)

    -- Non-speed effect types (e.g. sampleSellValue) must remain purely
    -- additive — synergy in this cycle only amplifies speed.
    local mixedCombo = gear.equippedTotals({ partA, partC })
    assert(mixedCombo.sampleSellValue == 5, "sampleSellValue must stay additive, got " .. tostring(mixedCombo.sampleSellValue))
end

return M
