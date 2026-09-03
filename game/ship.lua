local M = {}

function M.new()
    return { x = 0, y = 0, vx = 0, vy = 0, angle = -math.pi / 2 }
end

function M.update(ship, dt, input)
    local dx = 0
    local dy = 0
    if input.right then dx = dx + 1 end
    if input.left then dx = dx - 1 end
    if input.down then dy = dy + 1 end
    if input.up then dy = dy - 1 end
    
    if dx ~= 0 or dy ~= 0 then
        local mag = math.sqrt(dx * dx + dy * dy)
        dx = dx / mag
        dy = dy / mag
        
        local acceleration = 42
        ship.vx = ship.vx + dx * acceleration * dt
        ship.vy = ship.vy + dy * acceleration * dt
        ship.angle = math.atan2(dy, dx)
    elseif input.thrust then
        -- legacy forward thrust
        local acceleration = 42
        ship.vx = ship.vx + math.cos(ship.angle) * acceleration * dt
        ship.vy = ship.vy + math.sin(ship.angle) * acceleration * dt
    end
    
    local drag = math.max(0, 1 - 0.08 * dt)
    ship.vx, ship.vy = ship.vx * drag, ship.vy * drag
    ship.x, ship.y = ship.x + ship.vx * dt, ship.y + ship.vy * dt
end

return M
