local M = {}

-- Item 8 follow-up: the basic partial-settlement test does not cover the gear
-- interaction boundary documented by settleAtHub.
function M.run()
    local expedition = require("game.expedition")

    -- sampleSellValue is applied by collectSample before the pending value is
    -- settled, so the hub payout includes it.
    local sellCard = {
        id = "hub-sell-fixture", name = "SellGear", nameKo = "판매", icon = "▤",
        rarity = "common", tags = {"economy"}, editions = {},
        effects = { { type = "sampleSellValue", value = 10 } },
    }
    local sellRun = expedition.new()
    expedition.launch(sellRun)
    assert(expedition.equipGear(sellRun, "hull", sellCard))
    expedition.collectSample(sellRun, 5, "azure")
    assert(sellRun.pendingSampleValue == 15,
        "collectSample with sampleSellValue +10 gear must accumulate 15 into pendingSampleValue, got "
            .. tostring(sellRun.pendingSampleValue))
    local sellPayout = expedition.settleAtHub(sellRun)
    assert(sellPayout == 15,
        "settleAtHub must pass through the already-bonus'd pendingSampleValue (15), got "
            .. tostring(sellPayout))
    assert(sellRun.money == 15,
        "hub settle with sampleSellValue gear must credit the gear-boosted value, got "
            .. tostring(sellRun.money))

    -- Flat money gear is Earth-only and must not be applied at a hub.
    local moneyCard = {
        id = "hub-money-fixture", name = "MoneyGear", nameKo = "현금", icon = "✦",
        rarity = "common", tags = {"economy"}, editions = {},
        effects = { { type = "money", value = 20 } },
    }
    local moneyRun = expedition.new()
    expedition.launch(moneyRun)
    assert(expedition.equipGear(moneyRun, "hull", moneyCard))
    expedition.collectSample(moneyRun, 8, "ember")
    assert(moneyRun.pendingSampleValue == 8,
        "collectSample with money-only gear must not inflate pendingSampleValue (expected 8, got "
            .. tostring(moneyRun.pendingSampleValue) .. ")")
    local moneyPayout = expedition.settleAtHub(moneyRun)
    assert(moneyPayout == 8,
        "settleAtHub must NOT apply equippedHullMoneyBonus (Earth-only); expected payout 8, got "
            .. tostring(moneyPayout))
    assert(moneyRun.money == 8,
        "hub settle must credit only pendingSampleValue (8), not +money gear bonus; got "
            .. tostring(moneyRun.money))

    -- Hub settlement does not perform the Earth-only sample-count reset.
    local cntRun = expedition.new()
    expedition.launch(cntRun)
    expedition.collectSample(cntRun, 3, "void")
    expedition.collectSample(cntRun, 5, "void")
    assert(cntRun.sampleCount == 2, "two collectSample calls must set sampleCount to 2")
    expedition.settleAtHub(cntRun)
    assert(cntRun.sampleCount == 2,
        "settleAtHub must NOT reset sampleCount (that is Earth-settle only); expected 2, got "
            .. tostring(cntRun.sampleCount))

    -- Document the current phase-independent contract: settleAtHub always
    -- returns a number, even when called before launch.
    local launchRun = expedition.new()
    assert(launchRun.phase == "launch")
    launchRun.money = 50
    launchRun.pendingSampleValue = 99
    local noopPayout = expedition.settleAtHub(launchRun)
    assert(type(noopPayout) == "number", "settleAtHub must always return a number")
end

return M