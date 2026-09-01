local shipModule = require("game.ship")
local expedition = require("game.expedition")
local bestAltitudeStore = require("game.best_altitude_store")
local viewport = require("game.viewport")
local world = require("game.world")
local M = {}
M.__index = M

local steeringSpeed = 55
local returnControls = {
    top = 254,
    bottom = 278,
    leftMaxX = 55,
    slotMinX = 60,
    slotMaxX = 120,
    rightMinX = 125,
}

local function planetColor(hue)
    if hue < 0.33 then return 0.35, 0.75, 1 end
    if hue < 0.66 then return 0.95, 0.55, 0.3 end
    return 0.65, 0.45, 0.95
end

local sampleTierColors = {
    common = { 0.75, 0.8, 0.85 },
    rare = { 0.35, 0.75, 1 },
    epic = { 0.95, 0.7, 0.15 },
}

local function sampleTierColor(tier)
    local color = sampleTierColors[tier] or sampleTierColors.common
    return color[1], color[2], color[3]
end
M.sampleTierColor = sampleTierColor

local warningLabelMargin = 2

local function clampLabelX(centerX, textWidth, viewportWidth, margin)
    margin = margin or warningLabelMargin
    local x = centerX - textWidth / 2
    local maxX = viewportWidth - margin - textWidth
    if x > maxX then x = maxX end
    if x < margin then x = margin end
    return x
end
M.clampLabelX = clampLabelX

local slotReelStagger = 0.15
local slotSpinDuration = slotReelStagger * 3

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
        floatingTexts = {},
        slotSpin = nil,
        touches = {},
        message = "TAP TO LAUNCH",
    }, M)
end

function M:persistBestAltitude()
    return self.bestAltitudeStore:save(self.expedition.bestAltitude)
end

function M:collisionRisk(planet)
    local phase = self.expedition.phase
    if phase ~= "ascending" and phase ~= "returning" then return nil end
    local damage = world.collisionDamage(planet)
    local lethal = damage >= self.expedition.durability
    local risk = {
        damage = damage,
        lethal = lethal,
        label = string.format(lethal and "LETHAL -%d" or "RISK -%d", damage),
    }
    if phase == "ascending" then
        risk.sampleValue = world.sampleValue(planet)
        risk.sampleLabel = string.format("SAMPLE $%d", risk.sampleValue)
    end
    return risk
end

function M:approachWarning(planet, planetScreenY, shipScreenY)
    if planet.id and self.collided[planet.id] then return nil end
    local phase = self.expedition.phase
    local approaching = phase == "ascending" and planetScreenY >= 40 and planetScreenY < shipScreenY
        or phase == "returning" and planetScreenY > shipScreenY and planetScreenY < viewport.height
    if not approaching then return nil end
    return self:collisionRisk(planet)
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
        status = string.format("F%03d H%d/%d %-6s S%02d", math.floor(run.fuel), run.durability,
            run.maxDurability, string.upper(run.phase):sub(1, 6), run.slotOpportunities),
    }
end

local function launchForecastLine(run, maxFuel)
    local forecastAltitude, forecastSlots = expedition.launchForecast(run, maxFuel)
    return string.format("NO-HIT %d  SLOTS %d", math.floor(forecastAltitude), forecastSlots)
end

