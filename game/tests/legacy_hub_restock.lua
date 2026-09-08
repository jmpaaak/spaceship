local expedition = require("game.expedition")
local i18n = require("game.i18n")

local M = {}

-- INBOX 61(16): hub restock button characterization coverage.
function M.run()
    -- (a) hubRestock succeeds at hub settlement with enough money
    local run = { phase = "settlement", lastVisitedGalaxyId = "gal1", money = 100,
        hull = {}, engine = {}, gear = {}, maxHeight = 500 }
    local pool = {{ name = "TestPart", type = "hull", rarity = "common",
        suit = "solar", effects = {{ type = "hp", value = 5 }} }}
    local rolls = { rarity = 0.1, pick = 0.1, editionChance = 0.9, editionPick = 0.1 }
    local ok, offer = expedition.hubRestock(run, pool, rolls)
    assert(ok, "INBOX 61(16): hubRestock should succeed at hub")
    assert(offer, "INBOX 61(16): hubRestock should return an offer")
    assert(run.money == 100 - (expedition.hubRestockCost or 5),
        "INBOX 61(16): hubRestock should deduct cost, got " .. run.money)

    -- (b) hubRestock fails on Earth (no lastVisitedGalaxyId)
    local run2 = { phase = "settlement", lastVisitedGalaxyId = nil, money = 100,
        hull = {}, engine = {}, gear = {}, maxHeight = 500 }
    local ok2 = expedition.hubRestock(run2, pool, rolls)
    assert(not ok2, "INBOX 61(16): hubRestock should fail on Earth")

    -- (c) hubRestock fails with insufficient money
    local run3 = { phase = "settlement", lastVisitedGalaxyId = "gal1", money = 1,
        hull = {}, engine = {}, gear = {}, maxHeight = 500 }
    local ok3 = expedition.hubRestock(run3, pool, rolls)
    assert(not ok3, "INBOX 61(16): hubRestock should fail when broke")

    -- (d) i18n key exists
    local txt = i18n.t("hub_restock_btn", 5)
    assert(txt and not txt:find("hub_restock_btn"),
        "INBOX 61(16): hub_restock_btn i18n key must exist")

    print("  INBOX-61(16) hub restock OK")
end

return M
