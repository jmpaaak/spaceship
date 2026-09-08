local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test central-star gravity-well extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_central_star_gravity_well.lua")

    assert(runner:find('require("game.tests.legacy_central_star_gravity_well").run()', 1, true),
        "R1-C: self_test must delegate central-star gravity-well checks")
    assert(not runner:find("-- Item 9: Central star gravity well tests", 1, true)
            and not runner:find("local function makeWellScene", 1, true),
        "R1-C: central-star gravity-well characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted central-star gravity-well suite must expose run()")
    assert(suite:find("local savedGC = world.galaxyContaining", 1, true)
            and suite:find("world.galaxyContaining = savedGC", 1, true)
            and suite:find("world.sunPosition = savedSP", 1, true)
            and suite:find("world.nearbyPlanets = savedNP", 1, true)
            and suite:find("world.sampleValue = savedSV", 1, true),
        "R1-C: extracted suite must retain world-function stub restoration")
    assert(suite:find("- world.starWellRadius - 10", 1, true)
            and suite:find("s.starDotAccum == 0", 1, true)
            and suite:find("s.expedition.durability == 19", 1, true)
            and suite:find("s.starWellSampled[testGalaxy.id] == true", 1, true)
            and suite:find("leaving well must reset timer", 1, true)
            and suite:find("second 10s in same galaxy must NOT award another sample", 1, true),
        "R1-C: extracted suite must retain outside, damage, sampling, reset, and once-per-galaxy contracts")
    print("  R1-C self_test central-star gravity-well extraction OK")
end

return M
