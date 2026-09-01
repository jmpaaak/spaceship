local viewport = require("game.viewport")
local shipModule = require("game.ship")
local world = require("game.world")
local expedition = require("game.expedition")
local bestAltitudeStore = require("game.best_altitude_store")
local PlayScene = require("game.scenes.play")
local M = {}

function M.run()
    assert(viewport.width == 180 and viewport.height == 320)
    local scale, x, y = viewport.fit(720, 1280, false)
    assert(scale == 4 and x == 0 and y == 0)
    local gx, gy, inside = viewport.toGame(360, 640, 720, 1280, false)
    assert(gx == 90 and gy == 160 and inside)

    local ship = shipModule.new()
    shipModule.update(ship, 1, { thrust = true })
    assert(ship.y < 0 and ship.fuel < 100)
    local before = ship.angle
    shipModule.update(ship, 1, { right = true })
    assert(ship.angle > before)

    local a = world.planets(7, -3)
    local b = world.planets(7, -3)
    assert(#a == #b)
    for i = 1, #a do
        assert(a[i].id == b[i].id and a[i].x == b[i].x and a[i].y == b[i].y)
    end
    local sx, sy = world.sectorAt(-1, -193)
    assert(sx == -1 and sy == -2)
    assert(world.sampleValue({ y = -500 }) > world.sampleValue({ y = -50 }))
    assert(world.collisionDamage({ y = -499 }) == 1)
    assert(world.collisionDamage({ y = -500 }) == 2)
    assert(world.collisionDamage({ y = -1500 }) == 4)

    local riskScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    riskScene.expedition.phase = "ascending"
    riskScene.expedition.altitude = 500
    riskScene.expedition.durability = 3
    local warning = riskScene:collisionRisk({ y = -500 })
    assert(warning.damage == 2 and not warning.lethal and warning.label == "RISK -2")
    assert(warning.sampleValue == 35 and warning.sampleLabel == "SAMPLE $35")
    local lethalWarning = riskScene:collisionRisk({ y = -1000 })
    assert(lethalWarning.damage == 3 and lethalWarning.lethal and lethalWarning.label == "LETHAL -3")
    assert(lethalWarning.sampleValue == 60 and lethalWarning.sampleLabel == "SAMPLE $60")
    riskScene.expedition.phase = "returning"
    assert(riskScene:collisionRisk({ y = -500 }) == nil)
    riskScene.expedition.altitude = 725
    riskScene.expedition.returnDistance = 1000
    riskScene.expedition.returnSpeed = 45
    riskScene.expedition.sampleCount = 3
    riskScene.expedition.pendingSampleValue = 95
    local returningHud = riskScene:hudLines()
    assert(returningHud.samples == "SAMPLES 03  AT RISK $95")
    assert(returningHud.earth == "EARTH IN 725")
    assert(returningHud.returnProgress == "RETURN 28%  17s LEFT")
    riskScene.expedition.altitude = 250
    assert(riskScene:hudLines().returnProgress == "RETURN 75%  6s LEFT")
    riskScene.expedition.phase = "ascending"
    local ascendingHud = riskScene:hudLines()
    assert(ascendingHud.samples == "SAMPLES 03  AT RISK $95")
    assert(ascendingHud.earth == nil)
    assert(ascendingHud.returnProgress == nil)
    riskScene.expedition.altitude = 500
    local nearbyPlanets = world.nearbyPlanets
    world.nearbyPlanets = function()
        return { { id = "risk-test", x = 0, y = -500, radius = 7 } }
    end
    riskScene:update(0)
    world.nearbyPlanets = nearbyPlanets
    assert(riskScene.expedition.durability == 1)
    assert(riskScene.message == "COLLISION -2  HULL 1/3")

    local basicSlotRolls = { 1, 2, 3, 2, 3, 1 }
    local nextBasicSlotRoll = 0
    local run = expedition.new({
        fuel = 2,
        fuelBurnRate = 1,
        climbSpeed = 60,
        returnSpeed = 50,
        slotDistance = 100,
        slotRandom = function()
            nextBasicSlotRoll = nextBasicSlotRoll + 1
            return basicSlotRolls[nextBasicSlotRoll]
        end,
    })
    assert(run.phase == "launch" and run.altitude == 0 and run.slotOpportunities == 0)
    assert(expedition.launch(run) and run.phase == "ascending")
    expedition.update(run, 1)
    assert(run.phase == "ascending" and run.fuel == 1 and run.altitude == 60)
    assert(expedition.collectSample(run, 75))
    assert(run.sampleCount == 1 and run.pendingSampleValue == 75 and run.money == 0)
    expedition.update(run, 1)
    assert(run.phase == "returning" and run.fuel == 0 and run.altitude == 120)
    assert(run.maxAltitude == 120 and run.returnDistance == 120 and run.slotOpportunities == 2)
    assert(expedition.useSlot(run) and run.slotOpportunities == 1 and run.slotSpins == 1)
    assert(expedition.useSlot(run) and run.slotOpportunities == 0 and run.slotSpins == 2)
    assert(not expedition.useSlot(run) and run.slotOpportunities == 0 and run.slotSpins == 2)
    expedition.update(run, 1)
    assert(run.phase == "returning" and run.altitude == 70)
    expedition.update(run, 2)
    assert(run.phase == "settlement" and run.altitude == 0)
    assert(run.money == 85 and run.lastSettlement == 85)
    assert(run.lastSampleSettlement == 75 and run.lastSlotSettlement == 10)
    assert(run.sampleCount == 0 and run.pendingSampleValue == 0 and run.pendingSlotReward == 0)
    expedition.update(run, 1)
    assert(run.money == 85 and run.lastSettlement == 85)
    assert(run.lastSampleSettlement == 75 and run.lastSlotSettlement == 10)

    local slotRolls = { 3, 3, 3, 1, 1, 2, 3, 3, 3 }
    local nextSlotRoll = 0
    local slotRun = expedition.new({
        returnSpeed = 100,
        slotRandom = function()
            nextSlotRoll = nextSlotRoll + 1
            return slotRolls[nextSlotRoll]
        end,
    })
    slotRun.phase = "returning"
    slotRun.altitude = 10
    slotRun.slotOpportunities = 2
    slotRun.pendingSampleValue = 40
    assert(expedition.useSlot(slotRun))
    assert(table.concat(slotRun.lastSlotSymbols, "-") == "STAR-STAR-STAR")
    assert(slotRun.lastSlotReward == 75 and slotRun.pendingSlotReward == 75)
    assert(expedition.useSlot(slotRun))
    assert(table.concat(slotRun.lastSlotSymbols, "-") == "COMET-COMET-PLANET")
    assert(slotRun.lastSlotReward == 15 and slotRun.pendingSlotReward == 90)
    expedition.update(slotRun, 1)
    assert(slotRun.phase == "settlement" and slotRun.money == 130 and slotRun.lastSettlement == 130)
    assert(slotRun.lastSampleSettlement == 40 and slotRun.lastSlotSettlement == 90)
    assert(slotRun.pendingSlotReward == 0 and slotRun.lastSlotReward == 15)
    assert(expedition.launch(slotRun))
    assert(slotRun.lastSampleSettlement == 0 and slotRun.lastSlotSettlement == 0)
    slotRun.phase = "returning"
    slotRun.slotOpportunities = 1
    assert(expedition.useSlot(slotRun) and slotRun.pendingSlotReward == 75)
    assert(expedition.damage(slotRun, slotRun.durability))
    assert(slotRun.phase == "destroyed" and slotRun.money == 0 and slotRun.pendingSlotReward == 0)
    assert(slotRun.lastSampleSettlement == 0 and slotRun.lastSlotSettlement == 0)
    assert(slotRun.lastSlotSymbols == nil and slotRun.lastSlotReward == 0)

    local shopRun = expedition.new({
        fuel = 10,
        fuelUpgradeAmount = 5,
        fuelUpgradeCost = 50,
        money = 75,
    })
    assert(not expedition.buyFuelUpgrade(shopRun))
    shopRun.phase = "settlement"
    assert(expedition.buyFuelUpgrade(shopRun))
    assert(shopRun.money == 25 and shopRun.fuelUpgradeLevel == 1 and shopRun.maxFuel == 15)
    assert(not expedition.buyFuelUpgrade(shopRun))
    shopRun.maxAltitude = 120
    assert(expedition.launch(shopRun) and shopRun.phase == "ascending")
    assert(shopRun.fuel == 15 and shopRun.altitude == 0 and shopRun.maxAltitude == 0 and shopRun.lastSettlement == 0)

    local hullShopRun = expedition.new({
        durability = 2,
        durabilityUpgradeCost = 60,
        money = 85,
    })
    assert(not expedition.buyDurabilityUpgrade(hullShopRun))
    hullShopRun.phase = "settlement"
    assert(expedition.buyDurabilityUpgrade(hullShopRun))
    assert(hullShopRun.money == 25 and hullShopRun.durabilityUpgradeLevel == 1 and hullShopRun.maxDurability == 3)
    assert(not expedition.buyDurabilityUpgrade(hullShopRun))
    assert(expedition.launch(hullShopRun) and hullShopRun.phase == "ascending")
    assert(hullShopRun.durability == 3)

    local shipShopRun = expedition.new({
        fuel = 10,
        durability = 3,
        scoutShipCost = 90,
        scoutFuelBonus = 5,
        scoutDurabilityBonus = -1,
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
    assert(shipShopRun.maxFuel == 15 and shipShopRun.maxDurability == 2)
    assert(expedition.launch(shipShopRun) and shipShopRun.fuel == 15 and shipShopRun.durability == 2)
    assert(not expedition.damage(shipShopRun, 1))
    assert(expedition.damage(shipShopRun, 1))
    assert(shipShopRun.phase == "destroyed")
    assert(shipShopRun.selectedShipId == "starter" and shipShopRun.ownedShips.starter)
    assert(not shipShopRun.ownedShips.scout)
    assert(shipShopRun.maxFuel == 10 and shipShopRun.maxDurability == 3)

    local shopScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    shopScene.expedition.phase = "settlement"
    shopScene.expedition.money = shopScene.expedition.fuelUpgradeCost + 30
    shopScene:keypressed("f")
    assert(shopScene.expedition.fuelUpgradeLevel == 1 and shopScene.expedition.maxFuel == 120)
    assert(shopScene.expedition.money == 30)
    assert(shopScene.message == "FUEL TANK UPGRADED  MAX 120  NO-HIT 720  SLOTS 8  BALANCE $30")
    shopScene.expedition.money = shopScene.expedition.durabilityUpgradeCost + 10
    shopScene:keypressed("h")
    assert(shopScene.expedition.durabilityUpgradeLevel == 1 and shopScene.expedition.maxDurability == 4)
    assert(shopScene.expedition.money == 10)
    assert(shopScene.message == "HULL UPGRADED  MAX 4  BALANCE $10")
    shopScene.expedition.money = shopScene.expedition.scoutShipCost + 20
    shopScene:touchpressed("ship", 90, 244)
    assert(shopScene.expedition.ownedShips.scout and shopScene.expedition.selectedShipId == "scout")
    assert(shopScene.expedition.money == 20)
    assert(shopScene.message
        == "SCOUT PURCHASED AND SELECTED  MAX FUEL 160  HULL 3  NO-HIT 960  SLOTS 10  BALANCE $20")

    local scoutFuelMessageScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    scoutFuelMessageScene.expedition.phase = "settlement"
    scoutFuelMessageScene.expedition.money = scoutFuelMessageScene.expedition.scoutShipCost
        + scoutFuelMessageScene.expedition.fuelUpgradeCost + 20
    scoutFuelMessageScene:keypressed("v")
    assert(scoutFuelMessageScene.expedition.selectedShipId == "scout")
    scoutFuelMessageScene:keypressed("f")
    assert(scoutFuelMessageScene.expedition.fuelUpgradeLevel == 1
        and scoutFuelMessageScene.expedition.maxFuel == 160)
    assert(scoutFuelMessageScene.expedition.money == 20)
    assert(scoutFuelMessageScene.message
        == "FUEL TANK UPGRADED  MAX 160  NO-HIT 960  SLOTS 10  BALANCE $20")

    local shortfallScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    shortfallScene.expedition.phase = "settlement"
    shortfallScene.expedition.money = 20
    shortfallScene:keypressed("f")
    assert(shortfallScene.expedition.fuelUpgradeLevel == 0)
    assert(shortfallScene.message == "NEED $30 MORE FOR FUEL UPGRADE")
    shortfallScene:keypressed("h")
    assert(shortfallScene.expedition.durabilityUpgradeLevel == 0)
    assert(shortfallScene.message == "NEED $55 MORE FOR HULL UPGRADE")
    shortfallScene:touchpressed("ship", 90, 244)
    assert(not shortfallScene.expedition.ownedShips.scout)
    assert(shortfallScene.message == "NEED $105 MORE FOR SCOUT")

    local touchScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    touchScene:touchpressed("launch", 90, 280)
    assert(touchScene.expedition.phase == "ascending")
    touchScene:touchpressed("steer-left", 20, 160)
    touchScene:update(1)
    assert(touchScene.ship.x == -55)
    touchScene:touchreleased("steer-left")
    touchScene:update(1)
    assert(touchScene.ship.x == -55)
    touchScene.expedition.phase = "returning"
    touchScene.expedition.slotOpportunities = 1
    touchScene.expedition.slotRandom = function() return 3 end
    touchScene:touchpressed("slot", 90, 160)
    assert(touchScene.expedition.slotSpins == 1 and touchScene.expedition.slotOpportunities == 0)
    assert(table.concat(touchScene.expedition.lastSlotSymbols, " ") == "STAR STAR STAR")
    assert(touchScene.message == "STAR STAR STAR +$75  0 LEFT")
    local emptySlotButton = touchScene:slotButtonState()
    assert(not emptySlotButton.enabled and emptySlotButton.label == "NO SLOT CHANCES")
    touchScene:touchpressed("empty-slot", 90, 266)
    assert(touchScene.expedition.slotSpins == 1 and touchScene.expedition.slotOpportunities == 0)
    touchScene.expedition.slotOpportunities = 2
    local readySlotButton = touchScene:slotButtonState()
    assert(readySlotButton.enabled and readySlotButton.label == "TAP: SLOT SPIN  2 LEFT")
    touchScene.expedition.phase = "settlement"
    touchScene.expedition.money = touchScene.expedition.fuelUpgradeCost
        + touchScene.expedition.durabilityUpgradeCost + touchScene.expedition.scoutShipCost
    touchScene:touchpressed("fuel", 90, 186)
    touchScene:touchpressed("hull", 90, 208)
    touchScene:touchpressed("ship", 90, 244)
    assert(touchScene.expedition.fuelUpgradeLevel == 1)
    assert(touchScene.expedition.durabilityUpgradeLevel == 1)
    assert(touchScene.expedition.ownedShips.scout and touchScene.expedition.selectedShipId == "scout")
    touchScene:touchpressed("relaunch", 90, 300)
    assert(touchScene.expedition.phase == "ascending")

    local loadoutScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    local starterLoadout = loadoutScene:loadoutLines()
    assert(starterLoadout.ship == "SHIP STARTER")
    assert(starterLoadout.stats == "MAX FUEL 100  HULL 3")
    assert(starterLoadout.upgrades == "FUEL LV.0  HULL LV.0")
    assert(starterLoadout.forecast == "NO-HIT 600  SLOTS 6")
    loadoutScene.expedition.phase = "settlement"
    loadoutScene.expedition.money = loadoutScene.expedition.fuelUpgradeCost
        + loadoutScene.expedition.durabilityUpgradeCost + loadoutScene.expedition.scoutShipCost
    assert(expedition.buyFuelUpgrade(loadoutScene.expedition))
    assert(expedition.buyDurabilityUpgrade(loadoutScene.expedition))
    assert(expedition.buyShip(loadoutScene.expedition, "scout"))
    assert(expedition.selectShip(loadoutScene.expedition, "scout"))
    local upgradedLoadout = loadoutScene:loadoutLines()
    assert(upgradedLoadout.ship == "SHIP SCOUT")
    assert(upgradedLoadout.stats == "MAX FUEL 160  HULL 3")
    assert(upgradedLoadout.upgrades == "FUEL LV.1  HULL LV.1")
    assert(upgradedLoadout.forecast == "NO-HIT 960  SLOTS 10")
    assert(expedition.launch(loadoutScene.expedition))
    assert(expedition.damage(loadoutScene.expedition, loadoutScene.expedition.maxDurability))
    local resetLoadout = loadoutScene:loadoutLines()
    assert(resetLoadout.ship == "SHIP STARTER")
    assert(resetLoadout.stats == "MAX FUEL 100  HULL 3")
    assert(resetLoadout.upgrades == "FUEL LV.0  HULL LV.0")

    local nextLaunchScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    nextLaunchScene.expedition.phase = "settlement"
    local starterNextLaunch = nextLaunchScene:shopLoadoutLines()
    assert(starterNextLaunch.ship == "NEXT STARTER")
    assert(starterNextLaunch.stats == "MAX FUEL 100  HULL 3")
    assert(starterNextLaunch.forecast == "NO-HIT 600  SLOTS 6")
    assert(starterNextLaunch.scoutTradeoff == "SCOUT +40 FUEL / -1 HULL")
    assert(starterNextLaunch.shipAction == "BUY SCOUT $125")
    assert(starterNextLaunch.shipPreview == "SCOUT MAX FUEL 140  HULL 2")
    assert(starterNextLaunch.shipPreviewForecast == "NO-HIT 840  SLOTS 9")
    assert(starterNextLaunch.fuelAction == "T/F FUEL MAX 120 $50")
    assert(starterNextLaunch.fuelPreviewForecast == "NO-HIT 720  SLOTS 8")
    assert(starterNextLaunch.fuelStatus == "SHORT $50" and not starterNextLaunch.fuelAffordable)
    assert(starterNextLaunch.hullAction == "T/H HULL MAX 4 $75")
    assert(starterNextLaunch.hullStatus == "SHORT $75" and not starterNextLaunch.hullAffordable)
    assert(starterNextLaunch.shipStatus == "SHORT $125" and not starterNextLaunch.shipAffordable)
    nextLaunchScene.expedition.money = nextLaunchScene.expedition.fuelUpgradeCost
    local fuelReadyNextLaunch = nextLaunchScene:shopLoadoutLines()
    assert(fuelReadyNextLaunch.fuelStatus == "LEFT $0" and fuelReadyNextLaunch.fuelAffordable)
    assert(fuelReadyNextLaunch.hullStatus == "SHORT $25" and not fuelReadyNextLaunch.hullAffordable)
    assert(fuelReadyNextLaunch.shipStatus == "SHORT $75" and not fuelReadyNextLaunch.shipAffordable)
    nextLaunchScene.expedition.money = 200
    local balancePreviewNextLaunch = nextLaunchScene:shopLoadoutLines()
    assert(balancePreviewNextLaunch.fuelStatus == "LEFT $150" and balancePreviewNextLaunch.fuelAffordable)
    assert(balancePreviewNextLaunch.hullStatus == "LEFT $125" and balancePreviewNextLaunch.hullAffordable)
    assert(balancePreviewNextLaunch.shipStatus == "LEFT $75" and balancePreviewNextLaunch.shipAffordable)
    nextLaunchScene.expedition.money = nextLaunchScene.expedition.fuelUpgradeCost
        + nextLaunchScene.expedition.durabilityUpgradeCost + nextLaunchScene.expedition.scoutShipCost
    nextLaunchScene:keypressed("f")
    local fueledNextLaunch = nextLaunchScene:shopLoadoutLines()
    assert(fueledNextLaunch.stats == "MAX FUEL 120  HULL 3")
    assert(fueledNextLaunch.forecast == "NO-HIT 720  SLOTS 8")
    assert(fueledNextLaunch.shipPreviewForecast == "NO-HIT 960  SLOTS 10")
    assert(fueledNextLaunch.fuelPreviewForecast == "NO-HIT 840  SLOTS 9")
    nextLaunchScene:keypressed("h")
    local reinforcedNextLaunch = nextLaunchScene:shopLoadoutLines()
    assert(reinforcedNextLaunch.stats == "MAX FUEL 120  HULL 4")
    assert(reinforcedNextLaunch.shipPreview == "SCOUT MAX FUEL 160  HULL 3")
    nextLaunchScene:keypressed("v")
    local scoutNextLaunch = nextLaunchScene:shopLoadoutLines()
    assert(scoutNextLaunch.ship == "NEXT SCOUT")
    assert(scoutNextLaunch.stats == "MAX FUEL 160  HULL 3")
    assert(scoutNextLaunch.forecast == "NO-HIT 960  SLOTS 10")
    assert(scoutNextLaunch.shipPreviewForecast == "NO-HIT 720  SLOTS 8")
    assert(scoutNextLaunch.fuelAction == "T/F FUEL MAX 180 $50")
    assert(scoutNextLaunch.fuelPreviewForecast == "NO-HIT 1080  SLOTS 11")
    assert(scoutNextLaunch.hullAction == "T/H HULL MAX 4 $75")
    assert(scoutNextLaunch.scoutTradeoff == "SCOUT +40 FUEL / -1 HULL")
    assert(scoutNextLaunch.shipAction == "SELECT STARTER")
    assert(scoutNextLaunch.shipStatus == "OWNED" and scoutNextLaunch.shipAffordable)
    nextLaunchScene:keypressed("v")
    local reselectedNextLaunch = nextLaunchScene:shopLoadoutLines()
    assert(reselectedNextLaunch.ship == "NEXT STARTER")
    assert(reselectedNextLaunch.stats == "MAX FUEL 120  HULL 4")
    assert(reselectedNextLaunch.fuelPreviewForecast == "NO-HIT 840  SLOTS 9")
    assert(reselectedNextLaunch.shipAction == "SELECT SCOUT")
    assert(nextLaunchScene.message
        == "STARTER SELECTED  MAX FUEL 120  HULL 4  NO-HIT 720  SLOTS 8")
    nextLaunchScene:touchpressed("ship", 90, 244)
    assert(nextLaunchScene.expedition.selectedShipId == "scout")
    assert(nextLaunchScene.message
        == "SCOUT SELECTED  MAX FUEL 160  HULL 3  NO-HIT 960  SLOTS 10")
    assert(nextLaunchScene:shopLoadoutLines().shipAction == "SELECT STARTER")

    local destroyedRun = expedition.new({
        fuel = 10,
        durability = 2,
        fuelBurnRate = 1,
        climbSpeed = 80,
        fuelUpgradeAmount = 5,
        fuelUpgradeCost = 50,
        durabilityUpgradeCost = 40,
        money = 140,
    })
    destroyedRun.phase = "settlement"
    assert(expedition.buyFuelUpgrade(destroyedRun))
    assert(expedition.buyDurabilityUpgrade(destroyedRun))
    assert(expedition.launch(destroyedRun))
    expedition.update(destroyedRun, 1)
    assert(expedition.collectSample(destroyedRun, 70))
    assert(not expedition.damage(destroyedRun, 1))
    assert(destroyedRun.durability == 2 and destroyedRun.phase == "ascending")
    assert(not expedition.damage(destroyedRun, 1))
    assert(destroyedRun.durability == 1 and destroyedRun.phase == "ascending")
    assert(expedition.damage(destroyedRun, 1))
    assert(destroyedRun.phase == "destroyed" and destroyedRun.durability == 0)
    assert(destroyedRun.money == 0 and destroyedRun.sampleCount == 0 and destroyedRun.pendingSampleValue == 0)
    assert(destroyedRun.fuelUpgradeLevel == 0 and destroyedRun.maxFuel == destroyedRun.baseFuel)
    assert(destroyedRun.durabilityUpgradeLevel == 0 and destroyedRun.maxDurability == destroyedRun.baseDurability)
    assert(destroyedRun.bestAltitude == 80)
    assert(expedition.launch(destroyedRun) and destroyedRun.phase == "ascending")
    assert(destroyedRun.altitude == 0 and destroyedRun.durability == destroyedRun.maxDurability)
    assert(destroyedRun.bestAltitude == 80)

    local testSave = "self-test-best-altitude.txt"
    love.filesystem.remove(testSave)
    local altitudeStore = bestAltitudeStore.new(testSave)
    assert(altitudeStore:load() == 0)
    assert(altitudeStore:save(125.5))
    local restartedStore = bestAltitudeStore.new(testSave)
    assert(restartedStore:load() == 125.5)
    assert(not restartedStore:save(80))
    assert(bestAltitudeStore.new(testSave):load() == 125.5)

    local persistedRun = expedition.new({ bestAltitude = restartedStore:load(), money = 100 })
    persistedRun.phase = "ascending"
    persistedRun.durability = 1
    assert(expedition.damage(persistedRun, 1))
    assert(persistedRun.money == 0 and persistedRun.bestAltitude == 125.5)
    assert(bestAltitudeStore.new(testSave):load() == 125.5)
    assert(love.filesystem.remove(testSave))

    local savedBest = 40
    local fakeStore = {
        load = function() return savedBest end,
        save = function(_, altitude)
            if altitude <= savedBest then return false end
            savedBest = altitude
            return true
        end,
    }
    local persistedScene = PlayScene.new({ bestAltitudeStore = fakeStore })
    assert(persistedScene.expedition.bestAltitude == 40)
    assert(persistedScene:hudLines().best == "PERSONAL BEST 0040")
    persistedScene.expedition.phase = "settlement"
    assert(persistedScene:hudLines().best == "PERSONAL BEST 0040")
    persistedScene.expedition.phase = "launch"
    persistedScene.expedition.fuel = 1
    persistedScene.expedition.maxFuel = 1
    persistedScene.expedition.fuelBurnRate = 1
    persistedScene.expedition.climbSpeed = 60
    assert(expedition.launch(persistedScene.expedition))
    persistedScene:update(1)
    assert(persistedScene.expedition.phase == "returning" and savedBest == 60)
    local restartedScene = PlayScene.new({ bestAltitudeStore = fakeStore })
    assert(restartedScene.expedition.bestAltitude == 60)
    assert(restartedScene:hudLines().best == "PERSONAL BEST 0060")
    print("SPACESHIP_UNIT_OK")
end

return M
