local PlayScene = require("game.scenes.play")

local M = {}

-- Omnidirectional joystick movement (docs/GAME_DESIGN.md 이동 방식 개선 항목
-- 1, "조이스틱을 통해 전방향으로 이동 가능함"). This legacy coverage moved out
-- of self_test.lua so the central runner can continue shrinking.
function M.run()
    local joystick = require("game.joystick")
    local jdx, jdy, jmag = joystick.vector(0, 0, 0, 2)
    assert(jdx == 0 and jdy == 0 and jmag == 0, "drag inside the deadzone must report zero magnitude")
    jdx, jdy, jmag = joystick.vector(0, 0, 0, joystick.maxRadius)
    assert(math.abs(jdx - 0) < 1e-9 and math.abs(jdy - 1) < 1e-9 and math.abs(jmag - 1) < 1e-9,
        "a full-radius straight-down drag must report unit vector (0,1) at magnitude 1")
    jdx, jdy, jmag = joystick.vector(0, 0, joystick.maxRadius * 2, 0)
    assert(math.abs(jdx - 1) < 1e-9 and math.abs(jdy - 0) < 1e-9 and jmag == 1,
        "a drag beyond maxRadius must clamp magnitude at 1, not exceed it")
    local halfRadius = (joystick.deadzone + joystick.maxRadius) / 2
    jdx, jdy, jmag = joystick.vector(0, 0, 0, halfRadius)
    assert(jmag > 0 and jmag < 1, "a drag between deadzone and maxRadius must interpolate strictly between 0 and 1")

    -- Mobile-UI sub-item (3): joystick constants for mobile-friendly sizing.
    assert(joystick.deadzone >= 28,
        "deadzone must be >= 28px for touchscreen finger imprecision: " .. tostring(joystick.deadzone))
    assert(joystick.visualRadius >= 72,
        "visualRadius must be >= 72px for mobile thumb sizing: " .. tostring(joystick.visualRadius))
    assert(joystick.visualKnobRadius >= 18,
        "visualKnobRadius must be >= 18px for mobile thumb sizing: " .. tostring(joystick.visualKnobRadius))
    assert(joystick.anchorX and joystick.anchorX > 0 and joystick.anchorX < 360,
        "anchorX must be in left half of 720px canvas: " .. tostring(joystick.anchorX))
    assert(joystick.anchorY and joystick.anchorY > 960,
        "anchorY must be in bottom quarter of 1280px canvas for thumb reach: " .. tostring(joystick.anchorY))
    assert(joystick.touchZoneRadius and joystick.touchZoneRadius >= 100,
        "touchZoneRadius must be >= 100px for easy thumb target: " .. tostring(joystick.touchZoneRadius))

    -- A dragged touch (originX/originY set away from the current x/y) must
    -- move the ship diagonally: horizontal speed on ship.x, vertical speed
    -- directly on ship.y (no clamp — item 32 removed verticalOffset).
    local joystickMoveScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    joystickMoveScene.expedition.phase = "ascending"
    joystickMoveScene:touchpressed("launch-joy", 90, 280)
    joystickMoveScene.expedition.altitude = 500
    joystickMoveScene.ship.y = -500

    -- Drag straight down-right from origin (90,10) to (90+maxRadius,10+maxRadius)
    -- normalizes to roughly (0.707, 0.707) at full magnitude.
    joystickMoveScene.touches["stick"] = {
        originX = 90, originY = 10,
        x = 90 + joystick.maxRadius, y = 10 + joystick.maxRadius,
    }
    local shipXBefore, shipYBefore = joystickMoveScene.ship.x, joystickMoveScene.ship.y
    joystickMoveScene:update(1)
    assert(joystickMoveScene.ship.x > shipXBefore, "joystick drag with a positive x component must move ship.x right")
    assert(joystickMoveScene.ship.y > shipYBefore,
        "joystick drag with a positive y component must move ship.y downward")
    -- item 32: vertical movement is unlimited (no clamp), same as horizontal

    -- A plain tap-and-hold touch (no drag away from its origin) must keep
    -- using the legacy binary left/right steering exactly as before, so
    -- existing touch UX (returnControls/ascendControls bands) is unchanged.
    local expedition = require("game.expedition")
    local tapHoldScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    tapHoldScene.expedition.phase = "ascending"
    tapHoldScene.touches["hold"] = { x = 20, y = 160, originX = 20, originY = 160 }
    local tapShipXBefore = tapHoldScene.ship.x
    tapHoldScene:update(1)
    assert(tapHoldScene.ship.x == tapShipXBefore - expedition.effectiveSpeed(tapHoldScene.expedition),
        "an undragged tap-and-hold touch must still steer via the legacy binary left/right path")

    -- Desktop `love .` routes the mouse through the same touch API with
    -- id "mouse". Press then drag past the deadzone must produce a
    -- joystick knob and actually move the ship, otherwise a desktop play
    -- session looks identical to the old left/right-only controls.
    local mouseScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    mouseScene.expedition.phase = "ascending"
    mouseScene:touchpressed("mouse", 90, 160)
    assert(mouseScene:joystickKnob() == nil, "an undragged mouse press must not show a stick knob")
    mouseScene:touchmoved("mouse", 90 + joystick.maxRadius, 160)
    local mx, my, knobX = mouseScene:joystickKnob()
    assert(mx == 90 and my == 160 and knobX > 90, "a dragged mouse must report a stick knob")
    local mouseXBefore = mouseScene.ship.x
    mouseScene:update(1)
    assert(mouseScene.ship.x > mouseXBefore, "a rightward mouse-drag must move the ship")
    mouseScene:touchreleased("mouse")
    assert(mouseScene:joystickKnob() == nil, "releasing the mouse must hide the stick knob")

    assert(joystick.visualRadius < joystick.maxRadius,
        "drawn stick disc must be smaller than the input maxRadius")
    assert(joystick.visualFillAlpha < 0.2 and joystick.visualLineAlpha < 0.4,
        "drawn stick must be translucent, not a solid overlay")
    assert(math.abs(PlayScene.headingFromStick(1, 0)) < 1e-9, "stick right must be heading 0")
    assert(math.abs(PlayScene.headingFromStick(0, -1) + math.pi / 2) < 1e-9,
        "stick up must be heading -pi/2")
    assert(math.abs(PlayScene.shortestAngleDelta(0, 0.1) - 0.1) < 1e-9)

    -- Rightward stick must point the nose fully right (heading 0), not a
    -- capped lean off nose-up, and emit an RCS puff on that same side.
    local tiltScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    tiltScene.expedition.phase = "ascending"
    tiltScene.touches["stick"] = {
        originX = 90, originY = 160,
        x = 90 + joystick.maxRadius, y = 160,
    }
    local restAngle = tiltScene.ship.angle
    tiltScene:update(1)
    assert(math.abs(tiltScene.ship.angle) < 0.05,
        "a full-right stick must be allowed to reach heading 0, not a capped bank")
    assert(math.abs(tiltScene.ship.angle - restAngle) > 0.5,
        "unclamped heading must be able to travel more than the old 0.5 rad lean")
    assert(#tiltScene.particles > 0, "tilting left/right must spawn a side RCS puff")
    -- Single opposite-stick puff: right stick → puff vx < 0 (leftward exhaust).
    do
        local p = tiltScene.particles[1]
        assert(p.vx < 0,
            "a right stick's RCS puff must exhaust leftward (opposite stick direction)")
    end
    local heldAngle = tiltScene.ship.angle
    tiltScene.touches["stick"] = nil
    tiltScene:update(1)
    assert(tiltScene.ship.angle == heldAngle,
        "releasing the stick must keep the current heading, not spring back to nose-up")

    -- Main-engine climb must follow the current nose, not always -Y.
    -- A right stick while already nose-right applies thrust on +x.
    local headingThrustScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    headingThrustScene.expedition.phase = "ascending"
    headingThrustScene.ship.angle = 0
    headingThrustScene.touches["stick"] = {
        originX = 90, originY = 160,
        x = 90 + joystick.maxRadius, y = 160,
    }
    local hx, hy = headingThrustScene.ship.x, headingThrustScene.ship.y
    headingThrustScene:update(1)
    assert(headingThrustScene.ship.x > hx, "nose-right climb must move +x")
    assert(math.abs(headingThrustScene.ship.y - hy) < 1e-6,
        "nose-right climb must not keep forcing the ship straight up")
    local coastX = headingThrustScene.ship.x
    headingThrustScene.touches["stick"] = nil
    headingThrustScene:update(1)
    assert(headingThrustScene.ship.x ~= coastX,
        "coasting must keep moving on stored velocity")

    local puffScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    puffScene.expedition.phase = "ascending"
    puffScene.touches["stick"] = {
        originX = 90, originY = 160,
        x = 90, y = 160 + joystick.maxRadius,
    }
    puffScene:update(0.05)
    assert(#puffScene.particles > 0, "vertical stick must spawn an RCS puff")
    local verticalPuff
    for _, p in ipairs(puffScene.particles) do
        if p.vy < 0 then verticalPuff = p end
    end
    assert(verticalPuff, "downward stick must emit an upward puff (opposite stick)")
    assert(verticalPuff.y < puffScene.ship.y,
        "a down stick's RCS puff must emit from above the ship (opposite jet)")
    assert(math.abs(verticalPuff.maxTimer - PlayScene.rcsPuffDuration) < 1e-9)

    -- Diagonal stick must produce exactly 1 puff per tick (not 2).
    local diagScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    diagScene.expedition.phase = "ascending"
    diagScene.touches["stick"] = {
        originX = 90, originY = 160,
        x = 90 + joystick.maxRadius * 0.707, y = 160 + joystick.maxRadius * 0.707,
    }
    diagScene:update(0.05)
    local diagPuffCount = 0
    for _ in ipairs(diagScene.particles) do diagPuffCount = diagPuffCount + 1 end
    assert(diagPuffCount == 1, "diagonal stick must produce exactly 1 puff per tick, got " .. diagPuffCount)
    assert(PlayScene.stickTurnFollow < 5,
        "hull turn follow must be slow, not the old snap rate of 14")
end

return M
