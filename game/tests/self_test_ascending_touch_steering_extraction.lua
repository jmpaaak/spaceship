local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test ascending touch steering extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_ascending_touch_steering.lua")

    assert(runner:find('require("game.tests.legacy_ascending_touch_steering").run()', 1, true),
        "R1-C: self_test must delegate ascending touch steering checks")
    assert(not runner:find('ascendEdgeScene:touchpressed("ascend-edge-left"', 1, true)
            and not runner:find('ascendEdgeScene:touchpressed("ascend-edge-right"', 1, true),
        "R1-C: ascending touch steering characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted ascending touch steering suite must expose run()")
    assert(suite:find('touchpressed("ascend-edge-left", 20, ascendControls.top)', 1, true)
            and suite:find("leftActive and not ascendEdgeLeftSteering.rightActive", 1, true),
        "R1-C: extracted suite must retain left-half activation at the top edge")
    assert(suite:find('touchreleased("ascend-edge-left")', 1, true)
            and suite:find('touchreleased("ascend-edge-right")', 1, true),
        "R1-C: extracted suite must retain touch release behavior")
    assert(suite:find('touchpressed("ascend-edge-right", 500, ascendControls.bottom - 1)', 1, true)
            and suite:find("not ascendEdgeRightSteering.leftActive and ascendEdgeRightSteering.rightActive", 1, true),
        "R1-C: extracted suite must retain right-half activation at the bottom edge")
    print("  R1-C self_test ascending touch steering extraction OK")
end

return M
