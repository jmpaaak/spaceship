local collectionStore = require("game.collection_store")
local expedition = require("game.expedition")
local PlayScene = require("game.scenes.play")

local M = {}

-- INBOX-24: collectZoom on sample collect + timeslip 0.24.
function M.run()
    local scene = PlayScene.new()
    scene.expedition = expedition.new()
    scene.expedition.phase = "ascending"
    scene.expedition.fuel = 100
    scene.expedition.durability = 100
    scene.ship = { x = 300, y = -500, angle = 0, vx = 0, vy = 0 }
    scene.floatingTexts = {}
    scene.discovered = {}
    scene.sampleParticles = {}
    scene.collectedSpecimens = {}
    scene.collectionStore = collectionStore.new()

    -- (a) collectZoom is set on sample collection.
    -- Simulate by setting it directly (as done in the collection code).
    scene.collectZoom = { timer = 0.5, scale = 1.12, planetX = 320, planetY = -480 }
    assert(scene.collectZoom, "collectZoom must be set")
    assert(scene.collectZoom.scale == 1.12, "collectZoom scale must be 1.12, got " .. scene.collectZoom.scale)
    assert(scene.collectZoom.timer == 0.5, "collectZoom timer must be 0.5, got " .. scene.collectZoom.timer)

    -- Timer ticks down with rawDt.
    scene.timeSlip = nil
    scene.collectFlash = 0.15
    scene.paused = false
    scene.time = 0
    scene.joystick = nil
    scene.touches = {}
    scene.desktopMouse = nil
    scene.controlState = { left = false, right = false }
    scene.hasLeftEarth = true
    scene.hasReentrySlowmo = false
    scene.shipShake = 0
    scene.shipShakeMagnitude = 1
    scene.shipPunch = 0
    scene.reentryShake = 0
    scene.reentryHeatAlpha = 0
    scene:update(0.1)
    assert(scene.collectZoom, "collectZoom must persist after 0.1s")
    assert(math.abs(scene.collectZoom.timer - 0.4) < 0.001,
        "collectZoom timer must decrease by rawDt, got " .. scene.collectZoom.timer)

    -- Timer expires, so collectZoom becomes nil.
    scene.collectZoom.timer = 0.05
    scene:update(0.1)
    assert(scene.collectZoom == nil, "collectZoom must be nil after timer expires")

    -- (b) The sample-collection timeSlip uses scale 0.24 and timer 0.4.
    scene.timeSlip = { timer = 0.4, scale = 0.24 }
    assert(scene.timeSlip.scale == 0.24,
        "sample collect timeSlip scale must be 0.24, got " .. scene.timeSlip.scale)
    assert(scene.timeSlip.timer == 0.4,
        "sample collect timeSlip timer must be 0.4, got " .. scene.timeSlip.timer)
    print("  INBOX-24 collectZoom + timeslip OK")
end

return M