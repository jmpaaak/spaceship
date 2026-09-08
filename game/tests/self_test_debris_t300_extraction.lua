local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test debris-t300 extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_debris_t300.lua")

    assert(runner:find('require("game.tests.legacy_debris_t300").run()', 1, true),
        "R1-C: self_test must delegate debris-at-t300 checks")
    assert(not runner:find("-- INBOX 61(13): debris at t=300 must still appear near origin", 1, true)
            and not runner:find('"INBOX 61(13): debris must still exist near origin at t=300"', 1, true),
        "R1-C: debris-at-t300 characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted debris-at-t300 suite must expose run()")
    assert(suite:find("world.nearbyDebris(0, 0, 4, 300)", 1, true)
            and suite:find("assert(#pieces > 0", 1, true)
            and suite:find("assert(d.radius >= 3", 1, true),
        "R1-C: extracted suite must retain nearby debris and minimum radius contracts")
    print("  R1-C self_test debris-t300 extraction OK")
end

return M
