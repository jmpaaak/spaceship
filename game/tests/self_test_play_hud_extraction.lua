local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test play-hud extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_play_hud_extraction.lua")

    assert(runner:find('require("game.tests.legacy_play_hud_extraction").run()', 1, true),
        "R1-C: self_test must delegate play-hud extraction checks")
    assert(not runner:find("-- INBOX 61(32) play_hud.lua extraction test", 1, true)
            and not runner:find('hudSrc:find("drawGearPopup"', 1, true),
        "R1-C: play-hud extraction body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted play-hud suite must expose run()")
    assert(suite:find('type(PlayScene.drawGearPopup) == "function"', 1, true)
            and suite:find('type(PlayScene.drawPauseOverlay) == "function"', 1, true)
            and suite:find('hudSrc:find("synergyHint"', 1, true)
            and suite:find("Balatro%-style: small tooltip next to the gear slot", 1, true),
        "R1-C: extracted suite must retain installed methods, source location, and removed-inline checks")
    print("  R1-C self_test play-hud extraction OK")
end

return M