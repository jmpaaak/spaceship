--- play_hud.lua — Gear popup tooltip + pause overlay, extracted from play.lua
-- Provides: drawGearPopup, drawPauseOverlay
-- Called by play.lua via  require("game.scenes.play_hud").install(M)

local i18n       = require("game.i18n")
local fonts      = require("game.fonts")
local viewport   = require("game.viewport")

local PH = {}

-- Cached reference to PlayScene class table (set by install())
local _M

---------------------------------------------------------------------------
-- rarityRgb — colour helper (duplicated in play.lua, play_shop.lua)
---------------------------------------------------------------------------
local function rarityRgb(rarity)
    if rarity == "legendary" then return 1.00, 0.72, 0.18 end
    if rarity == "rare" then return 0.35, 0.62, 1.00 end
    if rarity == "uncommon" then return 0.35, 0.82, 0.45 end
    return 0.72, 0.74, 0.78
end
PH.rarityRgb = rarityRgb

---------------------------------------------------------------------------
-- drawGearPopup(self) — Balatro-style gear tooltip next to the slot
---------------------------------------------------------------------------
function PH.drawGearPopup(self)
    if not (self.gearPopup and self.gearPopup.part) then return end
    local M = _M
    local part = self.gearPopup.part
    local rr, rg, rb = rarityRgb(part.rarity)
    -- Balatro-style: small tooltip next to the gear slot, not full-screen overlay
    local slotIdx = self.gearPopup.slotIndex or 0
    local slotRect = self.gearPopup.slotRect
    local tipW, tipH = 320, 256
    local tipX, tipY
    if slotRect then
        tipX = slotRect.x + slotRect.w + 8
        tipY = slotRect.y
        if tipX + tipW > viewport.width - 8 then
            tipX = slotRect.x - tipW - 8
        end
        if tipY + tipH > viewport.height - 8 then
            tipY = viewport.height - 8 - tipH
        end
    else
        tipX = math.floor((viewport.width - tipW) / 2)
        tipY = 420
    end
    -- Semi-transparent bg (not full overlay)
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", 0, 0, viewport.width, viewport.height)
    -- Tooltip body
    love.graphics.setColor(0.10, 0.08, 0.12, 0.96)
    love.graphics.rectangle("fill", tipX, tipY, tipW, tipH, 10, 10)
    love.graphics.setColor(rr, rg, rb, 1)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", tipX, tipY, tipW, tipH, 10, 10)
    love.graphics.setLineWidth(1)
    local prevPopupFont = love.graphics.getFont()
    -- Part icon in popup (top-right corner)
    local getPartIcon = M.getPartIcon
    local popupIcon = getPartIcon and getPartIcon(part.id)
    if popupIcon then
        love.graphics.setColor(1, 1, 1, 0.9)
        local piw, pih = popupIcon:getDimensions()
        local psc = 40 / math.max(piw, pih)
        love.graphics.draw(popupIcon, tipX + tipW - 36, tipY + 12, 0, psc, psc, piw/2, 0)
    end
    -- Part name (large, white-gold)
    love.graphics.setFont(fonts.get(22))
    love.graphics.setColor(1, 0.98, 0.92, 1)
    love.graphics.printf(i18n.partName(part), tipX + 12, tipY + 12, tipW - 24, "center")
    -- Effects with highlighted numbers (gold numbers, white text)
    local effectsY = tipY + 44
    love.graphics.setFont(fonts.get(22))
    for _, eff in ipairs(part.effects or {}) do
        local line = i18n.effectLine(eff)
        love.graphics.setColor(0.95, 0.82, 0.28, 1)
        love.graphics.printf(line, tipX + 12, effectsY, tipW - 24, "center")
        effectsY = effectsY + 28
    end
    -- Rarity + Suit chips (vertical stack: one chip per line)
    local chipY2 = effectsY + 8
    local chipFont = fonts.get(22)
    love.graphics.setFont(chipFont)
    local rarLabel = i18n.rarityLabel(part.rarity)
    local rarW = chipFont:getWidth(rarLabel) + 24
    local rarH = 30
    local chipsCenterX = tipX + tipW / 2
    -- Rarity chip (centered)
    local rarX = chipsCenterX - rarW / 2
    love.graphics.setColor(rr, rg, rb, 0.85)
    love.graphics.rectangle("fill", rarX, chipY2, rarW, rarH, 6, 6)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(rarLabel, rarX, chipY2 + 4, rarW, "center")
    -- Suit chip (centered, below rarity)
    local suitLabel = i18n.suitLabel(part.suit)
    local hasSuit = suitLabel ~= ""
    if hasSuit then
        local suitColors = {
            solar = {1, 0.82, 0.2},
            nebula = {0.7, 0.3, 0.9},
            void = {0.2, 0.3, 0.8},
            pulsar = {0.1, 0.85, 0.95},
        }
        local sc = suitColors[part.suit] or {0.5, 0.5, 0.5}
        local suitW = chipFont:getWidth(suitLabel) + 24
        local suitX = chipsCenterX - suitW / 2
        local suitY = chipY2 + rarH + 6
        love.graphics.setColor(sc[1], sc[2], sc[3], 0.85)
        love.graphics.rectangle("fill", suitX, suitY, suitW, rarH, 6, 6)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(suitLabel, suitX, suitY + 4, suitW, "center")
        chipY2 = suitY  -- update for synergy hint positioning
    end
    -- Synergy hint: two lines (name at 22px, desc at 11px) (INBOX item 6)
    local hint = i18n.synergyHint(part.suit)
    if hint.name ~= "" then
        local gearMod = require("game.gear")
        local syn = gearMod.activeSynergies(
            self.expedition.equippedGear or {},
            self.expedition.equippedEngineParts or {})
        local suitSynergyKeys = {
            solar = "solarSystem", nebula = "nebulaField",
            void = "eventHorizon", pulsar = "pulsarBurst",
        }
        local synKey = suitSynergyKeys[part.suit]
        local isActive = synKey and syn[synKey]
        local hintY = chipY2 + rarH + 8
        -- Line 1: synergy name (22px, gold pulse if active, grey if not)
        love.graphics.setFont(fonts.get(22))
        if isActive then
            local pulse = 0.7 + 0.3 * math.sin((self.uiTime or self.time or 0) * 3)
            love.graphics.setColor(1.0, 0.85, 0.3, pulse)
        else
            love.graphics.setColor(0.55, 0.55, 0.55, 0.7)
        end
        love.graphics.printf(hint.name, tipX + 12, hintY, tipW - 24, "center")
        -- Line 2: condition desc (11px)
        local nameH = fonts.get(22):getHeight()
        love.graphics.setFont(fonts.get(11))
        if isActive then
            love.graphics.setColor(1.0, 0.92, 0.5, 0.9)
        else
            love.graphics.setColor(0.55, 0.55, 0.55, 0.6)
        end
        love.graphics.printf(hint.desc, tipX + 12, hintY + nameH + 2, tipW - 24, "center")
    end
    love.graphics.setFont(prevPopupFont)
