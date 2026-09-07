--- play_shop.lua — Settlement shop + destroyed overlay, extracted from play.lua
-- Provides: drawSettlementOverlay, drawDestroyedOverlay
-- Called by play.lua via  require("game.scenes.play_shop").install(M)

local i18n       = require("game.i18n")
local fonts      = require("game.fonts")
local viewport   = require("game.viewport")
local expedition = require("game.expedition")

local PS = {}

-- Cached reference to PlayScene class table (set by install())
local _M

---------------------------------------------------------------------------
-- rarityRgb — shared colour helper (also used by drawBalatroCard in play.lua)
---------------------------------------------------------------------------
local function rarityRgb(rarity)
    if rarity == "legendary" then return 1.00, 0.72, 0.18 end
    if rarity == "rare" then return 0.35, 0.62, 1.00 end
    if rarity == "uncommon" then return 0.35, 0.82, 0.45 end
    return 0.72, 0.74, 0.78
end
PS.rarityRgb = rarityRgb

---------------------------------------------------------------------------
-- reelWindowToScissor — convert game-space reel window to screen scissor.
-- love.graphics.setScissor is screen-space; after main.lua translate+scale
-- a game-coord scissor clips the wrong region (empty window on mobile).
---------------------------------------------------------------------------
function PS.reelWindowToScissor(rx, ry, rw, rh, transformPoint)
    transformPoint = transformPoint or (love.graphics and love.graphics.transformPoint)
    if type(transformPoint) ~= "function" then
        return rx, ry, rw, rh
    end
    local sx, sy = transformPoint(rx, ry)
    local sx2, sy2 = transformPoint(rx + rw, ry + rh)
    local x = math.min(sx, sx2)
    local y = math.min(sy, sy2)
    return x, y, math.abs(sx2 - sx), math.abs(sy2 - sy)
end

-- Large in-window letter when a reel icon image is missing.
function PS.drawReelFallbackText(symbol, rx, ry, rw, rh)
    local letter = string.sub(tostring(symbol or "?"), 1, 1)
    local prevFont = love.graphics.getFont()
    local size = math.max(18, math.floor(rh * 0.72))
    local ok, font = pcall(function()
        return fonts.get(size)
    end)
    if ok and font then
        love.graphics.setFont(font)
    end
    local fh = (love.graphics.getFont() and love.graphics.getFont():getHeight()) or size
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(letter, rx, ry + (rh - fh) / 2, rw, "center")
    if prevFont then love.graphics.setFont(prevFont) end
end

