local expedition = require("game.expedition")
local gear = require("game.gear")

local M = {}

-- Item 7 follow-up: galaxy-exclusive gear applies to the engine pool as well
-- as the hull pool, including deterministic per-galaxy variety and shared hub
-- exploration tracking across both categories.
function M.run()
    local enginePool = gear.loadEngineParts()
    local hasExclusive = false
    for _, part in ipairs(enginePool) do
        if part.galaxyExclusive then hasExclusive = true end
    end
    assert(hasExclusive, "the bundled engine_parts.json pool must contain at least one galaxyExclusive card")

    local earthEnginePool = gear.earthShopPool(enginePool)
    assert(#earthEnginePool < #enginePool, "Earth shop engine pool must exclude galaxy-exclusive engine parts")
    for _, part in ipairs(earthEnginePool) do
        assert(not part.galaxyExclusive, "Earth shop engine pool must not contain galaxy-exclusive parts")
    end

    local specific = gear.galaxySpecificGear(enginePool, "galaxy:3:4")
    assert(specific, "galaxySpecificGear must return an engine part")
    assert(specific.galaxyExclusive, "galaxySpecificGear must prefer a galaxy-exclusive engine card when one exists")

    local run = expedition.new()
    local offer1 = expedition.exploreHub(run, "galaxy:3:4", enginePool)
    assert(offer1 and offer1.id == specific.id,
        "exploreHub must return the deterministic galaxy-specific engine gear")
    assert(run.hubExplored["galaxy:3:4"], "exploreHub must mark the hub as explored")

    local offer2 = expedition.exploreHub(run, "galaxy:3:4", enginePool)
    assert(offer2 == nil, "exploreHub must return nil on subsequent visits to the same hub in the same run")

    local hullPool = gear.loadHullParts()

    local function countExclusive(pool)
        local n = 0
        for _, part in ipairs(pool) do
            if part.galaxyExclusive then n = n + 1 end
        end
        return n
    end
    assert(countExclusive(hullPool) >= 3,
        "hull_parts.json must carry at least 3 galaxyExclusive cards for real per-galaxy variety")
    assert(countExclusive(enginePool) >= 3,
        "engine_parts.json must carry at least 3 galaxyExclusive cards for real per-galaxy variety")

    local function distinctIdsAcrossGalaxies(pool)
        local seen = {}
        local count = 0
        for i = 1, 12 do
            local id = string.format("galaxy:%d:%d", i * 7, i * 13)
            local part = gear.galaxySpecificGear(pool, id)
            if not seen[part.id] then
                seen[part.id] = true
                count = count + 1
            end
        end
        return count
    end
    assert(distinctIdsAcrossGalaxies(hullPool) > 1,
        "galaxySpecificGear must return more than one distinct hull card across different galaxy ids")
    assert(distinctIdsAcrossGalaxies(enginePool) > 1,
        "galaxySpecificGear must return more than one distinct engine card across different galaxy ids")

    -- A hub is explored once, not once per gear category.
    local offer3 = expedition.exploreHub(run, "galaxy:3:4", hullPool)
    assert(offer3 == nil, "a galaxy hub already explored via one pool must stay explored for the other pool too")
end

return M