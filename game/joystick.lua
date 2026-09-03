-- Pure virtual-joystick math: given a touch/drag origin and current
-- point, returns a direction vector (dx, dy) and a 0..1 magnitude.
--
-- Slice 1 of the omnidirectional-movement request (docs/GAME_DESIGN.md
-- 이동 방식): the previous LEFT/RIGHT touch controls only ever produced a
-- binary +-1 horizontal value. This module lets a drag anywhere on
-- screen produce a full 2D direction, so the ship can be steered in any
-- direction instead of just left/right.
--
-- Deliberately framework-free (no love.* calls) so it can be unit tested
-- headlessly and reused by any future input surface (touch, mouse, a
-- future gamepad stick) that can supply an origin/current point pair.
local M = {}

-- Below this drag distance (canvas px) the input is treated as "not
-- dragged" (magnitude 0) so a simple tap-and-hold can fall back to the
-- legacy binary steering behavior instead of jittering on tiny finger
-- movement.
M.deadzone = 6

-- Drag distance (canvas px) at which the joystick reads full magnitude
-- (1.0). Input reach stays large so a finger/mouse can steer without
-- precision; the *drawn* disc is much smaller (visualRadius).
M.maxRadius = 40

-- On-screen stick size/alpha. The old disc used maxRadius (40px) at
-- ~0.35/0.9 alpha and read as a huge opaque overlay on the 720x1280
-- canvas. Keep input math on maxRadius; only the draw uses these.
M.visualRadius = 14
M.visualKnobRadius = 3
M.visualFillAlpha = 0.12
M.visualLineAlpha = 0.28
M.visualKnobAlpha = 0.4

-- Returns dx, dy, magnitude for a drag from (originX, originY) to
-- (currentX, currentY). dx/dy are components of a unit vector (or 0,0 if
-- within the deadzone); magnitude is 0..1, linearly scaled between the
-- deadzone and maxRadius and clamped at 1 beyond maxRadius.
function M.vector(originX, originY, currentX, currentY)
    local dx, dy = currentX - originX, currentY - originY
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance < M.deadzone then
        return 0, 0, 0
    end
    local magnitude = math.min(1, distance / M.maxRadius)
    return dx / distance, dy / distance, magnitude
end

return M
