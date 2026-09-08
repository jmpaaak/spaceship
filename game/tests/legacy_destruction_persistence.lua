local expedition = require("game.expedition")
local bestAltitudeStore = require("game.best_altitude_store")

local M = {}

function M.run()
    local destroyedRun = expedition.new({
        durability = 2,
        baseSpeed = 80,
        durabilityUpgradeCost = 40,
        money = 140,
    })
    destroyedRun.phase = "settlement"
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
    assert(destroyedRun.durabilityUpgradeLevel == 0 and destroyedRun.maxDurability == destroyedRun.baseDurability)
    assert(destroyedRun.bestAltitude == 80)
    assert(destroyedRun.lastLostSampleCount == 1 and destroyedRun.lastLostSampleValue == 70)
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
end

return M