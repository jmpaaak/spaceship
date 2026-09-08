local M = {}

function M.run()
    -- Legacy panel/overlay wiring: the helper remains exported, gracefully
    -- rejects nil images, draws panel art at native size, and retains 8 slots.
    local PlayScene = require("game.scenes.play")
    assert(type(PlayScene.drawPanelSprite) == "function",
        "drawPanelSprite must be exported on PlayScene")

    local ok, res = pcall(PlayScene.drawPanelSprite, nil, 0, 0, 100, 50)
    assert(ok, "drawPanelSprite(nil,...) must not throw")
    assert(res == false, "drawPanelSprite(nil,...) must return false")

    -- A 64x64 panel must not stretch to the 720px viewport. Keep native pixel
    -- size until a dedicated 9-slice or tile implementation replaces it.
    local fakeImage = {}
    function fakeImage:getDimensions()
        return 64, 64
    end
    local captured = nil
    local previousGraphics = love.graphics
    love.graphics = {
        draw = function(_, x, y, r, sx, sy)
            captured = {
                x = x,
                y = y,
                r = r or 0,
                sx = sx == nil and 1 or sx,
                sy = sy == nil and 1 or sy,
            }
        end,
    }
    local drawOk, drawRes = pcall(PlayScene.drawPanelSprite, fakeImage, 0, 0, 720, 32)
    love.graphics = previousGraphics
    assert(love.graphics == previousGraphics,
        "drawPanelSprite characterization must restore love.graphics")
    assert(drawOk, "drawPanelSprite(fake 64x64, dest 720x32) must not throw: " .. tostring(drawRes))
    assert(drawRes == true, "drawPanelSprite with an image must return true")
    assert(captured ~= nil, "drawPanelSprite must call love.graphics.draw")
    assert(captured.sx == 1 and captured.sy == 1,
        "drawPanelSprite must draw at native pixel size, not stretch 64x64 to 720x32 (got sx="
            .. tostring(captured.sx) .. " sy=" .. tostring(captured.sy) .. ")")
    assert(math.abs(captured.sx * 64 - 64) < 1e-9,
        "drawn width must stay native 64px, not viewport.width")

    local scene = PlayScene.new()
    for _, key in ipairs({
        "launchRocketIconImage", "loadoutPanelImage", "loadoutShipImage",
        "settlementPanelImage", "destroyedPanelImage",
        "relaunChImage", "slotResultPanelImage", "slotSpinButtonImage",
    }) do
        assert(scene[key] == nil or type(scene[key]) == "userdata",
            key .. " must be nil (headless) or image userdata")
    end
end

return M
