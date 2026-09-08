local expedition = require("game.expedition")
local gear = require("game.gear")

local M = {}

-- Item 9(c) follow-up: sellGear exists, but the documented swap loop is
-- "카드 획득(상점 구매/체크포인트 확정 드롭)과 교체". Hub drops
-- (exploreHub) and sellGear were wired; Earth-shop *purchase* of a part
-- was not -- shopDiscount therefore never applied to the card that is
-- supposed to be the shop's main product, and there was no run-level
-- counterpart to sellGear that spends money to occupy a slot. This
-- closes that gap with a pure buyPrice (rarity-scaled, well above
-- sellValue so sell-to-rebuy stays lossy) plus expedition.buyGear.
function M.run()
    -- buyPrice is 3x the matching sellValue so selling then rebuying is
    -- a real loss, matching the Item 9(c) schema note. An edition adds
    -- a flat premium (3x editionSellBonus), same shape as sellValue.
    assert(gear.buyPrice({ rarity = "common" }) == 12)
    assert(gear.buyPrice({ rarity = "uncommon" }) == 27)
    assert(gear.buyPrice({ rarity = "rare" }) == 54)
    assert(gear.buyPrice({ rarity = "legendary" }) == 120)
    assert(gear.buyPrice({ rarity = "legendary", edition = "irradiated" }) == 138,
        "an edition-carrying legendary card must cost base(120) + editionBuyBonus(18)")
    assert(gear.buyPrice({}) == 12, "unknown/missing rarity must fall back to common, like sellValue")
    assert(gear.buyPrice({ rarity = "common" }) > gear.sellValue({ rarity = "common" }),
        "buyPrice must exceed sellValue so sell-to-rebuy is lossy")

    local commonCard = {
        id = "hull_scrap_plate", name = "Scrap Plate", nameKo = "고철 장갑판", icon = "▭",
        rarity = "common", tags = { "defense" }, editions = {},
        effects = { { type = "hullDurability", value = 1 } },
    }

    -- Buying is settlement-only, same contract as sellGear / buyFuelUpgrade.
    local flightRun = expedition.new({ money = 50 })
    flightRun.phase = "ascending"
    local flightOk, flightErr = expedition.buyGear(flightRun, "hull", commonCard)
    assert(not flightOk, "buying gear must be rejected outside the settlement phase")
    assert(flightErr and #flightErr > 0)
    assert(flightRun.money == 50, "a rejected buy must not change money")
    assert(#flightRun.equippedGear == 0, "a rejected buy must not equip the card")

    -- Too-poor settlement run is rejected without mutating slots.
    local poorRun = expedition.new({ money = 11 })
    poorRun.phase = "settlement"
    local poorOk, poorErr = expedition.buyGear(poorRun, "hull", commonCard)
    assert(not poorOk, "buying must fail when money is below buyPrice")
    assert(poorErr and #poorErr > 0)
    assert(poorRun.money == 11)
    assert(#poorRun.equippedGear == 0)

    -- Successful hull purchase deducts exact buyPrice and equips.
    local shopRun = expedition.new({ money = 20 })
    shopRun.phase = "settlement"
    local ok, price = expedition.buyGear(shopRun, "hull", commonCard)
    assert(ok, "buying an affordable hull card during settlement must succeed")
    assert(price == 12, "returned buy price must match gear.buyPrice: got " .. tostring(price))
    assert(shopRun.money == 8, "money must decrease by exactly the buy price: got " .. tostring(shopRun.money))
    assert(#shopRun.equippedGear == 1 and shopRun.equippedGear[1].id == "hull_scrap_plate",
        "the purchased card must occupy a hull slot")
    -- hullDurability +1 on a base-3 ship must land immediately (equipGear
    -- already refreshes stats; buyGear must go through that path).
    assert(shopRun.maxDurability == 4,
        "buying a hullDurability card must refresh maxDurability, got " .. tostring(shopRun.maxDurability))

    -- Duplicate id is rejected with money unchanged.
    local dupOk, dupErr = expedition.buyGear(shopRun, "hull", commonCard)
    assert(not dupOk and dupErr)
    assert(shopRun.money == 8)
    assert(#shopRun.equippedGear == 1)

    -- Engine-slot purchase must not touch the hull list (item 10).
    local engineShopRun = expedition.new({ money = 54 })
    engineShopRun.phase = "settlement"
    local rareEngineCard = {
        id = "engine_test_thruster", name = "Test Thruster", nameKo = "테스트 추진기", icon = "◬",
        rarity = "rare", tags = { "speed" }, editions = {},
        effects = { { type = "boostCharge", value = 1 } },
    }
    local engineOk, enginePrice = expedition.buyGear(engineShopRun, "engine", rareEngineCard)
    assert(engineOk and enginePrice == 54)
    assert(#engineShopRun.equippedEngineParts == 1, "the purchased engine card must occupy an engine slot")
    assert(#engineShopRun.equippedGear == 0, "buying an engine card must not affect the hull slot list")

    -- Item 14(F): shopDiscount must apply to the gear purchase itself,
    -- not only to fuel/hull/steering upgrades. hull_trade_license is
    -- +20%, so a common card that costs 12 becomes 9.6.
    local tradeCard = gear.findById(gear.loadHullParts(), "hull_trade_license")
    assert(tradeCard, "fixture hull_trade_license must exist")
    local discountRun = expedition.new({ money = 50 })
    assert(expedition.equipGear(discountRun, "hull", tradeCard))
    discountRun.phase = "settlement"
    local expectedDiscountPrice = expedition.shopPrice(discountRun, gear.buyPrice(commonCard))
    assert(expectedDiscountPrice == 12 * 0.8,
        "shopPrice of a common card with +20% shopDiscount must be 9.6, got " .. tostring(expectedDiscountPrice))
    local discountOk, discountPrice = expedition.buyGear(discountRun, "hull", commonCard)
    assert(discountOk, "a discounted gear purchase must succeed")
    assert(discountPrice == expectedDiscountPrice)
    assert(discountRun.money == 50 - expectedDiscountPrice,
        "buying with an equipped shopDiscount card must charge the discounted gear price, got "
            .. tostring(discountRun.money))

    -- Item 7 Earth-shop rule reused by item 9(c)/10(c): galaxyExclusive
    -- cards are never sold on Earth. buyGear is that Earth-shop action.
    local exclusiveCard = {
        id = "hull_galaxy_only", name = "Galaxy Only", nameKo = "은하 전용", icon = "★",
        rarity = "rare", tags = { "economy" }, editions = {},
        galaxyExclusive = true,
        effects = { { type = "money", value = 5 } },
    }
    local exclusiveRun = expedition.new({ money = 200 })
    exclusiveRun.phase = "settlement"
    local exclusiveOk, exclusiveErr = expedition.buyGear(exclusiveRun, "hull", exclusiveCard)
    assert(not exclusiveOk, "Earth-shop buyGear must refuse a galaxyExclusive card")
    assert(exclusiveErr and #exclusiveErr > 0)
    assert(exclusiveRun.money == 200)
    assert(#exclusiveRun.equippedGear == 0)

    -- Selling a just-bought hullDurability card must also refresh
    -- maxDurability (sellGear historically bypassed unequipGear).
    local sellRefreshRun = expedition.new({ money = 20, durability = 3 })
    sellRefreshRun.phase = "settlement"
    assert(expedition.buyGear(sellRefreshRun, "hull", commonCard))
    assert(sellRefreshRun.maxDurability == 4)
    assert(expedition.sellGear(sellRefreshRun, "hull", "hull_scrap_plate"))
    assert(sellRefreshRun.maxDurability == 3,
        "selling a hullDurability card must refresh maxDurability back down, got "
            .. tostring(sellRefreshRun.maxDurability))
end

return M