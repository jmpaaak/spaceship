-- play_shop.lua: settlement/shop drawing extracted from play.lua (INBOX-32)
-- Draws the shop panel during the settlement phase.
-- play.lua delegates via M:drawSettlement() called inside M:draw().
local viewport   = require("game.viewport")
local i18n       = require("game.i18n")
local fonts      = require("game.fonts")
local expedition = require("game.expedition")

local M = {}

-- Inline drawPanelSprite (mirrors play.lua local drawPanelSprite).
local function drawPanelSprite(image, x, y, _w, _h)
    if not image then return false end
    love.graphics.draw(image, x, y)
    return true
end

-- Draw the settlement/shop panel (called when phase == "settlement").
-- self: PlayScene; P: play module for constants and helpers.
function M.drawSettlement(self, P)
    local previousFont = love.graphics.getFont()
    love.graphics.setFont(fonts.get(P.settlementFontSize))

    love.graphics.setColor(1, 1, 1, 0.94)
    if not drawPanelSprite(self.settlementPanelImage, 0, P.settlementPanelTop, viewport.width, P.settlementPanelHeight) then
        love.graphics.setColor(0.02, 0.03, 0.08, 0.94)
        love.graphics.rectangle("fill", 0, P.settlementPanelTop, viewport.width, P.settlementPanelHeight)
    end

    local titleStr = self.expedition.lastVisitedGalaxyId and i18n.t("hub_shop_label") or i18n.t("earth_shop_label")
    if titleStr then
        love.graphics.setColor(1, 0.9, 0.5)
        love.graphics.printf(titleStr, 0, P.settlementTitleY, viewport.width, "center")
    end

    love.graphics.setColor(1, 1, 1, 0.9)
    local shopEff = self.shopEffectImages or {}

    local nextLaunch = self:shopLoadoutLines()
    local fullX, fullW = 24, viewport.width - 48
    local rowStep = P.settlementRowStep
    local touchRowHeight = P.settlementTouchRowHeight

    local shopColumnLeftX  = P.shopColumnLeftX
    local shopColumnLeftW  = P.shopColumnLeftW
    local shopColumnRightX = P.shopColumnRightX
    local shopColumnRightW = P.shopColumnRightW

    -- Balatro-style shop card button.
    local function drawShopItem(rowTop, leftX, leftW, _actionImg, _statusImg, _previewImg, actionText, statusText, _previewText, isAffordable, _iconImg, _isHovered, descLine)
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
        if descLine and descLine ~= "" then
            valuesLabel = descLine
        end
        local numLines = 4
        local lineH = 26
        local totalTextH = numLines * lineH
        local startY = cardY + math.floor((cardH - totalTextH) / 2)
        love.graphics.setColor(1, 0.95, 0.9, 1)
        love.graphics.printf(actionLabel, leftX + 8, startY, leftW - 16, "center")
        love.graphics.setColor(0.75, 0.75, 0.8, 0.9)
        love.graphics.printf(valuesLabel, leftX + 8, startY + lineH, leftW - 16, "center")
        love.graphics.setColor(1, 0.85, 0.25, 1)
        love.graphics.printf(priceLabel, leftX + 8, startY + lineH * 2, leftW - 16, "center")
        love.graphics.setColor(isAffordable and 0.5 or 0.9, isAffordable and 0.9 or 0.35, isAffordable and 0.6 or 0.3, 0.7)
        love.graphics.printf(statusText, leftX + 8, startY + lineH * 3, leftW - 16, "center")
    end

    local shopIcons = self.shopIconImages or {}
    local r1 = P.settlementTouchRows[1].top
    drawShopItem(r1, shopColumnLeftX, shopColumnLeftW, shopEff.hullAction, shopEff.hullStatus, shopEff.hullPreview, nextLaunch.hullActionCompact, nextLaunch.hullStatus, nextLaunch.hullPreviewCompact, nextLaunch.hullAffordable, shopIcons.hull, self.hoverRow == 1 and self.hoverCol == "left")
    drawShopItem(r1, shopColumnRightX, shopColumnRightW, shopEff.steeringAction, shopEff.steeringStatus, shopEff.steeringPreview, nextLaunch.steeringActionCompact, nextLaunch.steeringStatus, nextLaunch.steeringPreviewCompact, nextLaunch.steeringAffordable, shopIcons.steering, self.hoverRow == 1 and self.hoverCol == "right")

    local r2 = P.settlementTouchRows[2].top
    local shopIconsYS = self.shopIconImages or {}
    drawShopItem(r2, shopColumnLeftX, shopColumnLeftW, shopEff.yieldAction, shopEff.yieldStatus, shopEff.yieldPreview, nextLaunch.yieldActionCompact, nextLaunch.yieldStatus, nextLaunch.yieldPreview, nextLaunch.yieldAffordable, shopIconsYS.yield, self.hoverRow == 2 and self.hoverCol == "left")
    if not nextLaunch.shipHidden then
        drawShopItem(r2, shopColumnRightX, shopColumnRightW, shopEff.shipAction, shopEff.shipStatus, shopEff.shipPreview, nextLaunch.shipActionCompact, nextLaunch.shipStatus, nextLaunch.shipPreviewCompact, nextLaunch.shipAffordable, shopIconsYS.ship, self.hoverRow == 2 and self.hoverCol == "right", nextLaunch.shipTradeoffLine)
    else
        local row = r2 + 8 + rowStep
        love.graphics.setColor(0.45, 1, 0.55)
        love.graphics.printf("SCOUT \226\156\147", shopColumnRightX, row, shopColumnRightW, "center")
    end

    local r3 = P.settlementTouchRows[3].top
    local row = r3 + math.floor((P.settlementTouchRows[3].bottom - r3 - 22) / 2)
    if self.earthShopGearOffer then
        local offer = self.earthShopGearOffer
        local gearMod = require("game.gear")
        local price = expedition.shopPrice(self.expedition, gearMod.buyPrice(offer))
        love.graphics.setColor(0.4, 1, 0.7)
        love.graphics.printf(i18n.t("earth_gear_offer", offer.name, price), fullX, row, fullW, "center")
    elseif self.expedition.lastVisitedGalaxyId then
        local restockCost = expedition.hubRestockCost or 5
        local canAfford = self.expedition.money >= restockCost
        if canAfford then
            love.graphics.setColor(0.3, 0.85, 0.5)
        else
            love.graphics.setColor(0.6, 0.3, 0.3)
        end
        love.graphics.printf(i18n.t("hub_restock_btn", restockCost), fullX, row, fullW, "center")
    end

    local r4 = P.settlementTouchRows[4].top
    row = r4 + 4
    do
        love.graphics.setColor(1, 1, 1, 1)
        local slotScale = 3
        local slotW = 96 * slotScale
        local mx = fullX + (fullW - slotW) / 2
        local my = row
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
        local leverX = mx + 91 * slotScale
        local leverTopY = my + 4 * slotScale
        local leverBotY = my + 40 * slotScale
        local leverPull = 0
        if self.slotLeverPull and self.slotLeverPull > 0 then
            leverPull = self.slotLeverPull * 60
            self.slotLeverPull = self.slotLeverPull - (love.timer and love.timer.getDelta() or 0.016) * 4
            if self.slotLeverPull < 0 then self.slotLeverPull = 0 end
        end
        love.graphics.setColor(0.55, 0.55, 0.55)
        love.graphics.setLineWidth(4)
        love.graphics.line(leverX, leverTopY, leverX, leverBotY + leverPull)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(0.9, 0.15, 0.1)
        love.graphics.circle("fill", leverX, leverBotY + leverPull, 10)

        if self.earthShopSlotResult or (self.slotState and self.slotState.spinning) then
            local rKeys = {"MONEY", "PART", "SPEED", "DURABILITY", "HARVEST"}
            local reelWindowW = 24 * slotScale
            local reelWindowH = 32 * slotScale
            local symSize = 32
            for i = 1, 3 do
                local rx = mx + (8 + (i - 1) * 28) * slotScale
                local ry = my + 8 * slotScale
                love.graphics.setScissor(rx, ry, reelWindowW, reelWindowH)
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
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.printf(string.sub(drawSym, 1, 1), rx, ry + yOff, reelWindowW, "center")
                end
                love.graphics.setScissor()
            end
        else
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
                local symImg = self.slotSymbolImages and self.slotSymbolImages[rKeys[i]]
                if symImg then
                    local symScale = reelWindowW / symSize * 0.85
                    local symOffX = (reelWindowW - symSize * symScale) / 2
                    local symOffY = (reelWindowH - symSize * symScale) / 2
                    love.graphics.setColor(1, 1, 1, pulse)
                    love.graphics.draw(symImg, rx + symOffX, ry + symOffY, 0, symScale, symScale)
                end
            end
        end

        local belowY = my + 48 * slotScale + 4
        if self.earthShopSlotResult or (self.slotState and self.slotState.spinning) then
            local profileLabel = self.earthShopSlotResult and P.earthSlotProfileLabel(self.earthShopSlotResult.rewardProfile)
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
            local spinCost = expedition.slotSpinCostFor(self.expedition, self.expedition.lastVisitedGalaxyId)
            love.graphics.setFont(fonts.get(22))
            love.graphics.setColor(1, 0.85, 0.25, 1)
            love.graphics.printf(i18n.t("earth_slot_spin_prompt"), fullX, belowY, fullW, "center")
            belowY = belowY + 26
            love.graphics.printf("$" .. spinCost, fullX, belowY, fullW, "center")
            love.graphics.setFont(fonts.get(P.settlementFontSize))
        end
    end

    local r5 = P.settlementTouchRows[5].top
    row = r5 + touchRowHeight - rowStep - 8
    love.graphics.setColor(0.6, 0.6, 0.6, 0.7)
    love.graphics.printf(i18n.t("tap_relaunch"), fullX, row, fullW, "center")

    love.graphics.setFont(previousFont)
