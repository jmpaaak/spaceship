local expedition = require("game.expedition")
local gear = require("game.gear")

local M = {}

-- Item 7(a) gap: `world.shopPlanet(galaxy)` has generated a deterministic
-- per-galaxy shop-planet coordinate since the item 7 data-layer slice, and
-- item 9(c)'s `M.buyGear` already lets a player spend money to occupy a
-- slot -- but `M.buyGear` refuses anything outside `settlement` (Earth)
-- AND explicitly refuses `galaxyExclusive` parts (item 7(c)'s Earth-only
-- restriction). That left item 7(a)'s "각 은하계의 고정 좌표에 존재하는
-- 상점 행성에서 돈으로 구매" acquisition path with a real coordinate and a
-- real price/equip mechanism but NO run function a shop-planet encounter
-- could actually call -- the same "documented acquisition path with zero
-- consumers" class of gap this lane has repeatedly found and closed.
function M.run()
    local commonCard = {
        id = "hull_shopplanet_fixture", name = "Shop Fixture", nameKo = "상점 픽스처", icon = "▭",
        rarity = "common", tags = { "defense" }, editions = {},
        effects = { { type = "hullDurability", value = 1 } },
    }

    -- Refused outside the ascending (in-flight) phase, e.g. still on the
    -- launch pad -- a shop planet can only be reached mid-flight.
    local launchRun = expedition.new({ money = 20 })
    local launchOk, launchErr = expedition.buyGearFromShopPlanet(launchRun, "hull", commonCard)
    assert(not launchOk, "buyGearFromShopPlanet must refuse outside the ascending phase")
    assert(launchErr and #launchErr > 0)
    assert(launchRun.money == 20)
    assert(#launchRun.equippedGear == 0)

    -- Refused during the Earth-shop settlement phase too (this is a
    -- DIFFERENT acquisition path from M.buyGear, not an alias for it).
    local settleRun = expedition.new({ money = 20 })
    settleRun.phase = "settlement"
    local settleOk = expedition.buyGearFromShopPlanet(settleRun, "hull", commonCard)
    assert(not settleOk, "buyGearFromShopPlanet must refuse during settlement -- that is Earth-shop's M.buyGear")

    -- Succeeds while ascending, deducts the exact buyPrice, and equips.
    local flightRun = expedition.new({ money = 20 })
    flightRun.phase = "ascending"
    local ok, price = expedition.buyGearFromShopPlanet(flightRun, "hull", commonCard)
    assert(ok, "an affordable shop-planet purchase while ascending must succeed")
    assert(price == 12, "returned price must match gear.buyPrice: got " .. tostring(price))
    assert(flightRun.money == 8, "money must decrease by exactly the buy price: got " .. tostring(flightRun.money))
    assert(#flightRun.equippedGear == 1 and flightRun.equippedGear[1].id == "hull_shopplanet_fixture")
    assert(flightRun.maxDurability == 4,
        "buying a hullDurability card from a shop planet must refresh maxDurability immediately, got "
            .. tostring(flightRun.maxDurability))

    -- Not enough money: refused, no partial effect.
    local poorRun = expedition.new({ money = 11 })
    poorRun.phase = "ascending"
    local poorOk, poorErr = expedition.buyGearFromShopPlanet(poorRun, "hull", commonCard)
    assert(not poorOk, "buying must fail when money is below buyPrice")
    assert(poorErr and #poorErr > 0)
    assert(poorRun.money == 11)
    assert(#poorRun.equippedGear == 0)

    -- Unlike Earth-shop M.buyGear, a shop planet MAY sell a galaxyExclusive
    -- card -- item 7(c) only names Earth's exclusion, and a shop planet's
    -- whole reason to exist (item 7(a)) is a physical in-galaxy location
    -- that could legitimately stock that galaxy's own exclusive gear.
    local exclusiveCard = {
        id = "hull_shopplanet_exclusive", name = "Exclusive Fixture", nameKo = "전용 픽스처", icon = "★",
        rarity = "rare", tags = { "economy" }, editions = {},
        galaxyExclusive = true,
        effects = { { type = "money", value = 5 } },
    }
    local exclusiveRun = expedition.new({ money = 200 })
    exclusiveRun.phase = "ascending"
    local exclusiveOk, exclusivePrice = expedition.buyGearFromShopPlanet(exclusiveRun, "hull", exclusiveCard)
    assert(exclusiveOk, "a shop planet must be allowed to sell a galaxyExclusive card, unlike Earth's buyGear")
    assert(exclusivePrice == gear.buyPrice(exclusiveCard))
    assert(#exclusiveRun.equippedGear == 1 and exclusiveRun.equippedGear[1].id == "hull_shopplanet_exclusive")

    -- Item 14(F) shopDiscount applies here too (M.shopPrice is shared with
    -- M.buyGear), and engine-slot purchases stay independent of hull (item
    -- 10 slot-category isolation).
    local tradeCard = gear.findById(gear.loadHullParts(), "hull_trade_license")
    assert(tradeCard, "fixture hull_trade_license must exist")
    local discountRun = expedition.new({ money = 50 })
    assert(expedition.equipGear(discountRun, "hull", tradeCard))
    discountRun.phase = "ascending"
    local expectedDiscountPrice = expedition.shopPrice(discountRun, gear.buyPrice(commonCard))
    local discountOk, discountPrice = expedition.buyGearFromShopPlanet(discountRun, "hull", commonCard)
    assert(discountOk and discountPrice == expectedDiscountPrice,
        "a shop-planet purchase must also honor an equipped shopDiscount card")

    local engineRun = expedition.new({ money = 54 })
    engineRun.phase = "ascending"
    local rareEngineCard = {
        id = "engine_shopplanet_fixture", name = "Engine Fixture", nameKo = "엔진 픽스처", icon = "◬",
        rarity = "rare", tags = { "speed" }, editions = {},
        effects = { { type = "boostCharge", value = 1 } },
    }
    local engineOk = expedition.buyGearFromShopPlanet(engineRun, "engine", rareEngineCard)
    assert(engineOk, "buying an engine card from a shop planet must succeed")
    assert(#engineRun.equippedEngineParts == 1)
    assert(#engineRun.equippedGear == 0, "an engine-slot shop-planet purchase must not affect the hull slot list")
end

return M