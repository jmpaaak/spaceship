local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test last-checkpoint extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_last_checkpoint.lua")

    assert(runner:find('require("game.tests.legacy_last_checkpoint").run()', 1, true),
        "R1-C: self_test must delegate last-checkpoint checks")
    assert(not runner:find("-- INBOX 61(24): Last checkpoint respawn after destruction", 1, true)
            and not runner:find("local cpX, cpY = expedition.lastCheckpointOrEarth(run2)", 1, true),
        "R1-C: last-checkpoint characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted last-checkpoint suite must expose run()")
    assert(suite:find("expedition.settle(run1)", 1, true)
            and suite:find("run2.lastHubX = 300", 1, true)
            and suite:find("expedition.damage(run2, 1)", 1, true)
            and suite:find("expedition.lastCheckpointOrEarth(run2)", 1, true)
            and suite:find("expedition.launch(run2)", 1, true),
        "R1-C: extracted suite must retain Earth, hub, destruction, fallback, and launch contracts")
    print("  R1-C self_test last-checkpoint extraction OK")
end

return M