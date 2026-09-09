local expedition = require("game.expedition")

local M = {}

function M.run()
    -- INBOX 61(35): slot reels must cover all 5 symbols, not just MONEY/PART/SPEED.
    local run = expedition.new()
    local tw = expedition.earthSlotTotalWeight(run, nil)
    local spinCheck = expedition.earthSlotSpin(run, nil, { reels = {0,0,0} })
    assert(tw == spinCheck.totalWeight,
        string.format("INBOX 61(35): earthSlotTotalWeight (%d) must match earthSlotSpin.totalWeight (%d)",
            tw, spinCheck.totalWeight))
    local reachable = {}
    for roll = 0, tw - 1 do
        local result = expedition.earthSlotSpin(run, nil, {
            reels = { roll, roll, roll },
        })
        reachable[result.symbols[1]] = true
    end
    for _, sym in ipairs(expedition.slotSymbols) do
        assert(reachable[sym],
            "INBOX 61(35): symbol " .. sym .. " must be reachable with rolls in [0, totalWeight)")
    end
    local luckRun = expedition.new()
    local luckPart = {
        id = "luck_test", name = "Lucky", nameKo = "행운", icon = "+",
        rarity = "common", tags = {}, editions = {},
        effects = { { type = "luck", value = 50 } },
    }
    expedition.equipGear(luckRun, "hull", luckPart)
    local twLuck = expedition.earthSlotTotalWeight(luckRun, nil)
    assert(twLuck > tw,
        string.format("INBOX 61(35): luck must increase totalWeight (%d > %d)", twLuck, tw))
    print("  INBOX-61(35) slot weighted random covers all 5 symbols OK")
end

return M
