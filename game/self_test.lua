local viewport = require("game.viewport")
local shipModule = require("game.ship")
local world = require("game.world")
local expedition = require("game.expedition")
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
    print("SPACESHIP_UNIT_OK")
end

return M
