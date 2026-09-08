local planets = require("game.scenes.play_planets")

local M = {}

local function near(actual, expected)
    return math.abs(actual - expected) < 0.000001
end

function M.run()
    print("  [R1] play_planets module tests...")

    local api = {}
    planets.install(api)
    for _, name in ipairs({ "planetColor", "planetVariation", "planetImagePathForPlanet" }) do
        assert(type(api[name]) == "function", "R1: play_planets must install " .. name)
    end

    local r1, g1, b1 = api.planetColor(0.1)
    assert(near(r1, 0.35) and near(g1, 0.75) and near(b1, 1),
        "R1: cool planet tint must remain stable")
    local r2, g2, b2 = api.planetColor(0.5)
    assert(near(r2, 0.95) and near(g2, 0.55) and near(b2, 0.3),
        "R1: warm planet tint must remain stable")
    local r3, g3, b3 = api.planetColor(0.8)
    assert(near(r3, 0.65) and near(g3, 0.45) and near(b3, 0.95),
        "R1: violet planet tint must remain stable")

    local rotation, scale = api.planetVariation(nil)
    assert(rotation == 0 and scale == 1, "R1: planets without ids must retain neutral variation")
    local repeatRotation, repeatScale = api.planetVariation({ id = "planet-7" })
    local sameRotation, sameScale = api.planetVariation({ id = "planet-7" })
    assert(repeatRotation == sameRotation and repeatScale == sameScale,
        "R1: planet variation must remain deterministic")
    assert(repeatRotation >= 0 and repeatRotation < 2 * math.pi
            and repeatScale >= 0.85 and repeatScale <= 1.15,
        "R1: planet variation must stay in its presentation bounds")

    assert(api.planetImagePathForPlanet({ hub = true, galaxyStarType = "ice" })
            == "assets/planet/pp_ice.png",
        "R1: typed hubs must use their PixelPlanets sprite")
    assert(api.planetImagePathForPlanet({ hub = true, galaxyStarType = "unknown" })
            == "assets/planet/planet_hub.png",
        "R1: unknown hub types must use the hub fallback")
    assert(api.planetImagePathForPlanet({ isShop = true })
            == "assets/planet/planet_shop.png",
        "R1: untyped shops must use the shop fallback")
    assert(api.planetImagePathForPlanet({ galaxyStarType = "lava" })
            == "assets/planet/pp_lava.png",
        "R1: typed planets must use their PixelPlanets sprite")
    assert(api.planetImagePathForPlanet({ galaxyStarType = "unknown" })
            == "assets/planet/planet_generic.png",
        "R1: unknown planet types must use the generic fallback")

    local playSource = love.filesystem.read("game/scenes/play.lua") or ""
    assert(playSource:find('require%("game%.scenes%.play_planets"%)'),
        "R1: play.lua must delegate planet presentation rules")
    assert(not playSource:find("local function planetColor"),
        "R1: planet tint rules must leave play.lua")
    assert(not playSource:find("function M%.planetVariation"),
        "R1: planet variation rules must leave play.lua")
    assert(not playSource:find("function M%.planetImagePathForPlanet"),
        "R1: planet sprite routing must leave play.lua")

    print("  R1 play_planets module OK")
end

return M
