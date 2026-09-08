local M = {}

function M.run()
    local PlayScene = require("game.scenes.play")
    local expedition = require("game.expedition")
    local gearMod = require("game.gear")

    -- Item 7(c) regression: Earth-shop gear offer ("b" key during settlement).
    -- On settlement entry an earthShopGearOffer is rolled (non-galaxy-exclusive).
    -- "b" during settlement: buys the offer, deducts money, equips gear, clears offer.
    -- "b" with no money: shows earth_gear_broke message, offer preserved.
    -- "b" with full slots: shows earth_gear_full message, offer preserved.
    -- After relaunch the offer is cleared.
    local commonCard = {
        id = "hull_7c_test_fixture",
        name = "7C Fixture", nameKo = "7C 테스트",
        icon = "▭", rarity = "common",
        galaxyExclusive = false,
        tags = {}, editions = {},
        effects = { { type = "hullDurability", value = 0 } },
    }
    local price = gearMod.buyPrice(commonCard)

    -- (a) successful buy: money deducted, gear equipped, offer cleared
    local buyScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() end },
    })
    buyScene.expedition.phase = "settlement"
    buyScene.expedition.money = price + 10
    buyScene.earthShopGearOffer = commonCard
    buyScene:keypressed("b")
    assert(buyScene.earthShopGearOffer == nil,
        "item 7(c): successful buy must clear earthShopGearOffer")
    assert(buyScene.expedition.money == 10,
        "item 7(c): buy must deduct exactly the gear price (money="
        .. tostring(buyScene.expedition.money) .. ")")
    assert(#buyScene.expedition.equippedGear == 1,
        "item 7(c): buy must equip the gear (equippedGear="
        .. tostring(#buyScene.expedition.equippedGear) .. ")")

    -- (b) not enough money: offer preserved, message set
    local poorScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() end },
    })
    poorScene.expedition.phase = "settlement"
    poorScene.expedition.money = price - 1
    poorScene.earthShopGearOffer = commonCard
    poorScene:keypressed("b")
    assert(poorScene.earthShopGearOffer ~= nil,
        "item 7(c): insufficient-money buy must preserve earthShopGearOffer")
    assert(poorScene.expedition.money == price - 1,
        "item 7(c): insufficient-money buy must not deduct money")
    assert(poorScene.message ~= nil and poorScene.message:find("%d"),
        "item 7(c): insufficient-money buy must set a message with a number")

    -- (c) slots full: offer preserved, message set
    local fullScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() end },
    })
    fullScene.expedition.phase = "settlement"
    fullScene.expedition.money = price * 10
    fullScene.earthShopGearOffer = commonCard
    local hullSlots = require("game.engine_parts").hullSlotCount
    for i = 1, hullSlots do
        local filler = {
            id = "filler_" .. i, name = "F" .. i, nameKo = "F" .. i,
            icon = "f", rarity = "common", tags = {}, editions = {},
            effects = { { type = "hullDurability", value = 0 } },
        }
        expedition.equipGear(fullScene.expedition, "hull", filler)
    end
    fullScene:keypressed("b")
    assert(fullScene.earthShopGearOffer ~= nil,
        "item 7(c): full-slots buy must preserve earthShopGearOffer")
    assert(#fullScene.expedition.equippedGear == hullSlots,
        "item 7(c): full-slots buy must not change equippedGear count")
    assert(fullScene.message ~= nil,
        "item 7(c): full-slots buy must set a message")

    -- (d) "b" outside settlement is a no-op on the offer
    local flyScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() end },
    })
    flyScene.expedition.phase = "ascending"
    flyScene.expedition.money = price + 10
    flyScene.earthShopGearOffer = commonCard
    flyScene:keypressed("b")
    assert(flyScene.earthShopGearOffer ~= nil,
        "item 7(c): 'b' outside settlement must not consume earthShopGearOffer")

    -- (e) relaunch clears earthShopGearOffer
    local relScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() end },
    })
    relScene.expedition.phase = "settlement"
    relScene.earthShopGearOffer = commonCard
    relScene:keypressed("space")
    assert(relScene.earthShopGearOffer == nil,
        "item 7(c): relaunch must clear earthShopGearOffer")
end

return M
