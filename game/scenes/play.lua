local shipModule = require("game.ship")
local expedition = require("game.expedition")
local viewport = require("game.viewport")
local world = require("game.world")
local M = {}
M.__index = M

local function planetColor(hue)
    if hue < 0.33 then return 0.35, 0.75, 1 end
    if hue < 0.66 then return 0.95, 0.55, 0.3 end
    return 0.65, 0.45, 0.95
end

function M.new()
    local ship = shipModule.new()
    return setmetatable({
        ship = ship,
        expedition = expedition.new(),
        discovered = {},
        collided = {},
        discoveredCount = 0,
        message = "PRESS SPACE TO LAUNCH",
    }, M)
end

function M:update(dt)
    local left = love.keyboard.isDown("left", "a")
    local right = love.keyboard.isDown("right", "d")
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
                if expedition.damage(self.expedition, 1) then
                    self.message = string.format("SHIP DESTROYED  BEST %d  META RESET", math.floor(self.expedition.bestAltitude))
                    break
                end
                self.message = string.format("COLLISION  HULL %d/%d", self.expedition.durability, self.expedition.maxDurability)
            end
        end
    end
end

function M:keypressed(key)
    if self.expedition.phase == "settlement" and (key == "f" or key == "down" or key == "s") then
        if expedition.buyFuelUpgrade(self.expedition) then
            self.message = string.format("FUEL TANK UPGRADED  MAX %d", self.expedition.maxFuel)
        else
            self.message = string.format("NEED $%d FOR FUEL UPGRADE", self.expedition.fuelUpgradeCost)
        end
        return
    end
    if key == "space" or key == "return" or key == "up" or key == "w" then
        if self.expedition.phase == "returning" and expedition.useSlot(self.expedition) then
            self.message = string.format("SLOT SPIN %d  %d CHANCES LEFT", self.expedition.slotSpins, self.expedition.slotOpportunities)
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

    love.graphics.setColor(0.02, 0.03, 0.08, 0.85)
    love.graphics.rectangle("fill", 0, 0, viewport.width, 34)
    love.graphics.setColor(0.7, 0.9, 1)
    love.graphics.print(string.format("ALT %04d  SAMPLES %02d  $%d", math.floor(self.expedition.altitude), self.expedition.sampleCount, self.expedition.money), 5, 4)
    love.graphics.print(string.format("F%03d H%d/%d %-9s S%02d", math.floor(self.expedition.fuel), self.expedition.durability, self.expedition.maxDurability, string.upper(self.expedition.phase), self.expedition.slotOpportunities), 5, 18)
    if self.expedition.phase == "settlement" then
        love.graphics.setColor(0.02, 0.03, 0.08, 0.92)
        love.graphics.rectangle("fill", 12, 214, viewport.width - 24, 62)
        love.graphics.setColor(0.7, 0.9, 1)
        love.graphics.printf(string.format("EARTH SHOP  FUEL LV.%d  MAX %d", self.expedition.fuelUpgradeLevel, self.expedition.maxFuel), 16, 222, viewport.width - 32, "center")
        love.graphics.printf(string.format("F / DOWN: +%d FUEL  $%d", self.expedition.fuelUpgradeAmount, self.expedition.fuelUpgradeCost), 16, 240, viewport.width - 32, "center")
        love.graphics.printf("SPACE: RELAUNCH", 16, 258, viewport.width - 32, "center")
    elseif self.expedition.phase == "destroyed" then
        love.graphics.setColor(0.08, 0.02, 0.03, 0.94)
        love.graphics.rectangle("fill", 12, 214, viewport.width - 24, 62)
        love.graphics.setColor(1, 0.55, 0.45)
        love.graphics.printf("SHIP DESTROYED", 16, 222, viewport.width - 32, "center")
        love.graphics.printf(string.format("META RESET  BEST %d", math.floor(self.expedition.bestAltitude)), 16, 240, viewport.width - 32, "center")
        love.graphics.printf("SPACE: START OVER", 16, 258, viewport.width - 32, "center")
    end
    love.graphics.setColor(0.85, 0.9, 1)
    love.graphics.printf(self.message, 4, viewport.height - 30, viewport.width - 8, "center")
    love.graphics.setColor(1, 0.65, 0.2, 0.85)
    love.graphics.printf("DEV PLACEHOLDER", 4, viewport.height - 13, viewport.width - 8, "center")
end

return M
