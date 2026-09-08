local world = require("game.world")
local PlayScene = require("game.scenes.play")

local M = {}

-- Drifting asteroids / junk. Hitting one uses the same destroy/reset path
-- as a lethal planet collision.
function M.run()
    local a = world.debris(3, -2)
    local b = world.debris(3, -2)
    assert(#a == #b)
    for i = 1, #a do
        assert(a[i].id == b[i].id and a[i].x == b[i].x and a[i].y == b[i].y)
        assert(a[i].radius == b[i].radius and a[i].kind == b[i].kind)
        assert(a[i].vx ~= nil and a[i].vy ~= nil)
    end

    local kinds, sizes = {}, {}
    for sx = -8, 8 do
        for sy = -8, 8 do
            for _, piece in ipairs(world.debris(sx, sy)) do
                kinds[piece.kind] = true
                sizes[piece.radius] = true
                assert(piece.radius >= 2 and piece.radius <= 16)
                assert(piece.kind == "asteroid" or piece.kind == "can" or piece.kind == "scrap")
            end
        end
    end
    assert(kinds.asteroid and kinds.can and kinds.scrap,
        "debris field must mix asteroids with junk (cans/scrap)")
    local distinctSizes = 0
    for _ in pairs(sizes) do distinctSizes = distinctSizes + 1 end
    assert(distinctSizes >= 3, "debris must come in several sizes")

    local drifted = nil
    local driftBase = nil
    -- Find any sector that actually has debris for the drift test
    for sx = -5, 5 do
        for sy = -5, 5 do
            local d0 = world.debris(sx, sy)
            if #d0 > 0 then
                driftBase = d0
                drifted = world.debris(sx, sy, 2)
                break
            end
        end
        if drifted then break end
    end
    assert(driftBase and drifted, "must find at least one sector with debris in -5..5")
    assert(#drifted == #driftBase)
    local moved = false
    for i = 1, #driftBase do
        if drifted[i].x ~= driftBase[i].x or drifted[i].y ~= driftBase[i].y then moved = true end
    end
    assert(moved, "debris must drift over time")

    -- sub-test: debris has rotation field that changes over time
    for i = 1, #driftBase do
        assert(type(driftBase[i].rotation) == "number", "debris must have rotation field")
        assert(type(driftBase[i].rotSpeed) == "number", "debris must have rotSpeed field")
    end
    local rotated = false
    for i = 1, #driftBase do
        if drifted[i].rotation ~= driftBase[i].rotation then rotated = true end
    end
    assert(rotated, "debris rotation must change over time")

    local nearby = world.nearbyDebris(0, 0, 1)
    assert(type(nearby) == "table")

    -- sub-test A: debris at full durability deals exactly 1 damage (not instant kill)
    local debrisScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    debrisScene.expedition.phase = "ascending"
    debrisScene.expedition.money = 80
    debrisScene.expedition.sampleCount = 2
    debrisScene.expedition.pendingSampleValue = 40
    debrisScene.expedition.bestAltitude = 400
    debrisScene.ship.x, debrisScene.ship.y = 0, -40
    local nearbyDebris = world.nearbyDebris
    world.nearbyDebris = function()
        return { { id = "junk-can", x = 0, y = -40, radius = 3, kind = "can", vx = 0, vy = 0 } }
    end
    debrisScene:update(0)
    world.nearbyDebris = nearbyDebris
    -- durability was 3, damage=1 → should survive at 2
    assert(debrisScene.expedition.phase == "ascending", "ship must survive debris hit at full durability")
    assert(debrisScene.expedition.durability == 2, "debris must deal exactly 1 damage (3→2)")
    assert(debrisScene.expedition.money == 80, "money must be unchanged after non-lethal debris hit")

    -- sub-test B: debris when durability==1 destroys ship
    local debrisScene2 = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    debrisScene2.expedition.phase = "ascending"
    debrisScene2.expedition.money = 80
    debrisScene2.expedition.sampleCount = 2
    debrisScene2.expedition.pendingSampleValue = 40
    debrisScene2.expedition.bestAltitude = 400
    debrisScene2.expedition.durability = 1
    debrisScene2.ship.x, debrisScene2.ship.y = 0, -40
    local nearbyDebris2 = world.nearbyDebris
    world.nearbyDebris = function()
        return { { id = "junk-can2", x = 0, y = -40, radius = 3, kind = "can", vx = 0, vy = 0 } }
    end
    debrisScene2:update(0)
    world.nearbyDebris = nearbyDebris2
    local wiped = debrisScene2.expedition
    assert(wiped.phase == "destroyed" and wiped.durability == 0, "debris must destroy ship when durability==1")
    assert(wiped.money == 0 and wiped.sampleCount == 0 and wiped.pendingSampleValue == 0)
    assert(wiped.bestAltitude == 400)
    assert(debrisScene2.message == "SHIP DESTROYED  BEST 400  META RESET")
end

return M