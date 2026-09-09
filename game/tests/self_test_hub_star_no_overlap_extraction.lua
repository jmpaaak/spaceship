local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test hub-star-no-overlap extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_hub_star_no_overlap.lua")

    assert(runner:find('require("game.tests.legacy_hub_star_no_overlap").run()', 1, true),
        "R1-C: self_test must delegate hub-star-no-overlap checks")
    assert(not runner:find("-- INBOX 61(33): hub planet must never overlap", 1, true)
            and not runner:find("for gx = -10, 10 do", 1, true),
        "R1-C: hub-star-no-overlap body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted hub-star-no-overlap suite must expose run()")
    assert(suite:find("for gx = -10, 10 do", 1, true)
            and suite:find("for gy = -10, 10 do", 1, true)
            and suite:find("world.starRadius + hub.radius + 40", 1, true)
            and suite:find("assert(checked >= 3", 1, true),
        "R1-C: extracted suite must retain the 21x21 scan, safe distance, and checked-count guard")
    print("  R1-C self_test hub-star-no-overlap extraction OK")
end

return M