local viewport = require("game.viewport")
local shipModule = require("game.ship")
local world = require("game.world")
local M = {}

function M.run()
    local scale, x, y = viewport.fit(1280, 720, false)
    assert(scale == 4 and x == 0 and y == 0)
    local gx, gy, inside = viewport.toGame(640, 360, 1280, 720, false)
    assert(gx == 160 and gy == 90 and inside)

    local ship = shipModule.new()
    shipModule.update(ship, 1, { thrust = true })
    assert(ship.y < 0 and ship.fuel < 100)
    local before = ship.angle
    shipModule.update(ship, 1, { right = true })
    assert(ship.angle > before)

    local a = world.planets(7, -3)
    local b = world.planets(7, -3)
    assert(#a == #b)
    for i = 1, #a do
        assert(a[i].id == b[i].id and a[i].x == b[i].x and a[i].y == b[i].y)
    end
    local sx, sy = world.sectorAt(-1, -193)
    assert(sx == -1 and sy == -2)
    print("SPACESHIP_UNIT_OK")
end

return M
