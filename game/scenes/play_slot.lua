local i18n = require("game.i18n")
local expedition = require("game.expedition")
local viewport = require("game.viewport")
local sfx = require("game.sfx")

local PS = {}
local _M

function PS:updateSlotMachine(dt, rawDt)
    if not self.slotState or not self.slotState.spinning then return end

    local allStopped = true
    for i, r in ipairs(self.slotState.reels) do
        if r.stopping then
            r.speed = math.max(100, r.speed - rawDt * 1500)
            r.y = r.y + r.speed * rawDt
            if r.speed <= 100 then
                local snap = math.floor(r.y / 32) * 32
                if math.abs(r.y - snap) < 5 then
                    r.y = snap
                    r.speed = 0
                    r.stopping = false
                    r.stopped = true
                    pcall(love.system.vibrate, 0.03)
                    self.slotShake = 0.15
                    -- Short sparkles
                    for k = 1, 3 do
                        self.particles[#self.particles + 1] = {
                            x = viewport.width / 2 + (i - 2) * 45 + (math.random() - 0.5) * 20,
                            y = _M.settlementTouchRows[4].top + 20 + (math.random() - 0.5) * 20,
                            vx = (math.random() - 0.5) * 40,
                            vy = (math.random() - 0.5) * 40,
                            timer = 0.3 + math.random() * 0.2,
                            maxTimer = 0.5,
                            r = 1, g = 0.9, b = 0.5,
                            radius = 2 + math.random() * 2,
                            hud = true,
                        }
                    end
                end
            end
            allStopped = false
        elseif not r.stopped then
            r.y = r.y + r.speed * rawDt
            allStopped = false
        end
    end
    if allStopped then
        self.slotState.spinning = false
        local result = self.earthShopSlotResult
        if result then
            local rt = result.rewardType or "money"
            local rv = result.rewardValue or 0
            local won = rt ~= "money" or rv > 0
            if rt == "money" then
                self.expedition.money = self.expedition.money + result.reward
                if result.reward > 0 then
                    self.slotResultMessage = table.concat(result.symbols, "  ") .. "\n+$" .. result.reward
                else
                    self.slotResultMessage = table.concat(result.symbols, "  ") .. "\n꽝"
                end
            elseif rt == "speed" then
                self.expedition.slotSpeedBonus = (self.expedition.slotSpeedBonus or 0) + rv
                self.slotResultMessage = table.concat(result.symbols, "  ") .. "\n속도 +" .. rv
            elseif rt == "durability" then
                self.expedition.durabilityUpgradeLevel = (self.expedition.durabilityUpgradeLevel or 0) + rv
                self.expedition.maxDurability = (self.expedition.maxDurability or 3) + rv
                self.expedition.durability = math.min(self.expedition.durability + rv, self.expedition.maxDurability)
                self.slotResultMessage = table.concat(result.symbols, "  ") .. "\n내구 +" .. rv
            elseif rt == "harvest" then
                -- INBOX 61: apply shop-upgrade units, not a hard-coded +1.
                -- 2-match 0.10 → +1 level; 3-match 0.50 → +5 levels (* tier).
                local step = self.expedition.sampleYieldUpgradeAmount or 0.10
                if step <= 0 then step = 0.10 end
                local levels = math.floor(rv / step + 0.5)
                self.expedition.sampleYieldUpgradeLevel = (self.expedition.sampleYieldUpgradeLevel or 0) + levels
                self.slotResultMessage = table.concat(result.symbols, "  ") .. "\n수확 +" .. string.format("%.2f", rv)
            elseif rt == "part" then
                local drop = result.rewardPart
                if drop then
                    local alreadyEquipped = false
                    for _, p in ipairs(self.expedition.equippedGear or {}) do
                        if p.id == drop.id then alreadyEquipped = true; break end
                    end
                    for _, p in ipairs(self.expedition.equippedEngineParts or {}) do
                        if p.id == drop.id then alreadyEquipped = true; break end
                    end
                    local spinCost = expedition.slotSpinCostFor(self.expedition, self.expedition.lastVisitedGalaxyId)
                    if alreadyEquipped then
                        self.expedition.money = self.expedition.money + spinCost
                        self.slotResultMessage = table.concat(result.symbols, "  ") .. "\n" .. i18n.partName(drop) .. "\n(중복 환불 +$" .. spinCost .. ")"
                    else
                        local gearMod = require("game.gear")
                        local engineParts = require("game.engine_parts")
                        local isEngine = gearMod.findById(gearMod.loadEngineParts() or {}, drop.id)
                        local cat = isEngine and "engine" or "hull"
                        local isFull = (cat == "hull" and engineParts.isFull(self.expedition.gearLoadout, "hull"))
                            or (cat == "engine" and engineParts.isFull(self.expedition.gearLoadout, "engine"))
                        
                        if isFull then
                            self.shopModal = { gear = drop, category = cat, price = 0, isReplacement = true }
                            self.slotResultMessage = table.concat(result.symbols, "  ") .. "\n" .. i18n.partName(drop) .. "\n(교체 대기중)"
                        else
                            local ok = expedition.equipGear(self.expedition, cat, drop)
                            if ok then
                                self.gearPopup = { part = drop, category = cat }
                            end
                            self.slotResultMessage = table.concat(result.symbols, "  ") .. "\n" .. i18n.partName(drop)
                        end
                    end
                else
                    self.slotResultMessage = table.concat(result.symbols, "  ") .. "\n부품 획득 실패!"
                end
            end
            if won then
                pcall(love.system.vibrate, 0.12)
                self.slotShake = 0.3
                for k = 1, 8 do
                    self.particles[#self.particles + 1] = {
                        x = viewport.width / 2 + (math.random() - 0.5) * 160,
                        y = (_M.settlementTouchRows[4].top or 600) + 40,
                        vx = (math.random() - 0.5) * 80,
                        vy = -40 - math.random() * 50,
                        timer = 0.7 + math.random() * 0.3,
                        maxTimer = 1.0,
                        r = 1, g = 0.85, b = 0.2,
                        radius = 2 + math.random() * 2,
                        hud = true,
                    }
                end
            else
                pcall(love.system.vibrate, 0.05)
                self.slotShake = 0.1
            end
        end
    end
end

function PS:spinSlotMachine()
    if self.expedition.phase ~= "settlement" then return end
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
    local tw = expedition.earthSlotTotalWeight(self.expedition, self.expedition.lastVisitedGalaxyId)
    for i = 1, 3 do reels[i] = math.random(0, tw - 1) end
    local result = expedition.earthSlotSpin(self.expedition, self.expedition.lastVisitedGalaxyId, {
        reels = reels,
        partRarity = math.random(),
        partPick = math.random(),
        partEditionChance = math.random(),
        partEditionPick = math.random()
    })
    self.earthShopSlotResult = result
    self.expedition.money = self.expedition.money - spinCost
    sfx.play("slot_spin")
    pcall(love.system.vibrate, 0.05)
    self.slotShake = 0.1
    self.slotLeverPull = 1.0  -- lever pull animation
    self.slotState = {
        spinning = true,
        startTime = self.time or 0,
        stopIndex = 1,
        reels = {
            { y = 0, speed = 800, stopping = false, stopped = false, sym = result.symbols[1] },
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
end

function PS.install(M)
    _M = M
    M.updateSlotMachine = PS.updateSlotMachine
    M.spinSlotMachine = PS.spinSlotMachine
end

return PS
