local playIcons = require("game.scenes.play_icons")

local M = {}

local function bounds(points)
    local minX, maxX, minY, maxY
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        minX = minX and math.min(minX, x) or x
        maxX = maxX and math.max(maxX, x) or x
        minY = minY and math.min(minY, y) or y
        maxY = maxY and math.max(maxY, y) or y
    end
    return minX, maxX, minY, maxY
end

function M.run()
    print("  [R1] play_icons module tests...")

    local scene = {}
    playIcons.install(scene)
    for _, name in ipairs({
        "rocketIconPoints", "shieldIconPoints", "coinIconPoints",
        "speedIconPoints", "drawCenteredIconText",
    }) do
        assert(type(scene[name]) == "function", "R1: play_icons must install " .. name)
    end

    for _, name in ipairs({
        "launchIconSize", "launchIconGap", "hullIconSize", "hullIconGap",
        "hpBlockSize", "hpBlockGap", "cashIconSize", "cashIconGap",
        "speedIconSize", "speedIconGap",
    }) do
        assert(type(scene[name]) == "number", "R1: play_icons must install " .. name)
    end

    for _, name in ipairs({ "rocketIconPoints", "shieldIconPoints", "coinIconPoints", "speedIconPoints" }) do
        local points = scene[name](40, 50, 20)
        assert(#points >= 6 and #points % 2 == 0, "R1: " .. name .. " must return coordinate pairs")
        local minX, maxX, minY, maxY = bounds(points)
        assert(minX < 40 and maxX > 40 and minY < 50 and maxY >= 50,
            "R1: " .. name .. " geometry must span its center")
    end

    local playSource = love.filesystem.read("game/scenes/play.lua") or ""
    assert(playSource:find('require%("game%.scenes%.play_icons"%)'),
        "R1: play.lua must delegate icon helpers to play_icons")
    assert(not playSource:find("function M%.rocketIconPoints"),
        "R1: icon geometry implementation must leave play.lua")
    assert(not playSource:find("function M%.drawCenteredIconText"),
        "R1: centered icon/text rendering must leave play.lua")

    print("  R1 play_icons module OK")
end

return M
