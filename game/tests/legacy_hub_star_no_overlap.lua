local M = {}

function M.run()
    -- INBOX 61(33): hub planet must never overlap the central star.
    -- The distance from galaxy center to hub center must be >= starRadius + hub.radius + 40.
    local world = require("game.world")
    local checked = 0
    for gx = -10, 10 do
        for gy = -10, 10 do
            local g = world.galaxy(gx, gy)
            if g and g.id ~= "milkyway" then
                local hub = world.hubPlanet(g)
                if hub then
                    local dx = hub.x - g.x
                    local dy = hub.y - g.y
                    local dist = math.sqrt(dx * dx + dy * dy)
                    local minSafe = world.starRadius + hub.radius + 40
                    assert(dist >= minSafe,
                        string.format("INBOX 61(33): hub %s at dist %.1f overlaps star (need >= %.1f)",
                            hub.id, dist, minSafe))
                    checked = checked + 1
                end
            end
        end
    end
    assert(checked >= 3, "INBOX 61(33): need at least 3 galaxies checked, got " .. checked)
    print("  INBOX-61(33) hub-star no-overlap OK (" .. checked .. " galaxies)")
end

return M