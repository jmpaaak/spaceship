--- play_gameover.lua — Destroyed-phase layout, keep-one card, Balatro card draw
-- Extracted from play.lua (MODULE_STRUCTURE rule: 800-line limit).
-- Provides: destroyedTouchArea, destroyedPanelY/H, destroyedRestartTextY,
--   destroyedKeepPartRects, keepConfirmPopupW/H/BtnH, keepConfirmButtons,
--   rarityRgb, drawBalatroCard, handleDestroyedTouch
-- Called by play.lua via  require("game.scenes.play_gameover").install(M)

local i18n  = require("game.i18n")
local fonts = require("game.fonts")

local PG = {}

-- Cached reference to PlayScene class table (set by install())
local _M

---------------------------------------------------------------------------
-- destroyedTouchArea — full-canvas tap target for restart
---------------------------------------------------------------------------
local destroyedTouchArea = { top = 0, bottom = 1280, left = 0, right = 720 }
PG.destroyedTouchArea = destroyedTouchArea

---------------------------------------------------------------------------
-- Destroyed-panel layout constants (INBOX 61(17))
---------------------------------------------------------------------------
PG.destroyedPanelY = 340
PG.destroyedPanelH = 560

-- Returns the Y position for "TAP TO START OVER" text on the destroyed screen.
-- When keepPartChoices is empty, center vertically in the panel.
-- When keepPartChoices has items, position near the bottom.
function PG.destroyedRestartTextY(hasChoices)
    if hasChoices then
        return PG.destroyedPanelY + PG.destroyedPanelH - 72
    else
        return PG.destroyedPanelY + math.floor(PG.destroyedPanelH / 2) - 11
    end
end

function PG.destroyedKeepPartRects(choices)
    choices = choices or {}
    local n = #choices
    if n == 0 then return {} end
    local size, gap = 72, 12
    local maxPerRow = 5
    local cols = math.min(n, maxPerRow)
    local rows = math.ceil(n / cols)
    local totalW = cols * size + (cols - 1) * gap
    local startX = math.floor((720 - totalW) / 2)
    local y = 500
    local rects = {}
    for i = 1, n do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        rects[i] = {
            x = startX + col * (size + gap),
            y = y + row * (size + gap),
            w = size, h = size,
            choice = choices[i],
        }
    end
    return rects
end

---------------------------------------------------------------------------
-- Keep-one confirm popup geometry (INBOX 61(12))
---------------------------------------------------------------------------
PG.keepConfirmPopupW = 360
PG.keepConfirmPopupH = 360
PG.keepConfirmBtnH = 48  -- ≥44px touch target

function PG.keepConfirmButtons()
    local pw, ph = PG.keepConfirmPopupW, PG.keepConfirmPopupH
    local px = math.floor((720 - pw) / 2)
    local py = math.floor((1280 - ph) / 2)
    local btnW = 120
    local btnH = PG.keepConfirmBtnH
    local gap = 24
    local btnY = py + ph - btnH - 16
    local yesX = px + pw / 2 - btnW - gap / 2
    local noX = px + pw / 2 + gap / 2
    return {
        px = px, py = py, pw = pw, ph = ph,
        yes = { x = yesX, y = btnY, w = btnW, h = btnH },
        no  = { x = noX,  y = btnY, w = btnW, h = btnH },
    }
end

---------------------------------------------------------------------------
-- rarityRgb — colour helper (shared with play_shop, play_hud)
---------------------------------------------------------------------------
local function rarityRgb(rarity)
    if rarity == "legendary" then return 1.00, 0.72, 0.18 end
    if rarity == "rare" then return 0.35, 0.62, 1.00 end
    if rarity == "uncommon" then return 0.35, 0.82, 0.45 end
    return 0.72, 0.74, 0.78
end
PG.rarityRgb = rarityRgb

