local PlayScene = require("game.scenes.play")

local M = {}

function M.run()
    -- Item 7(a) UI regression: the shop-planet modal keyboard interaction
    -- (keypressed "y" = buy, "n" = skip/leave) added in commit 4358510.
    local expedition = require("game.expedition")
    local gearMod = require("game.gear")

    -- Keep the require in this characterization boundary: the original block
    -- loaded expedition before exercising the scene callbacks.

    local fixtureCard = {
        id = "hull_shop_modal_fixture",
        name = "Modal Fixture", nameKo = "모달 픽스처",
        icon = "▭", rarity = "common",
        tags = {}, editions = {},
        effects = { { type = "hullDurability", value = 0 } },
    }
    local fixturePrice = gearMod.buyPrice(fixtureCard)

    -- "n" dismisses the modal without buying.
    local skipScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() end },
    })
    skipScene.expedition.phase = "ascending"
    skipScene.expedition.money = fixturePrice + 10
    local fakePlanet = { id = "shop:skip-test", x = 0, y = 0, isShop = true }
    skipScene.shopModal = { planet = fakePlanet, gear = fixtureCard, category = "hull", price = fixturePrice }
    skipScene:keypressed("n")
    assert(skipScene.shopModal == nil,
        "item 7(a): keypressed('n') must dismiss shopModal")
    assert(skipScene.expedition.money == fixturePrice + 10,
        "item 7(a): skip must not deduct money")
    assert(#skipScene.expedition.equippedGear == 0,
        "item 7(a): skip must not equip any gear")

    -- "y" with enough money buys the card.
    local buyScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() end },
    })
    buyScene.expedition.phase = "ascending"
    buyScene.expedition.money = fixturePrice + 5
    buyScene.shopModal = { planet = fakePlanet, gear = fixtureCard, category = "hull", price = fixturePrice }
    buyScene:keypressed("y")
    assert(buyScene.shopModal == nil,
        "item 7(a): successful buy must clear shopModal")
    assert(buyScene.expedition.money == 5,
        "item 7(a): buy must deduct exactly the gear buy price, got money="
            .. tostring(buyScene.expedition.money))
    assert(#buyScene.floatingTexts >= 1,
        "item 7(a): successful buy must append a floatingText")
    assert(buyScene.floatingTexts[#buyScene.floatingTexts].text:find(fixtureCard.name),
        "item 7(a): floating text must mention the acquired gear name")

    -- "y" without enough money refuses the purchase and keeps the modal.
    local poorScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() end },
    })
    poorScene.expedition.phase = "ascending"
    poorScene.expedition.money = fixturePrice - 1
    poorScene.shopModal = { planet = fakePlanet, gear = fixtureCard, category = "hull", price = fixturePrice }
    poorScene:keypressed("y")
    assert(poorScene.shopModal ~= nil,
        "item 7(a): failed buy must keep shopModal open")
    assert(poorScene.shopModal.errorText and #poorScene.shopModal.errorText > 0,
        "item 7(a): failed buy must set shopModal.errorText")
    assert(poorScene.expedition.money == fixturePrice - 1,
        "item 7(a): failed buy must not deduct money")

    -- An open modal consumes "y" before settlement shortcuts can use it.
    local blockScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() end },
    })
    blockScene.expedition.phase = "settlement"
    blockScene.expedition.money = blockScene.expedition.sampleYieldUpgradeCost + 50
    local beforeYieldLevel = blockScene.expedition.sampleYieldUpgradeLevel
    blockScene.shopModal = { planet = fakePlanet, gear = fixtureCard, category = "hull", price = fixturePrice }
    blockScene:keypressed("y")
    assert(blockScene.expedition.sampleYieldUpgradeLevel == beforeYieldLevel,
        "item 7(a): 'y' key must not trigger settlement sampleYield upgrade while shopModal is open")
end

return M