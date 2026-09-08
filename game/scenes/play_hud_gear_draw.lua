-- Equipped-gear HUD rendering, isolated from the oversized play scene.
local M = {}

local function rarityColor(graphics, rarity)
    if rarity == "legendary" then graphics.setColor(1, 0.6, 0, 0.7)
    elseif rarity == "rare" then graphics.setColor(0.3, 0.6, 1, 0.7)
    elseif rarity == "uncommon" then graphics.setColor(0.4, 0.8, 0.4, 0.7)
    else graphics.setColor(0.5, 0.5, 0.5, 0.7) end
end

local function drawSlots(graphics, slots, parts, getPartIcon)
    for i, rect in ipairs(slots) do
        local part = parts[i]
        if part then
            rarityColor(graphics, part.rarity)
            graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h)
            local icon = getPartIcon(part.id)
            if icon then
                graphics.setColor(1, 1, 1, 0.9)
                local iw, ih = icon:getDimensions()
                local scale = (rect.w - 4) / math.max(iw, ih)
                graphics.draw(icon, rect.x + rect.w / 2, rect.y + rect.h / 2,
                    0, scale, scale, iw / 2, ih / 2)
            end
            graphics.setColor(0.1, 0.1, 0.1, 1)
            graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h)
        else
            graphics.setColor(0.3, 0.35, 0.45, 0.5)
            graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h)
        end
    end
end

function M.install(scene, deps)
    -- Resolve graphics lazily because headless tests install their stub after loading play.lua.
    local configuredGraphics = deps.graphics
    local fonts = assert(deps.fonts, "play_hud_gear_draw requires fonts")
    local i18n = assert(deps.i18n, "play_hud_gear_draw requires i18n")
    local getPartIcon = assert(deps.getPartIcon, "play_hud_gear_draw requires getPartIcon")

    function scene.drawHudGearSlots(subject, hudHeight)
        local graphics = configuredGraphics or love.graphics
        local run = subject.expedition
        local layout = scene.hudGearSlotLayout(hudHeight)
        subject.hudGearLabelFont = subject.hudGearLabelFont
            or fonts.get(scene.hudGearLabelFontSize)
        local previousFont = graphics.getFont()
        graphics.setFont(subject.hudGearLabelFont)
        graphics.setColor(0.5, 0.6, 0.7, 0.7)
        graphics.printf(i18n.t("hud_hull_label"), 5, layout.labelY, 200, "left")
        drawSlots(graphics, layout.hull, run.equippedGear or {}, getPartIcon)
        graphics.setColor(0.5, 0.6, 0.7, 0.7)
        graphics.printf(i18n.t("hud_engine_label"), 5, layout.engineLabelY, 200, "left")
        drawSlots(graphics, layout.engine, run.equippedEngineParts or {}, getPartIcon)
        if previousFont then graphics.setFont(previousFont) end
    end
end

return M
