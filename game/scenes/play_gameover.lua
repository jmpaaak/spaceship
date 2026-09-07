-- play_gameover.lua: game-over screen drawing extracted from play.lua (INBOX-32)
-- Draws the destroyed phase panel, keep-one card choices, and confirm popup.
-- play.lua delegates via M:drawGameOver() called inside M:draw().
local viewport  = require("game.viewport")
local i18n      = require("game.i18n")
local fonts     = require("game.fonts")

local M = {}

-- Inline rarityRgb (mirrors play.lua local function rarityRgb).
local function rarityRgb(rarity)
    if rarity == "legendary" then return 1, 0.72, 0.18
    elseif rarity == "rare"  then return 0.35, 0.62, 1
    elseif rarity == "uncommon" then return 0.35, 0.82, 0.45
    else return 0.72, 0.74, 0.78 end
end

-- Inline drawPanelSprite (mirrors play.lua local drawPanelSprite).
local function drawPanelSprite(image, x, y, _w, _h)
    if not image then return false end
    love.graphics.draw(image, x, y)
    return true
end

-- Draw the game-over (destroyed) panel, card choices, and keep-one confirm popup.
-- self: PlayScene; P: play module (for layout constants and helpers).
function M.drawGameOver(self, P)
    local panelX, panelW = 24, viewport.width - 48
    local panelY, panelH = P.destroyedPanelY, P.destroyedPanelH
    love.graphics.setColor(1, 1, 1, 0.94)
    if not drawPanelSprite(self.destroyedPanelImage, panelX, panelY, panelW, panelH) then
        love.graphics.setColor(0.08, 0.02, 0.03, 0.94)
        love.graphics.rectangle("fill", panelX, panelY, panelW, panelH)
    end
    local previousFont = love.graphics.getFont()
    love.graphics.setFont(fonts.get(33))
    love.graphics.setColor(0.62, 0.64, 0.68, 0.85)
    love.graphics.printf(i18n.t("ship_destroyed_title"), panelX, panelY + 36, panelW, "center")
    love.graphics.setFont(fonts.get(22))
    love.graphics.setColor(0.7, 0.72, 0.76, 0.85)
    love.graphics.printf(i18n.t("meta_reset_line", math.floor(self.expedition.bestAltitude)),
        panelX, panelY + 92, panelW, "center")
    local choices = self.expedition.keepPartChoices or {}
    if #choices > 0 then
        love.graphics.setColor(0.65, 0.68, 0.72, 0.8)
        love.graphics.printf(i18n.t("keep_part_hint"), panelX, panelY + 150, panelW, "center")
        local rects = P.destroyedKeepPartRects(choices)
        local kept = self.expedition.keptPart
        for _, rect in ipairs(rects) do
            local selected = kept and kept.part and rect.choice.part
                and kept.part.id == rect.choice.part.id
                and kept.category == rect.choice.category
            P.drawBalatroCard(rect.choice.part, rect.x, rect.y, rect.w, rect.h, selected)
        end
        love.graphics.setColor(0.6, 0.6, 0.6, 0.7)
        love.graphics.printf(i18n.t("tap_start_over"), panelX, P.destroyedRestartTextY(true), panelW, "center")
    else
        love.graphics.setColor(0.6, 0.6, 0.6, 0.7)
        love.graphics.printf(i18n.t("tap_start_over"), panelX, P.destroyedRestartTextY(false), panelW, "center")
    end
    -- Keep-one confirm popup overlay
    if self.keepPartConfirm and self.keepPartConfirm.part then
        local cp = self.keepPartConfirm.part
        local rr, rg, rb = rarityRgb(cp.rarity)
        local btns = P.keepConfirmButtons()
        love.graphics.setColor(0, 0, 0, 0.55)
        love.graphics.rectangle("fill", 0, 0, viewport.width, viewport.height)
        love.graphics.setColor(0.10, 0.08, 0.12, 0.97)
        love.graphics.rectangle("fill", btns.px, btns.py, btns.pw, btns.ph, 10, 10)
        love.graphics.setColor(rr, rg, rb, 1)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", btns.px, btns.py, btns.pw, btns.ph, 10, 10)
        love.graphics.setLineWidth(1)
        love.graphics.setFont(fonts.get(22))
        love.graphics.setColor(1, 0.98, 0.92, 1)
        love.graphics.printf(i18n.partName(cp), btns.px + 12, btns.py + 14, btns.pw - 24, "center")
        local ey = btns.py + 46
        love.graphics.setFont(fonts.get(18))
        for _, eff in ipairs(cp.effects or {}) do
            love.graphics.setColor(0.95, 0.82, 0.28, 1)
            love.graphics.printf(i18n.effectLine(eff), btns.px + 12, ey, btns.pw - 24, "center")
            ey = ey + 24
        end
        local chipFont = fonts.get(18)
        love.graphics.setFont(chipFont)
        local rarLabel = i18n.rarityLabel(cp.rarity)
        local rarW = chipFont:getWidth(rarLabel) + 20
        local rarH2 = 26
        local chipCX = btns.px + btns.pw / 2
        love.graphics.setColor(rr, rg, rb, 0.85)
        love.graphics.rectangle("fill", chipCX - rarW/2, ey + 6, rarW, rarH2, 5, 5)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(rarLabel, chipCX - rarW/2, ey + 9, rarW, "center")
        local suitLabel = i18n.suitLabel(cp.suit)
        if suitLabel ~= "" then
            local suitColors = {
                solar = {1, 0.82, 0.2}, nebula = {0.7, 0.3, 0.9},
                void = {0.2, 0.3, 0.8}, pulsar = {0.1, 0.85, 0.95},
            }
            local sc2 = suitColors[cp.suit] or {0.5, 0.5, 0.5}
            local suitW = chipFont:getWidth(suitLabel) + 20
            love.graphics.setColor(sc2[1], sc2[2], sc2[3], 0.85)
            love.graphics.rectangle("fill", chipCX - suitW/2, ey + 6 + rarH2 + 4, suitW, rarH2, 5, 5)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf(suitLabel, chipCX - suitW/2, ey + 9 + rarH2 + 4, suitW, "center")
            ey = ey + rarH2 + 4
        end
        local hint = i18n.synergyHint(cp.suit)
        if hint.name ~= "" then
            local synY = ey + rarH2 + 14
            love.graphics.setFont(fonts.get(16))
            love.graphics.setColor(0.95, 0.82, 0.28, 0.9)
            love.graphics.printf(hint.name, btns.px + 12, synY, btns.pw - 24, "center")
            love.graphics.setFont(fonts.get(11))
            love.graphics.setColor(0.7, 0.7, 0.7, 0.8)
            love.graphics.printf(hint.desc, btns.px + 12, synY + 20, btns.pw - 24, "center")
        end
        love.graphics.setFont(fonts.get(22))
        love.graphics.setColor(0.2, 0.65, 0.3, 0.9)
        love.graphics.rectangle("fill", btns.yes.x, btns.yes.y, btns.yes.w, btns.yes.h, 8, 8)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(i18n.t("keep_yes"), btns.yes.x, btns.yes.y + 12, btns.yes.w, "center")
        love.graphics.setColor(0.6, 0.2, 0.2, 0.9)
        love.graphics.rectangle("fill", btns.no.x, btns.no.y, btns.no.w, btns.no.h, 8, 8)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(i18n.t("keep_no"), btns.no.x, btns.no.y + 12, btns.no.w, "center")
    end
    love.graphics.setFont(previousFont)
end

return M
