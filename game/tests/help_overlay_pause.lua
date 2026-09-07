-- INBOX (48): help overlay freezes play time like pause, without the pause menu.
local M = {}

function M.run()
    local PlayScene = require("game.scenes.play")
    local scene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    scene.expedition.phase = "ascending"
    scene.helpOverlayOpen = true
    scene.paused = false
    local t0 = scene.time
    local y0 = scene.ship.y
    scene:update(1.0)
    assert(scene.time == t0,
        "INBOX (48): self.time must freeze while help overlay is open, got "
            .. tostring(scene.time) .. " from " .. tostring(t0))
    assert(scene.ship.y == y0,
        "INBOX (48): ship must not move while help overlay is open")
    assert(scene.paused == false,
        "INBOX (48): help overlay must not set paused / open the pause menu")
    assert(scene.helpOverlayOpen == true,
        "INBOX (48): overlay stays open until tap")

    scene:touchpressed(1, 100, 600)
    assert(scene.helpOverlayOpen == false,
        "INBOX (48): tap anywhere must close help overlay")
    assert(scene.paused == false,
        "INBOX (48): closing help must not open the pause menu")

    local t1 = scene.time
    scene:update(0.5)
    assert(scene.time > t1,
        "INBOX (48): time must resume after help closes")

    assert(type(PlayScene.shouldFreezeUpdate) == "function",
        "INBOX (48): play_help must install shouldFreezeUpdate on PlayScene")

    print("  INBOX-48 help overlay freezes play time OK")
end

return M
