local world = require("game.world")

local M = {}

-- INBOX-37: Moon (satellite) system characterization coverage.
function M.run()
    print("  [INBOX-37] moon system tests...")

    -- (a) planetHasMoon deterministic ~30% rate
    local moonCount = 0
    local totalPlanets = 0
    for sx = -20, 20 do
        for sy = -20, 20 do
            for _, planet in ipairs(world.planets(sx, sy)) do
                totalPlanets = totalPlanets + 1
                if world.planetHasMoon(planet) then
                    moonCount = moonCount + 1
                end
            end
        end
    end
    if totalPlanets > 0 then
        local rate = moonCount / totalPlanets
        assert(rate > 0.15 and rate < 0.45,
            "moon spawn rate should be ~30%, got " .. tostring(rate))
    end

    -- (b) moonForPlanet returns nil for no-moon planets
    local testPlanet = { id = "test:0:1", x = 100, y = -200, radius = 10, hue = 0.3 }
    -- Hash-based: just verify the function returns a table or nil
    local moon = world.moonForPlanet(testPlanet, 0)
    if moon then
        assert(moon.id == testPlanet.id .. ":moon", "moon id must be planet.id .. ':moon'")
        assert(moon.radius >= 6 and moon.radius <= 11, "moon radius must be 6~11, got " .. tostring(moon.radius))
        assert(moon.orbitRadius >= testPlanet.radius + 25 and moon.orbitRadius <= testPlanet.radius + 39,
            "moon orbitRadius must be planet.radius + 25~39, got " .. tostring(moon.orbitRadius))
        assert(moon.parentX == testPlanet.x, "moon must store parentX")
        assert(moon.parentY == testPlanet.y, "moon must store parentY")
    end

    -- (c) moonForPlanet position changes over time (orbit)
    -- Find a planet that actually has a moon
    local moonPlanet = nil
    for sx = -5, 5 do
        for sy = -5, 5 do
            for _, p in ipairs(world.planets(sx, sy)) do
                if world.planetHasMoon(p) then
                    moonPlanet = p
                    break
                end
            end
            if moonPlanet then break end
        end
        if moonPlanet then break end
    end
    if moonPlanet then
        local m0 = world.moonForPlanet(moonPlanet, 0)
        local m1 = world.moonForPlanet(moonPlanet, 0.75) -- quarter period
        assert(m0 and m1, "moonForPlanet must return a table for moon planets")
        -- Positions must differ (orbiting)
        local posDiff = math.abs(m0.x - m1.x) + math.abs(m0.y - m1.y)
        assert(posDiff > 1, "moon must orbit — positions at t=0 and t=0.75 must differ, diff=" .. tostring(posDiff))
        -- Moon must stay within orbitRadius of parent
        local d0 = math.sqrt((m0.x - moonPlanet.x)^2 + (m0.y - moonPlanet.y)^2)
        assert(math.abs(d0 - m0.orbitRadius) < 1, "moon must orbit at orbitRadius distance")
    end

    -- (d) moonSampleValue: $2~$10 based on speed (faster = higher)
    local fastMoon = { speedFactor = 1.0 }
    local slowMoon = { speedFactor = 0.0 }
    local midMoon = { speedFactor = 0.5 }
    assert(world.moonSampleValue(fastMoon) == 10, "fastest moon must pay $10, got " .. world.moonSampleValue(fastMoon))
    assert(world.moonSampleValue(slowMoon) == 2, "slowest moon must pay $2, got " .. world.moonSampleValue(slowMoon))
    assert(world.moonSampleValue(midMoon) == 6, "mid-speed moon must pay $6, got " .. world.moonSampleValue(midMoon))
    assert(world.moonSampleValue(nil) == 6, "nil moon defaults to $6")

    -- (e) moonCollisionDamage: planet floor + speed bonus (+0/+1/+2)
    local planetDmg = world.collisionDamage({ x = 0, y = -500 })
    local slowMoonDmg = { parentX = 0, parentY = -500, speedFactor = 0 }
    local midMoonDmg = { parentX = 0, parentY = -500, speedFactor = 0.5 }
    local fastMoonDmg = { parentX = 0, parentY = -500, speedFactor = 1 }
    assert(world.moonCollisionDamage(slowMoonDmg) == planetDmg,
        "slowest moon damage must equal planet floor, got " .. tostring(world.moonCollisionDamage(slowMoonDmg)))
    assert(world.moonCollisionDamage(midMoonDmg) == planetDmg + 1,
        "mid-speed moon must deal planet+1, got " .. tostring(world.moonCollisionDamage(midMoonDmg)))
    assert(world.moonCollisionDamage(fastMoonDmg) == planetDmg + 2,
        "fastest moon must deal planet+2, got " .. tostring(world.moonCollisionDamage(fastMoonDmg)))

    -- (f) i18n moon_label
    local i18n = require("game.i18n")
    assert(i18n.t("moon_label") ~= nil and i18n.t("moon_label") ~= "", "moon_label i18n key must exist")

    print("  INBOX-37 moon system OK")
end

return M