local M = {}

local function rocketIconPoints(cx, cy, size)
    local halfWidth = size * 0.35
    local noseY = cy - size * 0.6
    local baseY = cy + size * 0.4
    local finY = cy + size * 0.6
    local finSpread = size * 0.55
    return {
        cx, noseY,
        cx + halfWidth, baseY,
        cx + finSpread, finY,
        cx, baseY,
        cx - finSpread, finY,
        cx - halfWidth, baseY,
    }
end

local function shieldIconPoints(cx, cy, size)
    local halfWidth = size * 0.45
    local topY = cy - size * 0.5
    local midY = cy
    local pointY = cy + size * 0.5
    return {
        cx - halfWidth, topY,
        cx + halfWidth, topY,
        cx + halfWidth, midY,
        cx, pointY,
        cx - halfWidth, midY,
    }
end

local function coinIconPoints(cx, cy, size)
    local r = size * 0.5
    local rDiag = r * 0.7071
    return {
        cx, cy - r,
        cx + rDiag, cy - rDiag,
        cx + r, cy,
        cx + rDiag, cy + rDiag,
        cx, cy + r,
        cx - rDiag, cy + rDiag,
        cx - r, cy,
        cx - rDiag, cy - rDiag,
    }
end

local function speedIconPoints(cx, cy, size)
    local r = size * 0.5
    local rDiag = r * 0.7071
    return {
        cx - r, cy,
        cx - rDiag, cy - rDiag,
        cx, cy - r,
        cx + rDiag, cy - rDiag,
        cx + r, cy,
        cx + r * 0.2, cy,
        cx + r * 0.5, cy - r * 0.5,
        cx - r * 0.2, cy,
    }
end

local function drawCenteredIconText(iconPointsFn, iconSize, iconGap, text, x, y, w)
    local font = love.graphics.getFont()
    local textWidth = font:getWidth(text)
    local totalWidth = iconSize + iconGap + textWidth
    local startX = x + w / 2 - totalWidth / 2
    local iconCenterX = startX + iconSize / 2
    local iconCenterY = y + font:getHeight() / 2

    love.graphics.polygon("fill", iconPointsFn(iconCenterX, iconCenterY, iconSize))
    love.graphics.print(text, startX + iconSize + iconGap, y)
end

function M.install(scene)
    scene.rocketIconPoints = rocketIconPoints
    scene.shieldIconPoints = shieldIconPoints
    scene.coinIconPoints = coinIconPoints
    scene.speedIconPoints = speedIconPoints
    scene.drawCenteredIconText = drawCenteredIconText

    scene.launchIconSize = 14
    scene.launchIconGap = 12
    scene.hullIconSize = 16
    scene.hullIconGap = 4
    scene.hpBlockSize = 12
    scene.hpBlockGap = 3
    scene.cashIconSize = 16
    scene.cashIconGap = 4
    scene.speedIconSize = 8
    scene.speedIconGap = 4
end

return M
