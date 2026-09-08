local expedition = require("game.expedition")

local M = {}

function M.run()
    -- Retained from the original runner to preserve this characterization
    -- block's local setup and RNG-consumption contract.
    local basicSlotRolls = { 1, 6, 10, 6, 10, 1 }
    local nextBasicSlotRoll = 0
    local run = expedition.new({
        baseSpeed = 60,
        returnSpeed = 50,    })
    assert(run.phase == "launch" and run.altitude == 0)
    assert(expedition.launch(run) and run.phase == "ascending")
    expedition.update(run, 1)
    assert(run.phase == "ascending" and run.altitude == 60)
    assert(expedition.collectSample(run, 75))
    assert(run.sampleCount == 1 and run.pendingSampleValue == 75 and run.money == 0)
    expedition.update(run, 1)
    assert(run.phase == "ascending" and run.altitude == 120)
    expedition.settle(run)
    assert(run.phase == "settlement" and run.altitude == 120)
    assert(run.money == 75 and run.lastSettlement == 75)
    assert(run.lastSampleSettlement == 75)
    assert(run.sampleCount == 0 and run.pendingSampleValue == 0)
    assert(run.lastSampleCount == 1)
    assert(run.lastAltitude == 120)
    assert(run.lastNewBest == true)
    expedition.update(run, 1)
    assert(run.money == 75 and run.lastSettlement == 75)
    assert(run.lastSampleSettlement == 75)
    assert(run.lastAltitude == 120)
    assert(run.lastNewBest == true)
    assert(expedition.launch(run) and run.lastSampleCount == 0)
    assert(run.lastAltitude == 0)

    local lowerRun = expedition.new({ bestAltitude = 500 })
    lowerRun.phase = "ascending"
    lowerRun.altitude = 300
    lowerRun.maxAltitude = 300
    expedition.settle(lowerRun)
    assert(lowerRun.phase == "settlement" and lowerRun.lastAltitude == 300)
    assert(lowerRun.lastNewBest == false)
    assert(lowerRun.bestAltitude == 500)
end

return M