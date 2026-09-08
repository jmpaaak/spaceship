local M = {}

local function testNewLaunchAndSettlement()
    local expedition = require("game.expedition")
    local run = expedition.new({ durability = 5, bestAltitude = 12, money = 7 })
    assert(run.phase == "launch" and run.durability == 5 and run.money == 7)
    assert(run.equippedGear == run.gearLoadout.hull)
    assert(run.equippedEngineParts == run.gearLoadout.engine)
    assert(expedition.launch(run) == true and run.phase == "ascending")

    run.pendingSampleValue = 9
    run.sampleCount = 2
    run.maxAltitude = 30
    run.bestAltitude = 30
    run.lastHubX, run.lastHubY = 44, 55
    expedition.settle(run)
    assert(run.phase == "settlement" and run.money == 16)
    assert(run.lastSettlement == 9 and run.lastSampleCount == 2)
    assert(run.lastCheckpointX == 44 and run.lastCheckpointY == 55)
    assert(run.pendingSampleValue == 0 and run.sampleCount == 0)
end

local function testHubSettlementAndDestructionReset()
    local expedition = require("game.expedition")
    local lifecycle = require("game.expedition_lifecycle")
    local run = expedition.new({ durability = 4, money = 20 })
    expedition.launch(run)
    run.pendingSampleValue = 6
    assert(expedition.settleAtHub(run) == 6)
    assert(run.phase == "ascending" and run.money == 26 and run.pendingSampleValue == 0)

    run.lastCheckpointX, run.lastCheckpointY = 8, 13
    run.sampleCount, run.pendingSampleValue, run.maxAltitude = 3, 21, 99
    run.ownedShips.scout = true
    assert(expedition.damage(run, 4) == true)
    assert(run.phase == "destroyed" and run.money == 0 and run.durability == 0)
    assert(run.lastLostSampleCount == 3 and run.lastLostSampleValue == 21)
    assert(run.ownedShips.starter and not run.ownedShips.scout)
    assert(#run.equippedGear == 0 and #run.equippedEngineParts == 0)
    local x, y = expedition.lastCheckpointOrEarth(run)
    assert(x == 8 and y == 13)
    local ex, ey = lifecycle.lastCheckpointOrEarth({})
    assert(ex == 0 and ey == 75)
end

function M.run()
    testNewLaunchAndSettlement()
    testHubSettlementAndDestructionReset()
    print("  expedition lifecycle delegation/reset/settlement OK")
end

return M