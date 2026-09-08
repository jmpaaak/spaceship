local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test ship-shop extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_ship_shop.lua")

    assert(runner:find('require("game.tests.legacy_ship_shop").run()', 1, true),
        "R1-C: self_test must delegate ship-shop checks")
    assert(not runner:find("local shipShopRun", 1, true),
        "R1-C: ship-shop characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted ship-shop suite must expose run()")
    assert(suite:find('not expedition.buyShip(shipShopRun, "scout")', 1, true),
        "R1-C: extracted suite must retain phase, funds, and duplicate-purchase gating")
    assert(suite:find('expedition.selectShip(shipShopRun, "scout")', 1, true),
        "R1-C: extracted suite must retain ship selection coverage")
    assert(suite:find("shipShopRun.maxDurability == 2", 1, true),
        "R1-C: extracted suite must retain selected-ship stat coverage")
    assert(suite:find("expedition.launch(shipShopRun) and shipShopRun.durability == 2", 1, true),
        "R1-C: extracted suite must retain launch durability coverage")
    assert(suite:find('shipShopRun.phase == "destroyed"', 1, true),
        "R1-C: extracted suite must retain destruction coverage")
    assert(suite:find("not shipShopRun.ownedShips.scout", 1, true),
        "R1-C: extracted suite must retain full-wipe coverage")
    print("  R1-C self_test ship-shop extraction OK")
end

return M
