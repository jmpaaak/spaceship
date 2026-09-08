local expedition = require("game.expedition")
local PlayScene = require("game.scenes.play")

local M = {}

function M.run()
    local loadoutScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    local starterLoadout = loadoutScene:loadoutLines()
    -- The ship-name line is dead weight while only the default STARTER hull
    -- is owned. It becomes meaningful only after a second ship is owned.
    assert(starterLoadout.ship == nil,
        "loadout ship line should be hidden while only STARTER is owned")
    assert(starterLoadout.stats == "HULL 3")
    assert(starterLoadout.upgrades == "HULL LV.0")
    assert(starterLoadout.steering == "60")

    loadoutScene.expedition.phase = "settlement"
    loadoutScene.expedition.money = loadoutScene.expedition.durabilityUpgradeCost
        + loadoutScene.expedition.scoutShipCost
        + loadoutScene.expedition.steeringUpgradeCost
    assert(expedition.buyDurabilityUpgrade(loadoutScene.expedition))
    assert(expedition.buyShip(loadoutScene.expedition, "scout"))
    assert(expedition.selectShip(loadoutScene.expedition, "scout"))
    assert(expedition.buySteeringUpgrade(loadoutScene.expedition))

    local upgradedLoadout = loadoutScene:loadoutLines()
    assert(upgradedLoadout.ship == "SHIP SCOUT")
    assert(upgradedLoadout.stats == "HULL 2")
    assert(upgradedLoadout.upgrades == "HULL LV.1")
    assert(upgradedLoadout.steering == "181")

    assert(expedition.launch(loadoutScene.expedition))
    assert(expedition.damage(loadoutScene.expedition, loadoutScene.expedition.maxDurability))
    local resetLoadout = loadoutScene:loadoutLines()
    -- Destruction wipes ownedShips back to STARTER, hiding the ship line.
    assert(resetLoadout.ship == nil,
        "loadout ship line should be hidden again after a meta-wipe reset")
    assert(resetLoadout.stats == "HULL 3")
    assert(resetLoadout.upgrades == "HULL LV.0")
    assert(resetLoadout.steering == "60")
end

return M
