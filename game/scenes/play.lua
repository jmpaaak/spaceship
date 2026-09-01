local shipModule = require("game.ship")
local expedition = require("game.expedition")
local bestAltitudeStore = require("game.best_altitude_store")
local viewport = require("game.viewport")
local world = require("game.world")
local M = {}
M.__index = M

local function planetColor(hue)
    if hue < 0.33 then return 0.35, 0.75, 1 end
    if hue < 0.66 then return 0.95, 0.55, 0.3 end
    return 0.65, 0.45, 0.95
end

function M.new(options)
    options = options or {}
    local ship = shipModule.new()
    local altitudeStore = options.bestAltitudeStore or bestAltitudeStore.new()
    return setmetatable({
        ship = ship,
        expedition = expedition.new({ bestAltitude = altitudeStore:load() }),
        bestAltitudeStore = altitudeStore,
        discovered = {},
        collided = {},
        discoveredCount = 0,
        touches = {},
        message = "TAP TO LAUNCH",
    }, M)
end

function M:persistBestAltitude()
    return self.bestAltitudeStore:save(self.expedition.bestAltitude)
end

function M:collisionRisk(planet)
    if self.expedition.phase ~= "ascending" then return nil end
    local damage = world.collisionDamage(planet)
    local lethal = damage >= self.expedition.durability
    local sampleValue = world.sampleValue(planet)
    return {
        damage = damage,
        lethal = lethal,
        label = string.format(lethal and "LETHAL -%d" or "RISK -%d", damage),
        sampleValue = sampleValue,
        sampleLabel = string.format("SAMPLE $%d", sampleValue),
    }
end

function M:hudLines()
    local run = self.expedition
    local samples
    local best
    local earth
    local returnProgress
    if run.phase == "ascending" or run.phase == "returning" then
        samples = string.format("SAMPLES %02d  AT RISK $%d", run.sampleCount, run.pendingSampleValue)
        if run.phase == "returning" then
            earth = string.format("EARTH IN %d", math.ceil(run.altitude))
            local progress = 1
            if run.returnDistance > 0 then
                progress = math.max(0, math.min(1, 1 - run.altitude / run.returnDistance))
            end
            local secondsLeft = run.returnSpeed > 0 and math.ceil(run.altitude / run.returnSpeed) or 0
            returnProgress = string.format("RETURN %d%%  %ds LEFT",
                math.floor(progress * 100 + 0.5), secondsLeft)
        end
    elseif run.phase == "launch" or run.phase == "settlement" then
        best = string.format("PERSONAL BEST %04d", math.floor(run.bestAltitude))
    end
    return {
        primary = string.format("ALT %04d  CASH $%d", math.floor(run.altitude), run.money),
        samples = samples,
        best = best,
        earth = earth,
        returnProgress = returnProgress,
        status = string.format("F%03d H%d/%d %-9s S%02d", math.floor(run.fuel), run.durability,
            run.maxDurability, string.upper(run.phase), run.slotOpportunities),
    }
end

function M:loadoutLines()
    local run = self.expedition
    return {
        ship = string.format("SHIP %s", string.upper(run.selectedShipId)),
        upgrades = string.format("FUEL LV.%d  HULL LV.%d",
            run.fuelUpgradeLevel, run.durabilityUpgradeLevel),
    }
end

local function purchaseStatus(money, cost)
    if money >= cost then return string.format("LEFT $%d", money - cost), true end
    return string.format("SHORT $%d", cost - money), false
end

local function purchaseShortfallMessage(money, cost, item)
    return string.format("NEED $%d MORE FOR %s", cost - money, item)
end

