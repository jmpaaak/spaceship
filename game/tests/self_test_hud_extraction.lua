local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test HUD extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_hud.lua")

    assert(runner:find('require("game.tests.legacy_hud").run(riskScene)', 1, true),
        "R1-C: self_test must delegate HUD checks with the configured risk scene")
    assert(not runner:find("devPlaceholderFontSize must be removed", 1, true),
        "R1-C: HUD characterization bodies must leave self_test")
    assert(suite:find("function M.run(riskScene)", 1, true),
        "R1-C: extracted HUD suite must accept the configured risk scene")
    print("  R1-C self_test HUD extraction OK")
end

return M