end

-- shopLoadoutLines is also needed by the settlement draw; keep it here.
-- Compute all the shop action/status lines from the expedition state.
-- self: PlayScene; P: play module for purchaseStatus helper.
function M.shopLoadoutLines(self, P)
    local run = self.expedition
    local i18n2  = require("game.i18n")
    local expedition2 = require("game.expedition")
    local purchaseStatus = P.purchaseStatus
    local shipAction, shipActionCompact, shipAffordable, shipStatus, previewShipId
    local shipHidden = false
    if not run.ownedShips.scout then
        shipAction        = i18n2.t("buy_scout", run.scoutShipCost)
        shipActionCompact = i18n2.t("buy_scout_compact", run.scoutShipCost)
        shipStatus, shipAffordable = purchaseStatus(run.money, run.scoutShipCost)
        previewShipId = "scout"
    elseif run.selectedShipId == "scout" then
        shipHidden    = true
        previewShipId = "scout"
    else
        shipAction        = i18n2.t("select_scout")
        shipActionCompact = i18n2.t("select_scout_compact")
        shipAffordable    = true
        shipStatus        = i18n2.t("owned_label")
        previewShipId     = "scout"
    end
    local previewDurability = run.baseDurability + run.durabilityUpgradeLevel * run.durabilityUpgradeAmount
    if previewShipId == "scout" then previewDurability = previewDurability + run.scoutDurabilityBonus end
    local hullStatus,     hullAffordable     = purchaseStatus(run.money, run.durabilityUpgradeCost)
    local yieldStatus,    yieldAffordable    = purchaseStatus(run.money, run.sampleYieldUpgradeCost)
    local steeringStatus, steeringAffordable = purchaseStatus(run.money, run.steeringUpgradeCost)
    return {
        ship = i18n2.t("next_ship_label", string.upper(run.selectedShipId)),
        stats = i18n2.t("stats_line", run.maxDurability),
        upgrades = i18n2.t("upgrades_line", run.durabilityUpgradeLevel),
        scoutTradeoff = shipHidden and {} or self.scoutTradeoffLines(run),
        shipHidden = shipHidden,
        shipAction = shipAction, shipActionCompact = shipActionCompact,
        shipStatus = shipStatus, shipAffordable = shipAffordable,
        shipTradeoffLine = (not shipHidden) and i18n2.t("scout_tradeoff_compact", run.scoutClimbSpeedBonus, run.scoutDurabilityBonus) or "",
        shipPreview = i18n2.t("ship_preview_line", string.upper(previewShipId), previewDurability),
        shipPreviewCompact = i18n2.t("ship_preview_compact", string.upper(previewShipId), previewDurability),
        hullAction = i18n2.t("hull_action_line", run.durabilityUpgradeLevel, run.durabilityUpgradeLevel + 1, expedition2.upgradeCost(run, run.durabilityUpgradeCost, run.durabilityUpgradeLevel)),
        hullActionCompact = i18n2.t("hull_action_compact", run.maxDurability, run.maxDurability + run.durabilityUpgradeAmount, expedition2.upgradeCost(run, run.durabilityUpgradeCost, run.durabilityUpgradeLevel)),
        hullPreview = i18n2.t("stats_line", run.maxDurability + run.durabilityUpgradeAmount),
        hullPreviewCompact = i18n2.t("hull_preview_compact", run.maxDurability + run.durabilityUpgradeAmount),
        hullStatus = hullStatus, hullAffordable = hullAffordable,
        yieldAction = i18n2.t("yield_action_line", run.sampleYieldUpgradeLevel, run.sampleYieldUpgradeLevel + 1, expedition2.upgradeCost(run, run.sampleYieldUpgradeCost, run.sampleYieldUpgradeLevel)),
        yieldActionCompact = i18n2.t("yield_action_compact", expedition2.sampleYieldMultiplier(run), 1 + (run.sampleYieldUpgradeLevel + 1) * run.sampleYieldUpgradeAmount, expedition2.upgradeCost(run, run.sampleYieldUpgradeCost, run.sampleYieldUpgradeLevel)),
        yieldPreview = i18n2.t("yield_preview_line", 1 + (run.sampleYieldUpgradeLevel + 1) * run.sampleYieldUpgradeAmount),
        yieldStatus = yieldStatus, yieldAffordable = yieldAffordable,
        steeringAction = i18n2.t("steering_action_line", run.steeringUpgradeLevel, run.steeringUpgradeLevel + 1, expedition2.upgradeCost(run, run.steeringUpgradeCost, run.steeringUpgradeLevel)),
        steeringActionCompact = i18n2.t("steering_action_compact", expedition2.effectiveSpeed(run), expedition2.effectiveSpeed(run) + run.steeringUpgradeAmount, expedition2.upgradeCost(run, run.steeringUpgradeCost, run.steeringUpgradeLevel)),
        steeringPreview = i18n2.t("steer_speed_line", expedition2.effectiveSpeed(run) + run.steeringUpgradeAmount),
        steeringPreviewCompact = i18n2.t("steering_preview_compact", expedition2.effectiveSpeed(run) + run.steeringUpgradeAmount),
        steeringStatus = steeringStatus, steeringAffordable = steeringAffordable,
    }
end

return M
