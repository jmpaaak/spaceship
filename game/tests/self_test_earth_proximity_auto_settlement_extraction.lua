local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test Earth-proximity auto-settlement extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_earth_proximity_auto_settlement.lua")

    assert(runner:find('require("game.tests.legacy_earth_proximity_auto_settlement").run()', 1, true),
        "R1-C: self_test must delegate Earth-proximity auto-settlement checks")
    assert(not runner:find("-- Item 2: Auto-settle on Earth proximity during ascending.", 1, true)
            and not runner:find("PlayScene.earthSettleRadius + 10", 1, true),
        "R1-C: Earth-proximity auto-settlement characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted Earth-proximity suite must expose run()")
    assert(suite:find('touchpressed("launch-rt", 90, 280)', 1, true)
            and suite:find("rtScene.ship.x = 0", 1, true)
            and suite:find("rtScene.ship.y = -500", 1, true)
            and suite:find("rtScene.ship.x = PlayScene.earthCenterX", 1, true)
            and suite:find("PlayScene.earthCenterY - PlayScene.earthSettleRadius + 10", 1, true)
            and suite:find('rtScene.expedition.phase == "settlement"', 1, true),
        "R1-C: extracted suite must retain launch, away, return, and settlement contracts")
    print("  R1-C self_test Earth-proximity auto-settlement extraction OK")
end

return M