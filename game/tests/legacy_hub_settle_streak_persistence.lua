local M = {}

-- Item 8 / item 9 streak boundary: hub settle (partial settlement) must NOT
-- reset the sample streak — the player is still in the same expedition and
-- their combo should carry forward. This is distinct from:
--   * Earth settle (full settle() + launch()) which does reset via launch()
--   * destroy() which explicitly resets sampleStreakCount/sampleStreakFamily
-- Also verifies: streak state persists through multiple hub settles so a
-- player who visits two hubs in one expedition keeps their combo alive.
function M.run()
    local expedition = require("game.expedition")

    local run = expedition.new()
    expedition.launch(run)

    -- Build a 3-collect azure streak.
    expedition.collectSample(run, 10, "azure")  -- sampleStreakCount == 1
    expedition.collectSample(run, 10, "azure")  -- sampleStreakCount == 2
    expedition.collectSample(run, 10, "azure")  -- sampleStreakCount == 3
    assert(run.sampleStreakCount == 3,
        "three same-family collects must build streak to 3, got " .. tostring(run.sampleStreakCount))
    assert(run.sampleStreakFamily == "azure",
        "sampleStreakFamily must be azure after three azure collects, got " .. tostring(run.sampleStreakFamily))

    -- Hub settle: drains pendingSampleValue but must NOT touch streak.
    expedition.settleAtHub(run)
    assert(run.sampleStreakCount == 3,
        "settleAtHub must NOT reset sampleStreakCount (in-flight combo survives hub visit), got "
            .. tostring(run.sampleStreakCount))
    assert(run.sampleStreakFamily == "azure",
        "settleAtHub must NOT reset sampleStreakFamily, got " .. tostring(run.sampleStreakFamily))

    -- A 4th azure collect after hub settle must continue the streak (streak
    -- count 4, not reset to 1).
    local _, _, mult4 = expedition.collectSample(run, 10, "azure")
    assert(run.sampleStreakCount == 4,
        "first collect AFTER hub settle must increment streak to 4, not reset to 1, got "
            .. tostring(run.sampleStreakCount))
    -- The multiplier at streak count 4 (base 0.2/step): 1 + 3*0.2 = 1.6
    assert(math.abs(mult4 - 1.6) < 1e-9,
        "multiplier at streak 4 (base rate) must be 1.6, got " .. tostring(mult4))

    -- Second hub settle: streak still intact.
    expedition.settleAtHub(run)
    assert(run.sampleStreakCount == 4,
        "a second hub settle must also leave streak count untouched, got "
            .. tostring(run.sampleStreakCount))

    -- Switching hue family DOES break the streak (unrelated to hub settle;
    -- regression safety: this should still work exactly as before).
    expedition.collectSample(run, 10, "ember")
    assert(run.sampleStreakCount == 1,
        "collecting a different hue family must reset streak to 1, got "
            .. tostring(run.sampleStreakCount))
    assert(run.sampleStreakFamily == "ember",
        "sampleStreakFamily must update to ember after hue switch, got "
            .. tostring(run.sampleStreakFamily))
end

return M