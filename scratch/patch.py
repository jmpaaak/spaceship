import re

with open("game/scenes/play.lua", "r") as f:
    code = f.read()

# 1. Image loading
code = code.replace(
    'local slotSymbolImagePaths = {\n        MONEY = "assets/slot_symbols/money.png",',
    'local slotMachineImagePath = "assets/slot_symbols/machine.png"\n    local slotSymbolImagePaths = {\n        MONEY = "assets/slot_symbols/money.png",'
)
code = code.replace(
    'local slotSymbolImages = loadSpriteMap(slotSymbolImagePaths)',
    'local slotMachineImage = loadSprite(slotMachineImagePath)\n    local slotSymbolImages = loadSpriteMap(slotSymbolImagePaths)'
)
code = code.replace(
    'slotSymbolImages = slotSymbolImages,\n        slotSymbolImagePaths = slotSymbolImagePaths,',
    'slotMachineImage = slotMachineImage,\n        slotSymbolImages = slotSymbolImages,\n        slotSymbolImagePaths = slotSymbolImagePaths,'
)

# 2. Update logic
update_logic = """
    if self.slotState and self.slotState.spinning then
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
            self.expedition.money = self.expedition.money + result.reward
            if result.reward > 0 then
                self.message = i18n.t("earth_slot_result",
                    table.concat(result.symbols, " "), result.reward)
            else
                self.message = i18n.t("earth_slot_miss",
                    table.concat(result.symbols, " "))
            end
        end
    end
"""
code = code.replace(
    'self.time = self.time + dt\n    self:pollDesktopMouse()',
    'self.time = self.time + dt\n' + update_logic + '    self:pollDesktopMouse()'
)

# 3. Keypressed "l"
keypressed_old = """    if self.expedition.phase == "settlement" and key == "l" then
        local spinCost = expedition.slotSpinCost or 10
        if self.expedition.money < spinCost then
            self.message = i18n.t("earth_slot_broke", spinCost - self.expedition.money)
            return
        end
        -- Item 15(b): earthSlotSpin expects rolls.reels (not a plain array).
        -- Building the table with the reels key ensures random values are used
        -- instead of the silent fallback to {0,0,0} that a plain array causes.
        local reels = {}
        for i = 1, 3 do reels[i] = math.random(1, 10) end
        local result = expedition.earthSlotSpin(self.expedition, self.expedition.lastVisitedGalaxyId, { reels = reels })
        self.earthShopSlotResult = result
        self.expedition.money = self.expedition.money - spinCost + result.reward
        if result.reward > 0 then
            self.message = i18n.t("earth_slot_result",
                table.concat(result.symbols, " "), result.reward)
        else
            self.message = i18n.t("earth_slot_miss",
                table.concat(result.symbols, " "))
        end
        return
    end"""

keypressed_new = """    if self.expedition.phase == "settlement" and key == "l" then
        if self.slotState and self.slotState.spinning then
            if self.slotState.stopNext then self.slotState:stopNext() end
            return
        end
        local spinCost = expedition.slotSpinCost or 10
        if self.expedition.money < spinCost then
            self.message = i18n.t("earth_slot_broke", spinCost - self.expedition.money)
            return
        end
        local reels = {}
        for i = 1, 3 do reels[i] = math.random(1, 10) end
        local result = expedition.earthSlotSpin(self.expedition, self.expedition.lastVisitedGalaxyId, { reels = reels })
        self.earthShopSlotResult = result
        self.expedition.money = self.expedition.money - spinCost
        self.slotState = {
            spinning = true,
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
        return
    end"""
code = code.replace(keypressed_old, keypressed_new)

# 4. Draw slot machine
draw_old = """        local r4 = M.settlementTouchRows[4].top
        row = r4 + 12
        if self.earthShopSlotResult then
            love.graphics.setColor(1, 1, 1, 0.85)
            drawPanelSprite(self.slotResultPanelImage, fullX, row - 2, fullW, rowStep * 2 + 2)
            love.graphics.setColor(0.85, 0.95, 1)
            love.graphics.printf(table.concat(self.earthShopSlotResult.symbols, "  "), fullX, row, fullW, "center")
            row = row + rowStep
            local profileLabel = M.earthSlotProfileLabel(self.earthShopSlotResult.rewardProfile)
            if profileLabel then
                love.graphics.setColor(1, 0.55, 0.45)
                love.graphics.printf(profileLabel, fullX, row, fullW, "center")
            end
        else
            love.graphics.setColor(1, 1, 1, 0.85)
            drawPanelSprite(self.slotSpinButtonImage, fullX, row - 2, fullW, rowStep + 4)
            love.graphics.setColor(1, 0.8, 0.3)
            love.graphics.printf(i18n.t("earth_slot_spin_prompt"), fullX, row, fullW, "center")
        end"""

draw_new = """        local r4 = M.settlementTouchRows[4].top
        row = r4 + 12
        if self.earthShopSlotResult or (self.slotState and self.slotState.spinning) then
            love.graphics.setColor(1, 1, 1, 1)
            local mx = fullX + (fullW - 96) / 2
            local my = row
            if self.slotMachineImage then
                love.graphics.draw(self.slotMachineImage, mx, my)
            end
            
            -- Draw Reels
            local rKeys = {"MONEY", "PART", "SPEED", "DURABILITY", "HARVEST"}
            for i = 1, 3 do
                local rx = mx + 12 + (i - 1) * 24
                local ry = my + 8
                love.graphics.setScissor(rx, ry, 20, 32)
                local rState = self.slotState and self.slotState.reels[i]
                local drawSym = self.earthShopSlotResult and self.earthShopSlotResult.symbols[i] or "MONEY"
                local yOff = 0
                if rState then
                    yOff = rState.y % 32
                    if not rState.stopped then
                        drawSym = rKeys[math.random(1, #rKeys)]
                    else
                        drawSym = rState.sym
                    end
                end
                
                local symImg = self.slotSymbolImages and self.slotSymbolImages[drawSym]
                if symImg then
                    love.graphics.draw(symImg, rx - 6, ry + yOff - 32)
                    local nextSym = rState and (not rState.stopped) and rKeys[math.random(1, #rKeys)] or drawSym
                    local nextImg = self.slotSymbolImages and self.slotSymbolImages[nextSym]
                    if nextImg then
                        love.graphics.draw(nextImg, rx - 6, ry + yOff)
                    end
                else
                    love.graphics.setColor(1,1,1,1)
                    love.graphics.print(string.sub(drawSym, 1, 1), rx, ry + yOff)
                end
                love.graphics.setScissor()
            end

            row = row + 48
            local profileLabel = self.earthShopSlotResult and M.earthSlotProfileLabel(self.earthShopSlotResult.rewardProfile)
            if profileLabel then
                love.graphics.setColor(1, 0.55, 0.45)
                love.graphics.printf(profileLabel, fullX, row, fullW, "center")
            end
            row = row + rowStep - 10
        else
            love.graphics.setColor(1, 1, 1, 0.85)
            drawPanelSprite(self.slotSpinButtonImage, fullX, row - 2, fullW, rowStep + 4)
            love.graphics.setColor(1, 0.8, 0.3)
            love.graphics.printf(i18n.t("earth_slot_spin_prompt"), fullX, row, fullW, "center")
        end"""
code = code.replace(draw_old, draw_new)

with open("game/scenes/play.lua", "w") as f:
    f.write(code)
