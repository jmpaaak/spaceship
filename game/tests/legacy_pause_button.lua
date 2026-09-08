local viewport = require("game.viewport")
local PlayScene = require("game.scenes.play")

local M = {}

-- Item 18: Pause button — ascending-only, 44×44 touch area, toggle behaviour.
function M.run()
    -- (a) pauseButton constants exist and are 44×44
    local pb = PlayScene.pauseButton
    assert(pb, "pauseButton must be exported")
    assert(pb.w == 44 and pb.h == 44,
        "pause touch area must be 44×44, got " .. pb.w .. "×" .. pb.h)
    -- Must be in the top-right quadrant
    assert(pb.x >= viewport.width / 2, "pause button must be on the right half")
    assert(pb.y < 60, "pause button must be near the top")

    -- (b) New PlayScene has paused = false
    local scene = PlayScene.new()
    assert(scene.paused == false, "paused must default to false")

    -- (c) touchpressed on pause button during ascending toggles pause
    scene.expedition.phase = "ascending"
    local cx = pb.x + pb.w / 2
    local cy = pb.y + pb.h / 2
    scene:touchpressed(1, cx, cy)
    assert(scene.paused == true, "tap pause button must set paused=true")
    scene:touchpressed(2, cx, cy)
    assert(scene.paused == false, "second tap must toggle paused back to false")

    -- (d) Tap outside pause button while paused unpauses
    scene.paused = true
    scene:touchpressed(3, 100, 600)
    assert(scene.paused == false, "tap anywhere while paused must unpause")

    -- (e) Pause button tap during non-ascending phases does not pause
    scene.expedition.phase = "settlement"
    scene.paused = false
    scene:touchpressed(4, cx, cy)
    assert(scene.paused == false, "pause button must not work during settlement")

    scene.expedition.phase = "destroyed"
    scene:touchpressed(5, cx, cy)
    assert(scene.paused == false, "pause button must not work during destroyed")

    scene.expedition.phase = "launch"
    scene:touchpressed(6, cx, cy)
    assert(scene.paused == false, "pause button must not work during launch")

    -- (f) update with paused=true during ascending returns early (dt=0 effect)
    scene.expedition.phase = "ascending"
    scene.paused = true
    local shipYBefore = scene.ship.y
    scene:update(1.0)
    assert(scene.ship.y == shipYBefore,
        "ship.y must not change while paused")

    -- (g) paused auto-clears if phase changes to non-ascending
    scene.paused = true
    scene.expedition.phase = "settlement"
    scene:update(0.016)
    assert(scene.paused == false,
        "paused must auto-clear when phase is not ascending")
end

return M
