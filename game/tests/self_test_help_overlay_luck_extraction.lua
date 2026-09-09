local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test help-overlay/luck extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_help_overlay_luck.lua")

    assert(runner:find('require("game.tests.legacy_help_overlay_luck").run()', 1, true),
        "R1-C: self_test must delegate help-overlay/luck checks")
    assert(not runner:find("-- INBOX 61(29): help overlay + luck % + ? button", 1, true)
            and not runner:find('luckLine == "LUCK +10%"', 1, true),
        "R1-C: help-overlay/luck body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted help-overlay/luck suite must expose run()")
    assert(suite:find('type(PlayScene.drawHelpOverlay) == "function"', 1, true)
            and suite:find("hb.w == 44 and hb.h == 44", 1, true)
            and suite:find('luckLine == "LUCK +10%"', 1, true)
            and suite:find('i18n.setLocale("en")', 1, true)
            and suite:find('helpSrc:find("drawHelpOverlay"', 1, true),
        "R1-C: extracted suite must retain methods, layout, luck, locale, and source assertions")
    print("  R1-C self_test help-overlay/luck extraction OK")
end

return M