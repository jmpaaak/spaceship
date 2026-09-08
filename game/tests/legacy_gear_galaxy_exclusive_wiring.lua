local expedition = require("game.expedition")
local gear = require("game.gear")

local M = {}

function M.run()
    local hullPool = gear.loadHullParts()
    local earthPool = gear.earthShopPool(hullPool)
    local hasExclusive = false
    for _, part in ipairs(hullPool) do
        if part.galaxyExclusive then hasExclusive = true end
    end
    if hasExclusive then
        assert(#earthPool < #hullPool, "Earth shop pool must exclude galaxy-exclusive parts")
        for _, part in ipairs(earthPool) do
            assert(not part.galaxyExclusive, "Earth shop pool must not contain galaxy-exclusive parts")
        end
    end

    local specific = gear.galaxySpecificGear(hullPool, "galaxy:1:2")
    assert(specific, "galaxySpecificGear must return a part")

    local run = expedition.new()
    local offer1 = expedition.exploreHub(run, "galaxy:1:2", hullPool)
    assert(offer1 and offer1.id == specific.id, "exploreHub must return the deterministic galaxy-specific gear")
    assert(run.hubExplored["galaxy:1:2"], "exploreHub must mark the hub as explored")

    local offer2 = expedition.exploreHub(run, "galaxy:1:2", hullPool)
    assert(offer2 == nil, "exploreHub must return nil on subsequent visits to the same hub in the same run")
end

return M