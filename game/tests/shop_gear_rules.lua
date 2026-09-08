local rules = require("game.shop_gear_rules")

local M = {}

function M.run()
    print("  [INBOX 77(1)] shop gear purchase limit tests...")
    local state = rules.newState()
    local calls = 0
    local function purchase()
        calls = calls + 1
        return true, 25
    end

    local ok, price = rules.tryPurchase(state, "galaxy:1:shop", purchase)
    assert(ok and price == 25, "first gear purchase at a shop must succeed")
    assert(not rules.canPurchase(state, "galaxy:1:shop"),
        "a shop must disable gear purchases after its first successful purchase")
    local secondOk, secondErr = rules.tryPurchase(state, "galaxy:1:shop", purchase)
    assert(not secondOk and secondErr == rules.limitError,
        "a second gear purchase at the same shop must be rejected")
    assert(calls == 1, "rejected second purchase must not invoke the purchase callback")

    assert(rules.tryPurchase(state, "galaxy:2:shop", purchase),
        "a different galaxy shop must keep an independent purchase allowance")
    assert(calls == 2, "the independent shop purchase must invoke the callback")

    local failedState = rules.newState()
    local failed = rules.tryPurchase(failedState, "galaxy:3:shop", function()
        return false, "not enough money"
    end)
    assert(not failed and rules.canPurchase(failedState, "galaxy:3:shop"),
        "failed purchases must not consume the shop allowance")

    local shopSource = love.filesystem.read("game/scenes/play_shop.lua") or ""
    local inputSource = love.filesystem.read("game/scenes/play_input.lua") or ""
    assert(shopSource:find('require%("game%.shop_gear_rules"%)'),
        "play_shop must consume the pure shop gear rules")
    assert(shopSource:find("shop_modal_limit", 1, true),
        "the purchase button must expose its disabled one-item-limit state")
    assert(inputSource:find("self:buyShopModalGear%(%)"),
        "play input module must delegate galaxy shop purchases to play_shop")
    print("  INBOX-77(1) one gear purchase per galaxy shop OK")
end

return M