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

function M.studioStarFixture()
    return {
        phase = "ascending",
        altitude = 900,
        ship = { x = 0, y = -900 },
        star = {
            id = "capture-studio-star-sun",
            x = 120,
            y = -960,
            starType = "earth",
        }
    }
end

function M.applyStudioStar(scene, world, expedition)
    local fixture = M.studioStarFixture()
    expedition.launch(scene.expedition)
    scene.expedition.altitude = fixture.altitude
    scene.ship.x = fixture.ship.x
    scene.ship.y = fixture.ship.y
    world.galaxyContaining = function() return { id = "milkyway", starType = fixture.star.starType, radius = 1200, checkpoint = false } end
    world.sunPosition = function() return { x = fixture.star.x, y = fixture.star.y } end
    world.nearbyPlanets = function() return {} end
    return fixture
end

function M.studioStarArtworkEvidence(scene)
    local sprite = scene.studioStarImages and scene.studioStarImages.earth
    assert(sprite, "studio-star capture requires decoded earth Asset Studio artwork")
    local width, height = sprite:getDimensions()
    assert(width == 128 and height == 128,
        "studio-star capture artwork must retain its 128x128 runtime dimensions")
    return "assets/star/studio/star_sun.png:" .. width .. "x" .. height
end

function M.studioHubFixture()
    return {
        phase = "ascending",
        altitude = 900,
        ship = { x = 0, y = -900 },
        planets = {
            {
                id = "capture-studio-hub-ice",
                x = 120,
                y = -960,
                radius = 45,
                hue = 0.5,
                galaxyStarType = "ice",
                hub = true,
                shop = true,
            },
        },
    }
end

function M.applyStudioHub(scene, world, expedition)
    local fixture = M.studioHubFixture()
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
    world.galaxyContaining = function() return nil end
    return fixture
end

function M.studioHubArtworkEvidence(scene)
    local sprite = scene.studioHubPlanetImages and scene.studioHubPlanetImages.ice
    assert(sprite, "studio-hub capture requires decoded ice Asset Studio artwork")
    local width, height = sprite:getDimensions()
    assert(width == 128 and height == 128,
        "studio-hub capture artwork must retain its 128x128 runtime dimensions")
    return "assets/planet/studio/hub_neptune.png:" .. width .. "x" .. height
end

return M
