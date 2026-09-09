local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test slot-distance-scaling extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_slot_distance_scaling.lua")

    assert(runner:find('require("game.tests.legacy_slot_distance_scaling").run()', 1, true),
        "R1-C: self_test must delegate slot-distance-scaling checks")
    assert(not runner:find("-- INBOX 61(25): slot cost/rewards scale with galaxy distance", 1, true)
            and not runner:find('local farId = "galaxy:1:0"', 1, true),
        "R1-C: slot-distance-scaling body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted slot-distance-scaling suite must expose run()")
    assert(suite:find("exp.slotTier(run, nil) == 1", 1, true)
            and suite:find('local farId = "galaxy:1:0"', 1, true)
            and suite:find("run.lastVisitedGalaxyId = farId", 1, true),
        "R1-C: extracted suite must retain Earth, tier-2, and fallback galaxy fixtures")
    print("  R1-C self_test slot-distance-scaling extraction OK")
end

return M