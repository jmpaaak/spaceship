local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test destroyed/launch touch extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_destroyed_launch_touch.lua")

    assert(runner:find('require("game.tests.legacy_destroyed_launch_touch").run()', 1, true),
        "R1-C: self_test must delegate destroyed/launch touch checks")
    assert(not runner:find("local destroyedArea = PlayScene.destroyedTouchArea", 1, true)
            and not runner:find("local launchArea = PlayScene.launchTouchArea", 1, true),
        "R1-C: destroyed/launch touch characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted destroyed/launch touch suite must expose run()")
    assert(suite:find("destroyedAreaPoints >= 44", 1, true)
            and suite:find("launchAreaPoints >= 44", 1, true),
        "R1-C: extracted suite must retain both 44pt touch-size checks")
    assert(suite:find('destroyedTouchScene.expedition.phase == "ascending"', 1, true)
            and suite:find('launchTouchScene.expedition.phase == "ascending"', 1, true),
        "R1-C: extracted suite must retain destroyed restart and launch actions")
    assert(suite:find("local function cornersAndCenter", 1, true)
            and suite:find("cornersAndCenter(destroyedArea)", 1, true)
            and suite:find("cornersAndCenter(launchArea)", 1, true),
        "R1-C: extracted suite must retain corner and center tap coverage")
    print("  R1-C self_test destroyed/launch touch extraction OK")
end

return M