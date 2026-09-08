-- Launch-screen equipped-gear rendering, isolated from the oversized play scene.
local M = {}

local function rarityColor(graphics, rarity)
    if rarity == "legendary" then graphics.setColor(1, 0.6, 0)
    elseif rarity == "rare" then graphics.setColor(0.3, 0.6, 1)
    elseif rarity == "uncommon" then graphics.setColor(0.4, 0.8, 0.4)
    else graphics.setColor(0.7, 0.7, 0.7) end
end

local function drawPart(graphics, rect, part, emptyColor, getPartIcon)
    if not part then
        graphics.setColor(emptyColor[1], emptyColor[2], emptyColor[3], emptyColor[4])
        graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h)
        return
    end

    rarityColor(graphics, part.rarity)
    graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h)
    local icon = getPartIcon(part.id)
    if icon then
        graphics.setColor(1, 1, 1, 0.8)
        local iw, ih = icon:getDimensions()
        local scale = (math.min(rect.w, rect.h) - 2) / math.max(iw, ih)
        graphics.draw(icon, rect.x + rect.w / 2, rect.y + rect.h / 2,
            0, scale, scale, iw / 2, ih / 2)
    end

    if part.edition and part.edition ~= "base" then
        graphics.setColor(1, 1, 0.5, 0.8)
        graphics.rectangle("line", rect.x - 1, rect.y - 1, rect.w + 2, rect.h + 2)
    else
        graphics.setColor(0.1, 0.1, 0.1, 1)
        graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h)
    end
end

function M.install(scene, deps)
    local configuredGraphics = deps.graphics
    local fonts = assert(deps.fonts, "play_loadout_draw requires fonts")
    local i18n = assert(deps.i18n, "play_loadout_draw requires i18n")
    local viewport = assert(deps.viewport, "play_loadout_draw requires viewport")
    local getPartIcon = assert(deps.getPartIcon, "play_loadout_draw requires getPartIcon")

    function scene.drawGearSlots(subject, y)
        local graphics = configuredGraphics or love.graphics
        local hullSlots, engineSlots = 6, 3
        local boxW, boxH = scene.launchGearBoxW, scene.launchGearBoxH
        local gap, groupGap = 5, 12
        local run = subject.expedition
        local hullGear = run.equippedGear or {}
        local engineGear = run.equippedEngineParts or {}
        local hullWidth = hullSlots * boxW + (hullSlots - 1) * gap
        local totalWidth = hullWidth + groupGap
            + engineSlots * boxW + (engineSlots - 1) * gap
        local startX = math.floor((viewport.width - totalWidth) / 2)

        subject.tinyFont = subject.tinyFont or fonts.get(22)
        local previousFont = graphics.getFont()
        graphics.setFont(subject.tinyFont)

        for i = 1, hullSlots do
            drawPart(graphics, {
                x = startX + (i - 1) * (boxW + gap), y = y, w = boxW, h = boxH,
            }, hullGear[i], {0.3, 0.35, 0.45, 0.6}, getPartIcon)
        end

        local engineStartX = startX + hullWidth + groupGap
        for i = 1, engineSlots do
            drawPart(graphics, {
                x = engineStartX + (i - 1) * (boxW + gap), y = y, w = boxW, h = boxH,
            }, engineGear[i], {0.45, 0.35, 0.3, 0.6}, getPartIcon)
        end

        graphics.setColor(0.6, 0.7, 0.8, 0.9)
        graphics.printf(i18n.t("equipped_gear_label"), 0, y - 28, viewport.width, "center")
        graphics.setFont(previousFont)
    end
end

return M