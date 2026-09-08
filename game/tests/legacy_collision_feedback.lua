local expedition = require("game.expedition")
local PlayScene = require("game.scenes.play")
local world = require("game.world")

local M = {}

function M.run(riskScene)
    riskScene.expedition.altitude = 500
    riskScene.ship.y = -500
    local nearbyPlanets = world.nearbyPlanets
    world.nearbyPlanets = function()
        return { { id = "risk-test", x = 0, y = -500, radius = 7 } }
    end
    assert(#riskScene.floatingTexts == 0)
    riskScene:update(0)
    world.nearbyPlanets = nearbyPlanets
    assert(riskScene.expedition.durability == 2)
    assert(riskScene.message == "" or riskScene.message == "COLLISION -1  HULL 2/3",
        "collision message must be empty (removed) or legacy format")
    local damageFloatingText
    for _, ft in ipairs(riskScene.floatingTexts) do
        if ft.kind == "damage" then damageFloatingText = ft end
    end
    assert(damageFloatingText)
    assert(damageFloatingText.text == "-1")
    -- Offset from ship.x (see play.lua's collision handling) so the damage
    -- text never renders stacked on top of a same-frame sample text.
    assert(damageFloatingText.x == riskScene.ship.x + 60)
    assert(damageFloatingText.y == riskScene.ship.y)

    assert(PlayScene.clampLabelX(90, 92, 180) == 44)
    assert(PlayScene.clampLabelX(178, 92, 180) == 86)
    assert(PlayScene.clampLabelX(2, 92, 180) == 2)
    assert(PlayScene.clampLabelX(90, 44, 180) == 68)

    local returnCollisionScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 750 end, save = function() return false end },
    })
    returnCollisionScene.expedition.phase = "settlement"
    returnCollisionScene.expedition.money = returnCollisionScene.expedition.durabilityUpgradeCost
        + returnCollisionScene.expedition.scoutShipCost + 25
    assert(expedition.buyDurabilityUpgrade(returnCollisionScene.expedition))
    assert(expedition.buyShip(returnCollisionScene.expedition, "scout"))
    assert(expedition.selectShip(returnCollisionScene.expedition, "scout"))
    assert(expedition.launch(returnCollisionScene.expedition))
    returnCollisionScene.expedition.phase = "ascending"
    returnCollisionScene.expedition.altitude = 500
    returnCollisionScene.expedition.returnDistance = 500
    returnCollisionScene.expedition.durability = 1
    returnCollisionScene.expedition.sampleCount = 2
    returnCollisionScene.expedition.pendingSampleValue = 80
    returnCollisionScene.ship.y = -500
    nearbyPlanets = world.nearbyPlanets
    world.nearbyPlanets = function()
        return { { id = "return-collision", x = 0, y = -500, radius = 7 } }
    end
    returnCollisionScene:update(0)
    world.nearbyPlanets = nearbyPlanets
    local wipedReturn = returnCollisionScene.expedition
    assert(wipedReturn.phase == "destroyed" and wipedReturn.durability == 0)
    assert(wipedReturn.money == 0 and wipedReturn.sampleCount == 0
        and wipedReturn.pendingSampleValue == 0)
    assert(wipedReturn.durabilityUpgradeLevel == 0)
    assert(wipedReturn.selectedShipId == "starter" and not wipedReturn.ownedShips.scout)
    assert(wipedReturn.bestAltitude == 750)
    print("MSG: ", tostring(returnCollisionScene.message))
    assert(returnCollisionScene.message == "SHIP DESTROYED  BEST 750  META RESET")
    assert(wipedReturn.lastLostSampleCount == 3 and wipedReturn.lastLostSampleValue == 81)
    assert(expedition.launch(wipedReturn))
    assert(wipedReturn.lastLostSampleCount == 0 and wipedReturn.lastLostSampleValue == 0)

    local hubCollisionScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    hubCollisionScene.expedition.phase = "ascending"
    hubCollisionScene.expedition.durability = 2
    hubCollisionScene.ship.y = -500
    nearbyPlanets = world.nearbyPlanets
    world.nearbyPlanets = function()
        return { { id = "hub-test", x = 0, y = -500, radius = 7, hub = true, galaxyId = "galaxy-test" } }
    end
    hubCollisionScene:update(0)
    world.nearbyPlanets = nearbyPlanets
    assert(hubCollisionScene.expedition.durability == 2, "hub planet must not deal collision damage")
    assert(not hubCollisionScene.collided["hub-test"], "hub planet must not be marked as collided")

    local shopCollisionScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    shopCollisionScene.expedition.phase = "ascending"
    shopCollisionScene.expedition.durability = 2
    shopCollisionScene.ship.y = -500
    nearbyPlanets = world.nearbyPlanets
    world.nearbyPlanets = function()
        return { { id = "shop-test", x = 0, y = -500, radius = 7, isShop = true, galaxyId = "galaxy-test" } }
    end
    shopCollisionScene:update(0)
    world.nearbyPlanets = nearbyPlanets
    assert(shopCollisionScene.expedition.durability == 2, "shop planet must not deal collision damage")
    assert(not shopCollisionScene.collided["shop-test"], "shop planet must not be marked as collided")
end

return M