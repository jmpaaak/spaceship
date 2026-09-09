local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test sample-streak extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_sample_streak.lua")

    assert(runner:find('require("game.tests.legacy_sample_streak").run()', 1, true),
        "R1-C: self_test must delegate same-hue sample-streak checks")
    assert(not runner:find("local streakRun", 1, true),
        "R1-C: same-hue sample-streak characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted sample-streak suite must expose run()")
    assert(suite:find("awarded3 == 140", 1, true),
        "R1-C: extracted suite must retain consecutive same-family multiplier coverage")
    assert(suite:find('collectSample(streakRun, 100, "nebula")', 1, true),
        "R1-C: extracted suite must retain family-switch reset coverage")
    assert(suite:find('streakRun.phase == "destroyed"', 1, true),
        "R1-C: extracted suite must retain destruction reset coverage")
    assert(suite:find("expedition.launch(streakRun)", 1, true),
        "R1-C: extracted suite must retain relaunch reset coverage")
    print("  R1-C self_test sample-streak extraction OK")
end

return M
