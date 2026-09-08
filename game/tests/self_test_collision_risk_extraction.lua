local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test collision-risk extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_collision_risk.lua")

    assert(runner:find('local riskScene = require("game.tests.legacy_collision_risk").run()', 1, true),
        "R1-C: self_test must delegate collision-risk checks and retain their configured scene")
    assert(not runner:find("local warning = riskScene:collisionRisk", 1, true),
        "R1-C: collision-risk preview test body must leave self_test")
    assert(suite:find("return riskScene", 1, true),
        "R1-C: extracted collision-risk suite must return the configured scene for following HUD checks")
    print("  R1-C self_test collision-risk extraction OK")
end

return M