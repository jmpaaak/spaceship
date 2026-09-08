local world = require("game.world")
local PlayScene = require("game.scenes.play")

local M = {}

function M.run()
    local floatingTextScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    assert(#floatingTextScene.floatingTexts == 0)
    floatingTextScene.expedition.phase = "ascending"
    floatingTextScene.expedition.altitude = 500
    floatingTextScene.ship.y = -500
    floatingTextScene.collided["floating-text-sample"] = true
    local floatingTextNearby = world.nearbyPlanets
    world.nearbyPlanets = function()
        return { { id = "floating-text-sample", x = 0, y = -500, radius = 7 } }
    end
    floatingTextScene:update(0)
    world.nearbyPlanets = floatingTextNearby
    assert(#floatingTextScene.floatingTexts == 1)
    local sampleFloatingText = floatingTextScene.floatingTexts[1]
    floatingTextScene.timeSlip = nil
    -- Numeric roll-up feedback (docs/feedback/INBOX.md 2026-09-02 후속
    -- 확정 사항 #2): "+$N" no longer pops in at its final value instantly.
    -- It starts at "+$0" and counts up over sampleRollupDuration (0.3s)
    -- like a slot-machine reel settling, then holds the final value.
    assert(sampleFloatingText.text == "+$0",
        "sample floating text must start its roll-up at +$0: " .. tostring(sampleFloatingText.text))
    assert(sampleFloatingText.timer == 1.0)
    local startingFloatingY = sampleFloatingText.y
    floatingTextScene:update(0.15)
    assert(#floatingTextScene.floatingTexts == 1)
    assert(math.abs(sampleFloatingText.timer - 0.85) < 1e-9)
    assert(sampleFloatingText.y < startingFloatingY)
    assert(sampleFloatingText.text == "+$1",
        "sample floating text must show a partial roll-up value mid-animation: "
            .. tostring(sampleFloatingText.text))
    floatingTextScene:update(0.15)
    assert(sampleFloatingText.text == "+$1",
        "sample floating text must reach the full awarded amount once the roll-up duration elapses: "
            .. tostring(sampleFloatingText.text))
    floatingTextScene:update(0.35)
    assert(#floatingTextScene.floatingTexts == 1)
    assert(sampleFloatingText.text == "+$1", "roll-up value must hold steady after completion")
    floatingTextScene:update(0.36)
    assert(#floatingTextScene.floatingTexts == 0)
end

return M
