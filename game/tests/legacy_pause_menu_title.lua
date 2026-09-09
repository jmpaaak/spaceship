local i18n = require("game.i18n")
local PlayScene = require("game.scenes.play")
local exp = require("game.expedition")
local TitleScene = require("game.scenes.title")

local M = {}

-- INBOX 61(21): pause menu buttons + title scene i18n
function M.run()
    -- Check i18n keys exist in both locales
    for _, loc in ipairs({"en", "ko"}) do
        i18n.setLocale(loc)
        for _, key in ipairs({"pause_restart", "pause_main_menu",
            "title_game_name", "title_new_game", "title_continue", "title_settings"}) do
            local val = i18n.t(key)
            assert(val and val ~= key,
                "INBOX 61(21): i18n key '" .. key .. "' missing for locale " .. loc)
        end
    end
    i18n.setLocale("en")

    -- pauseMenuRects returns properly shaped rects
    local rects = PlayScene.pauseMenuRects()
    assert(rects.restart and rects.restart.x and rects.restart.y and rects.restart.w and rects.restart.h,
        "INBOX 61(21): pauseMenuRects must return restart rect")
    assert(rects.mainMenu and rects.mainMenu.x and rects.mainMenu.y and rects.mainMenu.w and rects.mainMenu.h,
        "INBOX 61(21): pauseMenuRects must return mainMenu rect")
    -- mainMenu must be below restart
    assert(rects.mainMenu.y > rects.restart.y,
        "INBOX 61(21): mainMenu button must be below restart button")

    -- Pause restart: tapping restart during pause resets to launch
    local scene = PlayScene.new()
    exp.launch(scene.expedition)
    scene.expedition.altitude = 500
    scene.ship.y = -500
    scene.paused = true
    -- Simulate tap on restart button center
    local rc = rects.restart
    scene:touchpressed("test-restart", rc.x + rc.w / 2, rc.y + rc.h / 2)
    assert(scene.paused == false,
        "INBOX 61(21): restart tap must unpause")
    assert(scene.expedition.phase == "launch",
        "INBOX 61(21): restart must reset phase to launch, got " .. scene.expedition.phase)

    -- Pause main menu: tapping main menu calls onMainMenu callback
    local menuCalled = false
    local scene2 = PlayScene.new({ onMainMenu = function() menuCalled = true end })
    exp.launch(scene2.expedition)
    scene2.paused = true
    local mc = rects.mainMenu
    scene2:touchpressed("test-menu", mc.x + mc.w / 2, mc.y + mc.h / 2)
    assert(menuCalled, "INBOX 61(21): main menu tap must call onMainMenu callback")
    assert(scene2.paused == false, "INBOX 61(21): main menu tap must unpause")

    -- Title scene: new() creates valid object with buttonRects
    local startCalled = false
    local title = TitleScene.new({
        hasSave = false,
        onStart = function() startCalled = true end,
    })
    assert(title, "INBOX 61(21): TitleScene.new must return an object")
    local tRects = title:buttonRects()
    assert(tRects.start and tRects.continue_ and tRects.settings,
        "INBOX 61(21): TitleScene:buttonRects must return start/continue_/settings")
    -- Tap start
    title:touchpressed("test-start", tRects.start.x + 10, tRects.start.y + 10)
    assert(startCalled, "INBOX 61(21): tapping start button must call onStart")
    -- Continue disabled when hasSave=false
    local contCalled = false
    local title2 = TitleScene.new({
        hasSave = false,
        onContinue = function() contCalled = true end,
    })
    title2:touchpressed("test-cont", tRects.continue_.x + 10, tRects.continue_.y + 10)
    assert(not contCalled, "INBOX 61(21): continue must not fire when hasSave=false")
    -- Continue enabled when hasSave=true
    local title3 = TitleScene.new({
        hasSave = true,
        onContinue = function() contCalled = true end,
    })
    title3:touchpressed("test-cont2", tRects.continue_.x + 10, tRects.continue_.y + 10)
    assert(contCalled, "INBOX 61(21): continue must fire when hasSave=true")

    print("  INBOX-61(21) pause menu + title scene OK")
end

return M
