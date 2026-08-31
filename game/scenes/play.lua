local shipModule = require("game.ship")
local world = require("game.world")
local M = {}
M.__index = M

local function planetColor(hue)
    if hue < 0.33 then return 0.35, 0.75, 1 end
    if hue < 0.66 then return 0.95, 0.55, 0.3 end
    return 0.65, 0.45, 0.95
end

function M.new()
    return setmetatable({ ship = shipModule.new(), discovered = {}, discoveredCount = 0, message = "UNCHARTED SPACE AHEAD" }, M)
end

function M:update(dt)
    shipModule.update(self.ship, dt, {
        left = love.keyboard.isDown("left", "a"),
        right = love.keyboard.isDown("right", "d"),
        thrust = love.keyboard.isDown("up", "w", "space"),
    })
    for _, planet in ipairs(world.nearbyPlanets(self.ship.x, self.ship.y, 1)) do
        local dx, dy = planet.x - self.ship.x, planet.y - self.ship.y
        if dx * dx + dy * dy <= (planet.radius + 14) ^ 2 and not self.discovered[planet.id] then
            self.discovered[planet.id] = true
            self.discoveredCount = self.discoveredCount + 1
            self.message = "NEW PLANET DISCOVERED  " .. planet.id
        end
    end
end

function M:draw()
    love.graphics.clear(0.015, 0.02, 0.055)
    local cameraX, cameraY = self.ship.x - 160, self.ship.y - 90
    local sx, sy = world.sectorAt(self.ship.x, self.ship.y)
    for oy = -1, 1 do
        for ox = -1, 1 do
            for _, star in ipairs(world.stars(sx + ox, sy + oy)) do
                local x, y = math.floor(star.x - cameraX), math.floor(star.y - cameraY)
                if x >= 0 and x < 320 and y >= 0 and y < 180 then
                    local c = 0.35 + star.bright * 0.65
                    love.graphics.setColor(c, c, math.min(1, c + 0.1))
                    love.graphics.points(x, y)
                end
            end
        end
    end
    for _, planet in ipairs(world.nearbyPlanets(self.ship.x, self.ship.y, 1)) do
        local x, y = math.floor(planet.x - cameraX), math.floor(planet.y - cameraY)
        if x > -24 and x < 344 and y > -24 and y < 204 then
            love.graphics.setColor(planetColor(planet.hue))
            love.graphics.circle("fill", x, y, planet.radius)
            love.graphics.setColor(0.9, 0.95, 1, 0.45)
            love.graphics.circle("line", x, y, planet.radius + 2)
        end
    end
    love.graphics.push()
    love.graphics.translate(160, 90)
    love.graphics.rotate(self.ship.angle + math.pi / 2)
    love.graphics.setColor(0.8, 0.95, 1)
    love.graphics.polygon("fill", 0, -7, -5, 6, 0, 3, 5, 6)
    if love.keyboard.isDown("up", "w", "space") then
        love.graphics.setColor(1, 0.55, 0.15)
        love.graphics.polygon("fill", -2, 5, 0, 11, 2, 5)
    end
    love.graphics.pop()

    love.graphics.setColor(0.02, 0.03, 0.08, 0.85)
    love.graphics.rectangle("fill", 0, 0, 320, 24)
    love.graphics.setColor(0.7, 0.9, 1)
    love.graphics.print(string.format("SECTOR %d,%d   DISCOVERED %d   FUEL %03d", sx, sy, self.discoveredCount, math.floor(self.ship.fuel)), 6, 5)
    love.graphics.setColor(0.85, 0.9, 1)
    love.graphics.print(self.message, 6, 164)
end

return M
