local expedition = require("game.expedition")

local M = {}

function M.run()
    print("  [INBOX 68] admin buttons gone tests...")

    local playSrc = love.filesystem.read("game/scenes/play.lua") or ""
    assert(not playSrc:find("adminButtons", 1, true),
        "INBOX 68: play.lua must not keep an adminButtons table")
    assert(not playSrc:find("adminButtonRect", 1, true),
        "INBOX 68: play.lua must not keep adminButtonRect")

    local layoutSrc = love.filesystem.read("game/scenes/play_layout.lua") or ""
    assert(not layoutSrc:find("adminButtons", 1, true),
        "INBOX 68: play_layout.lua must not define adminButtons")
    assert(not layoutSrc:find("adminButtonRect", 1, true),
        "INBOX 68: play_layout.lua must not define adminButtonRect")
    assert(not layoutSrc:find("admin_speed", 1, true)
            and not layoutSrc:find("admin_hull", 1, true)
            and not layoutSrc:find("admin_yield", 1, true),
        "INBOX 68: speed+/hull+/yield+ HUD stack must leave play_layout")

    local drawSrc = love.filesystem.read("game/scenes/play_scene_draw.lua") or ""
    assert(not drawSrc:find("adminButtons", 1, true),
        "INBOX 68: play_scene_draw.lua must not draw adminButtons")
    assert(not drawSrc:find("adminButtonRect", 1, true),
        "INBOX 68: play_scene_draw.lua must not use adminButtonRect")
    assert(drawSrc:find("self:drawStreakHud()", 1, true),
        "INBOX 68: streak HUD must remain under pause/help")

    local inputSrc = love.filesystem.read("game/scenes/play_input.lua") or ""
    assert(not inputSrc:find("adminButtons", 1, true),
        "INBOX 68: play_input.lua must not hit-test adminButtons")
    assert(not inputSrc:find("adminButtonRect", 1, true),
        "INBOX 68: play_input.lua must not hit-test adminButtonRect")
    assert(not inputSrc:find("adminUpgrade", 1, true),
        "INBOX 68: HUD touch must not call expedition.adminUpgrade")

    assert(type(expedition.adminUpgrade) == "function",
        "INBOX 68: expedition.adminUpgrade may remain as a test helper")

    print("  INBOX 68 admin buttons gone OK")
end

return M
