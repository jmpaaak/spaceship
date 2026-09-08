local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test collision feedback extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_collision_feedback.lua")

    assert(runner:find('require("game.tests.legacy_collision_feedback").run(riskScene)', 1, true),
        "R1-C: self_test must delegate collision feedback checks with the configured risk scene")
    assert(not runner:find("collision message must be empty (removed) or legacy format", 1, true),
        "R1-C: collision feedback and destruction characterization bodies must leave self_test")
    assert(suite:find("function M.run(riskScene)", 1, true),
        "R1-C: extracted collision feedback suite must accept the configured risk scene")
    assert(suite:find("SHIP DESTROYED  BEST 750  META RESET", 1, true),
        "R1-C: extracted suite must retain the destruction/meta-wipe contract")
    print("  R1-C self_test collision feedback extraction OK")
end

return M