local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test planet-sheet extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_planet_sheet_sprites.lua")

    assert(runner:find('require("game.tests.legacy_planet_sheet_sprites").run()', 1, true),
        "R1-C: self_test must delegate planet-sheet sprite checks")
    assert(not runner:find("-- INBOX 61(14): planet sheet PNGs must be RGBA", 1, true)
            and not runner:find('"INBOX 61(14): sheet must load with mock graphics', 1, true),
        "R1-C: planet-sheet characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted planet-sheet suite must expose run()")

    for _, name in ipairs({ "ice", "lava", "dry", "gas", "earth", "bare" }) do
        assert(suite:find('assets/planet/pp_' .. name .. '_sheet.png', 1, true),
            "R1-C: extracted suite must retain " .. name .. " sheet coverage")
    end
    assert(suite:find('PlayScene.pngColorType("assets/planet/hub_sheet.png")', 1, true)
            and suite:find("PlayScene.shouldLoadRuntimeSprite(path) == true", 1, true),
        "R1-C: extracted suite must retain RGBA and runtime-gate checks")
    assert(suite:find('love.filesystem.read = function() return nil, "Mobile memory limit simulation" end', 1, true)
            and suite:find('io.open = function() return nil, "Mobile absolute path simulation" end', 1, true)
            and suite:find('PlayScene.loadSprite("assets/planet/pp_ice_sheet.png")', 1, true)
            and suite:find('PlayScene.loadSprite("assets/planet/pp_ice.png")', 1, true),
        "R1-C: extracted suite must retain mobile-failure sprite-load fallback coverage")
    print("  R1-C self_test planet-sheet extraction OK")
end

return M