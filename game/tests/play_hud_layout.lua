local hudLayout = require("game.scenes.play_hud_layout")

local M = {}

function M.run()
    print("  [R1] play_hud_layout module tests...")

    local scene = {
        hullIconSize = 20,
        hullIconGap = 4,
        hpBlockSize = 8,
        hpBlockGap = 2,
    }
    hudLayout.install(scene)

    for _, name in ipairs({
        "hudFontSize", "hudLineStep", "hudPrimaryStatusGap", "hudGalaxyShift",
        "hudOddsLineHeight", "hudBackgroundMaxWidth", "hudBackgroundPad",
    }) do
        assert(type(scene[name]) == "number", "R1: play_hud_layout must install " .. name)
    end
    assert(type(scene.hudHeight) == "function", "R1: play_hud_layout must install hudHeight")
    assert(type(scene.hudBackgroundWidth) == "function",
        "R1: play_hud_layout must install hudBackgroundWidth")

    assert(scene.hudHeight("ascending", {}, 0) == 4 + 3 * scene.hudLineStep,
        "R1: base HUD height must reserve three lines")
    assert(scene.hudHeight("returning", { galaxy = "HOME", best = "BEST 10" }, 0)
            == 4 + 5 * scene.hudLineStep,
        "R1: galaxy and best labels must each reserve one HUD line")

    local font = { getWidth = function(_, text) return #text * 10 end }
    local width = scene.hudBackgroundWidth({ distance = "DIST", cash = "$1" }, font)
    assert(width == 5 + scene.hullIconSize + scene.hullIconGap + 40 + scene.hudBackgroundPad,
        "R1: HUD width must follow the widest icon/text row")
    local capped = scene.hudBackgroundWidth({ distance = string.rep("X", 100) }, font)
    assert(capped == scene.hudBackgroundMaxWidth, "R1: HUD width must remain capped")

    local playSource = love.filesystem.read("game/scenes/play.lua") or ""
    assert(playSource:find('require%("game%.scenes%.play_hud_layout"%)'),
        "R1: play.lua must delegate HUD sizing to play_hud_layout")
    assert(not playSource:find("function M%.hudHeight"),
        "R1: hudHeight implementation must leave play.lua")
    assert(not playSource:find("function M%.hudBackgroundWidth"),
        "R1: hudBackgroundWidth implementation must leave play.lua")

    print("  R1 play_hud_layout module OK")
end

return M
