local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test collision-shake extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_collision_shake.lua")

    assert(runner:find('require("game.tests.legacy_collision_shake").run()', 1, true),
        "R1-C: self_test must delegate collision-shake checks to the legacy suite")
    assert(not runner:find("Collision impact should trigger", 1, true),
        "R1-C: collision-shake test body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted collision-shake suite must expose run()")
    print("  R1-C self_test collision-shake extraction OK")
end

return M