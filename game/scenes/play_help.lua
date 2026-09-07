-- play_help.lua  — INBOX 61(29): Help (?) button + overlay
-- Provides: drawHelpButton, drawHelpOverlay, hitHelpButton, shouldFreezeUpdate
local i18n = require("game.i18n")
local fonts = require("game.fonts")
local viewport = require("game.viewport")

local PH = {}
local _M

---------------------------------------------------------------------------
-- Help button rect (44×44, RIGHT of pause — closer to minimap edge)
---------------------------------------------------------------------------
function PH.helpButtonRect(pauseBtn)
    return {
        x = pauseBtn.x + pauseBtn.w + 8,
        y = pauseBtn.y,
        w = 44,
        h = 44,
    }
end

---------------------------------------------------------------------------
-- hitHelpButton(self, x, y) — returns true if help button was tapped
---------------------------------------------------------------------------
function PH.hitHelpButton(self, x, y)
    if not _M or self.expedition.phase ~= "ascending" then return false end
    local pb = _M.pauseButton
    if not pb then return false end
    local hb = PH.helpButtonRect(pb)
    return x >= hb.x and x < hb.x + hb.w and y >= hb.y and y < hb.y + hb.h
end

---------------------------------------------------------------------------
-- drawHelpButton(self) — ? icon next to pause, ascending only
---------------------------------------------------------------------------
function PH.drawHelpButton(self)
    if self.expedition.phase ~= "ascending" then return end
    local pb = _M.pauseButton
    if not pb then return end
    local hb = PH.helpButtonRect(pb)
    local cx = hb.x + hb.w / 2
    local cy = hb.y + hb.h / 2
    -- ? text only — no outer circle (user 2026-09-07)
    local prevFont = love.graphics.getFont()
    love.graphics.setFont(fonts.get(22))
    if self.helpOverlayOpen then
        love.graphics.setColor(0.3, 0.6, 1, 0.9)
    else
        love.graphics.setColor(1, 1, 1, 0.5)
    end
    love.graphics.printf("?", hb.x, cy - 11, hb.w, "center")
    love.graphics.setFont(prevFont)
end

---------------------------------------------------------------------------
-- shouldFreezeUpdate(self) — INBOX (48): freeze like pause, no pause menu
---------------------------------------------------------------------------
function PH.shouldFreezeUpdate(self)
    return self.helpOverlayOpen == true
end

---------------------------------------------------------------------------
-- drawHelpOverlay(self) — dark panel with game mechanic descriptions
---------------------------------------------------------------------------
function PH.drawHelpOverlay(self)
    if not self.helpOverlayOpen then return end
    -- Full-screen dim
    love.graphics.setColor(0, 0, 0, 0.65)
    love.graphics.rectangle("fill", 0, 0, viewport.width, viewport.height)
    -- Panel
    local panelW = 600
    local panelH = 520
    local panelX = math.floor((viewport.width - panelW) / 2)
    local panelY = math.floor((viewport.height - panelH) / 2)
    love.graphics.setColor(0.08, 0.06, 0.10, 0.96)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 12, 12)
    love.graphics.setColor(0.3, 0.6, 1, 0.6)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 12, 12)
    love.graphics.setLineWidth(1)
    -- Title
    local prevFont = love.graphics.getFont()
    love.graphics.setFont(fonts.get(32))
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.printf(i18n.t("help_title"), panelX, panelY + 16, panelW, "center")
    -- Help entries
    local entries = {
        "help_luck",
        "help_harvest",
        "help_streak",
        "help_boost",
        "help_synergy",
        "help_slot",
    }
    love.graphics.setFont(fonts.get(18))
    local textX = panelX + 24
    local textW = panelW - 48
    local textY = panelY + 64
    local lineH = 68
    for idx, key in ipairs(entries) do
        local text = i18n.t(key)
        -- Highlight the label part (before ':') in gold
        local label, desc = text:match("^([^:]+):(.+)$")
        if label then
            love.graphics.setColor(0.95, 0.82, 0.28, 1)
            love.graphics.print(label .. ":", textX, textY)
            love.graphics.setColor(0.85, 0.85, 0.88, 0.95)
            local labelW = fonts.get(18):getWidth(label .. ": ")
            love.graphics.printf(desc, textX, textY + 22, textW, "left")
        else
            love.graphics.setColor(0.85, 0.85, 0.88, 0.95)
            love.graphics.printf(text, textX, textY, textW, "left")
        end
        textY = textY + lineH
    end
    -- Close hint
    love.graphics.setFont(fonts.get(14))
    love.graphics.setColor(0.6, 0.6, 0.65, 0.7)
    love.graphics.printf("(tap anywhere to close)", panelX, panelY + panelH - 30, panelW, "center")
    love.graphics.setFont(prevFont)
end

---------------------------------------------------------------------------
-- install(M) — merge public names onto PlayScene class table
---------------------------------------------------------------------------
function PH.install(M)
    _M = M
    M.helpButtonRect      = PH.helpButtonRect
    M.hitHelpButton       = PH.hitHelpButton
    M.drawHelpButton      = PH.drawHelpButton
    M.drawHelpOverlay     = PH.drawHelpOverlay
    M.shouldFreezeUpdate  = PH.shouldFreezeUpdate
end

return PH
