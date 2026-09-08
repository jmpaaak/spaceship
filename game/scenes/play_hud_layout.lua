-- HUD band sizing rules extracted from the oversized play scene.
-- Rendering and input remain in their scene modules; this module only computes layout.
local M = {}

function M.install(scene)
    scene.hudFontSize = 22
    scene.hudLineStep = 30
    scene.hudPrimaryStatusGap = 6
    scene.hudGalaxyShift = 30
    scene.hudOddsLineHeight = 0
    scene.hudBackgroundMaxWidth = 280
    scene.hudBackgroundPad = 8

    function scene.hudHeight(phase, hud, galaxyShift)
        -- phase and galaxyShift remain accepted for compatibility with existing callers.
        local lines = 3 -- distance, cash, status
        if hud and hud.galaxy then lines = lines + 1 end
        if hud and hud.best then lines = lines + 1 end
        return 4 + lines * scene.hudLineStep
    end

    function scene.hudBackgroundWidth(hud, font)
        hud = hud or {}
        local function textWidth(text)
            if not text or text == "" then return 0 end
            if font and font.getWidth then return font:getWidth(text) end
            return 0
        end
        local icon = scene.hullIconSize
        local gap = scene.hullIconGap
        local left = 5
        local widest = 0
        local function consider(right)
            if right > widest then widest = right end
        end

        if hud.galaxy then consider(left + icon + gap + textWidth(hud.galaxy)) end
        consider(left + icon + gap + textWidth(hud.distance))
        consider(left + icon + gap + textWidth(hud.cash))
        if hud.maxDurability then
            local blocksWidth = hud.maxDurability * scene.hpBlockSize
                + math.max(0, hud.maxDurability - 1) * scene.hpBlockGap
            consider(left + icon + gap + blocksWidth)
        elseif hud.status then
            consider(left + icon + gap + textWidth(hud.status))
        end
        if hud.best then consider(left + icon + gap + textWidth(hud.best)) end
        if hud.earth then consider(left + icon + gap + textWidth(hud.earth)) end
        if hud.returnProgress then consider(left + icon + gap + textWidth(hud.returnProgress)) end

        return math.min(widest + scene.hudBackgroundPad, scene.hudBackgroundMaxWidth)
    end
end

return M
