local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test destruction-persistence extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_destruction_persistence.lua")

    assert(runner:find('require("game.tests.legacy_destruction_persistence").run()', 1, true),
        "R1-C: self_test must delegate destruction and persistence checks")
    assert(not runner:find("local destroyedRun", 1, true)
            and not runner:find('local testSave = "self-test-best-altitude.txt"', 1, true),
        "R1-C: destruction and persistence characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted destruction-persistence suite must expose run()")
    assert(suite:find("destroyedRun.lastLostSampleCount == 1", 1, true)
            and suite:find("destroyedRun.lastLostNewBest == false", 1, true),
        "R1-C: extracted suite must retain lost-run telemetry and relaunch reset coverage")
    assert(suite:find("restartedStore:load() == 125.5", 1, true)
            and suite:find("persistedRun.money == 0 and persistedRun.bestAltitude == 125.5", 1, true),
        "R1-C: extracted suite must retain best-altitude round-trip and destruction coverage")
    print("  R1-C self_test destruction-persistence extraction OK")
end

return M