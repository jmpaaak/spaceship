local M = {}

function M.run()
    local PlayScene = require("game.scenes.play")

    assert(PlayScene.collectRadiusPadding == 30,
        "collect radius padding must stay 30")
    local alpha = PlayScene.collectOrbitRingAlpha
    assert(type(alpha) == "number" and alpha >= 0.25 and alpha <= 0.35,
        "collect-orbit ring alpha must be 0.25–0.35, got " .. tostring(alpha))
    assert(PlayScene.collectOrbitRingLineWidth == 1,
        "collect-orbit fallback line width must be 1")
    assert(PlayScene.useCollectOrbitRimSprite == false,
        "opaque rim sprite must stay off; faint circle line only")
    assert(PlayScene.collectOrbitRadius(14) == 44,
        "collectOrbitRadius must be planet.radius + 30")
    assert(type(PlayScene.drawCollectOrbitRing) == "function",
        "drawCollectOrbitRing must be exported for alpha/width assertions")

    local colors, widths, circles, draws = {}, {}, 0, 0
    local previousGraphics = love.graphics
    love.graphics = {
        setColor = function(r, g, b, a)
            colors[#colors + 1] = { r, g, b, a }
        end,
        setLineWidth = function(w)
            widths[#widths + 1] = w
        end,
        getLineWidth = function()
            return 4
        end,
        circle = function(mode, _x, _y, radius)
            circles = circles + 1
            assert(mode == "line", "collect orbit must be a line circle")
            assert(radius == 44, "drawn ring radius must stay planet.radius+30")
        end,
        draw = function()
            draws = draws + 1
        end,
    }
    local dummyRim = { getDimensions = function() return 64, 64 end }
    local usedSprite = PlayScene.drawCollectOrbitRing(0, 0, 14, 0.75, 0.8, 0.85, dummyRim)
    love.graphics = previousGraphics
    assert(usedSprite == false, "rim sprite must not replace the faint line")
    assert(draws == 0, "rim sprite draw must stay skipped")
    assert(circles == 1, "fallback must draw exactly one line circle")
    assert(#colors >= 1 and colors[#colors][4] == alpha,
        "setColor must apply collect-orbit ring alpha")
    assert(widths[1] == 1, "setLineWidth(1) before the faint ring")
    assert(widths[#widths] == 4, "line width must restore after the faint ring")
end

return M
