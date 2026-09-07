-- play_input.lua: keyboard input handling extracted from play.lua (INBOX-32)
-- Handles keypressed logic: shop purchases, slot machine, relaunch, etc.
-- play.lua delegates via M:keypressed() thin wrapper.
local expedition = require("game.expedition")
local world      = require("game.world")
local i18n       = require("game.i18n")

local M = {}

-- Handle a key press on the PlayScene.
-- self: PlayScene; P: play module for spawn constants.
function M.keypressed(self, key, P)
    if self.gearPopup then
        if key == "escape" or key == "n" or key == "space" then
            self.gearPopup = nil
        end
        return
    end
    if self.shopModal then
        if key == "y" then
            local ok, err = expedition.buyGearFromShopPlanet(self.expedition, self.shopModal.category, self.shopModal.gear)
            if ok then
                self.gearPopup = { part = self.shopModal.gear, category = self.shopModal.category }
                table.insert(self.floatingTexts, {
                    text = i18n.t("floating_hub_gear", i18n.partName(self.shopModal.gear)),
                    x = self.shopModal.planet.x,
                    y = self.shopModal.planet.y + 20,
                    timer = 3.0,
                    kind = "sample",
                    awarded = 0,
                    rollupElapsed = 0,
                })
                self.shopVisited[self.shopModal.planet.id] = true
                self.shopModal = nil
            else
                self.shopModal.errorText = i18n.shopError(err)
            end
        elseif key == "n" then
            self.shopModal = nil
        end
        return
    end
    if self.expedition.phase == "settlement" and (key == "h" or key == "right" or key == "d") then
        expedition.buyDurabilityUpgrade(self.expedition)
        self.message = ""
        return
    end
    if self.expedition.phase == "settlement" and key == "y" then
        expedition.buySampleYieldUpgrade(self.expedition)
        self.message = ""
        return
    end
    if self.expedition.phase == "settlement" and key == "g" then
        expedition.buySteeringUpgrade(self.expedition)
        self.message = ""
        return
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
        return
    end
    if self.expedition.phase == "settlement" and key == "l" then
        if self.slotState and self.slotState.spinning then
            if self.slotState.stopNext then self.slotState:stopNext() end
            return
        end
        local spinCost = expedition.slotSpinCostFor(self.expedition, self.expedition.lastVisitedGalaxyId)
        if self.expedition.money < spinCost then
            self.message = i18n.t("earth_slot_broke", spinCost - self.expedition.money)
            return
        end
        local reels = {}
        for i = 1, 3 do reels[i] = math.random(1, 10) end
        local result = expedition.earthSlotSpin(self.expedition, self.expedition.lastVisitedGalaxyId, {
            reels = reels,
            partRarity = math.random(),
            partPick = math.random(),
            partEditionChance = math.random(),
            partEditionPick = math.random()
        })
        self.earthShopSlotResult = result
        self.expedition.money = self.expedition.money - spinCost
        pcall(love.system.vibrate, 0.05)
        self.slotShake = 0.1
        self.slotLeverPull = 1.0
        self.slotState = {
            spinning = true,
            startTime = self.time or 0,
            stopIndex = 1,
            reels = {
                { y = 0, speed = 800,  stopping = false, stopped = false, sym = result.symbols[1] },
                { y = 0, speed = 1000, stopping = false, stopped = false, sym = result.symbols[2] },
                { y = 0, speed = 1200, stopping = false, stopped = false, sym = result.symbols[3] }
            },
            stopNext = function(st)
                if st.stopIndex <= 3 then
                    st.reels[st.stopIndex].stopping = true
                    st.stopIndex = st.stopIndex + 1
                end
            end
        }
        return
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
                self.message = i18n.t("earth_gear_full")
            elseif self.expedition.money < price then
                self.message = i18n.t("earth_gear_broke", price - self.expedition.money)
            else
                local ok, err = expedition.buyGear(self.expedition, cat, offer)
                if ok then
                    self.earthShopGearOffer = nil
                    self.message = i18n.t("earth_gear_bought", offer.name, self.expedition.money)
                else
                    self.message = err or "PURCHASE FAILED"
                end
            end
        end
        return
    end
    if self.expedition.phase == "settlement" and key == "r" then
        if self.expedition.lastVisitedGalaxyId and not self.earthShopGearOffer then
            local gearMod = require("game.gear")
            local hull = gearMod.loadHullParts() or {}
            local engine = gearMod.loadEngineParts() or {}
            local pool = {}
            for _, p in ipairs(hull) do
                if not p.slotExclusive then pool[#pool+1] = p end
            end
            for _, p in ipairs(engine) do
                if not p.slotExclusive then pool[#pool+1] = p end
            end
            local rolls = {
                rarity = math.random(),
                pick = math.random(),
                editionChance = math.random(),
                editionPick = math.random(),
            }
            local ok, offer = expedition.hubRestock(self.expedition, pool, rolls)
            if ok then
                self.earthShopGearOffer = offer
                self.message = ""
            else
                self.message = offer or "RESTOCK FAILED"
            end
        end
        return
    end
    if key == "space" or key == "return" or key == "up" or key == "w" then
        local relaunching = self.expedition.phase == "settlement" or self.expedition.phase == "destroyed"
        local hubX = self.expedition.lastHubX
        local hubY = self.expedition.lastHubY
        local wasDestroyed = self.expedition.phase == "destroyed"
        local cpX, cpY = expedition.lastCheckpointOrEarth(self.expedition)
        if expedition.launch(self.expedition) then
            if relaunching then
                if wasDestroyed then
                    if cpX == 0 and cpY == 75 then
                        self.ship.x = P.launchSpawnX
                        self.ship.y = P.launchSpawnY
                        self.hasLeftEarth = false
                    else
                        self.ship.x = cpX
                        self.ship.y = cpY - 80
                        self.hasLeftEarth = true
                    end
                elseif hubX and hubY then
                    self.ship.x = hubX
                    self.ship.y = hubY - 80
                    self.hasLeftEarth = true
                else
                    self.ship.x = P.launchSpawnX
                    self.ship.y = P.launchSpawnY
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
                world.resetComets(self.time)
            end
            self.message = ""
        end
    end
    -- Item 2: Return-to-Earth 'r' keybinding removed. Direct steering only.
end

return M
