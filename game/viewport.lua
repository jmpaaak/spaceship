local M = { width = 180, height = 320 }

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

-- Converts an internal-canvas pixel length (e.g. a UI row height) into the
-- physical touch-target size a player's finger actually meets on a given
-- device, in device-independent points. Points, not raw device pixels, are
-- the unit accessibility guidelines (iOS/Android ~44pt minimum) are stated
-- in, so callers must divide out the device pixel ratio.
function M.canvasPixelsToPoints(canvasPixels, windowWidth, windowHeight, devicePixelRatio, fractional)
    local scale = M.fit(windowWidth, windowHeight, fractional)
    return canvasPixels * scale / devicePixelRatio
end

return M
