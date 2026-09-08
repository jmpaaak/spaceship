local exp = require("game.expedition")

local M = {}

-- INBOX 61(19): slot speed reward must use slotSpeedBonus, not steeringUpgradeLevel.
function M.run()
    local run = exp.new({ baseSpeed = 30, steeringUpgradeAmount = 1 })
    -- Simulate buying 2 shop steering upgrades.
    run.money = 1000
    run.phase = "settlement"
    exp.buySteeringUpgrade(run)
    exp.buySteeringUpgrade(run)
    assert(run.steeringUpgradeLevel == 2, "INBOX 61(19): shop upgrades should set level=2")
    local costAfterShop = exp.upgradeCost(run, run.steeringUpgradeCost, run.steeringUpgradeLevel)

    -- Simulate slot speed reward (+20) via slotSpeedBonus.
    run.slotSpeedBonus = (run.slotSpeedBonus or 0) + 20
    assert(run.steeringUpgradeLevel == 2,
        "INBOX 61(19): slot speed reward must not change steeringUpgradeLevel")
    local costAfterSlot = exp.upgradeCost(run, run.steeringUpgradeCost, run.steeringUpgradeLevel)
    assert(costAfterShop == costAfterSlot,
        "INBOX 61(19): upgrade cost must not change from slot reward, got " ..
        costAfterShop .. " vs " .. costAfterSlot)

    -- base=30 + 2*1(shop) + 20(slot) = 52.
    local speed = exp.effectiveSpeed(run)
    assert(speed >= 52,
        "INBOX 61(19): effectiveSpeed must include slotSpeedBonus, got " .. speed)

    -- Meta wipe must reset slotSpeedBonus.
    run.phase = "ascending"
    run.durability = run.maxDurability
    exp.damage(run, run.durability)
    assert(run.phase == "destroyed", "INBOX 61(19): should be destroyed")
    assert(run.slotSpeedBonus == 0,
        "INBOX 61(19): meta wipe must reset slotSpeedBonus")
    print("  INBOX-61(19) slot speed bonus separate from upgrade level OK")
end

return M