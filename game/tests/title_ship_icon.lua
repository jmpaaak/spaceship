-- INBOX (49): title starter ship above Jimmy's + 256 window icon.
local M = {}

local function pngIhdr(path)
    local data = love.filesystem.read(path)
    assert(type(data) == "string" and #data >= 26,
        "INBOX (49): missing PNG " .. path)
    assert(data:sub(1, 8) == "\137PNG\r\n\26\n",
        "INBOX (49): " .. path .. " must be PNG")
    local function u32(offset)
        return data:byte(offset) * 16777216
            + data:byte(offset + 1) * 65536
            + data:byte(offset + 2) * 256
            + data:byte(offset + 3)
    end
    return u32(17), u32(21), data:byte(26)
end

function M.run()
    local TitleScene = require("game.scenes.title")
    assert(type(TitleScene.shipLayout) == "function",
        "INBOX (49): title.shipLayout must exist (play.lua forbidden)")

    local layout = TitleScene.shipLayout(64, 64)
    assert(layout.path == "assets/ship/ship_default.png",
        "INBOX (49): title ship must be ship_default.png")
    assert(layout.filter == "nearest",
        "INBOX (49): title ship filter must be nearest")
    assert(layout.scale == 7,
        "INBOX (70): title ship nearest scale must stay ×7, got "
            .. tostring(layout.scale))
    local viewport = require("game.viewport")
    assert(layout.w == 64 * layout.scale and layout.h == 64 * layout.scale)
    assert(math.abs(layout.x - (viewport.width - layout.w) / 2) < 0.01,
        "INBOX (49): title ship must be horizontally centered")
    assert(layout.y >= 0, "INBOX (49): ship must stay on canvas")
    local bottom = layout.y + layout.h
    local gap = 488 - bottom
    assert(layout.y + layout.h <= 488,
        "INBOX (49): ship must sit above Jimmy's (y=488), bottom="
            .. tostring(bottom))
    assert(gap >= 0 and gap <= 4,
        "INBOX (70): ship bottom must sit 0~4px above Jimmy's (y=488), gap="
            .. tostring(gap) .. " bottom=" .. tostring(bottom))

    local titleSrc = love.filesystem.read("game/scenes/title.lua") or ""
    assert(titleSrc:find('setFilter("nearest", "nearest")', 1, true),
        "INBOX (49): title must set nearest filter")
    assert(titleSrc:find("assets/ship/ship_default.png", 1, true),
        "INBOX (49): title must load ship_default.png")

    local confSrc = love.filesystem.read("conf.lua") or ""
    local _, iconCount = confSrc:gsub('t%.window%.icon%s*=%s*"assets/icon.png"', "")
    assert(iconCount == 1,
        "INBOX (49): conf.lua must set t.window.icon once, got "
            .. tostring(iconCount))

    local w, h, colorType = pngIhdr("assets/icon.png")
    assert(w == 256 and h == 256,
        "INBOX (49): icon.png must be 256x256, got " .. w .. "x" .. h)
    assert(colorType == 6,
        "INBOX (49): icon.png must be RGBA color type 6, got "
            .. tostring(colorType))

    print("  INBOX-49 title ship + window icon OK")
end

return M
