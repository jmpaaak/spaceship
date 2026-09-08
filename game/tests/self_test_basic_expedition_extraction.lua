local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test basic expedition extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_basic_expedition.lua")

    assert(runner:find('require("game.tests.legacy_basic_expedition").run()', 1, true),
        "R1-C: self_test must delegate basic launch/settlement/best-altitude checks")
    assert(not runner:find("local basicSlotRolls", 1, true),
        "R1-C: basic expedition characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted basic expedition suite must expose run()")
    assert(suite:find("assert(run.lastNewBest == true)", 1, true),
        "R1-C: extracted suite must retain new-best settlement coverage")
    assert(suite:find("assert(lowerRun.bestAltitude == 500)", 1, true),
        "R1-C: extracted suite must retain existing-best preservation coverage")
    print("  R1-C self_test basic expedition extraction OK")
end

return M