function M:shopLoadoutLines()
    local run = self.expedition
    local shipAction
    local shipAffordable
    local shipStatus
    if not run.ownedShips.scout then
        shipAction = string.format("BUY SCOUT $%d", run.scoutShipCost)
        shipStatus, shipAffordable = purchaseStatus(run.money, run.scoutShipCost)
    elseif run.selectedShipId == "scout" then
        shipAction = "SELECT STARTER"
        shipAffordable = true
        shipStatus = "OWNED"
    else
        shipAction = "SELECT SCOUT"
        shipAffordable = true
        shipStatus = "OWNED"
    end
    local fuelStatus, fuelAffordable = purchaseStatus(run.money, run.fuelUpgradeCost)
    local hullStatus, hullAffordable = purchaseStatus(run.money, run.durabilityUpgradeCost)
    return {
        ship = string.format("NEXT %s", string.upper(run.selectedShipId)),
        stats = string.format("MAX FUEL %d  HULL %d", run.maxFuel, run.maxDurability),
        scoutTradeoff = string.format("SCOUT %+d FUEL / %+d HULL",
            run.scoutFuelBonus, run.scoutDurabilityBonus),
        shipAction = shipAction,
        shipStatus = shipStatus,
        shipAffordable = shipAffordable,
        fuelAction = string.format("T/F FUEL L%d +%d $%d", run.fuelUpgradeLevel,
            run.fuelUpgradeAmount, run.fuelUpgradeCost),
        fuelStatus = fuelStatus,
        fuelAffordable = fuelAffordable,
        hullAction = string.format("T/H HULL L%d +%d $%d", run.durabilityUpgradeLevel,
            run.durabilityUpgradeAmount, run.durabilityUpgradeCost),
        hullStatus = hullStatus,
        hullAffordable = hullAffordable,
    }
end

function M:slotButtonState()
    local chances = self.expedition.slotOpportunities
    if self.expedition.phase ~= "returning" or chances <= 0 then
        return { enabled = false, label = "NO SLOT CHANCES" }
    end
    return {
        enabled = true,
        label = string.format("TAP: SLOT SPIN  %d LEFT", chances),
    }
end

function M:update(dt)
    local left = love.keyboard.isDown("left", "a")
    local right = love.keyboard.isDown("right", "d")
    for _, touch in pairs(self.touches) do
        if touch.x < viewport.width / 2 then
            left = true
        else
            right = true
        end
    end
    local previousPhase = self.expedition.phase
    if self.expedition.phase == "ascending" then
        self.ship.x = self.ship.x + ((right and 1 or 0) - (left and 1 or 0)) * 55 * dt
    end
    if self.expedition.phase == "ascending" or self.expedition.phase == "returning" then
        expedition.update(self.expedition, dt)
        self.ship.y = -self.expedition.altitude
        self.ship.fuel = self.expedition.fuel
    end
    if previousPhase ~= self.expedition.phase and self.expedition.phase == "returning" then
        self:persistBestAltitude()
        self.message = string.format("RETURNING  %d SLOT CHANCES", self.expedition.slotOpportunities)
    elseif previousPhase ~= self.expedition.phase and self.expedition.phase == "settlement" then
        self.message = string.format("SETTLED +$%d  BALANCE $%d", self.expedition.lastSettlement, self.expedition.money)
    end
    if self.expedition.phase == "ascending" then
        for _, planet in ipairs(world.nearbyPlanets(self.ship.x, self.ship.y, 1)) do
            local dx, dy = planet.x - self.ship.x, planet.y - self.ship.y
            local distanceSquared = dx * dx + dy * dy
            if distanceSquared <= (planet.radius + 14) ^ 2 and not self.discovered[planet.id] then
                self.discovered[planet.id] = true
                self.discoveredCount = self.discoveredCount + 1
                local value = world.sampleValue(planet)
                expedition.collectSample(self.expedition, value)
                self.message = string.format("SAMPLE +$%d  %s", value, planet.id)
            end
            if distanceSquared <= (planet.radius + 5) ^ 2 and not self.collided[planet.id] then
                self.collided[planet.id] = true
                local damage = world.collisionDamage(planet)
                if expedition.damage(self.expedition, damage) then
                    self:persistBestAltitude()
                    self.message = string.format("SHIP DESTROYED  BEST %d  META RESET", math.floor(self.expedition.bestAltitude))
                    break
                end
                self.message = string.format("COLLISION -%d  HULL %d/%d", damage, self.expedition.durability, self.expedition.maxDurability)
            end
        end
    end
    if self.expedition.phase ~= "ascending" then self.touches = {} end
end

