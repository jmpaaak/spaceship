local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test shop-loadout-lines extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_shop_loadout_lines.lua")

    assert(runner:find('require("game.tests.legacy_shop_loadout_lines").run()', 1, true),
        "R1-C: self_test must delegate shop-loadout-lines checks")
    assert(not runner:find("local nextLaunchScene", 1, true),
        "R1-C: shop-loadout-lines characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted shop-loadout-lines suite must expose run()")
    assert(suite:find('starterNextLaunch.shipAction == "BUY SCOUT $125"', 1, true)
            and suite:find('starterNextLaunch.hullActionCompact == "HULL 3 -> 4 $10"', 1, true)
            and suite:find('balancePreviewNextLaunch.shipAffordable', 1, true),
        "R1-C: extracted suite must retain starter prices, compact labels, and affordability coverage")
    assert(suite:find('reinforcedNextLaunch.upgrades == "HULL LV.1"', 1, true)
            and suite:find('scoutNextLaunch.ship == "NEXT SCOUT"', 1, true)
            and suite:find('scoutNextLaunch.shipHidden == true', 1, true),
        "R1-C: extracted suite must retain upgrade, scout preview, and active-ship hiding coverage")
    print("  R1-C self_test shop-loadout-lines extraction OK")
end

return M