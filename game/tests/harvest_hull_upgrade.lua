-- INBOX (45): harvest upgrade +5% per buy; durability buy fills the new cell.
local M = {}

function M.run()
    local expedition = require("game.expedition")

    local yieldRun = expedition.new()
    assert(yieldRun.sampleYieldUpgradeAmount == 0.05,
        "INBOX (45): sampleYieldUpgradeAmount default must be 0.05, got "
            .. tostring(yieldRun.sampleYieldUpgradeAmount))
    yieldRun.phase = "settlement"
    yieldRun.money = yieldRun.sampleYieldUpgradeCost
    assert(expedition.buySampleYieldUpgrade(yieldRun))
    assert(expedition.sampleYieldMultiplier(yieldRun) == 1.05,
        "INBOX (45): first harvest buy must be x1.05, got "
            .. tostring(expedition.sampleYieldMultiplier(yieldRun)))

    local hullRun = expedition.new({ durability = 3 })
    hullRun.phase = "settlement"
    hullRun.durability = 2
    hullRun.money = hullRun.durabilityUpgradeCost
    local beforeMax = hullRun.maxDurability
    local beforeHp = hullRun.durability
    assert(expedition.buyDurabilityUpgrade(hullRun))
    assert(hullRun.maxDurability == beforeMax + 1,
        "INBOX (45): hull buy must add +1 maxDurability, got "
            .. tostring(hullRun.maxDurability))
    assert(hullRun.durability == beforeHp + 1,
        "INBOX (45): hull buy must fill the new cell (+1 current), got "
            .. tostring(hullRun.durability))
    assert(hullRun.durability < hullRun.maxDurability,
        "INBOX (45): Earth shop hull buy is not a full heal")

    print("  INBOX-45 harvest +5% and filled hull cell OK")
end

return M