function M:keypressed(key)
    if self.expedition.phase == "settlement" and (key == "f" or key == "down" or key == "s") then
        if expedition.buyFuelUpgrade(self.expedition) then
            self.message = string.format("FUEL TANK UPGRADED  MAX %d  BALANCE $%d",
                self.expedition.maxFuel, self.expedition.money)
        else
            self.message = purchaseShortfallMessage(self.expedition.money,
                self.expedition.fuelUpgradeCost, "FUEL UPGRADE")
        end
        return
    end
    if self.expedition.phase == "settlement" and (key == "h" or key == "right" or key == "d") then
        if expedition.buyDurabilityUpgrade(self.expedition) then
            self.message = string.format("HULL UPGRADED  MAX %d  BALANCE $%d",
                self.expedition.maxDurability, self.expedition.money)
        else
            self.message = purchaseShortfallMessage(self.expedition.money,
                self.expedition.durabilityUpgradeCost, "HULL UPGRADE")
        end
        return
    end
    if self.expedition.phase == "settlement" and key == "v" then
        if not self.expedition.ownedShips.scout then
            if expedition.buyShip(self.expedition, "scout") then
                expedition.selectShip(self.expedition, "scout")
                self.message = string.format("SCOUT PURCHASED AND SELECTED  BALANCE $%d",
                    self.expedition.money)
            else
                self.message = purchaseShortfallMessage(self.expedition.money,
                    self.expedition.scoutShipCost, "SCOUT")
            end
        else
            local shipId = self.expedition.selectedShipId == "scout" and "starter" or "scout"
            expedition.selectShip(self.expedition, shipId)
            self.message = string.format("%s SELECTED", string.upper(shipId))
        end
        return
    end
    if key == "space" or key == "return" or key == "up" or key == "w" then
        if self.expedition.phase == "returning" and expedition.useSlot(self.expedition) then
            self.message = string.format("%s +$%d  %d LEFT",
                table.concat(self.expedition.lastSlotSymbols, " "),
                self.expedition.lastSlotReward,
                self.expedition.slotOpportunities)
        else
            local relaunching = self.expedition.phase == "settlement" or self.expedition.phase == "destroyed"
            if expedition.launch(self.expedition) then
                if relaunching then
                    self.ship.x = 0
                    self.ship.y = 0
                    self.ship.fuel = self.expedition.fuel
                    self.discovered = {}
                    self.collided = {}
                    self.discoveredCount = 0
                end
                self.message = "ASCENDING  STEER LEFT / RIGHT"
            end
        end
    end
end

function M:touchpressed(id, x, y)
    if self.expedition.phase == "ascending" then
        self.touches[id] = { x = x, y = y }
        return
    end
    if self.expedition.phase == "settlement" then
        if y >= 184 and y < 206 then
            self:keypressed("f")
        elseif y >= 206 and y < 224 then
            self:keypressed("h")
        elseif y >= 224 and y < 250 then
            self:keypressed("v")
        elseif y >= 250 and y <= 280 then
            self:keypressed("space")
        end
        return
    end
    if self.expedition.phase == "launch" or self.expedition.phase == "returning" or self.expedition.phase == "destroyed" then
        self:keypressed("space")
    end
end

function M:touchmoved(id, x, y)
    if self.touches[id] then
        self.touches[id].x = x
        self.touches[id].y = y
    end
end

function M:touchreleased(id)
    self.touches[id] = nil
end

