local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test stellar synergy extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_stellar_synergies.lua")

    assert(runner:find('require("game.tests.legacy_stellar_synergies").run()', 1, true),
        "R1-C: self_test must delegate stellar synergy checks to the legacy suite")
    assert(not runner:find("testStellarSynergies", 1, true),
        "R1-C: stellar synergy test bodies must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted stellar synergy suite must expose run()")
    print("  R1-C self_test stellar synergy extraction OK")
end

return M