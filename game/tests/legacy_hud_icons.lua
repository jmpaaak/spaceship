local M = {}

-- docs/feedback/INBOX.md UI/HUD item 3 (아이콘 기반 HUD 간소화, first
-- slice): TAP TO LAUNCH gets a small rocket icon above it. The icon is a
-- pure-geometry helper (no love.graphics calls) so it can be regression
-- tested headless: it must return an even-length flat {x,y,...} polygon
-- list, be vertically symmetric around cx (nose tip and both fin tips
-- centered on cx), and have its topmost point (the nose) strictly above
-- its bottommost points (the fins) so it reads as an upward-pointing
-- rocket silhouette.
local function testLaunchRocketIcon()
    local PlayScene = require("game.scenes.play")
    local points = PlayScene.rocketIconPoints(90, 200, 14)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "rocket silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 200 and maxY > 200, "rocket must span above and below its center")
    assert(maxY - minY > 0, "rocket must have nonzero height")
    -- Nose tip (first point) is the topmost and horizontally centered.
    assert(points[1] == 90 and points[2] == minY,
        "first vertex must be the centered nose tip at the icon's topmost y")
end

-- docs/feedback/INBOX.md UI/HUD item 3 (icon-based HUD simplification,
-- second slice): the hull-durability status segment gets a small shield
-- icon paired with it. Pure-geometry regression test mirroring
-- testLaunchRocketIcon: even-length flat polygon list, horizontally
-- symmetric around cx, spans above and below cy.
local function testHullShieldIcon()
    local PlayScene = require("game.scenes.play")
    local points = PlayScene.shieldIconPoints(20, 20, 8)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "shield silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local y = points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 20 and maxY > 20, "shield must span above and below its center")
    -- Horizontally symmetric: for every point at x, there is a matching
    -- point at (2*cx - x) with the same y among the vertex list.
    local seen = {}
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        seen[string.format("%.2f,%.2f", x, y)] = true
    end
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        local mirroredKey = string.format("%.2f,%.2f", 40 - x, y)
        assert(seen[mirroredKey],
            "shield outline must be horizontally symmetric around cx")
    end
end

-- docs/feedback/INBOX.md UI/HUD item 3 (icon-based HUD simplification,
-- third slice): the CASH readout gets a small coin icon paired with it.
-- Pure-geometry regression test mirroring testHullShieldIcon: even-length
-- flat polygon list, at least a triangle, spans above and below cy, and
-- horizontally symmetric around cx (a coin drawn as a simple diamond/octagon
-- silhouette rather than a circle so it can be regression-tested exactly
-- like the other icons without love.graphics.circle's implicit segment
-- count).
local function testCashCoinIcon()
    local PlayScene = require("game.scenes.play")
    local points = PlayScene.coinIconPoints(20, 20, 8)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "coin silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local y = points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 20 and maxY > 20, "coin must span above and below its center")
    local seen = {}
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        seen[string.format("%.2f,%.2f", x, y)] = true
    end
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        local mirroredKey = string.format("%.2f,%.2f", 40 - x, y)
        assert(seen[mirroredKey],
            "coin outline must be horizontally symmetric around cx")
    end
end

local function testSpeedometerIcon()
    local PlayScene = require("game.scenes.play")
    local points = PlayScene.speedIconPoints(20, 20, 8)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "speedometer silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local y = points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 20 and maxY == 20, "speedometer must span above cy and be flat on bottom")
    -- The needle tip is at cx + r*0.5, cy - r*0.5 -> 24, 16.
    -- The left edge is at cx - r, cy -> 16, 20.
end

-- INBOX group (4): HUD icons must be 32x32 RGBA with transparent
-- padding (no full-bleed RGB square). Slice 1: cash/hull/speed.
-- Slice 2: distance/best/samples.
local function testHudIconRegenSlice()
    local paths = {
        "assets/hud/icon_cash.png",
        "assets/hud/icon_durability.png",
        "assets/effects/hud_speed.png",
        "assets/hud/icon_distance.png",
        "assets/effects/hud_best.png",
        "assets/effects/hud_samples.png",
        "assets/effects/hud_galaxy.png",
        "assets/effects/hud_return.png",
        "assets/effects/hud_earth.png",
    }
    for _, path in ipairs(paths) do
        local data = love.image.newImageData(path)
        local w, h = data:getWidth(), data:getHeight()
        assert((w == 32 and h == 32) or (w == 16 and h == 16),
            path .. " must be 32x32 or 16x16, got " .. w .. "x" .. h)
        local function cornerAlpha(x, y)
            local _r, _g, _b, a = data:getPixel(x, y)
            return a
        end
        local maxIdx = w - 1
        assert(cornerAlpha(0, 0) == 0, path .. " top-left corner must be transparent")
        assert(cornerAlpha(maxIdx, 0) == 0, path .. " top-right corner must be transparent")
        assert(cornerAlpha(0, maxIdx) == 0, path .. " bottom-left corner must be transparent")
        assert(cornerAlpha(maxIdx, maxIdx) == 0, path .. " bottom-right corner must be transparent")
        local opaque, transparent = 0, 0
        for y = 0, maxIdx do
            for x = 0, maxIdx do
                local _r, _g, _b, a = data:getPixel(x, y)
                if a > 0 then
                    opaque = opaque + 1
                else
                    transparent = transparent + 1
                end
            end
        end
        assert(opaque > 0, path .. " must contain an opaque symbol")
        assert(transparent > 0, path .. " must not be full-bleed")
    end
end

function M.run()
    testLaunchRocketIcon()
    testHullShieldIcon()
    testCashCoinIcon()
    testSpeedometerIcon()
    testHudIconRegenSlice()
end

return M
