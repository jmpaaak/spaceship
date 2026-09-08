local expedition = require("game.expedition")
local i18n = require("game.i18n")

local M = {}

-- INBOX-47: Hub planets open full settlement shop (not just settleAtHub).
-- Hub relaunch stores lastHubX/lastHubY; launch clears them.
function M.run()
    -- (a) Hub settlement: settle() enters "settlement" phase with full
    -- payout (including hull money bonus), same as Earth return.
    local run47a = expedition.new({ money = 50 })
    run47a.phase = "ascending"
    run47a.pendingSampleValue = 20
    run47a.sampleCount = 3
    run47a.maxAltitude = 500
    run47a.lastHubX = 100
    run47a.lastHubY = -2000
    expedition.settle(run47a)
    assert(run47a.phase == "settlement",
        "INBOX-47(a): hub settle must set phase to 'settlement', got " .. tostring(run47a.phase))
    assert(run47a.lastSettlement >= 20,
        "INBOX-47(a): hub settle must pay at least 20, got " .. tostring(run47a.lastSettlement))
    assert(run47a.pendingSampleValue == 0,
        "INBOX-47(a): hub settle must zero pendingSampleValue")
    -- lastHubX/Y should survive settle (cleared only on launch)
    assert(run47a.lastHubX == 100, "INBOX-47(a): lastHubX must survive settle")
    assert(run47a.lastHubY == -2000, "INBOX-47(a): lastHubY must survive settle")

    -- (b) Launch from hub settlement clears hub position
    local hubX_before = run47a.lastHubX
    local hubY_before = run47a.lastHubY
    assert(hubX_before ~= nil, "INBOX-47(b): lastHubX must exist before launch")
    expedition.launch(run47a)
    assert(run47a.phase == "ascending",
        "INBOX-47(b): launch must set phase to 'ascending'")
    assert(run47a.lastHubX == nil, "INBOX-47(b): launch must clear lastHubX")
    assert(run47a.lastHubY == nil, "INBOX-47(b): launch must clear lastHubY")
    assert(run47a.lastVisitedGalaxyId == nil,
        "INBOX-47(b): launch must clear lastVisitedGalaxyId")

    -- (c) new() initializes lastHubX/Y to nil
    local run47c = expedition.new()
    assert(run47c.lastHubX == nil, "INBOX-47(c): new() must init lastHubX to nil")
    assert(run47c.lastHubY == nil, "INBOX-47(c): new() must init lastHubY to nil")

    -- (d) destroy() clears lastHubX/Y
    local run47d = expedition.new()
    run47d.phase = "ascending"
    run47d.lastHubX = 50
    run47d.lastHubY = -1000
    run47d.durability = 0
    expedition.damage(run47d, 1)  -- triggers destroy
    assert(run47d.lastHubX == nil, "INBOX-47(d): destroy must clear lastHubX")
    assert(run47d.lastHubY == nil, "INBOX-47(d): destroy must clear lastHubY")

    -- (e) i18n hub_shop_label exists in both languages
    i18n.setLocale("en")
    local enLabel = i18n.t("hub_shop_label")
    assert(enLabel == "HUB SHOP",
        "INBOX-47(e): EN hub_shop_label must be 'HUB SHOP', got " .. tostring(enLabel))
    i18n.setLocale("ko")
    local koLabel = i18n.t("hub_shop_label")
    assert(koLabel == "HUB 상점",
        "INBOX-47(e): KO hub_shop_label must be 'HUB 상점', got " .. tostring(koLabel))
    i18n.setLocale("en")  -- restore

    print("  INBOX-47 hub full settlement shop OK")
end

return M