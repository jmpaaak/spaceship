local joystick = require("game.joystick")
local viewport = require("game.viewport")

local PJ = {}
local _M

function PJ:joystickVector()
    for _, touch in pairs(self.touches) do
        if touch.originX then
            local dx, dy, magnitude = joystick.vector(touch.originX, touch.originY, touch.x, touch.y)
            if magnitude > 0 then
                return dx, dy, magnitude
            end
        end
    end
    return 0, 0, 0
end

function PJ:joystickKnob()
    for _, touch in pairs(self.touches) do
        if touch.originX then
            local dx, dy, magnitude = joystick.vector(touch.originX, touch.originY, touch.x, touch.y)
            if magnitude > 0 then
                local reach = magnitude * joystick.visualRadius
                return touch.originX, touch.originY, touch.originX + dx * reach, touch.originY + dy * reach, magnitude
            end
        end
    end
    return nil
end

function PJ.joystickOrigin(x, y)
    local dx = x - joystick.anchorX
    local dy = y - joystick.anchorY
    if dx * dx + dy * dy <= joystick.touchZoneRadius * joystick.touchZoneRadius then
        return joystick.anchorX, joystick.anchorY
    end
    return x, y
end

-- Desktop fallback: if love.mousepressed was missed, poll the mouse each
-- frame and feed the same "mouse" touch id. Skipped during GAME_UNIT tests
-- so injected touches["mouse"] are not cleared by isDown()==false.
function PJ:pollDesktopMouse()
    if os.getenv("GAME_UNIT") == "1" then return end
    if not love.mouse or not love.mouse.isDown then return end
    if self.expedition.phase ~= "ascending"
        and self.expedition.phase ~= "launch" then
        return
    end
    if not love.mouse.isDown(1) then
        self.touches.mouse = nil
        return
    end
    if not love.graphics or not love.graphics.getDimensions then return end
    local mx, my = love.mouse.getPosition()
    local ww, wh = love.graphics.getDimensions()
    local gx, gy = viewport.toGame(mx, my, ww, wh, false)
    if gx < 0 then gx = 0 elseif gx > viewport.width then gx = viewport.width end
    if gy < 0 then gy = 0 elseif gy > viewport.height then gy = viewport.height end
    if not self.touches.mouse then
        self.touches.mouse = { x = gx, y = gy, originX = gx, originY = gy }
        if self.expedition.phase == "launch" and self.launchInputArmed then
            self:keypressed("space")
        end
    else
        self.touches.mouse.x = gx
        self.touches.mouse.y = gy
    end
end

-- Group 6 wiring: drawShopIconSprite is local in play.lua, so we pass it in if needed,
-- or we can just draw circles directly if we don't have access.
-- Wait, we can expose M.drawShopIconSprite from play.lua and call it here.
function PJ:drawJoystickStick()
    local ox, oy, kx, ky = self:joystickKnob()
    local radius = joystick.visualRadius
    local knob = joystick.visualKnobRadius
    -- No ghost pad when not dragging — joystick only appears on touch
    if not ox then return end
    
    love.graphics.setColor(0.35, 0.55, 0.8, joystick.visualFillAlpha)
    if not (_M.drawShopIconSprite and _M.drawShopIconSprite(self.joystickPadImage, ox, oy, radius * 2)) then
        love.graphics.circle("fill", ox, oy, radius)
    end
    love.graphics.setColor(0.65, 0.85, 1, joystick.visualLineAlpha)
    if not self.joystickPadImage then
        love.graphics.circle("line", ox, oy, radius)
    end
    love.graphics.setColor(0.9, 0.95, 1, joystick.visualKnobAlpha)
    if not (_M.drawShopIconSprite and _M.drawShopIconSprite(self.joystickKnobImage, kx, ky, knob * 2)) then
        love.graphics.circle("fill", kx, ky, knob)
    end
end

function PJ.install(M)
    _M = M
    M.joystickVector = PJ.joystickVector
    M.joystickKnob = PJ.joystickKnob
    M.pollDesktopMouse = PJ.pollDesktopMouse
    M.drawJoystickStick = PJ.drawJoystickStick
    M.joystickOrigin = PJ.joystickOrigin
end

return PJ
