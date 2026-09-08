local expedition = require("game.expedition")

local M = {}

function M.run()
    local hullShopRun = expedition.new({
        durability = 2,
        durabilityUpgradeCost = 60,
        money = 85,
    })
    assert(not expedition.buyDurabilityUpgrade(hullShopRun))
    hullShopRun.phase = "settlement"
    assert(expedition.buyDurabilityUpgrade(hullShopRun))
    assert(hullShopRun.money == 25 and hullShopRun.durabilityUpgradeLevel == 1 and hullShopRun.maxDurability == 3)
    assert(not expedition.buyDurabilityUpgrade(hullShopRun))
    assert(expedition.launch(hullShopRun) and hullShopRun.phase == "ascending")
    assert(hullShopRun.durability == 3)

    local yieldRun = expedition.new({
        sampleYieldUpgradeCost = 60,
        sampleYieldUpgradeAmount = 0.25,
        money = 45,
    })
    assert(not expedition.buySampleYieldUpgrade(yieldRun))
    yieldRun.phase = "settlement"
    assert(not expedition.buySampleYieldUpgrade(yieldRun))
    yieldRun.money = 60
    assert(expedition.buySampleYieldUpgrade(yieldRun))
    assert(yieldRun.money == 0 and yieldRun.sampleYieldUpgradeLevel == 1)
    assert(expedition.sampleYieldMultiplier(yieldRun) == 1.25)
    assert(expedition.launch(yieldRun) and yieldRun.phase == "ascending")
    local ok, awarded = expedition.collectSample(yieldRun, 20)
    assert(ok and awarded == 25 and yieldRun.pendingSampleValue == 25 and yieldRun.sampleCount == 1)
    assert(expedition.damage(yieldRun, yieldRun.durability))
    assert(yieldRun.phase == "destroyed" and yieldRun.sampleYieldUpgradeLevel == 0)
    assert(expedition.sampleYieldMultiplier(yieldRun) == 1)
end

return M
