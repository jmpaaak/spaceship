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
    assert(api.planetImagePathForPlanet({ hub = true, galaxyStarType = "gas" })
            == "assets/planet/pp_gas.png",
        "INBOX 78: ordinary-planet candidates must not replace hub artwork")
    assert(api.planetImagePathForPlanet({ hub = true, galaxyStarType = "unknown" })
            == "assets/planet/planet_hub.png",
        "R1: unknown hub types must use the hub fallback")
    assert(api.planetImagePathForPlanet({ isShop = true })
            == "assets/planet/planet_shop.png",
        "R1: untyped shops must use the shop fallback")
    assert(api.planetImagePathForPlanet({ galaxyStarType = "lava" })
            == "assets/planet/studio/pp_lava_nasa_pia00703.png",
        "INBOX 78: ordinary lava planets must use the approved Asset Studio derivative")
    assert(api.planetImagePathForPlanet({ galaxyStarType = "unknown" })
            == "assets/planet/planet_generic.png",
        "R1: unknown planet types must use the generic fallback")

    local studioPaths = api.studioPlanetImagePaths()
    assert(studioPaths.bare == "assets/planet/studio/pp_bare.png",
        "INBOX 78: bare planets must load the approved Asset Studio runtime derivative")
    assert(studioPaths.gas == "assets/planet/studio/pp_gas.png",
        "INBOX 78: gas planets must load the approved Asset Studio runtime derivative")
    assert(studioPaths.dry == "assets/planet/studio/pp_dry.png",
        "INBOX 78: dry planets must load the approved Asset Studio runtime derivative")
    assert(studioPaths.ice == "assets/planet/studio/pp_ice_nasa_pia00353.png",
        "INBOX 78: ice planets must load the approved Asset Studio runtime derivative")
    assert(studioPaths.lava == "assets/planet/studio/pp_lava_nasa_pia00703.png",
        "INBOX 78: lava planets must load the approved Asset Studio runtime derivative")

    local legacyBare = {}
    local legacyBareSheet = {}
    local studioBare = {}
    local sprite, sheet = api.selectPlanetArtwork({ galaxyStarType = "bare" }, {
        default = {},
        pixel = { bare = legacyBare },
        sheets = { bare = legacyBareSheet },
        studio = { bare = studioBare },
    })
    assert(sprite == studioBare and sheet == nil,
        "INBOX 78: a decoded studio candidate must take priority over the legacy animation sheet")

    sprite, sheet = api.selectPlanetArtwork({ galaxyStarType = "bare" }, {
        default = {},
        pixel = { bare = legacyBare },
        sheets = { bare = legacyBareSheet },
        studio = {},
    })
    assert(sprite == legacyBare and sheet == legacyBareSheet,
        "INBOX 78: a failed studio image load must preserve the existing legacy fallback")

    local legacyGas = {}
    local legacyGasSheet = {}
    local studioGas = {}
    sprite, sheet = api.selectPlanetArtwork({ galaxyStarType = "gas" }, {
        default = {},
        pixel = { gas = legacyGas },
        sheets = { gas = legacyGasSheet },
        studio = { gas = studioGas },
    })
    assert(sprite == studioGas and sheet == nil,
        "INBOX 78: decoded gas studio artwork must take priority over the legacy sheet")

    sprite, sheet = api.selectPlanetArtwork({ galaxyStarType = "gas" }, {
        default = {},
        pixel = { gas = legacyGas },
        sheets = { gas = legacyGasSheet },
        studio = {},
    })
    assert(sprite == legacyGas and sheet == legacyGasSheet,
        "INBOX 78: failed gas studio loading must preserve the legacy gas artwork")

    local legacyDry = {}
    local legacyDrySheet = {}
    local studioDry = {}
    sprite, sheet = api.selectPlanetArtwork({ galaxyStarType = "dry" }, {
        default = {},
        pixel = { dry = legacyDry },
        sheets = { dry = legacyDrySheet },
        studio = { dry = studioDry },
    })
    assert(sprite == studioDry and sheet == nil,
        "INBOX 78: decoded dry studio artwork must take priority over the legacy sheet")

    sprite, sheet = api.selectPlanetArtwork({ galaxyStarType = "dry" }, {
        default = {},
        pixel = { dry = legacyDry },
        sheets = { dry = legacyDrySheet },
        studio = {},
    })
    assert(sprite == legacyDry and sheet == legacyDrySheet,
        "INBOX 78: failed dry studio loading must preserve the legacy dry artwork")

    sprite, sheet = api.selectPlanetArtwork({ hub = true, galaxyStarType = "dry" }, {
        default = {},
        pixel = { dry = legacyDry },
        sheets = { dry = legacyDrySheet },
        studio = { dry = studioDry },
        hubSheet = legacyDrySheet,
    })
    assert(sprite == legacyDry and sheet == legacyDrySheet,
        "INBOX 78: ordinary dry studio artwork must not replace hub artwork")

    local legacyIce = {}
    local legacyIceSheet = {}
    local studioIce = {}
    sprite, sheet = api.selectPlanetArtwork({ galaxyStarType = "ice" }, {
        default = {},
        pixel = { ice = legacyIce },
        sheets = { ice = legacyIceSheet },
        studio = { ice = studioIce },
    })
    assert(sprite == studioIce and sheet == nil,
        "INBOX 78: decoded ice studio artwork must take priority over the legacy sheet")

    sprite, sheet = api.selectPlanetArtwork({ galaxyStarType = "ice" }, {
        default = {},
        pixel = { ice = legacyIce },
        sheets = { ice = legacyIceSheet },
        studio = {},
    })
    assert(sprite == legacyIce and sheet == legacyIceSheet,
        "INBOX 78: failed ice studio loading must preserve the legacy ice artwork")

    sprite, sheet = api.selectPlanetArtwork({ hub = true, galaxyStarType = "ice" }, {
        default = {},
        pixel = { ice = legacyIce },
        sheets = { ice = legacyIceSheet },
        studio = { ice = studioIce },
        hubSheet = legacyIceSheet,
    })
    assert(sprite == legacyIce and sheet == legacyIceSheet,
        "INBOX 78: ordinary ice studio artwork must not replace hub artwork")

    sprite, sheet = api.selectPlanetArtwork({ isShop = true, galaxyStarType = "ice" }, {
        default = {},
        pixel = { ice = legacyIce },
        sheets = { ice = legacyIceSheet },
        studio = { ice = studioIce },
        shopSprite = legacyIce,
    })
    assert(sprite == legacyIce and sheet == legacyIceSheet,
        "INBOX 78: ordinary ice studio artwork must not replace shop artwork")

    local legacyLava = {}
    local legacyLavaSheet = {}
    local studioLava = {}
    sprite, sheet = api.selectPlanetArtwork({ galaxyStarType = "lava" }, {
        default = {},
        pixel = { lava = legacyLava },
        sheets = { lava = legacyLavaSheet },
        studio = { lava = studioLava },
    })
    assert(sprite == studioLava and sheet == nil,
        "INBOX 78: decoded lava studio artwork must take priority over the legacy sheet")

    sprite, sheet = api.selectPlanetArtwork({ galaxyStarType = "lava" }, {
        default = {},
        pixel = { lava = legacyLava },
        sheets = { lava = legacyLavaSheet },
        studio = {},
    })
    assert(sprite == legacyLava and sheet == legacyLavaSheet,
        "INBOX 78: failed lava studio loading must preserve the legacy lava artwork")

    sprite, sheet = api.selectPlanetArtwork({ hub = true, galaxyStarType = "lava" }, {
        default = {},
        pixel = { lava = legacyLava },
        sheets = { lava = legacyLavaSheet },
        studio = { lava = studioLava },
        hubSheet = legacyLavaSheet,
    })
    assert(sprite == legacyLava and sheet == legacyLavaSheet,
        "INBOX 78: ordinary lava studio artwork must not replace hub artwork")

    sprite, sheet = api.selectPlanetArtwork({ isShop = true, galaxyStarType = "lava" }, {
        default = {},
        pixel = { lava = legacyLava },
        sheets = { lava = legacyLavaSheet },
        studio = { lava = studioLava },
        shopSprite = legacyLava,
    })
    assert(sprite == legacyLava and sheet == legacyLavaSheet,
        "INBOX 78: ordinary lava studio artwork must not replace shop artwork")

    local hubGas = {}
    local hubGasSheet = {}
    sprite, sheet = api.selectPlanetArtwork({ hub = true, galaxyStarType = "gas" }, {
        default = {},
        pixel = { gas = hubGas },
        sheets = { gas = legacyGasSheet },
        studio = { gas = studioGas },
        hubSheet = hubGasSheet,
    })
    assert(sprite == hubGas and sheet == hubGasSheet,
        "INBOX 78: ordinary-planet studio artwork must not replace hub artwork")

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
