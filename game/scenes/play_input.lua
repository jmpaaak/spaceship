--- Play scene input routing and pointer-consumption contract.
-- Priority: popup/modal -> phase UI -> world joystick. Every handled press returns
-- true so a state transition (notably settlement -> ascending) cannot reuse it.

local M = {}

local function hit(rect, x, y)
    return x >= rect.x and x < rect.x + rect.w and y >= rect.y and y < rect.y + rect.h
end

local function captureUiPointer(self, id)
    self.uiCapturedPointers = self.uiCapturedPointers or {}
    self.uiCapturedPointers[id] = true
    -- A pointer owned by UI must never remain available to the joystick.
    self.touches[id] = nil
end

function M.steeringButtonState(self, deps)
    local left = love.keyboard.isDown("left", "a")
    local right = love.keyboard.isDown("right", "d")
    local up = love.keyboard.isDown("up", "w")
    local down = love.keyboard.isDown("down", "s")
    for _, touch in pairs(self.touches) do
        if touch.x < deps.viewport.width / 2 then left = true else right = true end
    end
    return { leftActive = left, rightActive = right, upActive = up, downActive = down }
end

function M.keypressed(self, key, deps)
    local expedition = deps.expedition
    if self.gearPopup then
        if key == "s" and self.sellGearPopup then
            self:sellGearPopup()
        elseif key == "escape" or key == "n" or key == "space" then
            self.gearPopup = nil
        end
        return true
    end
    if self.shopModal then
        if key == "y" then
            self:buyShopModalGear()
        elseif key == "n" then
            self.shopModal = nil
        end
        return true
    end
    if self.expedition.phase == "settlement" and (key == "h" or key == "right" or key == "d") then
        expedition.buyDurabilityUpgrade(self.expedition)
        self.message = ""
        return true
    end
    if self.expedition.phase == "settlement" and key == "y" then
        expedition.buySampleYieldUpgrade(self.expedition)
        self.message = ""
        return true
    end
    if self.expedition.phase == "settlement" and key == "g" then
        expedition.buySteeringUpgrade(self.expedition)
        self.message = ""
        return true
    end
    if self.expedition.phase == "settlement" and key == "v" then
        if not self.expedition.ownedShips.scout then
            if expedition.buyShip(self.expedition, "scout") then
                expedition.selectShip(self.expedition, "scout")
            end
        elseif self.expedition.selectedShipId ~= "scout" then
            expedition.selectShip(self.expedition, "scout")
        end
        self.message = ""
        return true
    end
    if self.expedition.phase == "settlement" and key == "l" then
        self:spinSlotMachine()
        return true
    end
    if self.expedition.phase == "settlement" and key == "b" then
        local offer = self.earthShopGearOffer
        if offer then
            local gearMod = require("game.gear")
            local engine = gearMod.loadEngineParts() or {}
            local cat = gearMod.findById(engine, offer.id) and "engine" or "hull"
            local price = expedition.shopPrice(self.expedition, gearMod.buyPrice(offer))
            local engineParts = require("game.engine_parts")
            local slotsFull = (cat == "hull" and engineParts.isFull(self.expedition.gearLoadout, "hull"))
                or (cat == "engine" and engineParts.isFull(self.expedition.gearLoadout, "engine"))
            if slotsFull then
                self.message = deps.i18n.t("earth_gear_full")
            elseif self.expedition.money < price then
                self.message = deps.i18n.t("earth_gear_broke", price - self.expedition.money)
            else
                local ok, err = expedition.buyGear(self.expedition, cat, offer)
                if ok then
                    self.earthShopGearOffer = nil
                    self.message = deps.i18n.t("earth_gear_bought", offer.name, self.expedition.money)
                else
                    self.message = err or "PURCHASE FAILED"
                end
            end
        end
        return true
    end
    if self.expedition.phase == "settlement" and key == "r" then
        if self.expedition.lastVisitedGalaxyId and not self.earthShopGearOffer then
            local gearMod = require("game.gear")
            local hull = gearMod.loadHullParts() or {}
            local engine = gearMod.loadEngineParts() or {}
            local pool = {}
            for _, part in ipairs(hull) do
                if not part.slotExclusive then pool[#pool + 1] = part end
            end
            for _, part in ipairs(engine) do
                if not part.slotExclusive then pool[#pool + 1] = part end
            end
            local rolls = {
                rarity = math.random(), pick = math.random(),
                editionChance = math.random(), editionPick = math.random(),
            }
            local ok, offer = expedition.hubRestock(self.expedition, pool, rolls)
            if ok then
                self.earthShopGearOffer = offer
                self.message = ""
            else
                self.message = offer or "RESTOCK FAILED"
            end
        end
        return true
    end
    if key == "space" or key == "return" or key == "up" or key == "w" then
        if self.expedition.phase == "launch" and not self.launchInputArmed then return true end
        local relaunching = self.expedition.phase == "settlement" or self.expedition.phase == "destroyed"
        local hubX, hubY = self.expedition.lastHubX, self.expedition.lastHubY
        local wasDestroyed = self.expedition.phase == "destroyed"
        local cpX, cpY = expedition.lastCheckpointOrEarth(self.expedition)
        if expedition.launch(self.expedition) then
            if relaunching then
                if wasDestroyed then
                    if cpX == 0 and cpY == 75 then
                        self.ship.x, self.ship.y = self.launchSpawnX, self.launchSpawnY
                        self.hasLeftEarth = false
                    else
                        self.ship.x, self.ship.y = cpX, cpY - 80
                        self.hasLeftEarth = true
                    end
                elseif hubX and hubY then
                    self.ship.x, self.ship.y = hubX, hubY - 80
                    self.hasLeftEarth = true
                else
                    self.ship.x, self.ship.y = self.launchSpawnX, self.launchSpawnY
                    self.hasLeftEarth = false
                end
                self.discovered = {}
                self.collided = {}
                self.discoveredCount = 0
                self.floatingTexts = {}
                self.earthShopSlotResult = nil
                self.earthShopGearOffer = nil
                self.cometDiscovered = {}
                self.cometCollided = {}
                self.cometTailParticles = {}
                self.moonDiscovered = {}
                self.moonCollided = {}
                deps.world.resetComets(self.time)
            end
            self.message = ""
        end
        return true
    end
    return false
end

function M.touchpressed(self, id, x, y, deps)
    local expedition = deps.expedition
    if self.gearPopup then
        local sell = self.gearPopupSellRect and self:gearPopupSellRect() or nil
        local slot = self:hitHudGearSlot(x, y)
        if sell and hit(sell, x, y) then
            pcall(love.system.vibrate, 0.05)
            self:sellGearPopup()
        elseif slot then
            slot.slotRect = slot.rect
            self.gearPopup = slot
            pcall(love.system.vibrate, 0.02)
        else
            self.gearPopup = nil
        end
        return true
    end
    if self.shopModal then
        local slot = self:hitShopModalGearSlot(x, y)
        if slot and self.shopModal.isReplacement and slot.category == self.shopModal.category then
            pcall(love.system.vibrate, 0.05)
            local list = slot.category == "engine" and self.expedition.equippedEngineParts
                or self.expedition.equippedGear
            table.remove(list, slot.index)
            expedition.equipGear(self.expedition, slot.category, self.shopModal.gear)
            self.shopModal = nil
            self.slotResultMessage = (self.slotResultMessage or "") .. "\n(교체 완료)"
            return true
        end
        local buy, skip = self:shopModalButtonRects()
        if not self.shopModal.isReplacement and hit(buy, x, y) then
            pcall(love.system.vibrate, 0.02)
            self:keypressed("y")
        elseif hit(skip, x, y) then
            pcall(love.system.vibrate, 0.02)
            if self.shopModal.isReplacement then self.shopModal = nil end
            self:keypressed("n")
        end
        return true
    end

    if self.expedition.phase == "ascending" then
        if self.helpOverlayOpen then
            self.helpOverlayOpen = false
            return true
        end
        if hit(deps.pauseButton, x, y) then
            self.paused = not self.paused
            pcall(love.system.vibrate, 0.02)
            return true
        end
        -- The pause overlay owns the whole pointer surface. Check it before
        -- help/admin/gear controls that are visually underneath the overlay.
        if self.paused then
            local rects = self:pauseMenuRects()
            if hit(rects.restart, x, y) then
                self.paused = false
                expedition.launch(self.expedition)
                self.ship.x, self.ship.y = self.launchSpawnX, self.launchSpawnY
                self.expedition.phase = "launch"
                self.floatingTexts, self.particles = {}, {}
                pcall(love.system.vibrate, 0.05)
                return true
            end
            if hit(rects.mainMenu, x, y) then
                self.paused = false
                if self.onMainMenu then self.onMainMenu() end
                pcall(love.system.vibrate, 0.05)
                return true
            end
            self.paused = false
            return true
        end
        if self:hitHelpButton(x, y) then
            self.helpOverlayOpen = true
            pcall(love.system.vibrate, 0.02)
            return true
        end
        for i, button in ipairs(deps.adminButtons) do
            local ax, ay, aw, ah = deps.adminButtonRect(i, deps.pauseButton.y)
            if x >= ax and x < ax + aw and y >= ay and y < ay + ah then
                expedition.adminUpgrade(self.expedition, button.kind)
                return true
            end
        end
        local slot = self:hitHudGearSlot(x, y)
        if slot then
            slot.slotRect = slot.rect
            self.gearPopup = slot
            pcall(love.system.vibrate, 0.02)
            return true
        end
        local ox, oy = self.joystickOrigin(x, y)
        -- hitBoostButton consumes its visible button even when disabled, so a
        -- zero-charge BOOST tap cannot leak into world steering.
        if self.hitBoostButton and self:hitBoostButton(x, y) then
            return true
        end
        self.touches[id] = { x = x, y = y, originX = ox, originY = oy }
        return true
    end

    if self.expedition.phase == "settlement" then
        for _, row in ipairs(deps.settlementTouchRows) do
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
                if key == "hull" then
                    self:keypressed("h")
                elseif key == "steering" then
                    self:keypressed("g")
                elseif key == "yield" then
                    self:keypressed("y")
                elseif key == "ship" then
                    self:keypressed("v")
                elseif key == "gear" then
                    if self.expedition.lastVisitedGalaxyId and not self.earthShopGearOffer then
                        self:keypressed("r")
                    else
                        self:keypressed("b")
                    end
                elseif key == "slot" then
                    self:keypressed("l")
                elseif key == "relaunch" then
                    self:keypressed("space")
                end
                return true
            end
        end
        return true
    end
    if self.expedition.phase == "launch" then
        local slot = self:hitHudGearSlot(x, y)
        if slot then
            slot.slotRect = slot.rect
            self.gearPopup = slot
            pcall(love.system.vibrate, 0.02)
            return true
        end
        if self.launchInputArmed then self:keypressed("space") end
        return true
    end
    if self.expedition.phase == "destroyed" then
        return self:handleDestroyedTouch(x, y) ~= false
    end
    return false
end

function M.touchmoved(self, id, x, y)
    if self.uiCapturedPointers and self.uiCapturedPointers[id] then return true end
    local touch = self.touches[id]
    if not touch then return false end
    touch.x, touch.y = x, y
    return true
end

function M.touchreleased(self, id)
    if self.uiCapturedPointers and self.uiCapturedPointers[id] then
        self.uiCapturedPointers[id] = nil
        self.touches[id] = nil
        return true
    end
    if not self.touches[id] then return false end
    self.touches[id] = nil
    return true
end

function M.install(target, deps)
    assert(type(target) == "table" and type(deps) == "table", "play_input.install requires target and dependencies")
    target.steeringButtonState = function(self) return M.steeringButtonState(self, deps) end
    target.keypressed = function(self, key) return M.keypressed(self, key, deps) end
    target.touchpressed = function(self, id, x, y)
        local consumed = M.touchpressed(self, id, x, y, deps)
        -- World/joystick input records itself in touches. Every other handled
        -- press is UI and remains captured until release, including presses
        -- whose action was disabled or failed.
        if consumed and not self.touches[id] then captureUiPointer(self, id) end
        return consumed
    end
    target.touchmoved = M.touchmoved
    target.touchreleased = M.touchreleased
    return target
end

return M
