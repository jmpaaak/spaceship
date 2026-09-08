local world = require("game.world")
local PlayScene = require("game.scenes.play")
local M = {}

function M.run()
    -- Item 9: Central star gravity well tests
    local savedGC = world.galaxyContaining
    local savedSP = world.sunPosition
    local savedNP = world.nearbyPlanets
    local savedSV = world.sampleValue

    local testGalaxy = { id = "test-galaxy-well", x = 0, y = -2000, radius = 500 }
    local testSun = { x = 0, y = -2000 }

    -- Helper: create a scene placed at a given position relative to sun
    local function makeWellScene(shipX, shipY, durability)
        local s = PlayScene.new({
            bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
        })
        s.expedition.phase = "ascending"
        s.expedition.durability = durability or 20
        s.expedition.maxDurability = durability or 20
        s.ship.x = shipX
        s.ship.y = shipY
        -- stub out nearbyPlanets so no planet collision interferes
        world.nearbyPlanets = function() return {} end
        world.galaxyContaining = function() return testGalaxy end
        world.sunPosition = function() return testSun end
        world.sampleValue = function() return 100 end
        return s
    end

    -- Test 1: Outside well — no gravity pull, no damage
    do
        local s = makeWellScene(0, -2000 - world.starWellRadius - 10, 5)
        local origX, origY = s.ship.x, s.ship.y
        s:update(0.5)
        -- Ship should not be pulled (outside well)
        assert(s.starDotAccum == 0, "item9: outside well, dotAccum must be 0")
        assert(s.expedition.durability == 5, "item9: outside well, no damage expected")
        assert(s.starWellTimer == 0, "item9: outside well, timer must be 0")
    end

    -- Test 2: DoT — 0.5s per 1 damage
    do
        local s = makeWellScene(testSun.x + 10, testSun.y, 20)
        -- 0.5s tick → 1 damage (reset position to counter gravity pull)
        s:update(0.5)
        assert(s.expedition.durability == 19,
            "item9: 0.5s in well should deal 1 damage, got dur=" .. s.expedition.durability)
        -- Reset position (gravity moved ship), then another 0.5s
        s.ship.x = testSun.x + 10; s.ship.y = testSun.y
        s:update(0.5)
        assert(s.expedition.durability == 18,
            "item9: 1.0s in well should deal 2 total damage, got dur=" .. s.expedition.durability)
        -- 0.25s → no additional damage yet (accumulator not reached 0.5)
        s.ship.x = testSun.x + 10; s.ship.y = testSun.y
        s:update(0.25)
        assert(s.expedition.durability == 18,
            "item9: 1.25s, partial tick should not deal damage, got dur=" .. s.expedition.durability)
    end

    -- Test 3: 10s continuous survival → sample awarded once per galaxy
    do
        local s = makeWellScene(testSun.x + 10, testSun.y, 100)
        -- Tick 20 steps of 0.5s = 10s total (reset position each step to counter gravity)
        for i = 1, 20 do
            s.ship.x = testSun.x + 10; s.ship.y = testSun.y
            s:update(0.5)
        end
        assert(s.starWellSampled[testGalaxy.id] == true,
            "item9: 10s continuous in well must award sample")
        local sampleCount = s.expedition.sampleCount
        assert(sampleCount >= 1, "item9: sample count must be >= 1 after star well sample")
    end

    -- Test 4: Leaving well resets timer; re-entry restarts
    do
        local s = makeWellScene(testSun.x + 10, testSun.y, 100)
        -- Stay 4s in well
        for i = 1, 8 do
            s.ship.x = testSun.x + 10; s.ship.y = testSun.y
            s:update(0.5)
        end
        assert(s.starWellTimer >= 3.5, "item9: timer should be ~4s")

        -- Move outside well
        s.ship.x = testSun.x
        s.ship.y = testSun.y - world.starWellRadius - 50
        world.galaxyContaining = function() return nil end
        s:update(0.016)
        assert(s.starWellTimer == 0,
            "item9: leaving well must reset timer, got " .. s.starWellTimer)

        -- Re-enter well
        world.galaxyContaining = function() return testGalaxy end
        -- 4s again — should not have awarded yet
        for i = 1, 8 do
            s.ship.x = testSun.x + 10; s.ship.y = testSun.y
            s:update(0.5)
        end
        assert(not s.starWellSampled[testGalaxy.id],
            "item9: 4s re-entry should NOT award sample yet")
        -- 6 more seconds to complete 10s continuous
        for i = 1, 12 do
            s.ship.x = testSun.x + 10; s.ship.y = testSun.y
            s:update(0.5)
        end
        assert(s.starWellSampled[testGalaxy.id] == true,
            "item9: 10s continuous after re-entry must award sample")
    end

    -- Test 5: Per-galaxy once — second stay does not award again
    do
        local s = makeWellScene(testSun.x + 10, testSun.y, 200)
        -- First 10s
        for i = 1, 20 do
            s.ship.x = testSun.x + 10; s.ship.y = testSun.y
            s:update(0.5)
        end
        assert(s.starWellSampled[testGalaxy.id] == true, "item9: first sample awarded")
        local countAfterFirst = s.expedition.sampleCount

        -- Reset timer by leaving
        s.ship.y = testSun.y - world.starWellRadius - 50
        world.galaxyContaining = function() return nil end
        s:update(0.016)
        -- Re-enter for another 10s
        world.galaxyContaining = function() return testGalaxy end
        for i = 1, 20 do
            s.ship.x = testSun.x + 10; s.ship.y = testSun.y
            s:update(0.5)
        end
        assert(s.expedition.sampleCount == countAfterFirst,
            "item9: second 10s in same galaxy must NOT award another sample")
    end

    -- Restore stubs
    world.galaxyContaining = savedGC
    world.sunPosition = savedSP
    world.nearbyPlanets = savedNP
    world.sampleValue = savedSV
end

return M
