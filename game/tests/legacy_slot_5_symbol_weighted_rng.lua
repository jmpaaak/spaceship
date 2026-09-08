local expedition = require("game.expedition")

local M = {}

-- INBOX-61(35): deterministic coverage of all five weighted slot symbols.
function M.run()
    local run = expedition.new()
    local total = expedition.slotTotalWeight
    local seen = {}
    -- Run 200 deterministic spins across the full [0, totalWeight) range
    -- to guarantee every symbol is reachable. We sweep the range evenly
    -- plus a few targeted rolls near each symbol boundary.
    local spinCount = 200
    for i = 0, spinCount - 1 do
        local roll = math.floor(i * total / spinCount)
        local result = expedition.earthSlotSpin(run, nil, {
            reels = { roll, roll, roll },
        })
        for _, sym in ipairs(result.symbols) do
            seen[sym] = true
        end
    end
    -- Also sweep roll values 0 through totalWeight-1 explicitly.
    for r = 0, total - 1 do
        local result = expedition.earthSlotSpin(run, nil, {
            reels = { r, r, r },
        })
        for _, sym in ipairs(result.symbols) do
            seen[sym] = true
        end
    end
    for _, sym in ipairs(expedition.slotSymbols) do
        assert(seen[sym],
            "INBOX-61(35): symbol " .. sym .. " was never drawn — weighted RNG does not cover all 5 symbols")
    end
    print("INBOX-61(35) slot 5-symbol weighted OK")
end

return M
