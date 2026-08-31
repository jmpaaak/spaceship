local playerModule = require("game.player")
local M = {}
M.__index = M

function M.new()
    return setmetatable({ player = playerModule.new(), elapsed = 0 }, M)
end

function M:update(dt)
    self.elapsed = self.elapsed + dt
    playerModule.update(self.player, dt, {
        left = love.keyboard.isDown("left", "a"),
        right = love.keyboard.isDown("right", "d"),
        up = love.keyboard.isDown("up", "w"),
        down = love.keyboard.isDown("down", "s"),
    })
end

function M:draw()
    love.graphics.clear(0.025, 0.035, 0.08)
    love.graphics.setColor(0.08, 0.12, 0.22)
    for x = 0, 320, 16 do love.graphics.line(x, 0, x, 180) end
    for y = 0, 180, 16 do love.graphics.line(0, y, 320, y) end
    love.graphics.setColor(0.35, 0.85, 1)
    love.graphics.rectangle("fill", math.floor(self.player.x - 4), math.floor(self.player.y - 4), 8, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("LÖVE2D GAME SKELETON", 8, 8)
    love.graphics.print("Move: WASD / arrows", 8, 24)
end

return M
