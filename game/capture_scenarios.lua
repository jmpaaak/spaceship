local M = {}

function M.ordinaryPlanetFixture()
    return {
        phase = "ascending",
        altitude = 900,
        ship = { x = 0, y = -900 },
        planets = {
            {
                id = "capture-studio-ordinary-bare",
                x = 120,
                y = -960,
                radius = 33,
                hue = 0.1,
                galaxyStarType = "bare",
            },
        },
    }
end

function M.applyOrdinaryPlanet(scene, world, expedition)
    local fixture = M.ordinaryPlanetFixture()
    expedition.launch(scene.expedition)
    scene.expedition.altitude = fixture.altitude
    scene.ship.x = fixture.ship.x
    scene.ship.y = fixture.ship.y
    world.nearbyPlanets = function()
        return fixture.planets
    end
    world.collisionDamage = function() return 0 end
    world.sampleValue = function() return 1 end
    world.sampleTier = function() return "common" end
    return fixture
end

function M.ordinaryPlanetArtworkEvidence(scene)
    local sprite = scene.studioPlanetImages and scene.studioPlanetImages.bare
    assert(sprite, "ordinary-planet capture requires decoded bare Asset Studio artwork")
    local width, height = sprite:getDimensions()
    assert(width == 128 and height == 128,
        "ordinary-planet capture artwork must retain its 128x128 runtime dimensions")
    return "assets/planet/studio/pp_bare.png:" .. width .. "x" .. height
end

return M
