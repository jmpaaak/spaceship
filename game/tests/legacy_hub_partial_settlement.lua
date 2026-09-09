local M = {}

-- Item 8: normal collection only gives samples, while a hub converts pending
-- samples into money without triggering a full Earth settlement.
function M.run()
    local expedition = require("game.expedition")

    local run = expedition.new()
    expedition.launch(run)
    run.money = 100

    -- Normal planet collection.
    expedition.collectSample(run, 10, "solar")
    assert(run.pendingSampleValue == 10,
        "normal collection should only increase pendingSampleValue")
    assert(run.money == 100,
        "normal collection must not increase money immediately")

    -- Settle at hub.
    local payout = expedition.settleAtHub(run)
    assert(payout == 10, "settleAtHub should return the settled amount")
    assert(run.pendingSampleValue == 0,
        "settleAtHub must clear pendingSampleValue")
    assert(run.money == 110,
        "settleAtHub must add pendingSampleValue to money")

    -- Additional calls yield 0.
    local payout2 = expedition.settleAtHub(run)
    assert(payout2 == 0, "consecutive settleAtHub should yield 0")
    assert(run.money == 110, "money should remain unchanged on zero payout")
end

return M
