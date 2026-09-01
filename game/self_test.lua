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

    local run = expedition.new({
        fuel = 2,
        fuelBurnRate = 1,
        climbSpeed = 60,
        returnSpeed = 50,
        slotDistance = 100,
        slotReward = 10,
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
    assert(run.money == 95 and run.lastSettlement == 95)
    assert(run.sampleCount == 0 and run.pendingSampleValue == 0 and run.pendingSlotReward == 0)
    expedition.update(run, 1)
    assert(run.money == 95 and run.lastSettlement == 95)

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

    local destroyedRun = expedition.new({
        fuel = 10,
        durability = 2,
        fuelBurnRate = 1,
        climbSpeed = 80,
        fuelUpgradeAmount = 5,
        fuelUpgradeCost = 50,
        money = 90,
    })
    destroyedRun.phase = "settlement"
    assert(expedition.buyFuelUpgrade(destroyedRun))
    assert(expedition.launch(destroyedRun))
    expedition.update(destroyedRun, 1)
    assert(expedition.collectSample(destroyedRun, 70))
    assert(not expedition.damage(destroyedRun, 1))
    assert(destroyedRun.durability == 1 and destroyedRun.phase == "ascending")
    assert(expedition.damage(destroyedRun, 1))
    assert(destroyedRun.phase == "destroyed" and destroyedRun.durability == 0)
    assert(destroyedRun.money == 0 and destroyedRun.sampleCount == 0 and destroyedRun.pendingSampleValue == 0)
    assert(destroyedRun.fuelUpgradeLevel == 0 and destroyedRun.maxFuel == destroyedRun.baseFuel)
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
    persistedScene.expedition.fuel = 1
    persistedScene.expedition.maxFuel = 1
    persistedScene.expedition.fuelBurnRate = 1
    persistedScene.expedition.climbSpeed = 60
    assert(expedition.launch(persistedScene.expedition))
    persistedScene:update(1)
    assert(persistedScene.expedition.phase == "returning" and savedBest == 60)
    local restartedScene = PlayScene.new({ bestAltitudeStore = fakeStore })
    assert(restartedScene.expedition.bestAltitude == 60)
    print("SPACESHIP_UNIT_OK")
end

return M