---------------------------------------------------------------------------
-- drawBalatroCard — renders a Balatro-style gear card (keep-one screen, etc.)
---------------------------------------------------------------------------
function PG.drawBalatroCard(part, x, y, w, h, selected)
    part = part or {}
    local rr, rg, rb = rarityRgb(part.rarity)
    love.graphics.setColor(0.12, 0.10, 0.14, 0.96)
    love.graphics.rectangle("fill", x, y, w, h, 8, 8)
    love.graphics.setColor(rr, rg, rb, selected and 1 or 0.85)
    love.graphics.setLineWidth(selected and 4 or 2)
    love.graphics.rectangle("line", x, y, w, h, 8, 8)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(rr, rg, rb, 0.18)
    love.graphics.rectangle("fill", x + 4, y + 4, w - 8, 22, 4, 4)
    local prev = love.graphics.getFont()
    love.graphics.setFont(fonts.get(11))
    love.graphics.setColor(rr, rg, rb, 1)
    love.graphics.printf(i18n.rarityLabel(part.rarity), x + 4, y + 6, w - 8, "center")
    -- Part icon centered in card
    local icon = _M and _M.getPartIcon and _M.getPartIcon(part.id)
    if icon then
        love.graphics.setColor(1, 1, 1, 0.85)
        local iw, ih = icon:getDimensions()
        local iconSize = math.min(w, h) * 0.45
        local sc = iconSize / math.max(iw, ih)
        love.graphics.draw(icon, x + w/2, y + h/2, 0, sc, sc, iw/2, ih/2)
    end
    -- INBOX 61(12): name 11px, clipped inside card
    love.graphics.setFont(fonts.get(11))
    love.graphics.setColor(1, 0.98, 0.92, 1)
    love.graphics.setScissor(x, y, w, h)
    love.graphics.printf(i18n.partName(part), x + 4, y + h - 16, w - 8, "center")
    love.graphics.setScissor()
    if prev then love.graphics.setFont(prev) end
end

---------------------------------------------------------------------------
-- handleDestroyedTouch — touch handling for destroyed phase
-- Returns true if the touch was consumed, false otherwise.
---------------------------------------------------------------------------
function PG.handleDestroyedTouch(scene, x, y)
    local M = _M
    -- INBOX 61(12): confirm popup yes/no handling
    if scene.keepPartConfirm then
        local btns = PG.keepConfirmButtons()
        if btns then
            if x >= btns.yes.x and x < btns.yes.x + btns.yes.w
               and y >= btns.yes.y and y < btns.yes.y + btns.yes.h then
                scene.expedition.keptPart = scene.keepPartConfirm
                scene.keepPartConfirm = nil
                return true
            end
            if x >= btns.no.x and x < btns.no.x + btns.no.w
               and y >= btns.no.y and y < btns.no.y + btns.no.h then
                scene.keepPartConfirm = nil
                return true
            end
        end
        return true  -- absorb all taps while popup is open
    end
    local choices = scene.expedition.keepPartChoices or {}
    if #choices > 0 then
        for _, rect in ipairs(PG.destroyedKeepPartRects(choices)) do
            if x >= rect.x and x < rect.x + rect.w and y >= rect.y and y < rect.y + rect.h then
                -- INBOX 61(12): open confirm popup instead of immediate keep
                scene.keepPartConfirm = rect.choice
                return true
            end
        end
    end
    local area = destroyedTouchArea
    if x >= area.left and x < area.right and y >= area.top and y < area.bottom then
        scene:keypressed("space")
        return true
    end
    return false
end

---------------------------------------------------------------------------
-- install(M) — copy all symbols onto the PlayScene class table
---------------------------------------------------------------------------
function PG.install(M)
    _M = M
    M.destroyedTouchArea       = destroyedTouchArea
    M.destroyedPanelY          = PG.destroyedPanelY
    M.destroyedPanelH          = PG.destroyedPanelH
    M.destroyedRestartTextY    = PG.destroyedRestartTextY
    M.destroyedKeepPartRects   = PG.destroyedKeepPartRects
    M.keepConfirmPopupW        = PG.keepConfirmPopupW
    M.keepConfirmPopupH        = PG.keepConfirmPopupH
    M.keepConfirmBtnH          = PG.keepConfirmBtnH
    M.keepConfirmButtons       = PG.keepConfirmButtons
    M.rarityRgb                = rarityRgb
    M.drawBalatroCard          = PG.drawBalatroCard
    M.handleDestroyedTouch     = PG.handleDestroyedTouch
end

return PG
