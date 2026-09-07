-- play_joystick.lua: joystick input handling extracted from play.lua (INBOX-32)
-- Each exported function takes `self` (PlayScene) as its first argument.
-- play.lua delegates via thin wrappers that preserve the original M: names.
local joystick = require("game.joystick")
local viewport = require("game.viewport")

local M = {}

-- Inline copy of drawShopIconSprite (play.lua M.drawShopIconSprite).
-- Kept here to avoid a circular require on play.lua.
local function drawShopIconSprite(image, cx, cy, size)
    if not image then return false end
    local iw, ih = image:getDimensions()
    local scale = size / math.max(iw, ih)
    love.graphics.draw(image, cx - iw * scale / 2, cy - ih * scale / 2, 0, scale, scale)
    return true
end

-- Compute the joystick origin for a new touch (anchorX/Y zone, or raw coords).
local function joystickOrigin(x, y)
    local dx = x - joystick.anchorX
    local dy = y - joystick.anchorY
    if dx * dx + dy * dy <= joystick.touchZoneRadius * joystick.touchZoneRadius then
        return joystick.anchorX, joystick.anchorY
    end
    return x, y
end
M.joystickOrigin = joystickOrigin

-- Return the left/right/up/down key+touch state.
function M.steeringButtonState(self)
    local left = love.keyboard.isDown("left", "a")
    local right = love.keyboard.isDown("right", "d")
    local up = love.keyboard.isDown("up", "w")
    local down = love.keyboard.isDown("down", "s")
    for _, touch in pairs(self.touches) do
        if touch.x < viewport.width / 2 then
            left = true
        else
            right = true
        end
    end
    return { leftActive = left, rightActive = right, upActive = up, downActive = down }
end

-- Omnidirectional joystick vector.
function M.joystickVector(self)
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

-- Returns ox, oy, kx, ky, magnitude for the active joystick drag (nil if none).
function M.joystickKnob(self)
    for _, touch in pairs(self.touches) do
        if touch.originX then
            local dx, dy, magnitude = joystick.vector(touch.originX, touch.originY, touch.x, touch.y)
            if magnitude > 0 then
                local reach = magnitude * joystick.visualRadius
                return touch.originX, touch.originY,
                       touch.originX + dx * reach, touch.originY + dy * reach,
                       magnitude
            end
        end
    end
    return nil
end

-- Desktop mouse-to-touch fallback. Skipped under GAME_UNIT.
function M.pollDesktopMouse(self)
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
        if self.expedition.phase == "launch" then
            self:keypressed("space")
        end
    else
        self.touches.mouse.x = gx
        self.touches.mouse.y = gy
    end
end

-- Draw the joystick stick (pad + knob) when a touch drag is active.
function M.drawJoystickStick(self)
    local ox, oy, kx, ky = M.joystickKnob(self)
    local radius = joystick.visualRadius
    local knob = joystick.visualKnobRadius
    -- No ghost pad when not dragging
    if not ox then return end
    love.graphics.setColor(0.35, 0.55, 0.8, joystick.visualFillAlpha)
    if not drawShopIconSprite(self.joystickPadImage, ox, oy, radius * 2) then
        love.graphics.circle("fill", ox, oy, radius)
    end
    love.graphics.setColor(0.65, 0.85, 1, joystick.visualLineAlpha)
    if not self.joystickPadImage then
        love.graphics.circle("line", ox, oy, radius)
    end
    love.graphics.setColor(0.9, 0.95, 1, joystick.visualKnobAlpha)
    if not drawShopIconSprite(self.joystickKnobImage, kx, ky, knob * 2) then
        love.graphics.circle("fill", kx, ky, knob)
    end
end

return M
