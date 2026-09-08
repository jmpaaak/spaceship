local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test planet effect sprite extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_planet_effect_sprite.lua")

    assert(runner:find('require("game.tests.legacy_planet_effect_sprite").run()', 1, true),
        "R1-C: self_test must delegate planet effect sprite checks")
    assert(not runner:find("drawPlanetEffectSprite must be exported on PlayScene", 1, true)
            and not runner:find("scene.planetEffectImages must be a table", 1, true),
        "R1-C: planet effect sprite characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted planet effect sprite suite must expose run()")
    assert(suite:find("drawPlanetEffectSprite(nil,...) must return false", 1, true)
            and suite:find('{"glow","shadow","rim","twinkle","sampleValue","risk"}', 1, true),
        "R1-C: extracted suite must retain false-return and six image-slot contracts")
    print("  R1-C self_test planet effect sprite extraction OK")
end

return M