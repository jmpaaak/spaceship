-- play_touch.lua: touch input handling extracted from play.lua (INBOX-32)
-- Handles touchpressed, touchmoved, touchreleased.
-- play.lua delegates via thin wrappers.
local expedition = require("game.expedition")
local viewport   = require("game.viewport")

local M = {}

function M.touchpressed(self, id, x, y, P)
    local joystickOrigin = P.joystickOrigin or function(px, py) return px, py end
    local pauseButton = P.pauseButton
    local adminButtons = P.adminButtons
    local adminButtonRect = P.adminButtonRect
    local settlementTouchRows = P.settlementTouchRows
    local destroyedTouchArea = P.destroyedTouchArea

    if self.gearPopup then
        local hit = P.hitHudGearSlot(self, x, y)
        if hit then
            hit.slotRect = hit.rect
            self.gearPopup = hit
            pcall(love.system.vibrate, 0.02)
        else
            self.gearPopup = nil
        end
        return
    end
    if self.shopModal then
        local slotHit = P.hitShopModalGearSlot(self, x, y)
        if slotHit and self.shopModal.isReplacement and slotHit.category == self.shopModal.category then
            pcall(love.system.vibrate, 0.05)
            local expeditionMod = require("game.expedition")
            local list = slotHit.category == "engine" and self.expedition.equippedEngineParts or self.expedition.equippedGear
            table.remove(list, slotHit.index)
            expeditionMod.equipGear(self.expedition, slotHit.category, self.shopModal.gear)
            self.shopModal = nil
            self.slotResultMessage = (self.slotResultMessage or "") .. "\n(교체 완료)"
            return
        end
        local buy, skip = P.shopModalButtonRects()
        if not self.shopModal.isReplacement and x >= buy.x and x < buy.x + buy.w and y >= buy.y and y < buy.y + buy.h then
            pcall(love.system.vibrate, 0.02)
            self:keypressed("y")
        elseif x >= skip.x and x < skip.x + skip.w and y >= skip.y and y < skip.y + skip.h then
            pcall(love.system.vibrate, 0.02)
            if self.shopModal.isReplacement then self.shopModal = nil end
            self:keypressed("n")
        end
        return
    end
    if self.expedition.phase == "ascending" then
        local pb = pauseButton
        if x >= pb.x and x < pb.x + pb.w and y >= pb.y and y < pb.y + pb.h then
            self.paused = not self.paused
            pcall(love.system.vibrate, 0.02)
            return
        end
        for i, btn in ipairs(adminButtons) do
            local ax, ay, aw, ah = adminButtonRect(i, pb.y)
            if x >= ax and x < ax + aw and y >= ay and y < ay + ah then
                expedition.adminUpgrade(self.expedition, btn.kind)
                return
            end
        end
        local hit = P.hitHudGearSlot(self, x, y)
        if hit then
            hit.slotRect = hit.rect
            self.gearPopup = hit
            pcall(love.system.vibrate, 0.02)
            return
        end
        if self.paused then
            local rects = P.pauseMenuRects()
            if x >= rects.restart.x and x < rects.restart.x + rects.restart.w
                and y >= rects.restart.y and y < rects.restart.y + rects.restart.h then
                self.paused = false
                expedition.launch(self.expedition)
                self.ship.x = P.launchSpawnX
                self.ship.y = P.launchSpawnY
                self.expedition.phase = "launch"
                self.floatingTexts = {}
                self.particles = {}
                pcall(love.system.vibrate, 0.05)
                return
            end
            if x >= rects.mainMenu.x and x < rects.mainMenu.x + rects.mainMenu.w
                and y >= rects.mainMenu.y and y < rects.mainMenu.y + rects.mainMenu.h then
                self.paused = false
                if self.onMainMenu then self.onMainMenu() end
                pcall(love.system.vibrate, 0.05)
                return
            end
            self.paused = false
            return
        end
        local ox, oy = joystickOrigin(x, y)
        if x > viewport.width * 0.6 and y > viewport.height * 0.5 and expedition.boostsRemaining(self.expedition) > 0 and not self.boostActive then
            local ok = expedition.spendBoost(self.expedition)
            if ok then
                self.boostActive = { timer = 0.8, speedMultiplier = 3.0 }
                pcall(love.system.vibrate, 0.1)
                return
            end
        end
        self.touches[id] = { x = x, y = y, originX = ox, originY = oy }
        return
    end

    if self.expedition.phase == "settlement" then
        for _, row in ipairs(settlementTouchRows) do
            if y >= row.top and y < row.bottom then
                local key = row.key
                if row.columns then
                    for _, column in ipairs(row.columns) do
                        if x >= column.left and x < column.right then
                            key = column.key
                            break
                        end
                    end
                end
                if key == "hull" then self:keypressed("h")
                elseif key == "steering" then self:keypressed("g")
                elseif key == "yield" then self:keypressed("y")
                elseif key == "ship" then self:keypressed("v")
                elseif key == "gear" then
                    if self.expedition.lastVisitedGalaxyId and not self.earthShopGearOffer then
                        self:keypressed("r")
                    else
                        self:keypressed("b")
                    end
                elseif key == "slot" then self:keypressed("l")
                elseif key == "relaunch" then self:keypressed("space")
                end
                break
            end
        end
        return
    end
    if self.expedition.phase == "launch" then
        local hit = P.hitHudGearSlot(self, x, y)
        if hit then
            hit.slotRect = hit.rect
            self.gearPopup = hit
            pcall(love.system.vibrate, 0.02)
            return
        end
        self:keypressed("space")
        return
    end
    if self.expedition.phase == "destroyed" then
        if self.keepPartConfirm then
            local btns = P.keepConfirmButtons()
            if btns then
                if x >= btns.yes.x and x < btns.yes.x + btns.yes.w
                   and y >= btns.yes.y and y < btns.yes.y + btns.yes.h then
                    self.expedition.keptPart = self.keepPartConfirm
                    self.keepPartConfirm = nil
                    return
                end
                if x >= btns.no.x and x < btns.no.x + btns.no.w
                   and y >= btns.no.y and y < btns.no.y + btns.no.h then
                    self.keepPartConfirm = nil
                    return
                end
            end
            return
        end
        local choices = self.expedition.keepPartChoices or {}
        if #choices > 0 then
            for _, rect in ipairs(P.destroyedKeepPartRects(choices)) do
                if x >= rect.x and x < rect.x + rect.w and y >= rect.y and y < rect.y + rect.h then
                    self.keepPartConfirm = rect.choice
                    return
                end
            end
        end
        local area = destroyedTouchArea
        if x >= area.left and x < area.right and y >= area.top and y < area.bottom then
            self:keypressed("space")
        end
    end
end

function M.touchmoved(self, id, x, y)
    if self.touches[id] then
        self.touches[id].x = x
        self.touches[id].y = y
    end
end

function M.touchreleased(self, id)
    self.touches[id] = nil
end

return M
