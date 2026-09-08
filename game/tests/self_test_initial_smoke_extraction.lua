local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test initial-smoke extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_initial_smoke.lua")

    assert(runner:find('require("game.tests.legacy_initial_smoke").run()', 1, true),
        "R1-C: self_test must delegate initial viewport/ship/world checks to the legacy suite")
    assert(not runner:find("local scale, x, y = viewport.fit", 1, true),
        "R1-C: initial viewport/ship/world test body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted initial-smoke suite must expose run()")
    print("  R1-C self_test initial-smoke extraction OK")
end

return M