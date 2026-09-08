local expedition = require("game.expedition")
local PlayScene = require("game.scenes.play")

local M = {}

-- INBOX-33 / 2026-09-07: RCS exhaust is a continuous 0–999 speed gradient
-- white→red (t<0.33) → red→blue (t<0.66) → rainbow (t≥0.66)
-- radius = 1.5 + t * 2.5. Rainbow does NOT start at speed ~100.
function M.run()
    local function vis(speed)
        return expedition.rcsVisual({
            baseSpeed = speed,
            steeringUpgradeLevel = 0,
            steeringUpgradeAmount = 0,
            equippedGear = {},
            equippedEngineParts = {},
        }, 0, 0)
    end
    local r0, g0, b0, rad0, t0 = vis(0)
    assert(t0 == 0, "speed 0 → t=0")
    assert(r0 == 1 and g0 == 1 and b0 == 1, "speed 0 RCS must be white")
    assert(rad0 == 1.5, "speed 0 radius 1.5")

    local _, _, _, rad30, t30 = vis(30)
    assert(t30 > 0 and t30 < 0.05, "starter speed 30 is still early white→red, t=" .. tostring(t30))
    assert(rad30 > 1.5 and rad30 < 1.7, "starter radius barely above 1.5")

    local r100, g100, b100, rad100, t100 = vis(100)
    assert(math.abs(t100 - 100 / 999) < 1e-6)
    assert(r100 == 1 and g100 < 1 and b100 < 1, "speed 100 is still white→red, not rainbow")
    assert(rad100 < 2.0, "speed 100 radius still < 2, got " .. rad100)

    local r330, g330, b330, rad330, t330 = vis(330)
    assert(t330 > 0.32 and t330 < 0.34)
    assert(r330 > 0.9 and g330 < 0.5 and b330 < 0.3, "speed 330 is red")
    assert(math.abs(rad330 - (1.5 + t330 * 2.5)) < 1e-6)

    local r660, _, _, rad660, t660 = vis(660)
    assert(t660 > 0.65 and t660 < 0.67)
    assert(rad660 > 3.1 and rad660 < 3.2)
    -- t>=0.66 is rainbow: any valid RGB
    assert(r660 >= 0 and r660 <= 1)

    local _, _, _, rad999, t999 = vis(999)
    assert(t999 == 1)
    assert(rad999 == 4.0, "speed 999 radius 4.0, got " .. rad999)

    local _, _, _, radOver = vis(2000)
    assert(radOver == 4.0, "speed above 999 clamps")

    -- Scene: starter (~30) must NOT look like the old Lv3 rainbow (radius 3)
    local lv0Scene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    lv0Scene.expedition.phase = "ascending"
    lv0Scene.touches["stick"] = {
        originX = 90, originY = 160,
        x = 90 + 40, y = 160,
    }
    lv0Scene:update(1)
    assert(#lv0Scene.particles > 0, "starter must spawn RCS particles")
    local p0 = lv0Scene.particles[1]
    assert(p0.radius < 1.8, "starter RCS radius must stay small, got " .. p0.radius)
    assert(p0.r == 1 and p0.g > 0.85 and p0.b > 0.85,
        "starter RCS must still look near-white")

    -- High speed (~700) reaches rainbow size
    local hiScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    hiScene.expedition.phase = "ascending"
    hiScene.expedition.baseSpeed = 700
    hiScene.touches["stick"] = {
        originX = 90, originY = 160,
        x = 90 + 40, y = 160,
    }
    hiScene:update(1)
    assert(#hiScene.particles > 0, "high-speed must spawn RCS particles")
    local pHi = hiScene.particles[1]
    assert(pHi.radius > 3.0, "speed 700 RCS radius must be rainbow-sized, got " .. pHi.radius)

    print("  INBOX-33 RCS continuous 0-999 gradient OK")
end

return M