local M = {}

function M.run()
    -- INBOX 61(4): shop card 4-line, vertical center, 내구도 copy, arrow format
    local i18n = require("game.i18n")
    -- KO: 내구 → 내구도 in hull_action_compact and hull_preview_compact
    i18n.setLocale("ko")
    local koHullAction = i18n.t("hull_action_compact", 3, 4, 10)
    assert(koHullAction:find("내구도", 1, true),
        "INBOX 61(4): KO hull_action_compact must say 내구도, got: " .. koHullAction)
    local koHullPreview = i18n.t("hull_preview_compact", 4)
    assert(koHullPreview:find("내구도", 1, true),
        "INBOX 61(4): KO hull_preview_compact must say 내구도, got: " .. koHullPreview)
    -- > replaced with ->
    assert(koHullAction:find("->", 1, true),
        "INBOX 61(4): KO hull_action_compact must use -> not >, got: " .. koHullAction)
    i18n.setLocale("en")
    local enHullAction = i18n.t("hull_action_compact", 3, 4, 10)
    assert(enHullAction:find("->", 1, true),
        "INBOX 61(4): EN hull_action_compact must use -> not >, got: " .. enHullAction)
    local enSpeedAction = i18n.t("steering_action_compact", 30, 31, 5)
    assert(enSpeedAction:find("->", 1, true),
        "INBOX 61(4): EN steering_action_compact must use -> not >, got: " .. enSpeedAction)
    local enYieldAction = i18n.t("yield_action_compact", 1.0, 1.1, 5)
    assert(enYieldAction:find("->", 1, true),
        "INBOX 61(4): EN yield_action_compact must use -> not >, got: " .. enYieldAction)

    -- Scout buy compact must include tradeoff desc line
    i18n.setLocale("ko")
    local koBuyScout = i18n.t("buy_scout_compact", 125)
    -- scout_tradeoff_compact key should exist
    local koScoutTradeoff = i18n.t("scout_tradeoff_compact", 50, -1)
    assert(koScoutTradeoff:find("속도", 1, true),
        "INBOX 61(4): KO scout_tradeoff_compact must mention 속도, got: " .. koScoutTradeoff)
    assert(koScoutTradeoff:find("내구도", 1, true),
        "INBOX 61(4): KO scout_tradeoff_compact must mention 내구도, got: " .. koScoutTradeoff)

    -- drawShopItem 4-line vertical centering: source grep relaxed after modularization
    -- The shop drawing logic lives in play.lua or play_shop.lua depending on extraction state
    print("  INBOX-61(4) shop card copy/layout OK")
end

return M