local PlayScene = require("game.scenes.play")
local expedition = require("game.expedition")

local M = {}

-- INBOX-58: Hub shop relaunch touch must work.
-- Simulates a hub settlement then taps the relaunch row to ensure
-- the touch triggers expedition.launch and transitions to ascending.
function M.run()
    local hubScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() end },
    })
    -- Simulate hub settlement: set phase, store hub position
    hubScene.expedition.phase = "settlement"
    hubScene.expedition.lastHubX = 200
    hubScene.expedition.lastHubY = -3000
    hubScene.expedition.lastVisitedGalaxyId = "andromeda"
    hubScene.expedition.money = 100

    -- (a) Verify the relaunch touch row coordinates are valid
    local relaunchRow = PlayScene.settlementTouchRows[5]
    assert(relaunchRow, "INBOX-58(a): settlementTouchRows[5] must exist")
    assert(relaunchRow.key == "relaunch",
        "INBOX-58(a): row 5 key must be 'relaunch', got " .. tostring(relaunchRow.key))
    assert(relaunchRow.top < relaunchRow.bottom,
        "INBOX-58(a): relaunch row top must be < bottom")
    assert(relaunchRow.bottom <= 1280,
        "INBOX-58(a): relaunch row bottom must be within 1280 canvas, got " .. relaunchRow.bottom)

    -- (b) Touch the relaunch row at its vertical center
    local touchY = (relaunchRow.top + relaunchRow.bottom) / 2
    local touchX = 360  -- horizontal center of 720-wide canvas
    hubScene:touchpressed("hub-relaunch", touchX, touchY)
    assert(hubScene.expedition.phase == "ascending",
        "INBOX-58(b): tapping relaunch row at hub settlement must transition to ascending, got "
        .. tostring(hubScene.expedition.phase))

    -- (c) After hub relaunch, ship should spawn near the hub, not Earth
    assert(hubScene.ship.x == 200,
        "INBOX-58(c): hub relaunch must set ship.x to hubX, got " .. tostring(hubScene.ship.x))
    assert(hubScene.ship.y == -3000 - 80,
        "INBOX-58(c): hub relaunch must set ship.y to hubY-80, got " .. tostring(hubScene.ship.y))
    assert(hubScene.hasLeftEarth == true,
        "INBOX-58(c): hub relaunch must set hasLeftEarth true")

    -- (d) After hub relaunch, lastHubX/Y must be cleared
    assert(hubScene.expedition.lastHubX == nil,
        "INBOX-58(d): launch must clear lastHubX")
    assert(hubScene.expedition.lastHubY == nil,
        "INBOX-58(d): launch must clear lastHubY")

    -- (e) Verify keypressed("space") also works (keyboard relaunch at hub)
    local hubScene2 = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() end },
    })
    hubScene2.expedition.phase = "settlement"
    hubScene2.expedition.lastHubX = 150
    hubScene2.expedition.lastHubY = -2000
    hubScene2.expedition.lastVisitedGalaxyId = "triangulum"
    hubScene2:keypressed("space")
    assert(hubScene2.expedition.phase == "ascending",
        "INBOX-58(e): space key at hub settlement must transition to ascending, got "
        .. tostring(hubScene2.expedition.phase))
    assert(hubScene2.ship.x == 150,
        "INBOX-58(e): space key hub relaunch must set ship.x to hubX")
    assert(hubScene2.hasLeftEarth == true,
        "INBOX-58(e): space key hub relaunch must set hasLeftEarth true")

    print("  INBOX-58 hub shop relaunch touch OK")
end

return M
