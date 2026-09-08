local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test nearby search-radius extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_nearby_search_radius.lua")

    assert(runner:find('require("game.tests.legacy_nearby_search_radius").run()', 1, true),
        "R1-C: self_test must delegate nearby search-radius checks")
    assert(not runner:find("nearbyPlanets search radius must be 4 sectors", 1, true)
            and not runner:find("capturedDebrisRad", 1, true),
        "R1-C: nearby search-radius characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted nearby search-radius suite must expose run()")
    assert(suite:find('scene.expedition.phase = "ascending"', 1, true)
            and suite:find("world.nearbyPlanets = savedNP", 1, true)
            and suite:find("world.nearbyDebris = savedND", 1, true)
            and suite:find("capturedPlanetRad == 4", 1, true)
            and suite:find("capturedDebrisRad == 4", 1, true),
        "R1-C: extracted suite must retain setup, restoration, and exact radius contracts")
    print("  R1-C self_test nearby search-radius extraction OK")
end

return M
