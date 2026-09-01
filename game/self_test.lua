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

    assert(world.sampleTier({ y = -50 }) == "common")
    assert(world.sampleTier({ y = -299 }) == "common")
    assert(world.sampleTier({ y = -300 }) == "rare")
    assert(world.sampleTier({ y = -799 }) == "rare")
    assert(world.sampleTier({ y = -800 }) == "epic")
    assert(world.sampleTier({ y = -5000 }) == "epic")

    local commonR, commonG, commonB = PlayScene.sampleTierColor("common")
    local rareR, rareG, rareB = PlayScene.sampleTierColor("rare")
    local epicR, epicG, epicB = PlayScene.sampleTierColor("epic")
    assert(commonR and commonG and commonB)
    assert(rareR and rareG and rareB)
    assert(epicR and epicG and epicB)
    assert(commonR ~= rareR or commonG ~= rareG or commonB ~= rareB)
    assert(rareR ~= epicR or rareG ~= epicG or rareB ~= epicB)

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
    -- The SAMPLE YIELD upgrade multiplies the actual money awarded by
    -- expedition.collectSample (see collectSample's `awarded` return value
    -- and its use in PlayScene's floating "+$N" text), but the RISK/SAMPLE
    -- approach-warning preview label was still built directly from
    -- world.sampleValue(planet), ignoring the multiplier. That made the
    -- preview understate the real payout once a player owned any SAMPLE
    -- YIELD level, so it must also apply expedition.sampleYieldMultiplier.
    riskScene.expedition.sampleYieldUpgradeLevel = 1
    local yieldWarning = riskScene:collisionRisk({ y = -500 })
    assert(yieldWarning.sampleValue == 44 and yieldWarning.sampleLabel == "SAMPLE $44",
        "collisionRisk sampleValue/sampleLabel must apply the SAMPLE YIELD multiplier ("
            .. tostring(yieldWarning.sampleValue) .. " " .. tostring(yieldWarning.sampleLabel) .. ")")
    riskScene.expedition.sampleYieldUpgradeLevel = 0
    riskScene.expedition.phase = "returning"
    local returningPlanet = { id = "return-warning", y = -500 }
    local returningWarning = riskScene:approachWarning(returningPlanet, 205, 185)
    assert(returningWarning.damage == 2 and not returningWarning.lethal
        and returningWarning.label == "RISK -2")
    assert(returningWarning.sampleValue == nil and returningWarning.sampleLabel == nil)
    local returningLethalWarning = riskScene:approachWarning({ y = -1000 }, 205, 185)
    assert(returningLethalWarning.damage == 3 and returningLethalWarning.lethal
        and returningLethalWarning.label == "LETHAL -3")
    assert(riskScene:approachWarning(returningPlanet, 165, 185) == nil)
    riskScene.collided[returningPlanet.id] = true
    assert(riskScene:approachWarning(returningPlanet, 205, 185) == nil)
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
    riskScene.expedition.phase = "settlement"
    assert(riskScene:hudLines().status == "F100 H3/3 SETTLE S00")
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
    assert(#riskScene.floatingTexts == 0)
    riskScene:update(0)
    world.nearbyPlanets = nearbyPlanets
    assert(riskScene.expedition.durability == 1)
    assert(riskScene.message == "COLLISION -2  HULL 1/3")
    local damageFloatingText
    for _, ft in ipairs(riskScene.floatingTexts) do
        if ft.kind == "damage" then damageFloatingText = ft end
    end
    assert(damageFloatingText)
    assert(damageFloatingText.text == "-2")
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
    returnCollisionScene.expedition.money = returnCollisionScene.expedition.fuelUpgradeCost
        + returnCollisionScene.expedition.durabilityUpgradeCost
        + returnCollisionScene.expedition.scoutShipCost + 25
    assert(expedition.buyFuelUpgrade(returnCollisionScene.expedition))
    assert(expedition.buyDurabilityUpgrade(returnCollisionScene.expedition))
    assert(expedition.buyShip(returnCollisionScene.expedition, "scout"))
    assert(expedition.selectShip(returnCollisionScene.expedition, "scout"))
    assert(expedition.launch(returnCollisionScene.expedition))
    returnCollisionScene.expedition.phase = "returning"
    returnCollisionScene.expedition.altitude = 500
    returnCollisionScene.expedition.returnDistance = 500
    returnCollisionScene.expedition.durability = 2
    returnCollisionScene.expedition.sampleCount = 2
    returnCollisionScene.expedition.pendingSampleValue = 80
    returnCollisionScene.expedition.slotOpportunities = 3
    returnCollisionScene.expedition.slotSpins = 1
    returnCollisionScene.expedition.pendingSlotReward = 75
    returnCollisionScene.expedition.lastSlotSymbols = { "STAR", "STAR", "STAR" }
    returnCollisionScene.expedition.lastSlotReward = 75
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
        and wipedReturn.pendingSampleValue == 0 and wipedReturn.pendingSlotReward == 0)
    assert(wipedReturn.slotOpportunities == 0 and wipedReturn.slotSpins == 0
        and wipedReturn.lastSlotSymbols == nil and wipedReturn.lastSlotReward == 0)
    assert(wipedReturn.fuelUpgradeLevel == 0 and wipedReturn.durabilityUpgradeLevel == 0)
    assert(wipedReturn.selectedShipId == "starter" and not wipedReturn.ownedShips.scout)
    assert(wipedReturn.bestAltitude == 750)
    assert(returnCollisionScene.message == "SHIP DESTROYED  BEST 750  META RESET")
    assert(wipedReturn.lastLostSampleCount == 2 and wipedReturn.lastLostSampleValue == 80)
    assert(wipedReturn.lastLostSlotSpinsCount == 1 and wipedReturn.lastLostSlotValue == 75)
    assert(expedition.launch(wipedReturn))
    assert(wipedReturn.lastLostSampleCount == 0 and wipedReturn.lastLostSampleValue == 0)
    assert(wipedReturn.lastLostSlotSpinsCount == 0 and wipedReturn.lastLostSlotValue == 0)

    local basicSlotRolls = { 1, 6, 10, 6, 10, 1 }
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
    assert(run.lastSampleCount == 1 and run.lastSlotSpinsCount == 2)
    assert(run.lastAltitude == 120)
    assert(run.lastNewBest == true)
    expedition.update(run, 1)
    assert(run.money == 85 and run.lastSettlement == 85)
    assert(run.lastSampleSettlement == 75 and run.lastSlotSettlement == 10)
    assert(run.lastAltitude == 120)
    assert(run.lastNewBest == true)
    assert(expedition.launch(run) and run.lastSampleCount == 0 and run.lastSlotSpinsCount == 0)
    assert(run.lastAltitude == 0)

    local lowerRun = expedition.new({ bestAltitude = 500 })
    lowerRun.phase = "returning"
    lowerRun.altitude = 5
    lowerRun.maxAltitude = 300
    lowerRun.returnSpeed = 10
    expedition.update(lowerRun, 1)
    assert(lowerRun.phase == "settlement" and lowerRun.lastAltitude == 300)
    assert(lowerRun.lastNewBest == false)
    assert(lowerRun.bestAltitude == 500)

    local slotRolls = { 10, 10, 10, 1, 1, 6, 10, 10, 10 }
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

    local yieldRun = expedition.new({
        sampleYieldUpgradeCost = 60,
        sampleYieldUpgradeAmount = 0.25,
        money = 45,
    })
    assert(not expedition.buySampleYieldUpgrade(yieldRun))
    yieldRun.phase = "settlement"
    assert(not expedition.buySampleYieldUpgrade(yieldRun))
    yieldRun.money = 60
    assert(expedition.buySampleYieldUpgrade(yieldRun))
    assert(yieldRun.money == 0 and yieldRun.sampleYieldUpgradeLevel == 1)
    assert(expedition.sampleYieldMultiplier(yieldRun) == 1.25)
    assert(expedition.launch(yieldRun) and yieldRun.phase == "ascending")
    local ok, awarded = expedition.collectSample(yieldRun, 20)
    assert(ok and awarded == 25 and yieldRun.pendingSampleValue == 25 and yieldRun.sampleCount == 1)
    assert(expedition.damage(yieldRun, yieldRun.durability))
    assert(yieldRun.phase == "destroyed" and yieldRun.sampleYieldUpgradeLevel == 0)
    assert(expedition.sampleYieldMultiplier(yieldRun) == 1)

    -- GAME_DESIGN.md's meta loop lists four upgrade axes ("연료·내구도·조종·
    -- 표본 수익을 강화": fuel, hull, steering, sample yield), but only three
    -- (fuel/hull/sample yield) existed until now. STEERING is the missing
    -- fourth axis: it scales the ship's left/right steering speed used
    -- during ascending/returning, giving players a fourth strategic EARTH
    -- SHOP purchase that improves planet-collision avoidance rather than
    -- capacity or money yield.
    local steeringRun = expedition.new({
        steeringUpgradeCost = 65,
        steeringUpgradeAmount = 15,
        money = 40,
    })
    assert(expedition.steeringSpeed(steeringRun) == 55)
    assert(not expedition.buySteeringUpgrade(steeringRun))
    steeringRun.phase = "settlement"
    assert(not expedition.buySteeringUpgrade(steeringRun))
    steeringRun.money = 65
    assert(expedition.buySteeringUpgrade(steeringRun))
    assert(steeringRun.money == 0 and steeringRun.steeringUpgradeLevel == 1)
    assert(expedition.steeringSpeed(steeringRun) == 70)
    assert(expedition.launch(steeringRun) and steeringRun.phase == "ascending")
    assert(expedition.steeringSpeed(steeringRun) == 70,
        "steering upgrade must persist across relaunch like fuel/hull upgrades")
    assert(expedition.damage(steeringRun, steeringRun.durability))
    assert(steeringRun.phase == "destroyed" and steeringRun.steeringUpgradeLevel == 0)
    assert(expedition.steeringSpeed(steeringRun) == 55,
        "steering upgrade must reset to base speed on destruction like the other upgrades")

    local steeringMoveScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    steeringMoveScene.expedition.phase = "ascending"
    steeringMoveScene.expedition.steeringUpgradeLevel = 1
    steeringMoveScene.touches["upgraded-steer"] = { x = 160, y = 10 }
    local shipXBefore = steeringMoveScene.ship.x
    steeringMoveScene:update(1)
    assert(math.abs(steeringMoveScene.ship.x - shipXBefore - 70) < 1e-9,
        "ascending steering must move the ship at expedition.steeringSpeed(run), not a fixed constant ("
            .. tostring(steeringMoveScene.ship.x - shipXBefore) .. ")")

    local steeringShopScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    steeringShopScene.expedition.phase = "settlement"
    steeringShopScene.expedition.money = steeringShopScene.expedition.steeringUpgradeCost
    steeringShopScene:keypressed("g")
    assert(steeringShopScene.expedition.steeringUpgradeLevel == 1,
        "keypressed('g') in settlement must purchase the STEERING upgrade")
    assert(steeringShopScene.expedition.money == 0)
    steeringShopScene:keypressed("g")
    assert(steeringShopScene.expedition.steeringUpgradeLevel == 1,
        "a second STEERING purchase attempt without enough money must fail")

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
    assert(shopScene.message
        == "FUEL TANK UPGRADED  LV.1  MAX 120  NO-HIT 720  SLOTS 8  BALANCE $30")
    shopScene.expedition.money = shopScene.expedition.durabilityUpgradeCost + 10
    shopScene:keypressed("h")
    assert(shopScene.expedition.durabilityUpgradeLevel == 1 and shopScene.expedition.maxDurability == 4)
    assert(shopScene.expedition.money == 10)
    assert(shopScene.message
        == "HULL UPGRADED  LV.1  MAX FUEL 120  HULL 4  NO-HIT 720  SLOTS 8  BALANCE $10")
    shopScene.expedition.money = shopScene.expedition.sampleYieldUpgradeCost + 15
    shopScene:keypressed("y")
    assert(shopScene.expedition.sampleYieldUpgradeLevel == 1)
    assert(shopScene.expedition.money == 15)
    assert(shopScene.message == "SAMPLE YIELD UPGRADED  LV.1  x1.25  BALANCE $15")
    shopScene.expedition.money = 0
    shopScene:keypressed("y")
    assert(shopScene.expedition.sampleYieldUpgradeLevel == 1)
    assert(shopScene.message == string.format("NEED $%d MORE FOR SAMPLE YIELD UPGRADE",
        shopScene.expedition.sampleYieldUpgradeCost))
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
        == "FUEL TANK UPGRADED  LV.1  MAX 160  NO-HIT 960  SLOTS 10  BALANCE $20")

    local scoutHullMessageScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    scoutHullMessageScene.expedition.phase = "settlement"
    scoutHullMessageScene.expedition.money = scoutHullMessageScene.expedition.scoutShipCost
        + scoutHullMessageScene.expedition.durabilityUpgradeCost + 20
    scoutHullMessageScene:keypressed("v")
    assert(scoutHullMessageScene.expedition.selectedShipId == "scout")
    scoutHullMessageScene:keypressed("h")
    assert(scoutHullMessageScene.expedition.durabilityUpgradeLevel == 1
        and scoutHullMessageScene.expedition.maxDurability == 3)
    assert(scoutHullMessageScene.expedition.money == 20)
    assert(scoutHullMessageScene.message
        == "HULL UPGRADED  LV.1  MAX FUEL 140  HULL 3  NO-HIT 840  SLOTS 9  BALANCE $20")

    local repeatedUpgradeMessageScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    repeatedUpgradeMessageScene.expedition.phase = "settlement"
    repeatedUpgradeMessageScene.expedition.money = 250
    repeatedUpgradeMessageScene:keypressed("f")
    repeatedUpgradeMessageScene:keypressed("f")
    assert(repeatedUpgradeMessageScene.message
        == "FUEL TANK UPGRADED  LV.2  MAX 140  NO-HIT 840  SLOTS 9  BALANCE $150")
    repeatedUpgradeMessageScene:keypressed("h")
    repeatedUpgradeMessageScene:keypressed("h")
    assert(repeatedUpgradeMessageScene.message
        == "HULL UPGRADED  LV.2  MAX FUEL 140  HULL 5  NO-HIT 840  SLOTS 9  BALANCE $0")

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
    local idleAscendSteering = touchScene:steeringButtonState()
    assert(not idleAscendSteering.leftActive and not idleAscendSteering.rightActive)
    touchScene:touchpressed("steer-left", 20, 160)
    local leftAscendSteering = touchScene:steeringButtonState()
    assert(leftAscendSteering.leftActive and not leftAscendSteering.rightActive)
    touchScene:update(1)
    assert(touchScene.ship.x == -55)
    touchScene:touchreleased("steer-left")
    local releasedAscendSteering = touchScene:steeringButtonState()
    assert(not releasedAscendSteering.leftActive and not releasedAscendSteering.rightActive)
    touchScene:update(1)
    assert(touchScene.ship.x == -55)
    touchScene:touchpressed("steer-right", 160, 160)
    local rightAscendSteering = touchScene:steeringButtonState()
    assert(not rightAscendSteering.leftActive and rightAscendSteering.rightActive)
    touchScene:update(1)
    assert(touchScene.ship.x == 0)
    touchScene:touchreleased("steer-right")
    touchScene.expedition.phase = "returning"
    touchScene.expedition.altitude = 500
    touchScene.expedition.returnDistance = 500
    touchScene.expedition.returnSpeed = 0
    touchScene.expedition.slotOpportunities = 2
    touchScene.expedition.slotRandom = function() return 10 end
    local returnStartX = touchScene.ship.x
    nearbyPlanets = world.nearbyPlanets
    world.nearbyPlanets = function() return {} end
    local idleReturnSteering = touchScene:steeringButtonState()
    assert(not idleReturnSteering.leftActive and not idleReturnSteering.rightActive)
    touchScene:touchpressed("return-left", 20, 266)
    local leftReturnSteering = touchScene:steeringButtonState()
    assert(leftReturnSteering.leftActive and not leftReturnSteering.rightActive)
    assert(touchScene.expedition.slotSpins == 0 and touchScene.expedition.slotOpportunities == 2)
    touchScene:update(1)
    assert(touchScene.ship.x == returnStartX - 55)
    touchScene:touchreleased("return-left")
    local releasedReturnSteering = touchScene:steeringButtonState()
    assert(not releasedReturnSteering.leftActive and not releasedReturnSteering.rightActive)
    touchScene:update(1)
    assert(touchScene.ship.x == returnStartX - 55)
    touchScene:touchpressed("slot", 90, 266)
    assert(touchScene.expedition.slotSpins == 1 and touchScene.expedition.slotOpportunities == 1)
    local returnSteeredX = touchScene.ship.x
    touchScene:update(1)
    assert(touchScene.ship.x == returnSteeredX)
    touchScene:touchpressed("return-right", 160, 266)
    local rightReturnSteering = touchScene:steeringButtonState()
    assert(not rightReturnSteering.leftActive and rightReturnSteering.rightActive)
    assert(touchScene.expedition.slotSpins == 1 and touchScene.expedition.slotOpportunities == 1)
    touchScene:update(1)
    assert(touchScene.ship.x == returnSteeredX + 55)
    touchScene:touchreleased("return-right")
    world.nearbyPlanets = nearbyPlanets

    local returnAvoidanceScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    returnAvoidanceScene.expedition.phase = "returning"
    returnAvoidanceScene.expedition.altitude = 500
    returnAvoidanceScene.expedition.returnDistance = 500
    returnAvoidanceScene.ship.y = -500
    local avoidablePlanet = { id = "return-avoid", x = 0, y = -455, radius = 7 }
    nearbyPlanets = world.nearbyPlanets
    world.nearbyPlanets = function() return { avoidablePlanet } end
    returnAvoidanceScene:touchpressed("avoid-left", 20, 266)
    returnAvoidanceScene:update(1)
    world.nearbyPlanets = nearbyPlanets
    assert(returnAvoidanceScene.ship.x == -55)
    assert(returnAvoidanceScene.expedition.durability == 3)
    assert(not returnAvoidanceScene.collided[avoidablePlanet.id])

    assert(table.concat(touchScene.expedition.lastSlotSymbols, " ") == "STAR STAR STAR")
    assert(touchScene.message == "STAR STAR STAR +$75  1 LEFT")
    local readySlotButton = touchScene:slotButtonState()
    assert(readySlotButton.enabled and readySlotButton.label == "TAP: SLOT SPIN  1 LEFT")
    touchScene:touchpressed("last-slot", 90, 266)
    assert(touchScene.expedition.slotSpins == 2 and touchScene.expedition.slotOpportunities == 0)
    local spinningSlotButton = touchScene:slotButtonState()
    assert(not spinningSlotButton.enabled and spinningSlotButton.label == "SLOT SPINNING...")
    touchScene:update(1)
    local emptySlotButton = touchScene:slotButtonState()
    assert(not emptySlotButton.enabled and emptySlotButton.label == "NO SLOT CHANCES")
    touchScene:touchpressed("empty-slot", 90, 266)
    assert(touchScene.expedition.slotSpins == 2 and touchScene.expedition.slotOpportunities == 0)
    touchScene.expedition.phase = "settlement"
    touchScene.expedition.money = touchScene.expedition.fuelUpgradeCost
        + touchScene.expedition.durabilityUpgradeCost + touchScene.expedition.scoutShipCost
    touchScene:touchpressed("fuel", 90, 174)
    touchScene:touchpressed("hull", 45, 208)
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
    assert(starterLoadout.steering == "STEER SPEED 55")
    loadoutScene.expedition.phase = "settlement"
    loadoutScene.expedition.money = loadoutScene.expedition.fuelUpgradeCost
        + loadoutScene.expedition.durabilityUpgradeCost + loadoutScene.expedition.scoutShipCost
        + loadoutScene.expedition.steeringUpgradeCost
    assert(expedition.buyFuelUpgrade(loadoutScene.expedition))
    assert(expedition.buyDurabilityUpgrade(loadoutScene.expedition))
    assert(expedition.buyShip(loadoutScene.expedition, "scout"))
    assert(expedition.selectShip(loadoutScene.expedition, "scout"))
    assert(expedition.buySteeringUpgrade(loadoutScene.expedition))
    local upgradedLoadout = loadoutScene:loadoutLines()
    assert(upgradedLoadout.ship == "SHIP SCOUT")
    assert(upgradedLoadout.stats == "MAX FUEL 160  HULL 3")
    assert(upgradedLoadout.upgrades == "FUEL LV.1  HULL LV.1")
    assert(upgradedLoadout.forecast == "NO-HIT 960  SLOTS 10")
    assert(upgradedLoadout.steering == "STEER SPEED 70")
    assert(expedition.launch(loadoutScene.expedition))
    assert(expedition.damage(loadoutScene.expedition, loadoutScene.expedition.maxDurability))
    local resetLoadout = loadoutScene:loadoutLines()
    assert(resetLoadout.ship == "SHIP STARTER")
    assert(resetLoadout.stats == "MAX FUEL 100  HULL 3")
    assert(resetLoadout.upgrades == "FUEL LV.0  HULL LV.0")
    assert(resetLoadout.steering == "STEER SPEED 55")

    local nextLaunchScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    nextLaunchScene.expedition.phase = "settlement"
    local starterNextLaunch = nextLaunchScene:shopLoadoutLines()
    assert(starterNextLaunch.ship == "NEXT STARTER")
    assert(starterNextLaunch.stats == "MAX FUEL 100  HULL 3")
    assert(starterNextLaunch.upgrades == "FUEL LV.0  HULL LV.0")
    assert(starterNextLaunch.forecast == "NO-HIT 600  SLOTS 6")
    assert(starterNextLaunch.scoutTradeoff == "SCOUT +40 FUEL / -1 HULL")
    assert(starterNextLaunch.shipAction == "BUY SCOUT $125")
    assert(starterNextLaunch.shipPreview == "SCOUT MAX FUEL 140  HULL 2")
    assert(starterNextLaunch.shipPreviewForecast == "NO-HIT 840  SLOTS 9")
    assert(starterNextLaunch.fuelAction == "T/F FUEL LV.0>1 $50")
    assert(starterNextLaunch.fuelPreviewForecast == "NO-HIT 720  SLOTS 8")
    assert(starterNextLaunch.fuelStatus == "SHORT $50" and not starterNextLaunch.fuelAffordable)
    assert(starterNextLaunch.hullAction == "T/H HULL LV.0>1 $75")
    assert(starterNextLaunch.hullPreview == "MAX FUEL 100  HULL 4")
    assert(starterNextLaunch.hullPreviewForecast == "NO-HIT 600  SLOTS 6")
    assert(starterNextLaunch.hullStatus == "SHORT $75" and not starterNextLaunch.hullAffordable)
    assert(starterNextLaunch.shipStatus == "SHORT $125" and not starterNextLaunch.shipAffordable)
    assert(starterNextLaunch.yieldAction == "T/Y YIELD LV.0>1 $60")
    assert(starterNextLaunch.yieldPreview == "YIELD x1.25")
    assert(starterNextLaunch.yieldStatus == "SHORT $60" and not starterNextLaunch.yieldAffordable)
    assert(starterNextLaunch.steeringAction == "T/G STEER LV.0>1 $65")
    assert(starterNextLaunch.steeringPreview == "STEER SPEED 70")
    assert(starterNextLaunch.steeringStatus == "SHORT $65" and not starterNextLaunch.steeringAffordable)
    nextLaunchScene.expedition.money = nextLaunchScene.expedition.fuelUpgradeCost
    local fuelReadyNextLaunch = nextLaunchScene:shopLoadoutLines()
    assert(fuelReadyNextLaunch.fuelStatus == "LEFT $0" and fuelReadyNextLaunch.fuelAffordable)
    assert(fuelReadyNextLaunch.hullStatus == "SHORT $25" and not fuelReadyNextLaunch.hullAffordable)
    assert(fuelReadyNextLaunch.shipStatus == "SHORT $75" and not fuelReadyNextLaunch.shipAffordable)
    assert(fuelReadyNextLaunch.yieldStatus == "SHORT $10" and not fuelReadyNextLaunch.yieldAffordable)
    assert(fuelReadyNextLaunch.steeringStatus == "SHORT $15" and not fuelReadyNextLaunch.steeringAffordable)
    nextLaunchScene.expedition.money = 200
    local balancePreviewNextLaunch = nextLaunchScene:shopLoadoutLines()
    assert(balancePreviewNextLaunch.fuelStatus == "LEFT $150" and balancePreviewNextLaunch.fuelAffordable)
    assert(balancePreviewNextLaunch.hullStatus == "LEFT $125" and balancePreviewNextLaunch.hullAffordable)
    assert(balancePreviewNextLaunch.shipStatus == "LEFT $75" and balancePreviewNextLaunch.shipAffordable)
    assert(balancePreviewNextLaunch.yieldStatus == "LEFT $140" and balancePreviewNextLaunch.yieldAffordable)
    assert(balancePreviewNextLaunch.steeringStatus == "LEFT $135" and balancePreviewNextLaunch.steeringAffordable)
    nextLaunchScene.expedition.money = nextLaunchScene.expedition.fuelUpgradeCost
        + nextLaunchScene.expedition.durabilityUpgradeCost + nextLaunchScene.expedition.scoutShipCost
        + nextLaunchScene.expedition.sampleYieldUpgradeCost
    nextLaunchScene:keypressed("f")
    local fueledNextLaunch = nextLaunchScene:shopLoadoutLines()
    assert(fueledNextLaunch.stats == "MAX FUEL 120  HULL 3")
    assert(fueledNextLaunch.upgrades == "FUEL LV.1  HULL LV.0")
    assert(fueledNextLaunch.forecast == "NO-HIT 720  SLOTS 8")
    assert(fueledNextLaunch.fuelAction == "T/F FUEL LV.1>2 $50")
    assert(fueledNextLaunch.hullAction == "T/H HULL LV.0>1 $75")
    assert(fueledNextLaunch.shipPreviewForecast == "NO-HIT 960  SLOTS 10")
    assert(fueledNextLaunch.fuelPreviewForecast == "NO-HIT 840  SLOTS 9")
    assert(fueledNextLaunch.hullPreview == "MAX FUEL 120  HULL 4")
    assert(fueledNextLaunch.hullPreviewForecast == "NO-HIT 720  SLOTS 8")
    nextLaunchScene:keypressed("h")
    local reinforcedNextLaunch = nextLaunchScene:shopLoadoutLines()
    assert(reinforcedNextLaunch.stats == "MAX FUEL 120  HULL 4")
    assert(reinforcedNextLaunch.upgrades == "FUEL LV.1  HULL LV.1")
    assert(reinforcedNextLaunch.fuelAction == "T/F FUEL LV.1>2 $50")
    assert(reinforcedNextLaunch.hullAction == "T/H HULL LV.1>2 $75")
    assert(reinforcedNextLaunch.shipPreview == "SCOUT MAX FUEL 160  HULL 3")
    nextLaunchScene:keypressed("y")
    local yieldedNextLaunch = nextLaunchScene:shopLoadoutLines()
    assert(yieldedNextLaunch.yieldAction == "T/Y YIELD LV.1>2 $60")
    assert(yieldedNextLaunch.yieldPreview == "YIELD x1.50")
    nextLaunchScene:keypressed("v")
    local scoutNextLaunch = nextLaunchScene:shopLoadoutLines()
    assert(scoutNextLaunch.ship == "NEXT SCOUT")
    assert(scoutNextLaunch.stats == "MAX FUEL 160  HULL 3")
    assert(scoutNextLaunch.upgrades == "FUEL LV.1  HULL LV.1")
    assert(scoutNextLaunch.forecast == "NO-HIT 960  SLOTS 10")
    assert(scoutNextLaunch.shipPreviewForecast == "NO-HIT 720  SLOTS 8")
    assert(scoutNextLaunch.fuelAction == "T/F FUEL LV.1>2 $50")
    assert(scoutNextLaunch.fuelPreviewForecast == "NO-HIT 1080  SLOTS 11")
    assert(scoutNextLaunch.hullAction == "T/H HULL LV.1>2 $75")
    assert(scoutNextLaunch.hullPreview == "MAX FUEL 160  HULL 4")
    assert(scoutNextLaunch.hullPreviewForecast == "NO-HIT 960  SLOTS 10")
    assert(scoutNextLaunch.scoutTradeoff == "SCOUT +40 FUEL / -1 HULL")
    assert(scoutNextLaunch.shipAction == "SELECT STARTER")
    assert(scoutNextLaunch.shipStatus == "OWNED" and scoutNextLaunch.shipAffordable)
    nextLaunchScene:keypressed("v")
    local reselectedNextLaunch = nextLaunchScene:shopLoadoutLines()
    assert(reselectedNextLaunch.ship == "NEXT STARTER")
    assert(reselectedNextLaunch.stats == "MAX FUEL 120  HULL 4")
    assert(reselectedNextLaunch.upgrades == "FUEL LV.1  HULL LV.1")
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
    assert(destroyedRun.lastLostSampleCount == 1 and destroyedRun.lastLostSampleValue == 70)
    assert(destroyedRun.lastLostSlotSpinsCount == 0 and destroyedRun.lastLostSlotValue == 0)
    assert(destroyedRun.lastLostAltitude == 80)
    assert(destroyedRun.lastLostNewBest == true)
    assert(expedition.launch(destroyedRun) and destroyedRun.phase == "ascending")
    assert(destroyedRun.altitude == 0 and destroyedRun.durability == destroyedRun.maxDurability)
    assert(destroyedRun.bestAltitude == 80)
    assert(destroyedRun.lastLostSampleCount == 0 and destroyedRun.lastLostSampleValue == 0)
    assert(destroyedRun.lastLostNewBest == false)

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

    local floatingTextScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    assert(#floatingTextScene.floatingTexts == 0)
    floatingTextScene.expedition.phase = "ascending"
    floatingTextScene.expedition.altitude = 500
    floatingTextScene.ship.y = -500
    floatingTextScene.collided["floating-text-sample"] = true
    local floatingTextNearby = world.nearbyPlanets
    world.nearbyPlanets = function()
        return { { id = "floating-text-sample", x = 0, y = -500, radius = 7 } }
    end
    floatingTextScene:update(0)
    world.nearbyPlanets = floatingTextNearby
    assert(#floatingTextScene.floatingTexts == 1)
    local sampleFloatingText = floatingTextScene.floatingTexts[1]
    assert(sampleFloatingText.text == "+$35")
    assert(sampleFloatingText.timer == 1.0)
    local startingFloatingY = sampleFloatingText.y
    floatingTextScene:update(0.5)
    assert(#floatingTextScene.floatingTexts == 1)
    assert(math.abs(sampleFloatingText.timer - 0.5) < 1e-9)
    assert(sampleFloatingText.y < startingFloatingY)
    floatingTextScene:update(0.6)
    assert(#floatingTextScene.floatingTexts == 0)

    assert(expedition.slotTotalWeight == 10)
    assert(math.abs(expedition.slotSymbolProbability("COMET") - 0.5) < 1e-9)
    assert(math.abs(expedition.slotSymbolProbability("PLANET") - 0.4) < 1e-9)
    assert(math.abs(expedition.slotSymbolProbability("STAR") - 0.1) < 1e-9)
    assert(expedition.weightedSlotSymbol(1) == "COMET")
    assert(expedition.weightedSlotSymbol(5) == "COMET")
    assert(expedition.weightedSlotSymbol(6) == "PLANET")
    assert(expedition.weightedSlotSymbol(9) == "PLANET")
    assert(expedition.weightedSlotSymbol(10) == "STAR")
    local ev, probabilitySum = expedition.slotExpectedValue()
    assert(math.abs(probabilitySum - 1) < 1e-9)
    assert(ev > 0 and ev < 25)
    assert(math.abs(ev - 18.585) < 0.01)

    local slotOddsScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    assert(slotOddsScene:slotOddsLine() == "C50 P40 S10  AVG $18.58")

    local oddsLoadoutScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    local launchLoadoutOdds = oddsLoadoutScene:loadoutLines()
    assert(launchLoadoutOdds.odds == "C50 P40 S10  AVG $18.58")
    oddsLoadoutScene.expedition.phase = "settlement"
    local shopLoadoutOdds = oddsLoadoutScene:shopLoadoutLines()
    assert(shopLoadoutOdds.odds == "C50 P40 S10  AVG $18.58")

    for _, row in ipairs(PlayScene.settlementTouchRows) do
        assert(row.bottom - row.top >= 34,
            "settlement touch row " .. (row.key or "columns") .. " is under the 34px minimum")
    end

    -- EARTH SHOP fuel/hull/steering/yield/ship rows print an action string
    -- (left column) and a status string (right column, "LEFT $N"/"SHORT $N"/
    -- "OWNED") side by side. A real LÖVE font probe (GAME_FONTPROBE=1 love .)
    -- against the small scene-cached font (love.graphics.newFont(8)) measured
    -- the widest action string ("T/G STEER LV.9>10 $65") at 100px and the
    -- widest status string ("SHORT $125") at 52px. Verify the drawn columns
    -- clear both measured worst cases so long status text cannot wrap onto a
    -- second line and overlap the row spaced only 9px below.
    assert(PlayScene.shopActionColumnW >= 100,
        "EARTH SHOP action column is under the measured worst-case action text width")
    assert(PlayScene.shopStatusColumnW >= 52,
        "EARTH SHOP status column is under the measured worst-case status text width")
    assert(PlayScene.shopStatusColumnX >= PlayScene.shopActionColumnX + PlayScene.shopActionColumnW,
        "EARTH SHOP status column overlaps the action column")
    -- The smallest supported window (integer scale 1, e.g. 180x320) at a 1x
    -- device pixel ratio is the worst case for touch-target accessibility.
    -- iOS/Android guidelines require ~44pt minimum; verify every settlement
    -- row actually clears that bar via the real canvas-to-points conversion,
    -- not just the previously-checked 34px minimum.
    for _, row in ipairs(PlayScene.settlementTouchRows) do
        local heightPoints = viewport.canvasPixelsToPoints(row.bottom - row.top, 180, 320, 1, false)
        assert(heightPoints >= 44,
            "settlement touch row " .. (row.key or "columns")
                .. " is under the 44pt accessibility minimum at scale 1 (" .. heightPoints .. "pt)")
        if row.columns then
            for _, column in ipairs(row.columns) do
                local widthPoints = viewport.canvasPixelsToPoints(column.right - column.left, 180, 320, 1, false)
                assert(widthPoints >= 44,
                    "settlement touch column " .. column.key
                        .. " is under the 44pt accessibility minimum width at scale 1 (" .. widthPoints .. "pt)")
            end
        end
    end
    local rowTouchScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    rowTouchScene.expedition.phase = "settlement"
    rowTouchScene.expedition.money = rowTouchScene.expedition.fuelUpgradeCost
        + rowTouchScene.expedition.durabilityUpgradeCost + rowTouchScene.expedition.scoutShipCost
        + rowTouchScene.expedition.sampleYieldUpgradeCost + rowTouchScene.expedition.steeringUpgradeCost
    for _, row in ipairs(PlayScene.settlementTouchRows) do
        if row.columns then
            for _, column in ipairs(row.columns) do
                rowTouchScene:touchpressed(column.key,
                    column.left + math.floor((column.right - column.left) / 2),
                    row.top + math.floor((row.bottom - row.top) / 2))
            end
        else
            rowTouchScene:touchpressed(row.key, 90, row.top + math.floor((row.bottom - row.top) / 2))
        end
    end
    assert(rowTouchScene.expedition.fuelUpgradeLevel == 1)
    assert(rowTouchScene.expedition.durabilityUpgradeLevel == 1)
    assert(rowTouchScene.expedition.sampleYieldUpgradeLevel == 1)
    assert(rowTouchScene.expedition.steeringUpgradeLevel == 1)
    assert(rowTouchScene.expedition.ownedShips.scout and rowTouchScene.expedition.selectedShipId == "scout")
    assert(rowTouchScene.expedition.phase == "ascending")

    -- The returning-phase LEFT/RIGHT/SPIN band was a 24px-tall row (only
    -- ~24pt at the smallest supported window), well under the same 44pt
    -- accessibility minimum settlementTouchRows was fixed to meet. Verify
    -- the widened band clears 44pt and that touches at its top/bottom
    -- edges (not just its vertical center) still register steering and
    -- slot input.
    local returnControls = PlayScene.returnControls
    assert(returnControls.bottom - returnControls.top >= 34,
        "returning control band is under the 34px minimum")
    local returnBandPoints = viewport.canvasPixelsToPoints(
        returnControls.bottom - returnControls.top, 180, 320, 1, false)
    assert(returnBandPoints >= 44,
        "returning control band is under the 44pt accessibility minimum at scale 1 (" .. returnBandPoints .. "pt)")

    local returnEdgeScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    returnEdgeScene.expedition.phase = "returning"
    returnEdgeScene.expedition.altitude = 500
    returnEdgeScene.expedition.returnDistance = 500
    returnEdgeScene.expedition.returnSpeed = 0
    returnEdgeScene.expedition.slotOpportunities = 2
    returnEdgeScene.expedition.slotRandom = function() return 10 end
    local edgeNearbyPlanets = world.nearbyPlanets
    world.nearbyPlanets = function() return {} end
    returnEdgeScene:touchpressed("edge-left", 20, returnControls.top)
    local edgeLeftSteering = returnEdgeScene:steeringButtonState()
    assert(edgeLeftSteering.leftActive and not edgeLeftSteering.rightActive,
        "returning band top edge did not register left steering")
    returnEdgeScene:touchreleased("edge-left")
    returnEdgeScene:touchpressed("edge-right", 160, returnControls.bottom - 1)
    local edgeRightSteering = returnEdgeScene:steeringButtonState()
    assert(not edgeRightSteering.leftActive and edgeRightSteering.rightActive,
        "returning band bottom edge did not register right steering")
    returnEdgeScene:touchreleased("edge-right")
    returnEdgeScene:touchpressed("edge-slot", 90, returnControls.top)
    assert(returnEdgeScene.expedition.slotSpins == 1 and returnEdgeScene.expedition.slotOpportunities == 1,
        "returning band top edge did not register slot spin at slot x range")
    world.nearbyPlanets = edgeNearbyPlanets

    local destroyedArea = PlayScene.destroyedTouchArea
    assert(destroyedArea.bottom - destroyedArea.top >= 34,
        "destroyed touch area height is under the 34px minimum")
    assert(destroyedArea.right - destroyedArea.left >= 34,
        "destroyed touch area width is under the 34px minimum")
    local destroyedCorners = {
        { x = destroyedArea.left, y = destroyedArea.top },
        { x = destroyedArea.right - 1, y = destroyedArea.top },
        { x = destroyedArea.left, y = destroyedArea.bottom - 1 },
        { x = destroyedArea.right - 1, y = destroyedArea.bottom - 1 },
        { x = math.floor((destroyedArea.left + destroyedArea.right) / 2),
          y = math.floor((destroyedArea.top + destroyedArea.bottom) / 2) },
    }
    for _, point in ipairs(destroyedCorners) do
        local destroyedTouchScene = PlayScene.new({
            bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
        })
        destroyedTouchScene.expedition.phase = "destroyed"
        destroyedTouchScene:touchpressed("destroyed-tap", point.x, point.y)
        assert(destroyedTouchScene.expedition.phase == "ascending",
            "destroyed tap at (" .. point.x .. "," .. point.y .. ") did not restart the run")
    end

    -- LAUNCH phase's TAP TO LAUNCH action already accepts any tap on the
    -- internal canvas regardless of x/y (unconditional touchpressed branch),
    -- so the functional touch target has always spanned the full 180x320
    -- canvas -- but unlike destroyedTouchArea, this was never given a named
    -- constant or an explicit corner-touch regression test. Documented and
    -- tested here to close out the remaining unverified touch surface noted
    -- in docs/STATUS.md's next-slice note.
    local launchArea = PlayScene.launchTouchArea
    assert(launchArea.bottom - launchArea.top >= 34,
        "launch touch area height is under the 34px minimum")
    assert(launchArea.right - launchArea.left >= 34,
        "launch touch area width is under the 34px minimum")
    local launchAreaPoints = viewport.canvasPixelsToPoints(
        launchArea.bottom - launchArea.top, 180, 320, 1, false)
    assert(launchAreaPoints >= 44,
        "launch touch area is under the 44pt accessibility minimum at scale 1 (" .. launchAreaPoints .. "pt)")
    local launchCorners = {
        { x = launchArea.left, y = launchArea.top },
        { x = launchArea.right - 1, y = launchArea.top },
        { x = launchArea.left, y = launchArea.bottom - 1 },
        { x = launchArea.right - 1, y = launchArea.bottom - 1 },
        { x = math.floor((launchArea.left + launchArea.right) / 2),
          y = math.floor((launchArea.top + launchArea.bottom) / 2) },
    }
    for _, point in ipairs(launchCorners) do
        local launchTouchScene = PlayScene.new({
            bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
        })
        launchTouchScene:touchpressed("launch-tap", point.x, point.y)
        assert(launchTouchScene.expedition.phase == "ascending",
            "launch tap at (" .. point.x .. "," .. point.y .. ") did not start the run")
    end

    -- Ascending-phase HOLD LEFT/HOLD RIGHT button box was drawn 24px tall
    -- (only ~24pt at the smallest supported window), under the same 44pt
    -- accessibility minimum returnControls/settlementTouchRows were fixed
    -- to meet. touchpressed for this phase already accepts any tap on the
    -- full canvas regardless of y (functionally already >=44pt), so this
    -- test verifies the *visual* button box constant directly.
    local ascendControls = PlayScene.ascendControls
    assert(ascendControls.bottom - ascendControls.top >= 34,
        "ascending control band is under the 34px minimum")
    local ascendBandPoints = viewport.canvasPixelsToPoints(
        ascendControls.bottom - ascendControls.top, 180, 320, 1, false)
    assert(ascendBandPoints >= 44,
        "ascending control band is under the 44pt accessibility minimum at scale 1 (" .. ascendBandPoints .. "pt)")

    local ascendEdgeScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    ascendEdgeScene.expedition.phase = "ascending"
    ascendEdgeScene:touchpressed("ascend-edge-left", 20, ascendControls.top)
    local ascendEdgeLeftSteering = ascendEdgeScene:steeringButtonState()
    assert(ascendEdgeLeftSteering.leftActive and not ascendEdgeLeftSteering.rightActive,
        "ascending band top edge did not register left steering")
    ascendEdgeScene:touchreleased("ascend-edge-left")
    ascendEdgeScene:touchpressed("ascend-edge-right", 160, ascendControls.bottom - 1)
    local ascendEdgeRightSteering = ascendEdgeScene:steeringButtonState()
    assert(not ascendEdgeRightSteering.leftActive and ascendEdgeRightSteering.rightActive,
        "ascending band bottom edge did not register right steering")
    ascendEdgeScene:touchreleased("ascend-edge-right")

    -- docs/GAME_DESIGN.md's 귀환 슬롯 section lists repair vouchers
    -- (수리권) as one of the reward kinds a return slot spin can grant,
    -- alongside money. Only money payouts existed until now. A STAR-STAR-
    -- STAR jackpot is the rarest/most valuable combo (10% per reel, 0.1%
    -- overall), so it also restores 1 durability point (capped at
    -- run.maxDurability) as its repair-voucher bonus on top of the $75
    -- money reward. Non-jackpot combos grant no repair.
    local repairRun = expedition.new({
        slotRandom = function() return 10 end, -- always STAR (weight cumulative 10)
    })
    repairRun.durability = 1
    repairRun.phase = "returning"
    repairRun.slotOpportunities = 1
    assert(expedition.useSlot(repairRun))
    assert(table.concat(repairRun.lastSlotSymbols, "-") == "STAR-STAR-STAR")
    assert(repairRun.lastSlotReward == 75 and repairRun.pendingSlotReward == 75)
    assert(repairRun.durability == 2, "STAR triple must repair 1 durability point")
    assert(repairRun.lastSlotRepair == 1, "lastSlotRepair must report the actual repair applied")

    local repairAtCapRun = expedition.new({
        durability = 3,
        slotRandom = function() return 10 end,
    })
    repairAtCapRun.phase = "returning"
    repairAtCapRun.slotOpportunities = 1
    assert(expedition.useSlot(repairAtCapRun))
    assert(repairAtCapRun.durability == 3, "repair must not exceed maxDurability")
    assert(repairAtCapRun.lastSlotRepair == 0, "no repair should be reported once durability is already full")

    local noRepairRolls = { 1, 6, 10 } -- COMET-PLANET-STAR, no match, no repair
    local nextNoRepairRoll = 0
    local noRepairRun = expedition.new({
        slotRandom = function()
            nextNoRepairRoll = nextNoRepairRoll + 1
            return noRepairRolls[nextNoRepairRoll]
        end,
    })
    noRepairRun.durability = 1
    noRepairRun.phase = "returning"
    noRepairRun.slotOpportunities = 1
    assert(expedition.useSlot(noRepairRun))
    assert(noRepairRun.durability == 1, "non-jackpot combos must not repair durability")
    assert(noRepairRun.lastSlotRepair == 0)

    -- relaunch and destruction must reset the repair receipt like the
    -- other last-spin fields (lastSlotReward, lastSlotSymbols).
    repairRun.phase = "settlement"
    assert(expedition.launch(repairRun))
    assert(repairRun.lastSlotRepair == 0, "relaunch must clear the previous spin's repair receipt")
    repairRun.phase = "returning"
    repairRun.slotOpportunities = 1
    repairRun.durability = 1
    assert(expedition.useSlot(repairRun))
    assert(repairRun.lastSlotRepair == 1)
    assert(expedition.damage(repairRun, repairRun.durability))
    assert(repairRun.phase == "destroyed" and repairRun.lastSlotRepair == 0,
        "destruction must clear the repair receipt like other pending/last-spin fields")

    -- The returning-phase slot result message should surface the repair
    -- bonus so players can see it landed, alongside the existing money
    -- win/pending text.
    local repairMessageRolls = { 10, 10, 10 }
    local nextRepairMessageRoll = 0
    local repairMessageScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    repairMessageScene.expedition.slotRandom = function()
        nextRepairMessageRoll = nextRepairMessageRoll + 1
        return repairMessageRolls[nextRepairMessageRoll]
    end
    repairMessageScene.expedition.phase = "returning"
    repairMessageScene.expedition.altitude = 500
    repairMessageScene.expedition.durability = 1
    repairMessageScene.expedition.slotOpportunities = 1
    repairMessageScene:keypressed("up")
    repairMessageScene:update(repairMessageScene.slotSpin.duration + 0.01)
    assert(repairMessageScene.message == "STAR STAR STAR +$75 REPAIR +1  0 LEFT",
        "slot spin completion message must include the repair bonus: " .. tostring(repairMessageScene.message))

    -- docs/GAME_DESIGN.md's 귀환 슬롯 section also lists "다음 원정 연료
    -- 보너스" (next-expedition fuel bonus) as one of the reward kinds a
    -- return slot spin can grant. Only money and repair vouchers existed
    -- until now. A PLANET-PLANET-PLANET triple (40% per reel, 6.4%
    -- overall -- rarer than any generic triple's $40 payout but more
    -- common than the STAR jackpot) grants a fuel bonus that is banked at
    -- safe settlement and applied to the *next* expedition's starting
    -- fuel (not the current one, since the ship has already exhausted its
    -- fuel by the time it is returning).
    local fuelBonusRun = expedition.new({
        slotRandom = function() return 6 end, -- PLANET (cumulative 6..9)
    })
    fuelBonusRun.phase = "returning"
    fuelBonusRun.slotOpportunities = 1
    assert(expedition.useSlot(fuelBonusRun))
    assert(table.concat(fuelBonusRun.lastSlotSymbols, "-") == "PLANET-PLANET-PLANET")
    assert(fuelBonusRun.lastSlotReward == 40 and fuelBonusRun.pendingSlotReward == 40)
    assert(fuelBonusRun.lastSlotFuelBonus == 15, "PLANET triple must grant a 15 fuel bonus")
    assert(fuelBonusRun.pendingFuelBonus == 15, "fuel bonus must accumulate as pending until settlement")
    assert(fuelBonusRun.bankedFuelBonus == 0, "fuel bonus must not be banked before safe settlement")

    -- Non-jackpot, non-PLANET-triple combos grant no fuel bonus.
    assert(noRepairRun.lastSlotFuelBonus == 0)
    assert((noRepairRun.pendingFuelBonus or 0) == 0)

    -- Safe settlement banks the pending fuel bonus for the next launch and
    -- clears the pending counter; the current settlement's fuel is
    -- untouched (it only applies at the *next* M.launch).
    fuelBonusRun.altitude = 1
    expedition.update(fuelBonusRun, 1) -- drives altitude to 0 and calls settle()
    assert(fuelBonusRun.phase == "settlement")
    assert(fuelBonusRun.bankedFuelBonus == 15, "safe settlement must bank the pending fuel bonus")
    assert(fuelBonusRun.pendingFuelBonus == 0, "pending fuel bonus must clear once banked")

    -- The next launch applies the banked fuel bonus on top of maxFuel and
    -- clears the bank so it cannot be reused on a later launch.
    assert(expedition.launch(fuelBonusRun))
    assert(fuelBonusRun.fuel == fuelBonusRun.maxFuel + 15,
        "next launch must add the banked fuel bonus to starting fuel")
    assert(fuelBonusRun.bankedFuelBonus == 0, "banked fuel bonus must be consumed by the launch it funds")

    -- A second launch (no new bonus earned) must not carry over a bonus.
    fuelBonusRun.phase = "settlement"
    assert(expedition.launch(fuelBonusRun))
    assert(fuelBonusRun.fuel == fuelBonusRun.maxFuel,
        "launches without a freshly banked bonus must start at plain maxFuel")

    -- Destruction forfeits any pending/banked fuel bonus like the other
    -- pending rewards (samples, slot money, repair).
    local destroyedFuelBonusRun = expedition.new({
        slotRandom = function() return 6 end,
    })
    destroyedFuelBonusRun.phase = "returning"
    destroyedFuelBonusRun.slotOpportunities = 1
    assert(expedition.useSlot(destroyedFuelBonusRun))
    assert(destroyedFuelBonusRun.pendingFuelBonus == 15)
    assert(expedition.damage(destroyedFuelBonusRun, destroyedFuelBonusRun.durability))
    assert(destroyedFuelBonusRun.phase == "destroyed")
    assert(destroyedFuelBonusRun.pendingFuelBonus == 0, "destruction must forfeit the pending fuel bonus")
    assert(destroyedFuelBonusRun.bankedFuelBonus == 0, "destruction must forfeit any banked fuel bonus too")
    assert(destroyedFuelBonusRun.lastSlotFuelBonus == 0, "destruction must clear the last-spin fuel bonus receipt")

    -- The returning-phase slot result message should surface the fuel
    -- bonus alongside money/repair, and the launch message should surface
    -- the banked bonus actually applied to the new expedition.
    local fuelBonusMessageRolls = { 6, 6, 6 }
    local nextFuelBonusMessageRoll = 0
    local fuelBonusMessageScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    fuelBonusMessageScene.expedition.slotRandom = function()
        nextFuelBonusMessageRoll = nextFuelBonusMessageRoll + 1
        return fuelBonusMessageRolls[nextFuelBonusMessageRoll]
    end
    fuelBonusMessageScene.expedition.phase = "returning"
    fuelBonusMessageScene.expedition.altitude = 500
    fuelBonusMessageScene.expedition.slotOpportunities = 1
    fuelBonusMessageScene:keypressed("up")
    fuelBonusMessageScene:update(fuelBonusMessageScene.slotSpin.duration + 0.01)
    assert(fuelBonusMessageScene.message == "PLANET PLANET PLANET +$40 FUEL +15  0 LEFT",
        "slot spin completion message must include the fuel bonus: " .. tostring(fuelBonusMessageScene.message))

    -- The EARTH SHOP summary card (settlement phase) must surface a
    -- banked next-expedition fuel bonus so the player can see the reward
    -- they earned before relaunching, mirroring how SAMPLES/SPINS/PEAK
    -- ALT/NEW BEST already summarize other settlement outcomes.
    local fuelBonusSummaryScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    fuelBonusSummaryScene.expedition.bankedFuelBonus = 0
    assert(fuelBonusSummaryScene:summaryFuelBonusLine() == nil,
        "no fuel bonus banked must show no summary line")
    fuelBonusSummaryScene.expedition.bankedFuelBonus = 15
    assert(fuelBonusSummaryScene:summaryFuelBonusLine() == "NEXT LAUNCH FUEL +15",
        "banked fuel bonus must be summarized as NEXT LAUNCH FUEL +N: "
            .. tostring(fuelBonusSummaryScene:summaryFuelBonusLine()))

    -- Real LOVE runtime capture (GAME_CAPTURE_PHASE=ascending-damage-text,
    -- 1440x2560) showed the green "+$N" sample floating text and the red
    -- "-N" damage floating text spawning at the exact same screen point
    -- when a ship overlaps a planet closely enough to trigger both the
    -- sample-collection and the collision thresholds on the same update:
    -- both used planet.x/y or ship.x/y directly with no separation, so the
    -- two texts rendered stacked on top of each other and were unreadable
    -- ("+$?5" mangled by an overlapping red glyph). Verify the two texts
    -- created in the same frame are horizontally separated by at least the
    -- width of the 60px-wide centered text box so neither can overlap the
    -- other, regardless of how close the ship and planet positions are.
    local overlapScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    overlapScene.expedition.phase = "ascending"
    overlapScene.expedition.altitude = 500
    overlapScene.expedition.durability = 3
    overlapScene.ship.x = 0
    overlapScene.ship.y = -500
    local overlapNearby = world.nearbyPlanets
    world.nearbyPlanets = function()
        return { { id = "overlap-test", x = 0, y = -500, radius = 7 } }
    end
    overlapScene:update(0)
    world.nearbyPlanets = overlapNearby
    assert(#overlapScene.floatingTexts == 2,
        "same-frame sample+collision must create both floating texts")
    local overlapSample, overlapDamage
    for _, ft in ipairs(overlapScene.floatingTexts) do
        if ft.kind == "sample" then overlapSample = ft end
        if ft.kind == "damage" then overlapDamage = ft end
    end
    assert(overlapSample and overlapDamage)
    assert(math.abs(overlapSample.x - overlapDamage.x) >= 60,
        "sample and damage floating texts spawned in the same frame must be"
            .. " horizontally separated by at least the 60px text box width ("
            .. tostring(overlapSample.x) .. " vs " .. tostring(overlapDamage.x) .. ")")

    print("SPACESHIP_UNIT_OK")
end

return M
