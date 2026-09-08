local PlayScene = require("game.scenes.play")

local M = {}

function M.run()
    -- Regression: a real LÖVE runtime capture after the launch-screen
    -- text/layout cleanup still showed a faint blue crescent peeking out
    -- above the LAUNCH LOADOUT card's opaque box -- the top edge of the
    -- Earth disc drawn behind the scene (center y=75-cameraY, radius 58)
    -- pokes above the box's top edge by a couple of pixels. Assert the
    -- box's top y is at or above the Earth disc's topmost extent for a
    -- ship parked at the world origin (the launch-phase ship position),
    -- so the disc can never render above the box again.
    local shipScreenY = math.floor(1280 * 0.58)
    local cameraY = 0 - shipScreenY
    local earthY = math.floor(75 - cameraY)
    local earthTopY = earthY - 58
    assert(PlayScene.launchLoadoutBoxTop <= earthTopY,
        "launch loadout box top (" .. PlayScene.launchLoadoutBoxTop ..
        ") does not fully cover the Earth disc's top edge (" .. earthTopY .. ")")

    -- docs/feedback/INBOX.md UI/HUD item 4: the "LAUNCH LOADOUT"/"발사 장비"
    -- panel title itself was flagged for removal -- the card's contents
    -- (hull/upgrades/steering/odds) are self-explanatory once
    -- rendered inside an obviously bordered box directly below the Earth
    -- disc, so a redundant caption line just eats vertical space without
    -- adding information. M.showLaunchLoadoutTitle gates the title printf
    -- in draw(); this regression pins it to false so the caption line and
    -- its row-step gap stay removed.
    assert(PlayScene.showLaunchLoadoutTitle == false,
        "launch loadout panel title should stay hidden (docs/feedback item 4)")

    -- Mobile-UI sub-item (5): loadout panel positioned at bottom 1/3 of
    -- the 720×1280 canvas, gear slot boxes enlarged 1.5×, launch touch
    -- area covers full canvas, and loadout row step is mobile-friendly.
    assert(PlayScene.launchLoadoutBoxTop >= 700,
        "loadout panel should start near bottom 1/3 of 1280px canvas, got " .. PlayScene.launchLoadoutBoxTop)
    assert(PlayScene.launchLoadoutBoxTop <= earthTopY,
        "loadout panel top (" .. PlayScene.launchLoadoutBoxTop ..
        ") must still cover Earth disc top (" .. earthTopY .. ")")
    assert(PlayScene.launchLoadoutRowStep >= 20,
        "loadout row step should be ≥20px for mobile readability, got " .. PlayScene.launchLoadoutRowStep)
    assert(PlayScene.launchGearBoxW >= 15,
        "gear slot box width should be ≥15px (1.5× old 10px), got " .. PlayScene.launchGearBoxW)
    assert(PlayScene.launchGearBoxH >= 21,
        "gear slot box height should be ≥21px (1.5× old 14px), got " .. PlayScene.launchGearBoxH)
    assert(PlayScene.launchTouchArea.right >= 720,
        "launch touch area should span full 720px canvas width, got right=" .. PlayScene.launchTouchArea.right)
    assert(PlayScene.launchTouchArea.bottom >= 1280,
        "launch touch area should span full 1280px canvas height, got bottom=" .. PlayScene.launchTouchArea.bottom)
    assert(PlayScene.launchLoadoutFontSize >= 12,
        "loadout font should be ≥12px for mobile, got " .. PlayScene.launchLoadoutFontSize)
end

return M
