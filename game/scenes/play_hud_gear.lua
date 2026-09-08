-- Pure layout and hit testing for the equipped-gear HUD columns.
-- Rendering stays in the play scene; this module has no love.* dependency.
local M = {}

function M.install(scene)
    scene.hudGearSlotSize = 48
    scene.hudGearSlotGap = 4
    scene.hudGearLabelFontSize = 22

    function scene.hudGearSlotLayout(hudHeight)
        local slotSize = scene.hudGearSlotSize
        local gap = scene.hudGearSlotGap
        local groupGap = 8
        local labelY = (hudHeight or 0) + 2
        local gridStartY = labelY + scene.hudGearLabelFontSize + 4
        local startX = 5
        local hull = {}
        for i = 1, 6 do
            hull[i] = {
                x = startX,
                y = gridStartY + (i - 1) * (slotSize + gap),
                w = slotSize,
                h = slotSize,
            }
        end
        local engineLabelY = gridStartY + 6 * (slotSize + gap) + groupGap
        local engineStartY = engineLabelY + scene.hudGearLabelFontSize + 4
        local engine = {}
        for i = 1, 3 do
            engine[i] = {
                x = startX,
                y = engineStartY + (i - 1) * (slotSize + gap),
                w = slotSize,
                h = slotSize,
            }
        end
        return {
            hull = hull,
            engine = engine,
            labelY = labelY,
            engineLabelY = engineLabelY,
        }
    end

    function scene.hitHudGearSlot(subject, x, y)
        if not subject or not subject.expedition then return nil end
        local hud = subject.hudLines and subject:hudLines() or {}
        local hudHeight = scene.hudHeight(subject.expedition.phase, hud, 0)
        local layout = scene.hudGearSlotLayout(hudHeight)
        local hullGear = subject.expedition.equippedGear or {}
        local engineGear = subject.expedition.equippedEngineParts or {}
        for i, rect in ipairs(layout.hull) do
            if x >= rect.x and x < rect.x + rect.w and y >= rect.y and y < rect.y + rect.h then
                if hullGear[i] then
                    return { part = hullGear[i], category = "hull", index = i, rect = rect }
                end
                return nil
            end
        end
        for i, rect in ipairs(layout.engine) do
            if x >= rect.x and x < rect.x + rect.w and y >= rect.y and y < rect.y + rect.h then
                if engineGear[i] then
                    return { part = engineGear[i], category = "engine", index = i, rect = rect }
                end
                return nil
            end
        end
        return nil
    end
end

return M
