-- INBOX (52): title ship idle motion — slight tilt + slow bob + tiny sway.
local M = {}

function M.run()
    local TitleScene = require("game.scenes.title")
    assert(type(TitleScene.shipIdlePose) == "function",
        "INBOX (52): title.shipIdlePose must exist (play.lua forbidden)")

    local layout = TitleScene.shipLayout(64, 64)
    assert(layout.path == "assets/ship/ship_default.png",
        "INBOX (52): must keep ship_default.png")
    assert(layout.filter == "nearest",
        "INBOX (52): nearest scale must be kept")
    assert(layout.scale == 7,
        "INBOX (52): nearest scale 7 must be kept, got " .. tostring(layout.scale))

    local maxDeg = 8 * math.pi / 180
    local maxAbsAngle, maxAbsOx, maxAbsOy = 0, 0, 0
    local prev = TitleScene.shipIdlePose(0)
    local moved = false
    for i = 0, 200 do
        local t = i * 0.1
        local pose = TitleScene.shipIdlePose(t)
        assert(type(pose.angle) == "number", "INBOX (52): pose.angle required")
        assert(type(pose.ox) == "number", "INBOX (52): pose.ox (sway) required")
        assert(type(pose.oy) == "number", "INBOX (52): pose.oy (bob) required")
        assert(math.abs(pose.angle) <= maxDeg + 1e-6,
            "INBOX (52): tilt must stay within ±8°, got "
                .. tostring(pose.angle * 180 / math.pi) .. " deg")
        maxAbsAngle = math.max(maxAbsAngle, math.abs(pose.angle))
        maxAbsOx = math.max(maxAbsOx, math.abs(pose.ox))
        maxAbsOy = math.max(maxAbsOy, math.abs(pose.oy))
        if pose.angle ~= prev.angle or pose.ox ~= prev.ox or pose.oy ~= prev.oy then
            moved = true
        end
        prev = pose
    end
    assert(moved, "INBOX (52): idle pose must change over time")
    assert(maxAbsAngle >= (4 * math.pi / 180),
        "INBOX (52): diagonal tilt must reach at least ±4°, got "
            .. tostring(maxAbsAngle * 180 / math.pi) .. " deg")
    assert(maxAbsOy >= 4,
        "INBOX (52): slow bob amplitude too small, max |oy|=" .. tostring(maxAbsOy))
    assert(maxAbsOx > 0 and maxAbsOx <= 8,
        "INBOX (52): sway must be a tiny left-right wobble, max |ox|="
            .. tostring(maxAbsOx))
    assert(maxAbsOx < maxAbsOy,
        "INBOX (52): sway must be smaller than bob")

    -- Slow: 50ms of motion should not jump more than a couple of pixels.
    local a = TitleScene.shipIdlePose(0)
    local b = TitleScene.shipIdlePose(0.05)
    assert(math.abs(a.oy - b.oy) < 2,
        "INBOX (52): bob must be slow, Δoy=" .. tostring(math.abs(a.oy - b.oy)))
    assert(math.abs(a.ox - b.ox) < 2,
        "INBOX (52): sway must be slow, Δox=" .. tostring(math.abs(a.ox - b.ox)))

    local scene = TitleScene.new()
    scene:update(1.25)
    assert((scene.shipIdleTime or 0) >= 1.25,
        "INBOX (52): update must advance shipIdleTime")

    local titleSrc = love.filesystem.read("game/scenes/title.lua") or ""
    assert(titleSrc:find("shipIdlePose", 1, true),
        "INBOX (52): title draw must use shipIdlePose")
    assert(not titleSrc:find("love.graphics.draw(self.shipImage, layout.x, layout.y, 0,", 1, true),
        "INBOX (52): title must not draw the ship frozen at rotation 0")

    local playSrc = love.filesystem.read("game/scenes/play.lua") or ""
    assert(not playSrc:find("shipIdlePose", 1, true),
        "INBOX (52): play.lua must not own title idle motion")

    print("  INBOX-52 title ship idle motion OK")
end

return M
