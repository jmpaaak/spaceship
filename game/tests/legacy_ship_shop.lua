local expedition = require("game.expedition")

local M = {}

function M.run()
    local shipShopRun = expedition.new({
        durability = 3,
        scoutShipCost = 90,
        scoutClimbSpeedBonus = 5,
        money = 100,
    })
    assert(not expedition.buyShip(shipShopRun, "scout"))
    shipShopRun.phase = "settlement"
    assert(expedition.buyShip(shipShopRun, "scout"))
    assert(shipShopRun.money == 10 and shipShopRun.ownedShips.scout)
    assert(shipShopRun.selectedShipId == "starter")
    assert(not expedition.buyShip(shipShopRun, "scout") and shipShopRun.money == 10)
    assert(expedition.selectShip(shipShopRun, "scout"))
    assert(shipShopRun.selectedShipId == "scout")
    assert(shipShopRun.maxDurability == 2 and expedition.effectiveSpeed(shipShopRun) == 65)
    assert(expedition.launch(shipShopRun) and shipShopRun.durability == 2)
    assert(not expedition.damage(shipShopRun, 1))
    assert(expedition.damage(shipShopRun, 1))
    assert(shipShopRun.phase == "destroyed")
    assert(shipShopRun.selectedShipId == "starter" and shipShopRun.ownedShips.starter)
    assert(not shipShopRun.ownedShips.scout)
    assert(shipShopRun.maxDurability == 3)
end

return M
