local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test shop-card extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_shop_card_copy_layout.lua")

    assert(runner:find('require("game.tests.legacy_shop_card_copy_layout").run()', 1, true),
        "R1-C: self_test must delegate shop-card copy/layout checks to the legacy suite")
    assert(not runner:find("INBOX 61(4): shop card 4-line", 1, true),
        "R1-C: shop-card copy/layout test body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted shop-card copy/layout suite must expose run()")
    print("  R1-C self_test shop-card extraction OK")
end

return M