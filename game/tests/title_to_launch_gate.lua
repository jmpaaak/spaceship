-- INBOX (55): CONTINUE / NEW GAME must land on launch; same-press click-through
-- must not fire expedition.launch. Release, then the next tap launches.
local M = {}

local function stubStore()
    return { load = function() return 0 end, save = function() return false end }
end

function M.run()
    local PlayScene = require("game.scenes.play")
    local TitleScene = require("game.scenes.title")
    local sceneStack = require("game.scene_stack")

    -- Direct PlayScene (existing tests / pause-restart) still launches on tap.
    local direct = PlayScene.new({ bestAltitudeStore = stubStore() })
    assert(direct.expedition.phase == "launch",
        "INBOX (55): PlayScene.new must start in launch")
    direct:touchpressed("direct", 90, 280)
    assert(direct.expedition.phase == "ascending",
        "INBOX (55): a fresh PlayScene tap (not from title) must still launch")

    local function startGame(fresh)
        local play = PlayScene.new({
            bestAltitudeStore = stubStore(),
            fromTitle = true,
        })
        if fresh then
            play.expedition.phase = "launch"
        end
        return play
    end

    -- NEW GAME: title tap must not consume the same press as TAP TO LAUNCH.
    local playFromNew
    local title = TitleScene.new({
        hasSave = false,
        onNewGame = function()
            playFromNew = startGame(true)
        end,
    })
    local stack = sceneStack.new(title)
    local rects = title:buttonRects()
    stack.current:touchpressed("mouse", rects.newGame.x + 10, rects.newGame.y + 10)
    sceneStack.switch(stack, playFromNew)
    assert(stack.current.expedition.phase == "launch",
        "INBOX (55): NEW GAME must enter PlayScene at phase=launch")

    -- Same finger/mouse still down: PlayScene must ignore this press.
    stack.current:touchpressed("mouse", 360, 640)
    assert(stack.current.expedition.phase == "launch",
        "INBOX (55): same-press click-through must not launch, got "
            .. tostring(stack.current.expedition.phase))

    -- Held keypressed("space") from the same click also blocked.
    stack.current:keypressed("space")
    assert(stack.current.expedition.phase == "launch",
        "INBOX (55): held space/click-through must not launch")

    -- Release, then the next tap launches.
    stack.current:touchreleased("mouse")
    stack.current:update(0.1)
    stack.current:touchpressed("tap2", 360, 640)
    assert(stack.current.expedition.phase == "ascending",
        "INBOX (55): after release, the next tap must launch")

    -- CONTINUE also starts at launch and needs a second tap.
    local playFromContinue
    local title2 = TitleScene.new({
        hasSave = true,
        onContinue = function()
            playFromContinue = startGame(false)
        end,
    })
    title2:touchpressed("cont", title2:buttonRects().continue_.x + 10,
        title2:buttonRects().continue_.y + 10)
    assert(playFromContinue, "INBOX (55): CONTINUE must create PlayScene")
    assert(playFromContinue.expedition.phase == "launch",
        "INBOX (55): CONTINUE must enter PlayScene at phase=launch, got "
            .. tostring(playFromContinue.expedition.phase))
    playFromContinue:touchpressed("mouse", 100, 100)
    assert(playFromContinue.expedition.phase == "launch",
        "INBOX (55): CONTINUE same-press must not launch")
    playFromContinue:touchreleased("mouse")
    playFromContinue:update(0.1)
    playFromContinue:touchpressed("tap2", 100, 100)
    assert(playFromContinue.expedition.phase == "ascending",
        "INBOX (55): CONTINUE second tap must launch")

    -- Keyboard NEW GAME is a discrete press: land on launch, then space fires.
    local playFromKey
    local title3 = TitleScene.new({
        hasSave = false,
        onNewGame = function()
            playFromKey = startGame(true)
        end,
    })
    title3:keypressed("space")
    assert(playFromKey.expedition.phase == "launch",
        "INBOX (55): keyboard NEW GAME must land on launch, not auto-ascend")
    playFromKey:update(0.1)
    playFromKey:keypressed("space")
    assert(playFromKey.expedition.phase == "ascending",
        "INBOX (55): after title keyboard start, space on launch must fire")

    -- main.lua startGame must force launch for both fresh and continue.
    local mainSrc = love.filesystem.read("main.lua") or ""
    assert(mainSrc:find("fromTitle", 1, true),
        "INBOX (55): main.lua startGame must mark PlayScene as fromTitle")
    local launchAssignes = 0
    for _ in mainSrc:gmatch('play%.expedition%.phase = "launch"') do
        launchAssignes = launchAssignes + 1
    end
    assert(launchAssignes >= 1,
        "INBOX (55): startGame must set phase=launch")
    -- Both onNewGame and onContinue go through startGame; continue must not skip launch.
    assert(mainSrc:find("onContinue = function() startGame(false)", 1, true)
        or mainSrc:find("onContinue = function() startGame(false) end", 1, true),
        "INBOX (55): CONTINUE must call startGame")

    local joySrc = love.filesystem.read("game/scenes/play_joystick.lua") or ""
    assert(joySrc:find("launchInputArmed", 1, true),
        "INBOX (55): play_joystick.lua must gate launch mouse-down on launchInputArmed")

    print("  INBOX-55 title to launch click-through gate OK")
end

return M
