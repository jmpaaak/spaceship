local expedition = require("game.expedition")
local PlayScene = require("game.scenes.play")

local M = {}

function M.run()
    local nextLaunchScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    nextLaunchScene.expedition.phase = "settlement"
    local starterNextLaunch = nextLaunchScene:shopLoadoutLines()
    assert(starterNextLaunch.ship == "NEXT STARTER")
    assert(starterNextLaunch.stats == "HULL 3")
    assert(starterNextLaunch.upgrades == "HULL LV.0")

    assert(starterNextLaunch.scoutTradeoff[1] == "SCOUT GAINS +120 SPEED")
    assert(starterNextLaunch.scoutTradeoff[2] == "LOSSES -1 HULL")
    assert(starterNextLaunch.shipAction == "BUY SCOUT $125")
    assert(starterNextLaunch.shipPreview == "SCOUT HULL 2")

    assert(starterNextLaunch.hullAction == "T/H HULL LV.0>1 $10")
    assert(starterNextLaunch.hullPreview == "HULL 4")

    assert(starterNextLaunch.hullStatus == "SHORT $10" and not starterNextLaunch.hullAffordable)
    assert(starterNextLaunch.shipStatus == "SHORT $125" and not starterNextLaunch.shipAffordable)
    assert(starterNextLaunch.yieldAction == "T/Y HARVEST LV.0>1 $5")
    assert(starterNextLaunch.yieldPreview == "HARVEST x1.10")
    assert(starterNextLaunch.yieldStatus == "SHORT $5" and not starterNextLaunch.yieldAffordable)
    assert(starterNextLaunch.steeringAction == "T/G SPEED LV.0>1 $5")
    assert(starterNextLaunch.steeringPreview == "61")
    assert(starterNextLaunch.steeringStatus == "SHORT $5" and not starterNextLaunch.steeringAffordable)
    -- Compact column labels for the HULL/STEERING shared touch row (see
    -- settlementTouchRows: HULL occupies the left half, STEERING the right
    -- half of one 90px-wide column). The existing hullAction/steeringAction
    -- strings ("T/H HULL LV.0>1 $75", 91-96px measured) are too wide to sit
    -- side-by-side in a single 90 canvas px column, so these shorter
    -- "H:"/"G:" prefixed variants (measured 58-63px via GAME_FONTPROBE) are
    -- drawn in the column instead, without changing the existing full
    -- strings other callers may still rely on.
    assert(starterNextLaunch.hullActionCompact == "HULL 3 -> 4 $10")
    assert(starterNextLaunch.steeringActionCompact == "SPEED 60 -> 61 $5")
    assert(starterNextLaunch.hullPreviewCompact == "HULL 4")
    assert(starterNextLaunch.steeringPreviewCompact == "61")
    -- Same compact treatment for the YIELD/SHIP shared touch row (see
    -- settlementTouchRows: YIELD occupies the left half, SHIP the right
    -- half). yieldAction ("T/Y YIELD LV.0>1 $60", 92-97px) and shipAction
    -- ("BUY SCOUT $125"/"SELECT STARTER"/"SELECT SCOUT", 63-72px) are both
    -- too wide for a 90px column once a "T/V "/"T/Y " prefix and a
    -- side-by-side status line are added, so compact "Y:"/"V:" variants
    -- (measured 38-62px) are drawn in the column instead.
    assert(starterNextLaunch.yieldActionCompact == "HARVEST x1.00 -> x1.10 $5")
    assert(starterNextLaunch.shipActionCompact == "SCOUT $125")
    nextLaunchScene.expedition.money = 200
    local balancePreviewNextLaunch = nextLaunchScene:shopLoadoutLines()
    assert(balancePreviewNextLaunch.hullStatus == "LEFT $190" and balancePreviewNextLaunch.hullAffordable)
    assert(balancePreviewNextLaunch.shipStatus == "LEFT $75" and balancePreviewNextLaunch.shipAffordable)
    assert(balancePreviewNextLaunch.yieldStatus == "LEFT $195" and balancePreviewNextLaunch.yieldAffordable)
    assert(balancePreviewNextLaunch.steeringStatus == "LEFT $195" and balancePreviewNextLaunch.steeringAffordable)
    nextLaunchScene.expedition.money = nextLaunchScene.expedition.durabilityUpgradeCost
        + nextLaunchScene.expedition.scoutShipCost
        + nextLaunchScene.expedition.sampleYieldUpgradeCost
    nextLaunchScene:keypressed("h")
    local reinforcedNextLaunch = nextLaunchScene:shopLoadoutLines()
    assert(reinforcedNextLaunch.stats == "HULL 4")
    assert(reinforcedNextLaunch.upgrades == "HULL LV.1")
    assert(reinforcedNextLaunch.hullAction == "T/H HULL LV.1>2 $" .. expedition.upgradeCost(nextLaunchScene.expedition, nextLaunchScene.expedition.durabilityUpgradeCost, 1))
    assert(reinforcedNextLaunch.shipPreview == "SCOUT HULL 2")
    nextLaunchScene:keypressed("y")
    local yieldedNextLaunch = nextLaunchScene:shopLoadoutLines()
    assert(yieldedNextLaunch.yieldAction == "T/Y HARVEST LV.1>2 $" .. expedition.upgradeCost(nextLaunchScene.expedition, nextLaunchScene.expedition.sampleYieldUpgradeCost, 1))
    assert(yieldedNextLaunch.yieldPreview == "HARVEST x1.20")
    nextLaunchScene:keypressed("v")
    local scoutNextLaunch = nextLaunchScene:shopLoadoutLines()
    assert(scoutNextLaunch.ship == "NEXT SCOUT")
    assert(scoutNextLaunch.stats == "HULL 2")
    assert(scoutNextLaunch.upgrades == "HULL LV.1")

    assert(scoutNextLaunch.hullAction == "T/H HULL LV.1>2 $" .. expedition.upgradeCost(nextLaunchScene.expedition, nextLaunchScene.expedition.durabilityUpgradeCost, 1))
    assert(scoutNextLaunch.hullPreview == "HULL 3")

    assert(scoutNextLaunch.scoutTradeoff[1] == nil, "INBOX-30: scoutTradeoff hidden when scout active")
    assert(scoutNextLaunch.scoutTradeoff[2] == nil, "INBOX-30: scoutTradeoff hidden when scout active")
    assert(scoutNextLaunch.shipAction == nil, "INBOX-30: shipAction nil when scout active")
    assert(scoutNextLaunch.shipHidden == true, "INBOX-30: shipHidden true when scout active")
    assert(scoutNextLaunch.shipStatus == nil and scoutNextLaunch.shipAffordable == nil,
        "INBOX-30: no shipStatus/shipAffordable when scout active")
    -- INBOX-30: pressing "v" when scout is active is a no-op (no starter switch)
    nextLaunchScene:keypressed("v")
    assert(nextLaunchScene.expedition.selectedShipId == "scout",
        "INBOX-30: v is no-op when scout active")
    local reselectedNextLaunch = nextLaunchScene:shopLoadoutLines()
    assert(reselectedNextLaunch.shipHidden == true,
        "INBOX-30: still hidden after v press")
    -- touch on ship zone is also a no-op
    nextLaunchScene:touchpressed("ship", 540, 670)
    assert(nextLaunchScene.expedition.selectedShipId == "scout",
        "INBOX-30: touch ship zone is no-op when scout active")
    assert(nextLaunchScene:shopLoadoutLines().shipHidden == true,
        "INBOX-30: still hidden after touch")
end

return M