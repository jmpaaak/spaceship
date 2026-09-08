local M = {}

function M.run()
    local PlayScene = require("game.scenes.play")
    local viewport = require("game.viewport")

    assert(PlayScene.hudBackgroundMaxWidth == 280,
        "HUD background must cap at ~280px for 22px font (item 41)")
    assert(type(PlayScene.hudBackgroundWidth) == "function",
        "hudBackgroundWidth must measure left-text width for the HUD fill")
    local font = {
        getWidth = function(_, text) return #tostring(text) * 8 end,
        getHeight = function() return 14 end,
    }
    local hud = {
        distance = "DIST 0",
        cash = "CASH $0",
        status = "H3/3 LAUNCH",
        best = "RECORD 0",
        galaxy = "SOLAR SYSTEM",
        samples = "SAMPLES 03  AT RISK $95",
    }
    local w = PlayScene.hudBackgroundWidth(hud, font)
    assert(w <= PlayScene.hudBackgroundMaxWidth,
        "HUD fill must not exceed hudBackgroundMaxWidth, got " .. tostring(w))
    assert(w < viewport.width,
        "HUD fill must not span the full viewport width")
    assert(w > 80, "HUD fill must still cover left text+icons, got " .. tostring(w))

    local huge = PlayScene.hudBackgroundWidth({
        distance = string.rep("W", 80),
        cash = string.rep("W", 80),
        status = string.rep("W", 80),
        samples = string.rep("W", 80),
    }, font)
    assert(huge == PlayScene.hudBackgroundMaxWidth,
        "oversized HUD text must still cap at hudBackgroundMaxWidth")
end

return M