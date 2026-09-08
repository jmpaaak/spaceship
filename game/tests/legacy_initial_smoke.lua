local viewport = require("game.viewport")
local shipModule = require("game.ship")
local world = require("game.world")
local M = {}

function M.run()
    require("game.i18n").setLocale("en")
    assert(viewport.width == 720 and viewport.height == 1280)
    local scale, x, y = viewport.fit(720, 1280, false)
    assert(scale == 1 and x == 0 and y == 0)
    local gx, gy, inside = viewport.toGame(360, 640, 720, 1280, false)
    assert(gx == 360 and gy == 640 and inside)

    local ship = shipModule.new()
    shipModule.update(ship, 1, { thrust = true })
    assert(ship.y < 0)
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
    assert(world.sampleValue({ y = -500 }) == 1, "flat $1 planet sample value")
    assert(world.sampleValue({ y = -50 }) == 1, "flat $1 planet sample value (close)")
    assert(world.collisionDamage({ y = -499 }) == 1)
    assert(world.collisionDamage({ y = -2000 }) == 2)
    assert(world.collisionDamage({ y = -4500 }) == 3)
end

return M