function M:draw()
    love.graphics.clear(0.015, 0.02, 0.055)
    local shipScreenX, shipScreenY = viewport.width / 2, math.floor(viewport.height * 0.58)
    local cameraX, cameraY = self.ship.x - shipScreenX, self.ship.y - shipScreenY
    local sx, sy = world.sectorAt(self.ship.x, self.ship.y)
    for oy = -1, 1 do
        for ox = -1, 1 do
            for _, star in ipairs(world.stars(sx + ox, sy + oy)) do
                local x, y = math.floor(star.x - cameraX), math.floor(star.y - cameraY)
                if x >= 0 and x < viewport.width and y >= 0 and y < viewport.height then
                    local c = 0.35 + star.bright * 0.65
                    love.graphics.setColor(c, c, math.min(1, c + 0.1))
                    love.graphics.points(x, y)
                end
            end
        end
    end
    local earthX, earthY = math.floor(-cameraX), math.floor(75 - cameraY)
    if earthY < viewport.height + 64 then
        love.graphics.setColor(0.15, 0.45, 0.9)
        love.graphics.circle("fill", earthX, earthY, 58)
        love.graphics.setColor(0.25, 0.8, 0.45)
        love.graphics.circle("fill", earthX - 18, earthY - 18, 15)
        love.graphics.circle("fill", earthX + 21, earthY - 5, 12)
    end
    for _, planet in ipairs(world.nearbyPlanets(self.ship.x, self.ship.y, 1)) do
        local x, y = math.floor(planet.x - cameraX), math.floor(planet.y - cameraY)
        if x > -24 and x < viewport.width + 24 and y > -24 and y < viewport.height + 24 then
            love.graphics.setColor(planetColor(planet.hue))
            love.graphics.circle("fill", x, y, planet.radius)
            love.graphics.setColor(0.9, 0.95, 1, 0.45)
            love.graphics.circle("line", x, y, planet.radius + 2)
            if y >= 40 and y < shipScreenY then
                local risk = self:collisionRisk(planet)
                if risk then
                    local previewX = math.max(2, math.min(viewport.width - 66, x - 33))
                    local previewY = math.max(48, y - planet.radius - 24)
                    love.graphics.setColor(0.45, 0.95, 1)
                    love.graphics.printf(risk.sampleLabel, previewX, previewY, 66, "center")
                    if risk.lethal then
                        love.graphics.setColor(1, 0.3, 0.25)
                    else
                        love.graphics.setColor(1, 0.8, 0.25)
                    end
                    love.graphics.printf(risk.label, previewX, previewY + 11, 66, "center")
                end
            end
        end
    end
    love.graphics.push()
    love.graphics.translate(shipScreenX, shipScreenY)
    love.graphics.rotate(self.ship.angle + math.pi / 2)
    love.graphics.setColor(0.8, 0.95, 1)
    love.graphics.polygon("fill", 0, -7, -5, 6, 0, 3, 5, 6)
    if self.expedition.phase == "ascending" then
        love.graphics.setColor(1, 0.55, 0.15)
        love.graphics.polygon("fill", -2, 5, 0, 11, 2, 5)
    end
    love.graphics.pop()

    local hud = self:hudLines()
    local hudHeight = hud.returnProgress and 70 or ((hud.samples or hud.best) and 46 or 34)
    love.graphics.setColor(0.02, 0.03, 0.08, 0.85)
    love.graphics.rectangle("fill", 0, 0, viewport.width, hudHeight)
    love.graphics.setColor(0.7, 0.9, 1)
    love.graphics.print(hud.primary, 5, 4)
    if hud.samples then
        love.graphics.setColor(1, 0.8, 0.3)
        love.graphics.print(hud.samples, 5, 16)
        love.graphics.setColor(0.7, 0.9, 1)
        love.graphics.print(hud.status, 5, 30)
        if hud.earth then
            love.graphics.setColor(0.4, 0.85, 1)
            love.graphics.print(hud.earth, 5, 43)
            love.graphics.print(hud.returnProgress, 5, 55)
        end
    elseif hud.best then
        love.graphics.print(hud.status, 5, 18)
        love.graphics.setColor(1, 0.8, 0.3)
        love.graphics.print(hud.best, 5, 30)
    else
        love.graphics.print(hud.status, 5, 18)
    end
    if self.expedition.phase == "launch" then
        local loadout = self:loadoutLines()
        love.graphics.setColor(0.02, 0.03, 0.08, 0.92)
        love.graphics.rectangle("fill", 12, 220, viewport.width - 24, 58)
        love.graphics.setColor(0.7, 0.9, 1)
        love.graphics.printf("LAUNCH LOADOUT", 16, 226, viewport.width - 32, "center")
        love.graphics.setColor(1, 0.8, 0.3)
        love.graphics.printf(loadout.ship, 16, 242, viewport.width - 32, "center")
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(loadout.upgrades, 16, 258, viewport.width - 32, "center")
    elseif self.expedition.phase == "settlement" then
        love.graphics.setColor(0.02, 0.03, 0.08, 0.92)
        love.graphics.rectangle("fill", 12, 122, viewport.width - 24, 168)
        love.graphics.setColor(0.7, 0.9, 1)
        love.graphics.printf("EARTH SHOP", 16, 126, viewport.width - 32, "center")
        love.graphics.setColor(1, 0.8, 0.3)
        love.graphics.printf(string.format("SETTLEMENT TOTAL $%d", self.expedition.lastSettlement), 16, 142, viewport.width - 32, "center")
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(string.format("SAMPLES $%d", self.expedition.lastSampleSettlement), 16, 156, viewport.width - 32, "center")
        love.graphics.printf(string.format("SLOTS $%d", self.expedition.lastSlotSettlement), 16, 168, viewport.width - 32, "center")
        local nextLaunch = self:shopLoadoutLines()
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(nextLaunch.fuelAction, 16, 190, 88, "left")
        love.graphics.printf(nextLaunch.hullAction, 16, 208, 88, "left")
        love.graphics.setColor(nextLaunch.fuelAffordable and 0.45 or 1,
            nextLaunch.fuelAffordable and 1 or 0.4, nextLaunch.fuelAffordable and 0.55 or 0.35)
        love.graphics.printf(nextLaunch.fuelStatus, 104, 190, 60, "right")
        love.graphics.setColor(nextLaunch.hullAffordable and 0.45 or 1,
            nextLaunch.hullAffordable and 1 or 0.4, nextLaunch.hullAffordable and 0.55 or 0.35)
        love.graphics.printf(nextLaunch.hullStatus, 104, 208, 60, "right")
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(nextLaunch.scoutTradeoff, 16, 224, viewport.width - 32, "center")
        love.graphics.printf("T/V " .. nextLaunch.shipAction, 16, 238, 88, "left")
        love.graphics.setColor(nextLaunch.shipAffordable and 0.45 or 1,
            nextLaunch.shipAffordable and 1 or 0.4, nextLaunch.shipAffordable and 0.55 or 0.35)
        love.graphics.printf(nextLaunch.shipStatus, 104, 238, 60, "right")
        love.graphics.setColor(1, 0.8, 0.3)
        love.graphics.printf(nextLaunch.ship, 16, 252, viewport.width - 32, "center")
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(nextLaunch.stats, 16, 264, viewport.width - 32, "center")
        love.graphics.printf("TAP: RELAUNCH", 16, 276, viewport.width - 32, "center")
    elseif self.expedition.phase == "destroyed" then
        local loadout = self:loadoutLines()
        love.graphics.setColor(0.08, 0.02, 0.03, 0.94)
        love.graphics.rectangle("fill", 12, 198, viewport.width - 24, 80)
        love.graphics.setColor(1, 0.55, 0.45)
        love.graphics.printf("SHIP DESTROYED", 16, 204, viewport.width - 32, "center")
        love.graphics.printf(string.format("META RESET  BEST %d", math.floor(self.expedition.bestAltitude)), 16, 218, viewport.width - 32, "center")
        love.graphics.setColor(1, 0.8, 0.3)
        love.graphics.printf("NEXT " .. loadout.ship, 16, 234, viewport.width - 32, "center")
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(loadout.upgrades, 16, 248, viewport.width - 32, "center")
        love.graphics.printf("TAP: START OVER", 16, 264, viewport.width - 32, "center")
    elseif self.expedition.phase == "ascending" then
        love.graphics.setColor(0.25, 0.55, 0.8, 0.45)
        love.graphics.rectangle("fill", 5, 254, 76, 24)
        love.graphics.rectangle("fill", 99, 254, 76, 24)
        love.graphics.setColor(0.85, 0.95, 1)
        love.graphics.printf("HOLD LEFT", 5, 262, 76, "center")
        love.graphics.printf("HOLD RIGHT", 99, 262, 76, "center")
    elseif self.expedition.phase == "returning" then
        if self.expedition.lastSlotSymbols then
            love.graphics.setColor(0.02, 0.03, 0.08, 0.9)
            love.graphics.rectangle("fill", 18, 210, 144, 36)
            love.graphics.setColor(0.85, 0.95, 1)
            love.graphics.printf(table.concat(self.expedition.lastSlotSymbols, "  "), 20, 216, 140, "center")
            love.graphics.setColor(1, 0.8, 0.3)
            love.graphics.printf(string.format("WIN +$%d  PENDING $%d",
                self.expedition.lastSlotReward,
                self.expedition.pendingSlotReward), 20, 231, 140, "center")
        end
        local slotButton = self:slotButtonState()
        if slotButton.enabled then
            love.graphics.setColor(0.25, 0.55, 0.8, 0.6)
        else
            love.graphics.setColor(0.18, 0.2, 0.25, 0.75)
        end
        love.graphics.rectangle("fill", 28, 254, 124, 24)
        if slotButton.enabled then
            love.graphics.setColor(0.85, 0.95, 1)
        else
            love.graphics.setColor(0.55, 0.58, 0.65)
        end
        love.graphics.printf(slotButton.label, 28, 262, 124, "center")
    end
    love.graphics.setColor(0.85, 0.9, 1)
    love.graphics.printf(self.message, 4, viewport.height - 30, viewport.width - 8, "center")
    love.graphics.setColor(1, 0.65, 0.2, 0.85)
    love.graphics.printf("DEV PLACEHOLDER", 4, viewport.height - 13, viewport.width - 8, "center")
end

return M
