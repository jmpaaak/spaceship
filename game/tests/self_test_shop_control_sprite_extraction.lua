local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test shop/control sprite extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_shop_control_sprite.lua")

    assert(runner:find('require("game.tests.legacy_shop_control_sprite").run()', 1, true),
        "R1-C: self_test must delegate shop/control sprite checks")
    assert(not runner:find("drawShopIconSprite must be exported on PlayScene", 1, true)
            and not runner:find('"joystickPadImage", "joystickKnobImage"', 1, true),
        "R1-C: shop/control sprite characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted shop/control sprite suite must expose run()")
    assert(suite:find("drawShopIconSprite(nil,...) must return false", 1, true)
            and suite:find("drawStarPointSprite(nil,...) must return false", 1, true)
            and suite:find("specimenBannerImage", 1, true)
            and suite:find('"hull", "steering", "yield", "ship"', 1, true),
        "R1-C: extracted suite must retain nil returns and all image-slot contracts")
    print("  R1-C self_test shop/control sprite extraction OK")
end

return M