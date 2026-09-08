local playDraw = require("game.scenes.play_draw")

local M = {}

function M.run()
    print("  [R1] play_draw module tests...")

    local scene = {
        collectOrbitRadius = function(radius) return radius + 7 end,
        collectOrbitRingAlpha = 0.25,
        collectOrbitRingLineWidth = 2,
        useCollectOrbitRimSprite = false,
    }
    playDraw.install(scene)

    for _, name in ipairs({
        "drawHudSpriteOrPoly", "drawPlanetEffectSprite",
        "drawCollectOrbitRing", "drawFloatingIconSprite", "drawPanelSprite",
        "drawShopIconSprite", "drawStarPointSprite", "drawPixelStar",
    }) do
        assert(type(scene[name]) == "function", "R1: play_draw must install " .. name)
    end

    assert(scene.drawPanelSprite(nil, 0, 0, 10, 10) == false,
        "R1: nil panel sprite must preserve fallback signal")
    assert(scene.drawFloatingIconSprite(nil, 0, 0, 10, 1) == false,
        "R1: nil floating icon must preserve fallback signal")

    local playSource = love.filesystem.read("game/scenes/play.lua") or ""
    assert(playSource:find('require%("game%.scenes%.play_draw"%)'),
        "R1: play.lua must delegate draw helpers to play_draw")
    assert(not playSource:find("local function drawPixelStar"),
        "R1: sprite draw implementation must leave play.lua")

    print("  R1 play_draw module OK")
end

return M
