local M = {}

-- docs/feedback/INBOX.md 처리대기 항목 11(c): the ship table used to carry
-- its own standalone `fuel` field and gate thrust on it, a leftover from an
-- earlier design where fuel constrained flight. game/expedition.lua's real
-- flight/altitude loop has never fuel-gated ascent (see its "Fuel is no
-- longer a flight constraint" comment), and game/scenes/play.lua only ever
-- *wrote* a dead ship.fuel mirror from expedition.fuel without ever reading
-- it back -- so this module-local simulation was unreachable, misleading
-- residue. Removed entirely: thrust now applies unconditionally and no
-- fuel field is ever created here.
function M.new()
    return { x = 0, y = 0, vx = 0, vy = 0, angle = -math.pi / 2 }
end

-- docs/feedback/INBOX.md item 11(c): fuel is no longer a flight constraint
-- anywhere in the game (game/expedition.lua's maneuverFuel/burnManeuverFuel
-- are no-ops and run.fuel is never burned by ascent/steering). This module
-- used to gate thrust on ship.fuel > 0 and drain a local fuel counter --
-- dead logic left over from the old fuel-limited-flight design that no
-- longer matches expedition.lua's rules and could only ever mislead a
-- future reader. Thrust now always works; `fuel` is kept only as a display
-- field that game/scenes/play.lua syncs from run.fuel (which itself is
-- purely cosmetic/no-op-driven), never mutated here.
function M.update(ship, dt, input)
    local turn = (input.right and 1 or 0) - (input.left and 1 or 0)
    ship.angle = ship.angle + turn * 2.3 * dt
    if input.thrust then
        local acceleration = 42
        ship.vx = ship.vx + math.cos(ship.angle) * acceleration * dt
        ship.vy = ship.vy + math.sin(ship.angle) * acceleration * dt
    end
    local drag = math.max(0, 1 - 0.08 * dt)
    ship.vx, ship.vy = ship.vx * drag, ship.vy * drag
    ship.x, ship.y = ship.x + ship.vx * dt, ship.y + ship.vy * dt
end

return M
