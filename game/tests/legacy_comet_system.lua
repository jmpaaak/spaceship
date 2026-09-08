local world = require("game.world")
local PlayScene = require("game.scenes.play")

local M = {}

-- INBOX-35: Comet system characterization coverage.
function M.run()
    print("  [INBOX-35] comet system tests...")

    -- (a) world.resetComets clears state
    world.resetComets()
    assert(#world.comets == 0, "resetComets must clear comets table")
    assert(world.cometIdCounter == 0, "resetComets must reset id counter")
    assert(world.cometNextSpawn == 60, "resetComets must set next spawn to 60")
    assert(world.cometFirstSpawned == false, "resetComets must reset firstSpawned flag")

    -- (b) No spawn before 60 seconds
    local result = world.tickCometSpawn(30, 0, 0, 720, 1280)
    assert(result == nil, "No comet should spawn before 60s")
    assert(#world.comets == 0, "Comets table should be empty before 60s")

    -- (c) First spawn at 60s is guaranteed
    local first = world.tickCometSpawn(60, 0, 0, 720, 1280)
    assert(first ~= nil, "First comet at 60s must spawn (guaranteed)")
    assert(first.id == "comet_1", "First comet id must be comet_1, got " .. tostring(first.id))
    assert(first.radius >= 8 and first.radius <= 12,
        "Comet radius must be 8-12, got " .. first.radius)
    assert(first.speed >= 240 and first.speed <= 360,
        "Comet speed must be 240-360 (3x), got " .. first.speed)
    assert(world.cometFirstSpawned == true, "firstSpawned must be true after first spawn")

    -- (d) cometPosition returns correct position over time
    local cx, cy = world.cometPosition(first, first.spawnTime + 1)
    local expectedX = first.startX + first.vx * 1
    local expectedY = first.startY + first.vy * 1
    assert(math.abs(cx - expectedX) < 0.01, "cometPosition x incorrect")
    assert(math.abs(cy - expectedY) < 0.01, "cometPosition y incorrect")

    -- (e) cometSampleValue = 50x planet sampleValue
    local testComet = { x = 0, y = -500, radius = 10, hue = 0.12 }
    local planetVal = world.sampleValue(testComet)
    local cometVal = world.cometSampleValue(testComet)
    assert(cometVal == planetVal * 50,
        "Comet sample value must be 50x planet value, got " ..
        cometVal .. " vs " .. planetVal * 50)

    -- (f) cometCollisionDamage same as planet collision damage
    local cometDmg = world.cometCollisionDamage(testComet)
    local planetDmg = world.collisionDamage(testComet)
    assert(cometDmg == planetDmg, "Comet collision damage must match planet formula")

    -- (g) nearbyComets returns positioned comets and prunes far ones
    world.resetComets()
    local c = world.spawnComet(0, 0, 0, 720, 1280)
    -- At time 0, comet is near the viewport edge
    local nearby = world.nearbyComets(0, 0, 0, 720, 1280)
    assert(#nearby >= 1, "nearbyComets should return the spawned comet")
    assert(nearby[1].id == c.id, "nearbyComets should return correct id")

    -- (h) After enough time, comet should be pruned (too far)
    nearby = world.nearbyComets(0, 0, 100, 720, 1280)
    assert(#nearby == 0, "Comet should be pruned after traveling far off-screen")
    assert(#world.comets == 0, "Pruned comet should be removed from world.comets")

    -- (i) Next spawn interval is 30s; test that cometNextSpawn advances
    world.resetComets()
    world.tickCometSpawn(60, 0, 0, 720, 1280) -- first at 60
    assert(world.cometNextSpawn == 90, "After first spawn, next should be at 90, got " .. world.cometNextSpawn)

    -- (j) Play scene initializes comet state
    local cometScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    assert(type(cometScene.cometDiscovered) == "table", "cometDiscovered must be initialized")
    assert(type(cometScene.cometCollided) == "table", "cometCollided must be initialized")

    -- Clean up
    world.resetComets()

    print("  INBOX-35 comet system OK")
end

return M