end

---------------------------------------------------------------------------
-- drawPauseOverlay(self) — INBOX 61(21) pause with restart/main-menu
---------------------------------------------------------------------------
function PH.drawPauseOverlay(self)
    if not (self.paused and self.expedition.phase == "ascending") then return end
    local M = _M
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 0, viewport.width, viewport.height)
    love.graphics.setColor(1, 1, 1, 0.95)
    local pauseFont = fonts.get(48)
    local prevFont = love.graphics.getFont()
    love.graphics.setFont(pauseFont)
    love.graphics.printf(i18n.t("paused_label"), 0, viewport.height / 2 - 100, viewport.width, "center")
    -- Pause menu buttons
    local btnFont = fonts.get(32)
    love.graphics.setFont(btnFont)
    local rects = M.pauseMenuRects()
    -- Restart button
    love.graphics.setColor(0.08, 0.14, 0.22, 0.9)
    love.graphics.rectangle("fill", rects.restart.x, rects.restart.y, rects.restart.w, rects.restart.h, 10, 10)
    love.graphics.setColor(0.3, 0.6, 1, 0.8)
    love.graphics.rectangle("line", rects.restart.x, rects.restart.y, rects.restart.w, rects.restart.h, 10, 10)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.printf(i18n.t("pause_restart"), rects.restart.x, rects.restart.y + rects.restart.h / 2 - 14, rects.restart.w, "center")
    -- Main menu button
    love.graphics.setColor(0.08, 0.14, 0.22, 0.9)
    love.graphics.rectangle("fill", rects.mainMenu.x, rects.mainMenu.y, rects.mainMenu.w, rects.mainMenu.h, 10, 10)
    love.graphics.setColor(0.9, 0.4, 0.2, 0.8)
    love.graphics.rectangle("line", rects.mainMenu.x, rects.mainMenu.y, rects.mainMenu.w, rects.mainMenu.h, 10, 10)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.printf(i18n.t("pause_main_menu"), rects.mainMenu.x, rects.mainMenu.y + rects.mainMenu.h / 2 - 14, rects.mainMenu.w, "center")
    love.graphics.setFont(prevFont)
end

---------------------------------------------------------------------------
-- install(M) — merge public names onto PlayScene class table
---------------------------------------------------------------------------
function PH.install(M)
    _M = M
    M.drawGearPopup     = PH.drawGearPopup
    M.drawPauseOverlay  = PH.drawPauseOverlay
end

return PH
