local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test touch-flight-settlement extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_touch_flight_settlement.lua")

    assert(runner:find('require("game.tests.legacy_touch_flight_settlement").run()', 1, true),
        "R1-C: self_test must delegate touch flight and settlement checks")
    assert(not runner:find("local touchScene", 1, true),
        "R1-C: touch flight and settlement characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted touch flight and settlement suite must expose run()")
    assert(suite:find('touchScene:touchpressed("launch", 90, 280)', 1, true)
            and suite:find('touchScene:touchpressed("steer-left", 20, 160)', 1, true)
            and suite:find('touchScene:touchreleased("steer-right")', 1, true),
        "R1-C: extracted suite must retain launch and held-steering coverage")
    assert(suite:find("touchScene.ship.x - (-60)", 1, true)
            and suite:find("touchScene.ship.x > xBeforeRight", 1, true),
        "R1-C: extracted suite must retain left/right movement assertions")
    assert(suite:find('touchScene:touchpressed("hull", 180, 500)', 1, true)
            and suite:find('touchScene:touchpressed("ship", 540, 670)', 1, true)
            and suite:find('touchScene:touchpressed("relaunch"', 1, true),
        "R1-C: extracted suite must retain settlement purchase and relaunch coverage")
    print("  R1-C self_test touch-flight-settlement extraction OK")
end

return M