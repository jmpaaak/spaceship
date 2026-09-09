local M = {}

-- INBOX 61(24): Last checkpoint respawn after destruction
function M.run()
    local expedition = require("game.expedition")

    -- (a) settle at Earth (no hub) sets checkpoint to Earth
    local run1 = expedition.new()
    run1.phase = "ascending"
    run1.pendingSampleValue = 5
    expedition.settle(run1)
    assert(run1.lastCheckpointX == 0,
        "INBOX 61(24): Earth settle must set lastCheckpointX=0, got " .. tostring(run1.lastCheckpointX))
    assert(run1.lastCheckpointY == 75,
        "INBOX 61(24): Earth settle must set lastCheckpointY=75, got " .. tostring(run1.lastCheckpointY))

    -- (b) settle at hub sets checkpoint to hub position
    local run2 = expedition.new()
    run2.phase = "ascending"
    run2.pendingSampleValue = 5
    run2.lastHubX = 300
    run2.lastHubY = -500
    expedition.settle(run2)
    assert(run2.lastCheckpointX == 300,
        "INBOX 61(24): Hub settle must set lastCheckpointX to hub X, got " .. tostring(run2.lastCheckpointX))
    assert(run2.lastCheckpointY == -500,
        "INBOX 61(24): Hub settle must set lastCheckpointY to hub Y, got " .. tostring(run2.lastCheckpointY))

    -- (c) destroy preserves lastCheckpointX/Y
    run2.phase = "ascending"
    run2.durability = 1
    expedition.damage(run2, 1)
    assert(run2.phase == "destroyed", "INBOX 61(24): damage at 0 dur must destroy")
    assert(run2.lastCheckpointX == 300,
        "INBOX 61(24): destroy must preserve lastCheckpointX, got " .. tostring(run2.lastCheckpointX))
    assert(run2.lastCheckpointY == -500,
        "INBOX 61(24): destroy must preserve lastCheckpointY, got " .. tostring(run2.lastCheckpointY))

    -- (d) lastCheckpointOrEarth helper
    local cpX, cpY = expedition.lastCheckpointOrEarth(run2)
    assert(cpX == 300 and cpY == -500,
        "INBOX 61(24): lastCheckpointOrEarth must return hub checkpoint")
    local run3 = expedition.new()
    local defX, defY = expedition.lastCheckpointOrEarth(run3)
    assert(defX == 0 and defY == 75,
        "INBOX 61(24): lastCheckpointOrEarth must default to Earth (0,75)")

    -- (e) launch after destroy preserves checkpoint
    expedition.launch(run2)
    assert(run2.lastCheckpointX == 300,
        "INBOX 61(24): launch after destroy must preserve lastCheckpointX")
    assert(run2.lastCheckpointY == -500,
        "INBOX 61(24): launch after destroy must preserve lastCheckpointY")

    print("  INBOX-61(24) last checkpoint respawn OK")
end

return M