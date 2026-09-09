local M = {}

function M.run()
    local world = require("game.world")
    local station = require("game.station")
    local expedition = require("game.expedition")
    
    -- Test 1: spawn probabilities and intervals
    station.reset(0)
    -- before 60s, no spawn
    assert(station.tickSpawn(59, 0, 0, 720, 1280) == nil)
    -- at 60s, guaranteed spawn
    local st1 = station.tickSpawn(60, 0, 0, 720, 1280)
    assert(st1 ~= nil and st1.id == "station_1")
    
    -- Test 2: Arc hit docking
    local shipX, shipY = st1.x, st1.y
    -- get arc angle
    local angle = st1.initialArcAngle
    local dist = 10
    shipX = st1.x + math.cos(angle) * dist
    shipY = st1.y + math.sin(angle) * dist
    
    -- moving slowly
    local res = station.checkDocking(st1, shipX, shipY, 10, 10, 150)
    assert(res == "docked")
    
    -- Test 3: Arc miss collision
    local badAngle = angle + math.pi
    local badX = st1.x + math.cos(badAngle) * dist
    local badY = st1.y + math.sin(badAngle) * dist
    local res2 = station.checkDocking(st1, badX, badY, 10, 10, 150)
    assert(res2 == "crash")
    
    -- Test 4: Too fast collision
    local res3 = station.checkDocking(st1, shipX, shipY, 200, 200, 150)
    assert(res3 == "crash")
    
    print("station_dock OK")
end

return M
