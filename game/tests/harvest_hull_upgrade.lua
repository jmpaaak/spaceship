-- INBOX (51): harvest +0.10 per shop buy; slot HARVEST uses the same unit.
local M = {}

function M.run()
    local expedition = require("game.expedition")

    local yieldRun = expedition.new()
    assert(yieldRun.sampleYieldUpgradeAmount == 0.10,
        "INBOX (51): sampleYieldUpgradeAmount default must be 0.10, got "
            .. tostring(yieldRun.sampleYieldUpgradeAmount))
    yieldRun.phase = "settlement"
    yieldRun.money = yieldRun.sampleYieldUpgradeCost
    assert(expedition.buySampleYieldUpgrade(yieldRun))
    assert(expedition.sampleYieldMultiplier(yieldRun) == 1.10,
        "INBOX (51): first harvest buy must be x1.10, got "
            .. tostring(expedition.sampleYieldMultiplier(yieldRun)))

    -- Weights MONEY6+PART3+SPEED4+DURABILITY3 = 16; HARVEST starts at 16.
    local two = expedition.earthSlotSpin(expedition.new(), nil, { reels = { 16, 16, 0 } })
    assert(two.rewardType == "harvest" and two.matchCount == 2,
        "INBOX (51): 2 HARVEST must be harvest type, got "
            .. tostring(two.rewardType) .. " x" .. tostring(two.matchCount))
    assert(math.abs((two.rewardValue or 0) - 0.10) < 1e-9,
        "INBOX (51): 2-match HARVEST must be +0.10, got " .. tostring(two.rewardValue))
    local three = expedition.earthSlotSpin(expedition.new(), nil, { reels = { 16, 16, 16 } })
    assert(three.rewardType == "harvest" and three.matchCount == 3)
    assert(math.abs((three.rewardValue or 0) - 0.50) < 1e-9,
        "INBOX (51): 3-match HARVEST must be +0.50, got " .. tostring(three.rewardValue))

    local hullRun = expedition.new({ durability = 3 })
    hullRun.phase = "settlement"
    hullRun.durability = 2
    hullRun.money = hullRun.durabilityUpgradeCost
    local beforeMax = hullRun.maxDurability
    local beforeHp = hullRun.durability
    assert(expedition.buyDurabilityUpgrade(hullRun))
    assert(hullRun.maxDurability == beforeMax + 1)
    assert(hullRun.durability == beforeHp + 1)
    assert(hullRun.durability < hullRun.maxDurability)

    print("  INBOX-51 harvest +0.10 and slot HARVEST 0.10/0.50 OK")
end

return M
