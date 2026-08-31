local M = {}

function M.new()
    return { x = 160, y = 90, speed = 72 }
end

function M.update(player, dt, input)
    local dx = (input.right and 1 or 0) - (input.left and 1 or 0)
    local dy = (input.down and 1 or 0) - (input.up and 1 or 0)
    if dx ~= 0 and dy ~= 0 then
        local diagonal = 1 / math.sqrt(2)
        dx, dy = dx * diagonal, dy * diagonal
    end
    player.x = math.max(5, math.min(315, player.x + dx * player.speed * dt))
    player.y = math.max(5, math.min(175, player.y + dy * player.speed * dt))
end

return M
