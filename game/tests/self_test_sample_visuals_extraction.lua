local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test sample-visual extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_sample_tier_visuals.lua")

    assert(runner:find('require("game.tests.legacy_sample_tier_visuals").run()', 1, true),
        "R1-C: self_test must delegate sample-tier visual checks to the legacy suite")
    assert(not runner:find("Balatro-style visual punch-up", 1, true),
        "R1-C: sample-tier visual test body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted sample-tier visual suite must expose run()")
    print("  R1-C self_test sample-visual extraction OK")
end

return M