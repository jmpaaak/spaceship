local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test best-altitude persistence extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_best_altitude_persistence.lua")

    assert(runner:find('require("game.tests.legacy_best_altitude_persistence").run()', 1, true),
        "R1-C: self_test must delegate best-altitude persistence checks")
    assert(not runner:find("local savedBest = 40", 1, true)
            and not runner:find("persistedScene:persistBestAltitude()", 1, true),
        "R1-C: best-altitude persistence characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted best-altitude suite must expose run()")
    assert(suite:find('hudLines().best == "RECORD 40"', 1, true)
            and suite:find('hudLines().best == "RECORD 60"', 1, true),
        "R1-C: extracted suite must retain HUD record coverage before and after reload")
    assert(suite:find('phase = "settlement"', 1, true)
            and suite:find('phase = "launch"', 1, true)
            and suite:find('phase = "returning"', 1, true),
        "R1-C: extracted suite must retain launch, settlement, and returning phase coverage")
    assert(suite:find("persistedScene:persistBestAltitude()", 1, true)
            and suite:find("savedBest == 60", 1, true),
        "R1-C: extracted suite must retain injected-store save coverage")
    print("  R1-C self_test best-altitude persistence extraction OK")
end

return M