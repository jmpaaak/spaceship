local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test PixelPlanets planet-sprite extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_pixelplanets_planet_sprite.lua")

    assert(runner:find('require("game.tests.legacy_pixelplanets_planet_sprite").run()', 1, true),
        "R1-C: self_test must delegate PixelPlanets planet-sprite checks")
    assert(not runner:find("-- INBOX (12): PixelPlanets planet sprites", 1, true)
            and not runner:find("local ppTypes =", 1, true),
        "R1-C: PixelPlanets planet-sprite characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted PixelPlanets planet-sprite suite must expose run()")
    assert(suite:find('local ppTypes = { "ice", "lava", "dry", "gas", "earth", "bare" }', 1, true)
            and suite:find("PlayScene.pngColorType(path)", 1, true)
            and suite:find("validTypes[g.starType]", 1, true),
        "R1-C: extracted suite must retain RGBA PNG and galaxy starType coverage")
    assert(suite:find("p.galaxyStarType == fg.starType", 1, true)
            and suite:find('assets/planet/studio/pp_ice_nasa_pia00353.png', 1, true)
            and suite:find('assets/planet/studio/hub_saturn.png', 1, true)
            and suite:find('assets/planet/planet_generic.png', 1, true),
        "R1-C: extracted suite must retain planet mapping and image-path contracts")
    print("  R1-C self_test PixelPlanets planet-sprite extraction OK")
end

return M