---------------------------------------------------------------------------
-- drawSettlementOverlay(self) — settlement shop UI
---------------------------------------------------------------------------
function PS.drawSettlementOverlay(self)
    local M = _M
    local drawPanelSprite = M.drawPanelSprite
    local previousFont = love.graphics.getFont()
    love.graphics.setFont(fonts.get(M.settlementFontSize))
    local summaryExtraLine
    if self.expedition.lastNewBest then
        summaryExtraLine = i18n.t("newbest_label")
    end

    love.graphics.setColor(1, 1, 1, 0.94)
    if not drawPanelSprite(self.settlementPanelImage, 0, M.settlementPanelTop, viewport.width, M.settlementPanelHeight) then
        love.graphics.setColor(0.02, 0.03, 0.08, 0.94)
        love.graphics.rectangle("fill", 0, M.settlementPanelTop, viewport.width, M.settlementPanelHeight)
    end

    local titleStr = self.expedition.lastVisitedGalaxyId and i18n.t("hub_shop_label") or i18n.t("earth_shop_label")
    if titleStr then
        love.graphics.setColor(1, 0.9, 0.5)
        love.graphics.printf(titleStr, 0, M.settlementTitleY, viewport.width, "center")
    end

    love.graphics.setColor(1, 1, 1, 0.9)
    local shopEff = self.shopEffectImages or {}
    -- Summary stats removed (user 2026-09-07): title only, no total/samples/altitude

    local nextLaunch = self:shopLoadoutLines()
    local shopColumnLeftX  = M.shopColumnLeftX
    local shopColumnLeftW  = M.shopColumnLeftW
    local shopColumnRightX = M.shopColumnRightX
    local shopColumnRightW = M.shopColumnRightW
    local fullX, fullW = 24, viewport.width - 48
    local rowStep = M.settlementRowStep
    local touchRowHeight = M.settlementTouchRowHeight

    -- Helper: Balatro-style shop card button with hover effect
    -- 4 lines vertically centered: title / desc / price / balance
    local function drawShopItem(rowTop, leftX, leftW, actionImg, statusImg, previewImg, actionText, statusText, previewText, isAffordable, iconImg, isHovered, descLine)
        local cardH = touchRowHeight - 16
        local cardY = rowTop + 8
        love.graphics.setColor(0.08, 0.06, 0.12, 0.92)
        love.graphics.rectangle("fill", leftX + 4, cardY, leftW - 8, cardH, 8, 8)
        if isAffordable then
            love.graphics.setColor(0.3, 0.85, 0.4, 0.8)
        else
            love.graphics.setColor(0.6, 0.25, 0.2, 0.6)
        end
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", leftX + 4, cardY, leftW - 8, cardH, 8, 8)
        love.graphics.setLineWidth(1)
        -- Parse: extract label, values, price from actionText
        local actionLabel = actionText
        local valuesLabel = ""
        local priceLabel = ""
        local priceStart = string.find(actionText, "%$%d")
        if priceStart then
            priceLabel = string.sub(actionText, priceStart)
            local beforePrice = string.sub(actionText, 1, priceStart - 2)
            local splitAt = string.find(beforePrice, "[%d%+%-x]")
            if splitAt then
                actionLabel = string.sub(beforePrice, 1, splitAt - 1):match("^(.-)%s*$") or ""
                valuesLabel = string.sub(beforePrice, splitAt):match("^%s*(.-)%s*$") or ""
            else
                actionLabel = beforePrice
            end
        end
        -- Use descLine override for 2nd line if provided (e.g. scout tradeoff)
        if descLine and descLine ~= "" then
            valuesLabel = descLine
        end
        -- 4 lines vertically centered in card, 22px font, ~26px line height
        local numLines = 4
        local lineH = 26
        local totalTextH = numLines * lineH
        local startY = cardY + math.floor((cardH - totalTextH) / 2)
        -- Line 1: title (white)
        love.graphics.setColor(1, 0.95, 0.9, 1)
        love.graphics.printf(actionLabel, leftX + 8, startY, leftW - 16, "center")
        -- Line 2: values or desc (light grey)
        love.graphics.setColor(0.75, 0.75, 0.8, 0.9)
        love.graphics.printf(valuesLabel, leftX + 8, startY + lineH, leftW - 16, "center")
        -- Line 3: price (gold)
        love.graphics.setColor(1, 0.85, 0.25, 1)
        love.graphics.printf(priceLabel, leftX + 8, startY + lineH * 2, leftW - 16, "center")
        -- Line 4: balance (subtle)
        love.graphics.setColor(isAffordable and 0.5 or 0.9, isAffordable and 0.9 or 0.35, isAffordable and 0.6 or 0.3, 0.7)
        love.graphics.printf(statusText, leftX + 8, startY + lineH * 3, leftW - 16, "center")
    end

    local shopIcons = self.shopIconImages or {}
    local r1 = M.settlementTouchRows[1].top
    drawShopItem(r1, shopColumnLeftX, shopColumnLeftW, shopEff.hullAction, shopEff.hullStatus, shopEff.hullPreview, nextLaunch.hullActionCompact, nextLaunch.hullStatus, nextLaunch.hullPreviewCompact, nextLaunch.hullAffordable, shopIcons.hull, self.hoverRow == 1 and self.hoverCol == "left")
    drawShopItem(r1, shopColumnRightX, shopColumnRightW, shopEff.steeringAction, shopEff.steeringStatus, shopEff.steeringPreview, nextLaunch.steeringActionCompact, nextLaunch.steeringStatus, nextLaunch.steeringPreviewCompact, nextLaunch.steeringAffordable, shopIcons.steering, self.hoverRow == 1 and self.hoverCol == "right")

    local r2 = M.settlementTouchRows[2].top
    local shopIconsYS = self.shopIconImages or {}
    drawShopItem(r2, shopColumnLeftX, shopColumnLeftW, shopEff.yieldAction, shopEff.yieldStatus, shopEff.yieldPreview, nextLaunch.yieldActionCompact, nextLaunch.yieldStatus, nextLaunch.yieldPreview, nextLaunch.yieldAffordable, shopIconsYS.yield, self.hoverRow == 2 and self.hoverCol == "left")
    if not nextLaunch.shipHidden then
        drawShopItem(r2, shopColumnRightX, shopColumnRightW, shopEff.shipAction, shopEff.shipStatus, shopEff.shipPreview, nextLaunch.shipActionCompact, nextLaunch.shipStatus, nextLaunch.shipPreviewCompact, nextLaunch.shipAffordable, shopIconsYS.ship, self.hoverRow == 2 and self.hoverCol == "right", nextLaunch.shipTradeoffLine)
    else
        -- INBOX-30: show "SCOUT ✓" label in ship slot when scout is active
        local row = r2 + 8 + rowStep
        love.graphics.setColor(0.45, 1, 0.55)
        love.graphics.printf("SCOUT \226\156\147", shopColumnRightX, row, shopColumnRightW, "center")
    end

    local r3 = M.settlementTouchRows[3].top
    -- INBOX 61(18): compact row3 — center gear text vertically in 70px row
    local row = r3 + math.floor((M.settlementTouchRows[3].bottom - r3 - 22) / 2)
    if self.earthShopGearOffer then
        local offer = self.earthShopGearOffer
        local gearMod = require("game.gear")
        local price = expedition.shopPrice(self.expedition, gearMod.buyPrice(offer))
        love.graphics.setColor(0.4, 1, 0.7)
        love.graphics.printf(i18n.t("earth_gear_offer", offer.name, price), fullX, row, fullW, "center")
    elseif self.expedition.lastVisitedGalaxyId then
        -- INBOX 61(16): hub-only restock button when gear offer is empty
        local restockCost = expedition.hubRestockCost or 5
        local canAfford = self.expedition.money >= restockCost
        if canAfford then
            love.graphics.setColor(0.3, 0.85, 0.5)
        else
            love.graphics.setColor(0.6, 0.3, 0.3)
        end
        love.graphics.printf(i18n.t("hub_restock_btn", restockCost), fullX, row, fullW, "center")
    end

    local r4 = M.settlementTouchRows[4].top
    row = r4 + 4
    -- Always show slot machine (spinning or idle)
    do
        love.graphics.setColor(1, 1, 1, 1)
        local slotScale = 3
        local slotW = 96 * slotScale
        local mx = fullX + (fullW - slotW) / 2
        local my = row
        -- Slot shake effect
        local shakeX, shakeY = 0, 0
        if (self.slotShake or 0) > 0 then
            self.slotShake = self.slotShake - (love.timer and love.timer.getDelta() or 0.016)
            shakeX = (math.random() - 0.5) * 8
            shakeY = (math.random() - 0.5) * 6
        end
        mx = mx + shakeX
        my = my + shakeY
        if self.slotMachineImage then
            love.graphics.draw(self.slotMachineImage, mx, my, 0, slotScale, slotScale)
        end
        -- Lever: red handle that pulls down on each spin touch
        local leverX = mx + 91 * slotScale
        local leverTopY = my + 4 * slotScale
        local leverBotY = my + 40 * slotScale
        local leverPull = 0
        if self.slotLeverPull and self.slotLeverPull > 0 then
            leverPull = self.slotLeverPull * 60
            self.slotLeverPull = self.slotLeverPull - (love.timer and love.timer.getDelta() or 0.016) * 4
            if self.slotLeverPull < 0 then self.slotLeverPull = 0 end
        end
        -- Lever rod (grey)
        love.graphics.setColor(0.55, 0.55, 0.55)
        love.graphics.setLineWidth(4)
        love.graphics.line(leverX, leverTopY, leverX, leverBotY + leverPull)
        love.graphics.setLineWidth(1)
        -- Lever ball (red, big)
        love.graphics.setColor(0.9, 0.15, 0.1)
        love.graphics.circle("fill", leverX, leverBotY + leverPull, 10)

        -- Draw reels (spinning or static icons)
        if self.earthShopSlotResult or (self.slotState and self.slotState.spinning) then
            local rKeys = {"MONEY", "PART", "SPEED", "DURABILITY", "HARVEST"}
            local reelWindowW = 24 * slotScale
            local reelWindowH = 32 * slotScale
            local symSize = 32
            for i = 1, 3 do
                local rx = mx + (8 + (i - 1) * 28) * slotScale
                local ry = my + 8 * slotScale
                local sx, sy, sw, sh = PS.reelWindowToScissor(rx, ry, reelWindowW, reelWindowH)
                love.graphics.setScissor(sx, sy, sw, sh)
                local rState = self.slotState and self.slotState.reels[i]
                local drawSym = self.earthShopSlotResult and self.earthShopSlotResult.symbols[i] or "MONEY"
                local yOff = 0
                if rState then
                    yOff = (rState.y % 32) * slotScale
                    if not rState.stopped then
                        drawSym = rKeys[math.random(1, #rKeys)]
                    else
                        drawSym = rState.sym
                    end
                end
                local symImg = self.slotSymbolImages and self.slotSymbolImages[drawSym]
                local symScale = reelWindowW / symSize * 0.85
                local symOffX = (reelWindowW - symSize * symScale) / 2
                local symOffY = (reelWindowH - symSize * symScale) / 2
                if symImg then
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.draw(symImg, rx + symOffX, ry + symOffY + yOff - reelWindowH, 0, symScale, symScale)
                    love.graphics.draw(symImg, rx + symOffX, ry + symOffY + yOff, 0, symScale, symScale)
                else
                    PS.drawReelFallbackText(drawSym, rx, ry, reelWindowW, reelWindowH)
                end
                love.graphics.setScissor()
            end
        else
            -- Idle: show static icons with gentle glow pulse, rotating through all 5 symbols
            local allSyms = {"MONEY", "SPEED", "HARVEST", "DURABILITY", "PART"}
            local idleCycle = math.floor((self.time or 0) / 2) % #allSyms
            local rKeys = {}
            for i = 0, 2 do
                rKeys[i + 1] = allSyms[(idleCycle + i) % #allSyms + 1]
            end
            local reelWindowW = 24 * slotScale
            local reelWindowH = 32 * slotScale
            local symSize = 32
            local pulse = 0.7 + 0.3 * math.sin((self.time or 0) * 2)
            for i = 1, 3 do
                local rx = mx + (8 + (i - 1) * 28) * slotScale
                local ry = my + 8 * slotScale
                local sx, sy, sw, sh = PS.reelWindowToScissor(rx, ry, reelWindowW, reelWindowH)
                love.graphics.setScissor(sx, sy, sw, sh)
                local symImg = self.slotSymbolImages and self.slotSymbolImages[rKeys[i]]
                if symImg then
                    local symScale = reelWindowW / symSize * 0.85
                    local symOffX = (reelWindowW - symSize * symScale) / 2
                    local symOffY = (reelWindowH - symSize * symScale) / 2
                    love.graphics.setColor(1, 1, 1, pulse)
                    love.graphics.draw(symImg, rx + symOffX, ry + symOffY, 0, symScale, symScale)
                else
                    PS.drawReelFallbackText(rKeys[i], rx, ry, reelWindowW, reelWindowH)
                end
                love.graphics.setScissor()
            end
        end

        -- Result text / cost below slot
        local belowY = my + 48 * slotScale + 4
        if self.earthShopSlotResult or (self.slotState and self.slotState.spinning) then
            local profileLabel = self.earthShopSlotResult and M.earthSlotProfileLabel(self.earthShopSlotResult.rewardProfile)
            if profileLabel then
                love.graphics.setColor(1, 0.55, 0.45)
                love.graphics.printf(profileLabel, fullX, belowY, fullW, "center")
                belowY = belowY + 26
            end
            if self.slotResultMessage then
                love.graphics.setColor(1, 0.9, 0.5)
                love.graphics.printf(self.slotResultMessage, fullX, belowY, fullW, "center")
            end
        else
            -- Cost label below idle slot
            local spinCost = expedition.slotSpinCostFor(self.expedition, self.expedition.lastVisitedGalaxyId)
            love.graphics.setFont(fonts.get(22))
            love.graphics.setColor(1, 0.85, 0.25, 1)
            love.graphics.printf(i18n.t("earth_slot_spin_prompt"), fullX, belowY, fullW, "center")
            belowY = belowY + 26
            love.graphics.printf("$" .. spinCost, fullX, belowY, fullW, "center")
            love.graphics.setFont(fonts.get(M.settlementFontSize))
        end
    end

    -- Row 5: only gray "tap to relaunch" text, nothing else
    local r5 = M.settlementTouchRows[5].top
    row = r5 + touchRowHeight - rowStep - 8
    love.graphics.setColor(0.6, 0.6, 0.6, 0.7)
    love.graphics.printf(i18n.t("tap_relaunch"), fullX, row, fullW, "center")

    love.graphics.setFont(previousFont)
end

---------------------------------------------------------------------------
-- drawDestroyedOverlay(self) — game-over / destroyed UI
---------------------------------------------------------------------------
function PS.drawDestroyedOverlay(self)
    local M = _M
    local drawPanelSprite = M.drawPanelSprite
    local panelX, panelW = 24, viewport.width - 48
    local panelY, panelH = M.destroyedPanelY, M.destroyedPanelH
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
        love.graphics.printf(i18n.t("keep_part_hint"), panelX, panelY + 130, panelW, "center")
        local rects = M.destroyedKeepPartRects(choices)
        local kept = self.expedition.keptPart
        for _, rect in ipairs(rects) do
            local selected = kept and kept.part and rect.choice.part
                and kept.part.id == rect.choice.part.id
                and kept.category == rect.choice.category
            M.drawBalatroCard(rect.choice.part, rect.x, rect.y, rect.w, rect.h, selected)
        end
        love.graphics.setColor(0.6, 0.6, 0.6, 0.7)
        love.graphics.printf(i18n.t("tap_start_over"), panelX, M.destroyedRestartTextY(true), panelW, "center")
    else
        -- No items to keep: center the restart prompt vertically
        love.graphics.setColor(0.6, 0.6, 0.6, 0.7)
        love.graphics.printf(i18n.t("tap_start_over"), panelX, M.destroyedRestartTextY(false), panelW, "center")
    end
    -- INBOX 61(12): keep-one confirm popup overlay
    if self.keepPartConfirm and self.keepPartConfirm.part then
        local cp = self.keepPartConfirm.part
        local rr, rg, rb = rarityRgb(cp.rarity)
        local btns = M.keepConfirmButtons()
        -- Dim background
        love.graphics.setColor(0, 0, 0, 0.55)
        love.graphics.rectangle("fill", 0, 0, viewport.width, viewport.height)
        -- Popup body
        love.graphics.setColor(0.10, 0.08, 0.12, 0.97)
        love.graphics.rectangle("fill", btns.px, btns.py, btns.pw, btns.ph, 10, 10)
        love.graphics.setColor(rr, rg, rb, 1)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", btns.px, btns.py, btns.pw, btns.ph, 10, 10)
        love.graphics.setLineWidth(1)
        -- Title
        love.graphics.setFont(fonts.get(22))
        love.graphics.setColor(1, 0.98, 0.92, 1)
        love.graphics.printf(i18n.partName(cp), btns.px + 12, btns.py + 14, btns.pw - 24, "center")
        -- Effects
        local ey = btns.py + 46
        love.graphics.setFont(fonts.get(18))
        for _, eff in ipairs(cp.effects or {}) do
            love.graphics.setColor(0.95, 0.82, 0.28, 1)
            love.graphics.printf(i18n.effectLine(eff), btns.px + 12, ey, btns.pw - 24, "center")
            ey = ey + 24
        end
        -- Rarity chip
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
        -- Suit chip
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
        -- Synergy hint (two lines)
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
        -- Yes / No buttons
        love.graphics.setFont(fonts.get(22))
        -- YES button
        love.graphics.setColor(0.2, 0.65, 0.3, 0.9)
        love.graphics.rectangle("fill", btns.yes.x, btns.yes.y, btns.yes.w, btns.yes.h, 8, 8)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(i18n.t("keep_yes"), btns.yes.x, btns.yes.y + 12, btns.yes.w, "center")
        -- NO button
        love.graphics.setColor(0.6, 0.2, 0.2, 0.9)
        love.graphics.rectangle("fill", btns.no.x, btns.no.y, btns.no.w, btns.no.h, 8, 8)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(i18n.t("keep_no"), btns.no.x, btns.no.y + 12, btns.no.w, "center")
    end
    love.graphics.setFont(previousFont)
end

---------------------------------------------------------------------------
-- Shop Modal (Extracted from play.lua)
---------------------------------------------------------------------------
function PS.shopModalLayout()
    local panelX, panelY = 20, 80
    local panelW, panelH = 680, 420
    local titleY = panelY + 28
    local nameY = titleY + 40
    local slotsY = nameY + 48
    local errY = slotsY + 56
    local btnW, btnH, btnGap = 200, 56, 28
    local btnY = panelY + panelH - 80
    local pairW = btnW * 2 + btnGap
    local buyX = panelX + math.floor((panelW - pairW) / 2)
    local skipX = buyX + btnW + btnGap
    return {
        panelX = panelX, panelY = panelY, panelW = panelW, panelH = panelH,
        titleY = titleY, nameY = nameY, slotsY = slotsY, errY = errY,
        buy = { x = buyX, y = btnY, w = btnW, h = btnH },
        skip = { x = skipX, y = btnY, w = btnW, h = btnH },
    }
end

function PS.shopModalButtonRects()
    local L = _M.shopModalLayout()
    return L.buy, L.skip
end

function PS.hitShopModalGearSlot(scene, x, y)
    local L = _M.shopModalLayout()
    local hullSlots, engineSlots = 6, 3
    local boxW, boxH, gap, groupGap = _M.launchGearBoxW, _M.launchGearBoxH, 5, 12
    local totalWidth = (hullSlots * boxW + (hullSlots - 1) * gap) + groupGap + (engineSlots * boxW + (engineSlots - 1) * gap)
    local startX = math.floor((viewport.width - totalWidth) / 2)
    local sy = L.slotsY
    if y >= sy and y < sy + boxH then
        local hullGear = scene.expedition.equippedGear or {}
        for i = 1, hullSlots do
            local sx = startX + (i - 1) * (boxW + gap)
            if x >= sx and x < sx + boxW then
                if hullGear[i] then return { part = hullGear[i], category = "hull", index = i } end
            end
        end
        local engineStartX = startX + (hullSlots * boxW + (hullSlots - 1) * gap) + groupGap
        local engineGear = scene.expedition.equippedEngineParts or {}
        for i = 1, engineSlots do
            local sx = engineStartX + (i - 1) * (boxW + gap)
            if x >= sx and x < sx + boxW then
                if engineGear[i] then return { part = engineGear[i], category = "engine", index = i } end
            end
        end
    end
    return nil
end

function PS.drawShopModal(self)
    if self.shopModal then
        local L = _M.shopModalLayout()
        love.graphics.setColor(0, 0, 0, 0.85)
        love.graphics.rectangle("fill", 0, 0, viewport.width, viewport.height)

        love.graphics.setColor(0.08, 0.14, 0.22, 1)
        love.graphics.rectangle("fill", L.panelX, L.panelY, L.panelW, L.panelH, 8, 8)
        love.graphics.setColor(0.3, 0.6, 1, 1)
        love.graphics.rectangle("line", L.panelX, L.panelY, L.panelW, L.panelH, 8, 8)

        local prevFont = love.graphics.getFont()
        local titleFont = fonts.get(22)
        love.graphics.setFont(titleFont)
        love.graphics.setColor(1, 1, 1)
        if self.shopModal.isReplacement then
            love.graphics.printf("교체할 장착 칸을 탭하세요", L.panelX, L.titleY, L.panelW, "center")
        else
            love.graphics.printf(i18n.t("shop_modal_title"), L.panelX, L.titleY, L.panelW, "center")
        end

        love.graphics.setColor(0.7, 0.8, 1)
        love.graphics.printf(i18n.partName(self.shopModal.gear), L.panelX, L.nameY, L.panelW, "center")

        self:drawGearSlots(L.slotsY)

        if self.shopModal.errorText then
            love.graphics.setColor(1, 0.35, 0.35)
            love.graphics.printf(self.shopModal.errorText, L.panelX + 16, L.errY, L.panelW - 32, "center")
        end

        local buy, skip = L.buy, L.skip
        if not self.shopModal.isReplacement then
            love.graphics.setColor(0.2, 0.45, 0.22, 1)
            love.graphics.rectangle("fill", buy.x, buy.y, buy.w, buy.h, 6, 6)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(i18n.t("shop_modal_buy", self.shopModal.price), buy.x, buy.y + 16, buy.w, "center")
        end

        love.graphics.setColor(0.45, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", skip.x, skip.y, skip.w, skip.h, 6, 6)
        love.graphics.setColor(1, 1, 1)
        if self.shopModal.isReplacement then
            love.graphics.printf("버리기", skip.x, skip.y + 16, skip.w, "center")
        else
            love.graphics.printf(i18n.t("shop_modal_skip"), skip.x, skip.y + 16, skip.w, "center")
        end
        love.graphics.setFont(prevFont)
    end
end

---------------------------------------------------------------------------
-- install(M) — merge public names onto PlayScene class table
---------------------------------------------------------------------------
function PS.install(M)
    _M = M
    M.rarityRgb               = rarityRgb
    M.reelWindowToScissor      = PS.reelWindowToScissor
    M.drawReelFallbackText     = PS.drawReelFallbackText
    M.drawSettlementOverlay    = PS.drawSettlementOverlay
    M.shopModalLayout          = PS.shopModalLayout
    M.shopModalButtonRects     = PS.shopModalButtonRects
    M.hitShopModalGearSlot     = PS.hitShopModalGearSlot
    M.drawShopModal            = PS.drawShopModal
    M.drawDestroyedOverlay     = PS.drawDestroyedOverlay
end

return PS
