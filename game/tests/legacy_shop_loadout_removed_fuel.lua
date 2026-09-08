local PlayScene = require("game.scenes.play")

local M = {}

function M.run()
    -- Item 11(c) follow-up: the Earth shop's shopLoadoutLines() must not expose
    -- any fuel-upgrade keys (fuelAction/fuelStatus/fuelAffordable/fuelPreview)
    -- now that the fuel upgrade mechanic is fully abolished. This prevents a
    -- future refactor from re-introducing dead fuel UI into the settlement shop.
    local shopScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() end },
    })
    shopScene.expedition.phase = "settlement"
    local loadout = shopScene:shopLoadoutLines()
    assert(loadout.fuelAction == nil,
        "item 11(c): shopLoadoutLines must not expose fuelAction (fuel upgrade abolished)")
    assert(loadout.fuelStatus == nil,
        "item 11(c): shopLoadoutLines must not expose fuelStatus")
    assert(loadout.fuelAffordable == nil,
        "item 11(c): shopLoadoutLines must not expose fuelAffordable")
    assert(loadout.fuelPreview == nil,
        "item 11(c): shopLoadoutLines must not expose fuelPreview")
    -- The shop must still expose the remaining three upgrade rows.
    assert(loadout.hullAction ~= nil,
        "item 11(c): shopLoadoutLines must still expose hullAction")
    assert(loadout.yieldAction ~= nil,
        "item 11(c): shopLoadoutLines must still expose yieldAction")
    assert(loadout.steeringAction ~= nil,
        "item 11(c): shopLoadoutLines must still expose steeringAction")
end

return M
