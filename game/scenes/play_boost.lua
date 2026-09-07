local i18n = require("game.i18n")
local expedition = require("game.expedition")
local fonts = require("game.fonts")
local viewport = require("game.viewport")

local PB = {}
local _M

-- state for speedlines
PB.speedLines = {}

---------------------------------------------------------------------------
-- updateBoostSpeedLines
---------------------------------------------------------------------------
function PB:updateBoostSpeedLines(dt)
    if not self.boostActive then
        PB.speedLines = {}
        return
    end

    -- update existing lines
    for i = #PB.speedLines, 1, -1 do
        local line = PB.speedLines[i]
        line.y = line.y + line.speed * dt
        if line.y > viewport.height then
            table.remove(PB.speedLines, i)
        end
    end

    -- spawn new lines
    if math.random() < dt * 60 then
        local side = math.random() < 0.5 and -1 or 1
        local x = (side == -1) and math.random(5, 30) or (viewport.width - math.random(5, 30))
        local h = math.random(60, 150)
        table.insert(PB.speedLines, {
            x = x,
            y = -h,
            h = h,
            speed = math.random(1500, 2500)
        })
    end
end

---------------------------------------------------------------------------
-- drawBoostSpeedLines
---------------------------------------------------------------------------
function PB:drawBoostSpeedLines()
    if not self.boostActive then return end
    love.graphics.setColor(1, 1, 1, 0.4)
    for _, line in ipairs(PB.speedLines) do
        love.graphics.rectangle("fill", line.x, line.y, 2, line.h)
    end
end

---------------------------------------------------------------------------
-- drawBoostButton
---------------------------------------------------------------------------
function PB:drawBoostButton()
    local remaining = expedition.boostsRemaining(self.expedition)
    -- Disabled if phase is not ascending
    if self.expedition.phase ~= "ascending" then return end

    local w, h = 54, 54
    -- position: bottom right, above joystick if joystick takes up left.
    local bx = viewport.width - w - 16
    local by = viewport.height - h - 16
    
    self.boostBtnRect = { x = bx, y = by, w = w, h = h }

    local r, g, b = 0.4, 0.4, 0.4
    if remaining > 0 then
        if self.boostActive then
            r, g, b = 1.0, 0.85, 0.3
        else
            r, g, b = 0.2, 0.6, 1.0
        end
    end
    
    love.graphics.setColor(r, g, b, 0.8)
    love.graphics.rectangle("fill", bx, by, w, h, 8, 8)
    
    love.graphics.setColor(1, 1, 1, 1)
    local prevFont = love.graphics.getFont()
    
    love.graphics.setFont(fonts.get("m5x7", 22))
    love.graphics.printf("BOOST", bx, by + 8, w, "center")
    
    if remaining > 0 then
        love.graphics.printf(tostring(remaining), bx, by + 28, w, "center")
    else
        love.graphics.setColor(0.7, 0.7, 0.7, 1)
        love.graphics.printf("0", bx, by + 28, w, "center")
    end
    love.graphics.setFont(prevFont)
end

---------------------------------------------------------------------------
-- hitBoostButton
---------------------------------------------------------------------------
function PB:hitBoostButton(x, y)
    if self.expedition.phase ~= "ascending" then return false end
    local rect = self.boostBtnRect
    if not rect then return false end
    if x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
        if expedition.boostsRemaining(self.expedition) > 0 and not self.boostActive then
            local ok = expedition.spendBoost(self.expedition)
            if ok then
                self.boostActive = { timer = 0.8, speedMultiplier = 3.0 }
                pcall(love.system.vibrate, 0.1)
            end
        end
        return true
    end
    return false
end

---------------------------------------------------------------------------
-- install(M)
---------------------------------------------------------------------------
function PB.install(M)
    _M = M
    M.updateBoostSpeedLines = PB.updateBoostSpeedLines
    M.drawBoostSpeedLines = PB.drawBoostSpeedLines
    M.drawBoostButton = PB.drawBoostButton
    M.hitBoostButton = PB.hitBoostButton
end

return PB
