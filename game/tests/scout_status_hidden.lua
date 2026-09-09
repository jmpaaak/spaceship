local PlayScene = require("game.scenes.play")

local M = {}

local function sceneWithOwnedScout()
    local scene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    scene.expedition.phase = "settlement"
    scene.expedition.ownedShips.scout = true
    return scene
end

function M.run()
    print("  [INBOX 77(3)] purchased scout status text tests...")

    local owned = sceneWithOwnedScout()
    owned.expedition.selectedShipId = "starter"
    local selectable = owned:shopLoadoutLines()
    assert(selectable.shipActionCompact == "SCOUT",
        "an owned inactive scout must remain selectable")
    assert(selectable.shipStatus == nil,
        "an owned scout card must not retain a redundant status label")

    owned.expedition.selectedShipId = "scout"
    local selected = owned:shopLoadoutLines()
    assert(selected.shipHidden and selected.shipStatus == nil,
        "the selected scout must not expose card status text")

    local shopSource = love.filesystem.read("game/scenes/play_shop.lua") or ""
    assert(not shopSource:find("SCOUT \\226\\156\\147", 1, true),
        "the selected scout slot must not render the legacy SCOUT checkmark label")
    print("  INBOX-77(3) purchased scout status text hidden OK")
end

return M