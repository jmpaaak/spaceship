local gear = require("game.gear")

local M = {}

local function testGearEditionScopeContentCoverage()
    local pools = { gear.loadHullParts(), gear.loadEngineParts() }
    local deadCombos = {}
    for _, pool in ipairs(pools) do
        for _, part in ipairs(pool) do
            for _, editionId in ipairs(part.editions or {}) do
                local def = gear.editionEffects[editionId]
                assert(def, "part '" .. part.id .. "' references unknown edition '" .. tostring(editionId) .. "'")
                if def.scope ~= "all" then
                    local hasScopedEffect = false
                    for _, effect in ipairs(part.effects) do
                        if effect.type == def.scope then
                            hasScopedEffect = true
                            break
                        end
                    end
                    if not hasScopedEffect then
                        deadCombos[#deadCombos + 1] = part.id .. ":" .. editionId
                    end
                end
            end
        end
    end
    assert(#deadCombos == 0,
        "every bundled card x edition combo whose edition has a scoped (non-\"all\") multiplier must " ..
        "carry at least one effect of that scoped type, otherwise rolling that edition on that card " ..
        "is a silent no-op (edition badge shown, numbers unchanged); dead combos: " ..
        table.concat(deadCombos, ", "))
end

local function testHullCardsHaveNonEngineOnlyEffect()
    local engineOnlyTypes = {
        boostCharge = true
    }
    local hullPool = gear.loadHullParts()
    local deadCards = {}
    for _, part in ipairs(hullPool) do
        local hasNonEngineOnlyEffect = false
        for _, effect in ipairs(part.effects) do
            if not engineOnlyTypes[effect.type] then
                hasNonEngineOnlyEffect = true
                break
            end
        end
        if not hasNonEngineOnlyEffect then
            deadCards[#deadCards + 1] = part.id
        end
    end
    assert(#deadCards == 0,
        "hull_parts.json contains cards with ONLY engine-scoped (G) effects, " ..
        "making them completely dead in the hull slot: " .. table.concat(deadCards, ", "))
end

local function testEngineCardsHaveCategoryAgnosticEffectCoverage()
    local engineExpectedTypes = {
        "luck", "chainTrigger", "rerollBonus", "collisionRadius",
        "detectionRadius", "autoCollect", "streakMultiplier", "boostCharge",
    }
    local enginePool = gear.loadEngineParts()
    local seen = {}
    for _, part in ipairs(enginePool) do
        for _, effect in ipairs(part.effects) do
            seen[effect.type] = true
        end
    end
    local missing = {}
    for _, t in ipairs(engineExpectedTypes) do
        if not seen[t] then
            missing[#missing + 1] = t
        end
    end
    assert(#missing == 0,
        "engine_parts.json must cover engine-appropriate effect types; missing: " ..
        table.concat(missing, ", "))
end

function M.run()
    testGearEditionScopeContentCoverage()
    testHullCardsHaveNonEngineOnlyEffect()
    testEngineCardsHaveCategoryAgnosticEffectCoverage()
end

return M