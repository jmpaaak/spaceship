local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test rim-marker styling extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_rim_marker_styling.lua")

    assert(runner:find('require("game.tests.legacy_rim_marker_styling").run()', 1, true),
        "R1-C: self_test must delegate rim-marker styling checks")
    assert(not runner:find("-- INBOX 61(9): second galaxy rim marker", 1, true)
            and not runner:find("local c1 = PlayScene.rimMarker1Color", 1, true),
        "R1-C: rim-marker styling characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted rim-marker styling suite must expose run()")
    assert(suite:find("c1[1] == c2[1]", 1, true)
            and suite:find("c2[4] >= 0.4 and c2[4] <= 0.5", 1, true)
            and suite:find("PlayScene.rimMarker2Radius < PlayScene.rimMarker1Radius", 1, true),
        "R1-C: extracted suite must retain shared RGB, secondary alpha, and radius contracts")
    print("  R1-C self_test rim-marker styling extraction OK")
end

return M
