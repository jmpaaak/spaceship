local expedition = require("game.expedition")

local M = {}

function M.run()
    -- docs/feedback/INBOX.md's Balatro core-mechanics porting plan item 1
    -- ("점진적 시너지/빌드업") asks for a multiplicative STREAK bonus when the
    -- player collects consecutive same-hue-family samples. collectSample's
    -- optional third argument is the hueKey (game/world.lua's
    -- specimenKind/hueFamily); consecutive calls with the same hueKey should
    -- grow the streak multiplier (x1.0, x1.2, x1.4, ...), and a different
    -- hueKey (or no hueKey) should reset the streak back to x1.0.
    local streakRun = expedition.new({})
    streakRun.phase = "ascending"
    assert(expedition.streakMultiplier(0) == 1)
    assert(expedition.streakMultiplier(1) == 1)
    assert(expedition.streakMultiplier(2) == 1.2)
    assert(expedition.streakMultiplier(3) == 1.4)
    local ok1, awarded1, mult1 = expedition.collectSample(streakRun, 100, "azure")
    assert(ok1 and awarded1 == 100 and mult1 == 1,
        "first azure sample must award base value at x1.0 streak (" .. tostring(awarded1) .. ")")
    local ok2, awarded2, mult2 = expedition.collectSample(streakRun, 100, "azure")
    assert(ok2 and awarded2 == 120 and mult2 == 1.2,
        "second consecutive azure sample must award x1.2 streak (" .. tostring(awarded2) .. ")")
    local ok3, awarded3, mult3 = expedition.collectSample(streakRun, 100, "azure")
    assert(ok3 and awarded3 == 140 and mult3 == 1.4,
        "third consecutive azure sample must award x1.4 streak (" .. tostring(awarded3) .. ")")
    local ok4, awarded4, mult4 = expedition.collectSample(streakRun, 100, "ember")
    assert(ok4 and awarded4 == 100 and mult4 == 1,
        "switching hue family must reset the streak back to x1.0 (" .. tostring(awarded4) .. ")")
    assert(streakRun.pendingSampleValue == 100 + 120 + 140 + 100
        and streakRun.sampleCount == 4)
    assert(expedition.damage(streakRun, streakRun.durability))
    assert(streakRun.phase == "destroyed" and streakRun.sampleStreakCount == 0
        and streakRun.sampleStreakFamily == nil)
    assert(expedition.launch(streakRun) and streakRun.phase == "ascending")
    assert(streakRun.sampleStreakCount == 0 and streakRun.sampleStreakFamily == nil)
end

return M
