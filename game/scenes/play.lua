local shipModule = require("game.ship")
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
    if os.getenv("GAME_CAPTURE") == "1" then
        for sy = -1, 1 do
            for sx = -1, 1 do
                local planets = world.planets(sx, sy)
                if #planets > 0 then
                    ship.x, ship.y = planets[1].x - 54, planets[1].y
                    return setmetatable({ ship = ship, discovered = {}, discoveredCount = 0, message = "UNCHARTED SPACE AHEAD" }, M)
                end
            end
        end
    end
    return setmetatable({ ship = ship, discovered = {}, discoveredCount = 0, message = "UNCHARTED SPACE AHEAD" }, M)
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
    if love.keyboard.isDown("up", "w", "space") then
        love.graphics.setColor(1, 0.55, 0.15)
        love.graphics.polygon("fill", -2, 5, 0, 11, 2, 5)
    end
    love.graphics.pop()

    love.graphics.setColor(0.02, 0.03, 0.08, 0.85)
    love.graphics.rectangle("fill", 0, 0, viewport.width, 34)
    love.graphics.setColor(0.7, 0.9, 1)
    love.graphics.print(string.format("ALT %04d  SAMPLES %02d", math.max(0, math.floor(-self.ship.y)), self.discoveredCount), 5, 4)
    love.graphics.print(string.format("FUEL %03d  SECTOR %d,%d", math.floor(self.ship.fuel), sx, sy), 5, 18)
    love.graphics.setColor(0.85, 0.9, 1)
    love.graphics.printf(self.message, 4, viewport.height - 30, viewport.width - 8, "center")
    love.graphics.setColor(1, 0.65, 0.2, 0.85)
    love.graphics.printf("DEV PLACEHOLDER", 4, viewport.height - 13, viewport.width - 8, "center")
end

return M
