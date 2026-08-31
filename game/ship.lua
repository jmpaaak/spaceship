local M = {}

function M.new()
    return { x = 0, y = 0, vx = 0, vy = 0, angle = -math.pi / 2, fuel = 100 }
end

function M.update(ship, dt, input)
    local turn = (input.right and 1 or 0) - (input.left and 1 or 0)
    ship.angle = ship.angle + turn * 2.3 * dt
    if input.thrust and ship.fuel > 0 then
        local acceleration = 42
        ship.vx = ship.vx + math.cos(ship.angle) * acceleration * dt
        ship.vy = ship.vy + math.sin(ship.angle) * acceleration * dt
        ship.fuel = math.max(0, ship.fuel - 1.8 * dt)
    end
    local drag = math.max(0, 1 - 0.08 * dt)
    ship.vx, ship.vy = ship.vx * drag, ship.vy * drag
    ship.x, ship.y = ship.x + ship.vx * dt, ship.y + ship.vy * dt
end

return M
