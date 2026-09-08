local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test launch loadout layout extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_launch_loadout_layout.lua")

    assert(runner:find('require("game.tests.legacy_launch_loadout_layout").run()', 1, true),
        "R1-C: self_test must delegate launch loadout layout checks")
    assert(not runner:find("local earthTopY = earthY - 58", 1, true)
            and not runner:find("PlayScene.launchLoadoutRowStep >= 20", 1, true),
        "R1-C: launch loadout layout characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted launch loadout layout suite must expose run()")
    assert(suite:find("PlayScene.launchLoadoutBoxTop <= earthTopY", 1, true)
            and suite:find("PlayScene.showLaunchLoadoutTitle == false", 1, true),
        "R1-C: extracted suite must retain Earth coverage and hidden-title checks")
    assert(suite:find("PlayScene.launchLoadoutBoxTop >= 700", 1, true)
            and suite:find("PlayScene.launchLoadoutRowStep >= 20", 1, true),
        "R1-C: extracted suite must retain bottom-third placement and row spacing checks")
    assert(suite:find("PlayScene.launchGearBoxW >= 15", 1, true)
            and suite:find("PlayScene.launchGearBoxH >= 21", 1, true),
        "R1-C: extracted suite must retain gear-box sizing checks")
    assert(suite:find("PlayScene.launchTouchArea.right >= 720", 1, true)
            and suite:find("PlayScene.launchTouchArea.bottom >= 1280", 1, true)
            and suite:find("PlayScene.launchLoadoutFontSize >= 12", 1, true),
        "R1-C: extracted suite must retain touch bounds and font-size checks")
    print("  R1-C self_test launch loadout layout extraction OK")
end

return M
