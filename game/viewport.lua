local M = { width = 320, height = 180 }

function M.fit(windowWidth, windowHeight, fractional)
    local available = math.min(windowWidth / M.width, windowHeight / M.height)
    local scale = fractional and available or (available >= 1 and math.floor(available) or available)
    local x = fractional and (windowWidth - M.width * scale) / 2 or math.floor((windowWidth - M.width * scale) / 2)
    local y = fractional and (windowHeight - M.height * scale) / 2 or math.floor((windowHeight - M.height * scale) / 2)
    return scale, x, y
end

function M.toGame(screenX, screenY, windowWidth, windowHeight, fractional)
    local scale, x, y = M.fit(windowWidth, windowHeight, fractional)
    local gameX, gameY = (screenX - x) / scale, (screenY - y) / scale
    return gameX, gameY, gameX >= 0 and gameX <= M.width and gameY >= 0 and gameY <= M.height
end

return M
