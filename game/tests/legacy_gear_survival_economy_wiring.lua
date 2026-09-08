local expedition = require("game.expedition")
local gear = require("game.gear")

local M = {}

-- Insurance and shopDiscount were originally only pure gear conversions;
-- this characterizes their expedition destruction and purchase wiring.
function M.run()
    local hullPool = gear.loadHullParts()

    -- An equipped emergency beacon survives one lethal hit without a meta
    -- wipe. The second lethal hit consumes the usual destruction path.
    local beaconCard = gear.findById(hullPool, "hull_emergency_beacon")
    assert(beaconCard, "fixture hull card 'hull_emergency_beacon' must exist in the bundled pool")
    local insuredRun = expedition.new({ durability = 2, money = 40 })
    assert(expedition.equipGear(insuredRun, "hull", beaconCard))
    expedition.launch(insuredRun)
    insuredRun.durability = 1

    local destroyedFirstHit = expedition.damage(insuredRun, 5)
    assert(destroyedFirstHit == false,
        "an equipped insurance part must prevent destruction on the first lethal hit")
    assert(insuredRun.phase == "ascending", "an insured survival must keep the run in its current phase")
    assert(insuredRun.durability > 0, "an insured survival must restore at least 1 durability")
    assert(insuredRun.money == 40, "an insured survival must NOT trigger the meta wipe (money must be untouched)")
    assert(#insuredRun.equippedGear == 1, "an insured survival must keep equipped gear (no meta wipe)")

    insuredRun.durability = 1
    local destroyedSecondHit = expedition.damage(insuredRun, 5)
    assert(destroyedSecondHit == true,
        "insurance is a one-time save; a second lethal hit must destroy normally")
    assert(insuredRun.phase == "destroyed")
    assert(insuredRun.money == 0, "the second (uninsured) destruction must still perform the full meta wipe")

    local uninsuredRun = expedition.new({ durability = 1, money = 10 })
    expedition.launch(uninsuredRun)
    assert(expedition.damage(uninsuredRun, 5) == true,
        "a run with no insurance gear must destroy on the first lethal hit, same as before this slice")

    -- An equipped trade license applies its 20% discount to the actual
    -- settlement purchase, while an unequipped run pays full price.
    local tradeCard = gear.findById(hullPool, "hull_trade_license")
    assert(tradeCard, "fixture hull card 'hull_trade_license' must exist in the bundled pool")
    local discountRun = expedition.new({ durabilityUpgradeCost = 50, money = 50 })
    assert(expedition.equipGear(discountRun, "hull", tradeCard))
    discountRun.phase = "settlement"
    assert(expedition.shopPrice(discountRun, discountRun.durabilityUpgradeCost) == 40,
        "shopPrice must apply the equipped shopDiscount percentage")
    assert(expedition.buyDurabilityUpgrade(discountRun),
        "a discounted purchase must still succeed at the reduced price")
    assert(discountRun.money == 10,
        "buying with an equipped shopDiscount card must charge the discounted price (50 - 40 = 10 left), got "
            .. tostring(discountRun.money))

    local fullPriceRun = expedition.new({ durabilityUpgradeCost = 50, money = 50 })
    fullPriceRun.phase = "settlement"
    assert(expedition.buyDurabilityUpgrade(fullPriceRun))
    assert(fullPriceRun.money == 0,
        "a run with no shopDiscount gear must still pay the full base price, got " .. tostring(fullPriceRun.money))
end

return M
