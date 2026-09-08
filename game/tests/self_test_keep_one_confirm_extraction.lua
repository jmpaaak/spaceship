local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test keep-one confirm extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_keep_one_confirm.lua")

    assert(runner:find('require("game.tests.legacy_keep_one_confirm").run()', 1, true),
        "R1-C: self_test must delegate keep-one confirmation checks")
    assert(not runner:find("-- INBOX 61(12): keep-one card text 11px + confirm popup with yes/no", 1, true)
            and not runner:find('"INBOX 61(12): yes button height must be >= 44px, got "', 1, true),
        "R1-C: keep-one confirmation characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted keep-one confirmation suite must expose run()")
    assert(suite:find("btns.yes.h >= 44", 1, true)
            and suite:find("btns.no.h >= 44", 1, true)
            and suite:find("btns.px + btns.pw <= 720", 1, true)
            and suite:find("btns.py + btns.ph <= 1280", 1, true)
            and suite:find("btns.yes.x + btns.yes.w <= btns.px + btns.pw", 1, true)
            and suite:find("btns.no.x + btns.no.w <= btns.px + btns.pw", 1, true)
            and suite:find("PlayScene.keepConfirmBtnH >= 44", 1, true),
        "R1-C: extracted suite must retain touch target, bounds, placement, and button-height contracts")
    print("  R1-C self_test keep-one confirm extraction OK")
end

return M