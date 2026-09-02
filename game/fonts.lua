-- Bundled-font helper. love.filesystem is sandboxed to the game
-- directory, so Hangul cannot come from a macOS system path at runtime.
-- A Korean-capable TTF ships at assets/fonts/AppleGothic.ttf (smaller
-- than AppleSDGothicNeo.ttc). Callers use fonts.get(size) instead of
-- love.graphics.newFont(N). Headless tests must not call this
-- (conf.lua disables the graphics module under GAME_HEADLESS=1).
local M = {}

local FONT_PATH = "assets/fonts/AppleGothic.ttf"
local cache = {}

function M.get(size)
    size = size or 14
    local cached = cache[size]
    if cached then
        return cached
    end
    local font = love.graphics.newFont(FONT_PATH, size)
    cache[size] = font
    return font
end

M.path = FONT_PATH

return M
