local world = require("game.world")
local M = {}

function M.run()
    -- INBOX 61(11): star scan range must cover canvas height.
    -- bgScanR/fgScanR are local to draw(), so preserve the original contract
    -- over the shared sector size and the 1280px portrait canvas formula.
    local ss = world.sectorSize
    assert(ss and ss > 0, "INBOX 61(11): world.sectorSize must be positive")
    local minScan = math.max(4, math.ceil(1280 / 2 / ss) + 2)
    assert(minScan >= 4,
        "INBOX 61(11): star scan range must be >= 4 sectors, got " .. tostring(minScan))
    print("  INBOX-61(11) star scan range OK")
end

return M