function M:loadoutLines()
    local run = self.expedition
    return {
        ship = string.format("SHIP %s", string.upper(run.selectedShipId)),
        stats = string.format("MAX FUEL %d  HULL %d", run.maxFuel, run.maxDurability),
        upgrades = string.format("FUEL LV.%d  HULL LV.%d",
            run.fuelUpgradeLevel, run.durabilityUpgradeLevel),
        forecast = launchForecastLine(run),
        odds = self:slotOddsLine(),
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
    local previewShipId
    if not run.ownedShips.scout then
        shipAction = string.format("BUY SCOUT $%d", run.scoutShipCost)
        shipStatus, shipAffordable = purchaseStatus(run.money, run.scoutShipCost)
        previewShipId = "scout"
    elseif run.selectedShipId == "scout" then
        shipAction = "SELECT STARTER"
        shipAffordable = true
        shipStatus = "OWNED"
        previewShipId = "starter"
    else
        shipAction = "SELECT SCOUT"
        shipAffordable = true
        shipStatus = "OWNED"
        previewShipId = "scout"
    end
    local previewFuel = run.baseFuel + run.fuelUpgradeLevel * run.fuelUpgradeAmount
    local previewDurability = run.baseDurability
        + run.durabilityUpgradeLevel * run.durabilityUpgradeAmount
    if previewShipId == "scout" then
        previewFuel = previewFuel + run.scoutFuelBonus
        previewDurability = previewDurability + run.scoutDurabilityBonus
    end
    local fuelStatus, fuelAffordable = purchaseStatus(run.money, run.fuelUpgradeCost)
    local hullStatus, hullAffordable = purchaseStatus(run.money, run.durabilityUpgradeCost)
    return {
        ship = string.format("NEXT %s", string.upper(run.selectedShipId)),
        stats = string.format("MAX FUEL %d  HULL %d", run.maxFuel, run.maxDurability),
        upgrades = string.format("FUEL LV.%d  HULL LV.%d",
            run.fuelUpgradeLevel, run.durabilityUpgradeLevel),
        forecast = launchForecastLine(run),
        scoutTradeoff = string.format("SCOUT %+d FUEL / %+d HULL",
            run.scoutFuelBonus, run.scoutDurabilityBonus),
        shipAction = shipAction,
        shipStatus = shipStatus,
        shipAffordable = shipAffordable,
        shipPreview = string.format("%s MAX FUEL %d  HULL %d",
            string.upper(previewShipId), previewFuel, previewDurability),
        shipPreviewForecast = launchForecastLine(run, previewFuel),
        fuelAction = string.format("T/F FUEL LV.%d>%d $%d",
            run.fuelUpgradeLevel, run.fuelUpgradeLevel + 1, run.fuelUpgradeCost),
        fuelPreviewForecast = launchForecastLine(run, run.maxFuel + run.fuelUpgradeAmount),
        fuelStatus = fuelStatus,
        fuelAffordable = fuelAffordable,
        hullAction = string.format("T/H HULL LV.%d>%d $%d",
            run.durabilityUpgradeLevel, run.durabilityUpgradeLevel + 1,
            run.durabilityUpgradeCost),
        hullPreview = string.format("MAX FUEL %d  HULL %d",
            run.maxFuel, run.maxDurability + run.durabilityUpgradeAmount),
        hullPreviewForecast = launchForecastLine(run),
        hullStatus = hullStatus,
        hullAffordable = hullAffordable,
        odds = self:slotOddsLine(),
    }
end

function M:slotOddsLine()
    local ev = expedition.slotExpectedValue()
    return string.format("C%d P%d S%d  AVG $%.2f",
        math.floor(expedition.slotSymbolProbability("COMET") * 100 + 0.5),
        math.floor(expedition.slotSymbolProbability("PLANET") * 100 + 0.5),
        math.floor(expedition.slotSymbolProbability("STAR") * 100 + 0.5),
        ev)
end

function M:slotButtonState()
    local chances = self.expedition.slotOpportunities
    if self.slotSpin then
        return { enabled = false, label = "SLOT SPINNING...", compactLabel = "SPINNING" }
    end
    if self.expedition.phase ~= "returning" or chances <= 0 then
        return { enabled = false, label = "NO SLOT CHANCES", compactLabel = "NO SLOTS" }
    end
    return {
        enabled = true,
        label = string.format("TAP: SLOT SPIN  %d LEFT", chances),
        compactLabel = string.format("SPIN %d", chances),
    }
end

function M:beginSlotSpin()
    self.slotSpin = {
        elapsed = 0,
        reelStagger = slotReelStagger,
        duration = slotSpinDuration,
        symbols = self.expedition.lastSlotSymbols,
        reward = self.expedition.lastSlotReward,
        opportunitiesAfter = self.expedition.slotOpportunities,
    }
    self.message = "SLOT SPINNING..."
end

function M:currentSlotReels()
    if not self.slotSpin then
        return self.expedition.lastSlotSymbols
    end
    local reels = {}
    for i = 1, 3 do
        local stopTime = i * self.slotSpin.reelStagger
        if self.slotSpin.elapsed >= stopTime then
            reels[i] = self.slotSpin.symbols[i]
        else
            local cycle = math.floor(self.slotSpin.elapsed * 12) + i
            reels[i] = expedition.slotSymbols[(cycle % #expedition.slotSymbols) + 1]
        end
    end
    return reels
end

function M:steeringButtonState()
    local left = love.keyboard.isDown("left", "a")
    local right = love.keyboard.isDown("right", "d")
    for _, touch in pairs(self.touches) do
        if touch.x < viewport.width / 2 then
            left = true
        else
            right = true
        end
    end
    return { leftActive = left, rightActive = right }
end

function M:update(dt)
    local steering = self:steeringButtonState()
    local previousPhase = self.expedition.phase
    for i = #self.floatingTexts, 1, -1 do
        local ft = self.floatingTexts[i]
        ft.timer = ft.timer - dt
        ft.y = ft.y - 20 * dt
        if ft.timer <= 0 then
            table.remove(self.floatingTexts, i)
        end
    end
    if self.slotSpin then
        self.slotSpin.elapsed = self.slotSpin.elapsed + dt
        if self.slotSpin.elapsed >= self.slotSpin.duration then
            self.message = string.format("%s +$%d  %d LEFT",
                table.concat(self.slotSpin.symbols, " "),
                self.slotSpin.reward,
                self.slotSpin.opportunitiesAfter)
            self.slotSpin = nil
        end
    end
    if self.expedition.phase == "ascending" or self.expedition.phase == "returning" then
        self.ship.x = self.ship.x
            + ((steering.rightActive and 1 or 0) - (steering.leftActive and 1 or 0))
            * steeringSpeed * dt
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
    if self.expedition.phase == "ascending" or self.expedition.phase == "returning" then
        for _, planet in ipairs(world.nearbyPlanets(self.ship.x, self.ship.y, 1)) do
            local dx, dy = planet.x - self.ship.x, planet.y - self.ship.y
            local distanceSquared = dx * dx + dy * dy
            if self.expedition.phase == "ascending"
                and distanceSquared <= (planet.radius + 14) ^ 2
                and not self.discovered[planet.id] then
                self.discovered[planet.id] = true
                self.discoveredCount = self.discoveredCount + 1
                local value = world.sampleValue(planet)
                expedition.collectSample(self.expedition, value)
                table.insert(self.floatingTexts, {
                    text = string.format("+$%d", value),
                    x = planet.x,
                    y = planet.y,
                    timer = 1.0,
                })
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
    if self.expedition.phase ~= "ascending" and self.expedition.phase ~= "returning" then
        self.touches = {}
    end
end

function M:keypressed(key)
    if self.expedition.phase == "settlement" and (key == "f" or key == "down" or key == "s") then
        if expedition.buyFuelUpgrade(self.expedition) then
            self.message = string.format("FUEL TANK UPGRADED  LV.%d  MAX %d  %s  BALANCE $%d",
                self.expedition.fuelUpgradeLevel, self.expedition.maxFuel,
                launchForecastLine(self.expedition), self.expedition.money)
        else
            self.message = purchaseShortfallMessage(self.expedition.money,
                self.expedition.fuelUpgradeCost, "FUEL UPGRADE")
        end
        return
    end
    if self.expedition.phase == "settlement" and (key == "h" or key == "right" or key == "d") then
        if expedition.buyDurabilityUpgrade(self.expedition) then
            self.message = string.format(
                "HULL UPGRADED  LV.%d  MAX FUEL %d  HULL %d  %s  BALANCE $%d",
                self.expedition.durabilityUpgradeLevel, self.expedition.maxFuel,
                self.expedition.maxDurability,
                launchForecastLine(self.expedition), self.expedition.money)
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
                self.message = string.format(
                    "SCOUT PURCHASED AND SELECTED  MAX FUEL %d  HULL %d  %s  BALANCE $%d",
                    self.expedition.maxFuel, self.expedition.maxDurability,
                    launchForecastLine(self.expedition), self.expedition.money)
            else
                self.message = purchaseShortfallMessage(self.expedition.money,
                    self.expedition.scoutShipCost, "SCOUT")
            end
        else
            local shipId = self.expedition.selectedShipId == "scout" and "starter" or "scout"
            expedition.selectShip(self.expedition, shipId)
            self.message = string.format("%s SELECTED  MAX FUEL %d  HULL %d  %s",
                string.upper(shipId), self.expedition.maxFuel, self.expedition.maxDurability,
                launchForecastLine(self.expedition))
        end
        return
    end
    if key == "space" or key == "return" or key == "up" or key == "w" then
        if self.expedition.phase == "returning" and not self.slotSpin and expedition.useSlot(self.expedition) then
            self:beginSlotSpin()
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
                    self.floatingTexts = {}
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
    if self.expedition.phase == "returning" then
        local inControlRow = y >= returnControls.top and y <= returnControls.bottom
        if inControlRow and x >= returnControls.slotMinX and x <= returnControls.slotMaxX then
            self:keypressed("space")
        elseif inControlRow and (x <= returnControls.leftMaxX or x >= returnControls.rightMinX) then
            self.touches[id] = { x = x, y = y }
        end
        return
    end
    if self.expedition.phase == "settlement" then
        if y >= 150 and y < 179 then
            self:keypressed("f")
        elseif y >= 179 and y < 212 then
            self:keypressed("h")
        elseif y >= 212 and y < 256 then
            self:keypressed("v")
        elseif y >= 256 and y <= 320 then
            self:keypressed("space")
        end
        return
    end
    if self.expedition.phase == "launch" or self.expedition.phase == "destroyed" then
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
            if not self.discovered[planet.id] then
                love.graphics.setColor(sampleTierColor(world.sampleTier(planet)))
                love.graphics.circle("line", x, y, planet.radius + 3)
            end
            love.graphics.setColor(0.9, 0.95, 1, 0.45)
            love.graphics.circle("line", x, y, planet.radius + 2)
            local risk = self:approachWarning(planet, y, shipScreenY)
            if risk then
                local font = love.graphics.getFont()
                local previewY
                if risk.sampleLabel then
                    previewY = math.max(48, y - planet.radius - 24)
                    love.graphics.setColor(0.45, 0.95, 1)
                    love.graphics.print(risk.sampleLabel,
                        clampLabelX(x, font:getWidth(risk.sampleLabel), viewport.width), previewY)
                    previewY = previewY + 11
                else
                    previewY = math.max(72, y - planet.radius - 12)
                end
                if risk.lethal then
                    love.graphics.setColor(1, 0.3, 0.25)
                else
                    love.graphics.setColor(1, 0.8, 0.25)
                end
                love.graphics.print(risk.label,
                    clampLabelX(x, font:getWidth(risk.label), viewport.width), previewY)
            end
        end
    end
    for _, ft in ipairs(self.floatingTexts) do
        local fx, fy = math.floor(ft.x - cameraX), math.floor(ft.y - cameraY)
        if fx >= -30 and fx <= viewport.width + 30 and fy >= -20 and fy <= viewport.height + 20 then
            local alpha = math.max(0, math.min(1, ft.timer))
            love.graphics.setColor(0.45, 1, 0.6, alpha)
            love.graphics.printf(ft.text, fx - 30, fy - 10, 60, "center")
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
        love.graphics.rectangle("fill", 12, 204, viewport.width - 24, 90)
        love.graphics.setColor(0.7, 0.9, 1)
        love.graphics.printf("LAUNCH LOADOUT", 16, 208, viewport.width - 32, "center")
        love.graphics.setColor(1, 0.8, 0.3)
        love.graphics.printf(loadout.ship, 16, 222, viewport.width - 32, "center")
        love.graphics.setColor(0.4, 0.85, 1)
        love.graphics.printf(loadout.stats, 16, 234, viewport.width - 32, "center")
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(loadout.upgrades, 16, 246, viewport.width - 32, "center")
        love.graphics.setColor(0.45, 1, 0.6)
        love.graphics.printf(loadout.forecast, 16, 260, viewport.width - 32, "center")
        self.smallFont = self.smallFont or love.graphics.newFont(8)
        local previousLaunchFont = love.graphics.getFont()
        love.graphics.setFont(self.smallFont)
        love.graphics.setColor(0.6, 0.8, 1)
        love.graphics.printf(loadout.odds, 16, 274, viewport.width - 32, "center")
        love.graphics.setFont(previousLaunchFont)
    elseif self.expedition.phase == "settlement" then
        love.graphics.setColor(0.02, 0.03, 0.08, 0.94)
        love.graphics.rectangle("fill", 12, 70, viewport.width - 24, 250)
        love.graphics.setColor(0.7, 0.9, 1)
        love.graphics.printf("EARTH SHOP", 16, 74, viewport.width - 32, "center")
        love.graphics.setColor(0.04, 0.08, 0.16, 0.85)
        love.graphics.rectangle("fill", 18, 90, viewport.width - 36, 62)
        love.graphics.setColor(1, 0.8, 0.3)
        love.graphics.printf(string.format("TOTAL $%d", self.expedition.lastSettlement), 22, 94, viewport.width - 44, "center")
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(string.format("SAMPLES (%d) $%d", self.expedition.lastSampleCount or 0, self.expedition.lastSampleSettlement), 22, 105, viewport.width - 44, "center")
        love.graphics.printf(string.format("SPINS (%d) $%d", self.expedition.lastSlotSpinsCount or 0, self.expedition.lastSlotSettlement), 22, 116, viewport.width - 44, "center")
        love.graphics.setColor(0.6, 0.8, 1)
        love.graphics.printf(string.format("PEAK ALT %d", math.floor(self.expedition.lastAltitude or 0)), 22, 127, viewport.width - 44, "center")
        if self.expedition.lastNewBest then
            love.graphics.setColor(1, 0.95, 0.3)
            love.graphics.printf("NEW BEST!", 22, 138, viewport.width - 44, "center")
        end
        local nextLaunch = self:shopLoadoutLines()
        self.smallFont = self.smallFont or love.graphics.newFont(8)
        local previousFont = love.graphics.getFont()
        love.graphics.setFont(self.smallFont)
        local actionX, actionW = 16, 102
        local statusX, statusW = 120, 48
        local fullX, fullW = 16, viewport.width - 32
        local row = 154
        local rowStep = 10
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(nextLaunch.fuelAction, actionX, row, actionW, "left")
        love.graphics.setColor(nextLaunch.fuelAffordable and 0.45 or 1,
            nextLaunch.fuelAffordable and 1 or 0.4, nextLaunch.fuelAffordable and 0.55 or 0.35)
        love.graphics.printf(nextLaunch.fuelStatus, statusX, row, statusW, "right")
        row = row + rowStep
        love.graphics.setColor(0.45, 1, 0.6)
        love.graphics.printf(nextLaunch.fuelPreviewForecast, fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(nextLaunch.hullAction, actionX, row, actionW, "left")
        love.graphics.setColor(nextLaunch.hullAffordable and 0.45 or 1,
            nextLaunch.hullAffordable and 1 or 0.4, nextLaunch.hullAffordable and 0.55 or 0.35)
        love.graphics.printf(nextLaunch.hullStatus, statusX, row, statusW, "right")
        row = row + rowStep
        love.graphics.setColor(0.4, 0.85, 1)
        love.graphics.printf(nextLaunch.hullPreview, fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.setColor(0.45, 1, 0.6)
        love.graphics.printf(nextLaunch.hullPreviewForecast, fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(nextLaunch.scoutTradeoff, fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.setColor(0.4, 0.85, 1)
        love.graphics.printf(nextLaunch.shipPreview, fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.setColor(0.45, 1, 0.6)
        love.graphics.printf(nextLaunch.shipPreviewForecast, fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf("T/V " .. nextLaunch.shipAction, actionX, row, actionW, "left")
        love.graphics.setColor(nextLaunch.shipAffordable and 0.45 or 1,
            nextLaunch.shipAffordable and 1 or 0.4, nextLaunch.shipAffordable and 0.55 or 0.35)
        love.graphics.printf(nextLaunch.shipStatus, statusX, row, statusW, "right")
        row = row + rowStep
        love.graphics.setColor(1, 0.8, 0.3)
        love.graphics.printf(nextLaunch.ship, fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(nextLaunch.stats, fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.printf(nextLaunch.upgrades, fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.setColor(0.45, 1, 0.6)
        love.graphics.printf(nextLaunch.forecast, fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.setColor(0.6, 0.8, 1)
        love.graphics.printf(nextLaunch.odds, fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf("TAP: RELAUNCH", fullX, row, fullW, "center")
        love.graphics.setFont(previousFont)
    elseif self.expedition.phase == "destroyed" then
        local loadout = self:loadoutLines()
        love.graphics.setColor(0.08, 0.02, 0.03, 0.94)
        love.graphics.rectangle("fill", 12, 174, viewport.width - 24, 134)
        self.smallFont = self.smallFont or love.graphics.newFont(8)
        local previousFont = love.graphics.getFont()
        love.graphics.setFont(self.smallFont)
        local fullX, fullW = 16, viewport.width - 32
        local row = 178
        local rowStep = 11
        love.graphics.setColor(1, 0.55, 0.45)
        love.graphics.printf("SHIP DESTROYED", fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.setColor(1, 0.8, 0.3)
        love.graphics.printf(string.format("LOST TOTAL $%d",
            (self.expedition.lastLostSampleValue or 0) + (self.expedition.lastLostSlotValue or 0)),
            fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(string.format("SAMPLES (%d) $%d",
            self.expedition.lastLostSampleCount or 0, self.expedition.lastLostSampleValue or 0),
            fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.printf(string.format("SPINS (%d) $%d",
            self.expedition.lastLostSlotSpinsCount or 0, self.expedition.lastLostSlotValue or 0),
            fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.setColor(0.6, 0.8, 1)
        love.graphics.printf(string.format("PEAK ALT %d", math.floor(self.expedition.lastLostAltitude or 0)),
            fullX, row, fullW, "center")
        row = row + rowStep
        if self.expedition.lastLostNewBest then
            love.graphics.setColor(1, 0.95, 0.3)
            love.graphics.printf("NEW BEST!", fullX, row, fullW, "center")
            row = row + rowStep
        end
        love.graphics.setColor(1, 0.55, 0.45)
        love.graphics.printf(string.format("META RESET  BEST %d", math.floor(self.expedition.bestAltitude)), fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.setColor(1, 0.8, 0.3)
        love.graphics.printf("NEXT " .. loadout.ship, fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(loadout.upgrades, fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.printf("TAP: START OVER", fullX, row, fullW, "center")
        love.graphics.setFont(previousFont)
    elseif self.expedition.phase == "ascending" then
        local steering = self:steeringButtonState()
        if steering.leftActive then
            love.graphics.setColor(0.35, 0.9, 1, 0.8)
        else
            love.graphics.setColor(0.25, 0.55, 0.8, 0.45)
        end
        love.graphics.rectangle("fill", 5, 254, 76, 24)
        if steering.rightActive then
            love.graphics.setColor(0.35, 0.9, 1, 0.8)
        else
            love.graphics.setColor(0.25, 0.55, 0.8, 0.45)
        end
        love.graphics.rectangle("fill", 99, 254, 76, 24)
        self.smallFont = self.smallFont or love.graphics.newFont(8)
        local previousSteeringFont = love.graphics.getFont()
        love.graphics.setFont(self.smallFont)
        love.graphics.setColor(steering.leftActive and 0.05 or 0.85,
            steering.leftActive and 0.15 or 0.95, steering.leftActive and 0.2 or 1)
        love.graphics.printf("HOLD LEFT", 5, 263, 76, "center")
        love.graphics.setColor(steering.rightActive and 0.05 or 0.85,
            steering.rightActive and 0.15 or 0.95, steering.rightActive and 0.2 or 1)
        love.graphics.printf("HOLD RIGHT", 99, 263, 76, "center")
        love.graphics.setFont(previousSteeringFont)
    elseif self.expedition.phase == "returning" then
        self.smallFont = self.smallFont or love.graphics.newFont(8)
        local previousOddsFont = love.graphics.getFont()
        love.graphics.setFont(self.smallFont)
        love.graphics.setColor(0.6, 0.8, 1)
        love.graphics.printf(self:slotOddsLine(), 12, 197, viewport.width - 24, "center")
        love.graphics.setFont(previousOddsFont)
        if self.slotSpin then
            love.graphics.setColor(0.02, 0.03, 0.08, 0.9)
            love.graphics.rectangle("fill", 18, 210, 144, 36)
            love.graphics.setColor(0.85, 0.95, 1)
            love.graphics.printf(table.concat(self:currentSlotReels(), "  "), 20, 216, 140, "center")
            love.graphics.setColor(1, 0.8, 0.3)
            love.graphics.printf("SPINNING...", 20, 231, 140, "center")
        elseif self.expedition.lastSlotSymbols then
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
        local steering = self:steeringButtonState()
        if steering.leftActive then
            love.graphics.setColor(0.35, 0.9, 1, 0.95)
        else
            love.graphics.setColor(0.25, 0.55, 0.8, 0.6)
        end
        love.graphics.rectangle("fill", 5, returnControls.top, 50, 24)
        if steering.rightActive then
            love.graphics.setColor(0.35, 0.9, 1, 0.95)
        else
            love.graphics.setColor(0.25, 0.55, 0.8, 0.6)
        end
        love.graphics.rectangle("fill", 125, returnControls.top, 50, 24)
        if slotButton.enabled then
            love.graphics.setColor(0.25, 0.55, 0.8, 0.6)
        else
            love.graphics.setColor(0.18, 0.2, 0.25, 0.75)
        end
        love.graphics.rectangle("fill", 60, returnControls.top, 60, 24)
        self.smallFont = self.smallFont or love.graphics.newFont(8)
        local previousReturnButtonFont = love.graphics.getFont()
        love.graphics.setFont(self.smallFont)
        love.graphics.setColor(steering.leftActive and 0.05 or 0.85,
            steering.leftActive and 0.15 or 0.95, steering.leftActive and 0.2 or 1)
        love.graphics.printf("LEFT", 5, 263, 50, "center")
        love.graphics.setColor(steering.rightActive and 0.05 or 0.85,
            steering.rightActive and 0.15 or 0.95, steering.rightActive and 0.2 or 1)
        love.graphics.printf("RIGHT", 125, 263, 50, "center")
        if slotButton.enabled then
            love.graphics.setColor(0.85, 0.95, 1)
        else
            love.graphics.setColor(0.55, 0.58, 0.65)
        end
        love.graphics.printf(slotButton.compactLabel, 60, 263, 60, "center")
        love.graphics.setFont(previousReturnButtonFont)
    end
    love.graphics.setColor(0.85, 0.9, 1)
    local messageY = (self.expedition.phase == "settlement" or self.expedition.phase == "destroyed") and 50 or viewport.height - 30
    love.graphics.printf(self.message, 4, messageY, viewport.width - 8, "center")
    love.graphics.setColor(1, 0.65, 0.2, 0.85)
    love.graphics.printf("DEV PLACEHOLDER", 4, viewport.height - 13, viewport.width - 8, "center")
end

return M
