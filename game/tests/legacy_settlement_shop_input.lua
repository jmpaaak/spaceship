local PlayScene = require("game.scenes.play")

local M = {}

local function newScene()
    return PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
end

function M.run()
    local shopScene = newScene()
    shopScene.expedition.phase = "settlement"
    shopScene.expedition.money = shopScene.expedition.durabilityUpgradeCost + 10
    shopScene:keypressed("h")
    assert(shopScene.expedition.durabilityUpgradeLevel == 1 and shopScene.expedition.maxDurability == 4)
    assert(shopScene.expedition.money == 10)
    -- Shop cards already show values (user 2026-09-07); banner stays empty.
    assert(shopScene.message == "")
    shopScene.expedition.money = shopScene.expedition.sampleYieldUpgradeCost + 15
    shopScene:keypressed("y")
    assert(shopScene.expedition.sampleYieldUpgradeLevel == 1)
    assert(shopScene.expedition.money == 15)
    assert(shopScene.message == "")
    shopScene.expedition.money = 0
    shopScene:keypressed("y")
    assert(shopScene.expedition.sampleYieldUpgradeLevel == 1)
    assert(shopScene.message == "")
    shopScene.expedition.money = shopScene.expedition.scoutShipCost + 20
    shopScene:touchpressed("ship", 540, 670)
    assert(shopScene.expedition.ownedShips.scout and shopScene.expedition.selectedShipId == "scout")
    assert(shopScene.expedition.money == 20)
    assert(shopScene.message == "")

    local scoutHullMessageScene = newScene()
    scoutHullMessageScene.expedition.phase = "settlement"
    scoutHullMessageScene.expedition.money = scoutHullMessageScene.expedition.scoutShipCost
        + scoutHullMessageScene.expedition.durabilityUpgradeCost + 20
    scoutHullMessageScene:keypressed("v")
    assert(scoutHullMessageScene.expedition.selectedShipId == "scout")
    scoutHullMessageScene:keypressed("h")
    assert(scoutHullMessageScene.expedition.durabilityUpgradeLevel == 1
        and scoutHullMessageScene.expedition.maxDurability == 2)
    assert(scoutHullMessageScene.expedition.money == 20)
    assert(scoutHullMessageScene.message == "")

    local repeatedUpgradeMessageScene = newScene()
    repeatedUpgradeMessageScene.expedition.phase = "settlement"
    repeatedUpgradeMessageScene.expedition.money = 250
    repeatedUpgradeMessageScene:keypressed("h")
    repeatedUpgradeMessageScene:keypressed("h")
    -- durability $10 base: lv0→1 $10, lv1→2 floor(10*1.05+0.5)=$11 → balance 250-10-11=229
    assert(repeatedUpgradeMessageScene.expedition.durabilityUpgradeLevel == 2)
    assert(repeatedUpgradeMessageScene.expedition.maxDurability == 5)
    assert(repeatedUpgradeMessageScene.expedition.money == 229)
    assert(repeatedUpgradeMessageScene.message == "")

    local shortfallScene = newScene()
    shortfallScene.expedition.phase = "settlement"
    shortfallScene.expedition.money = 3
    shortfallScene:keypressed("h")
    assert(shortfallScene.expedition.durabilityUpgradeLevel == 0)
    assert(shortfallScene.message == "")
    shortfallScene:touchpressed("ship", 540, 670)
    assert(not shortfallScene.expedition.ownedShips.scout)
    assert(shortfallScene.message == "")
end

return M