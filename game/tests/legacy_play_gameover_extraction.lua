local PlayScene = require("game.scenes.play")

local M = {}

function M.run()
    -- INBOX 61(32) play_gameover.lua extraction test: destroyed-phase layout
    -- and drawBalatroCard must exist on PlayScene (installed from play_gameover.lua)
    -- and the inline code must be removed from play.lua.
    assert(type(PlayScene.destroyedRestartTextY) == "function",
        "INBOX 61(32): destroyedRestartTextY must be installed on PlayScene from play_gameover.lua")
    assert(type(PlayScene.destroyedKeepPartRects) == "function",
        "INBOX 61(32): destroyedKeepPartRects must be installed on PlayScene from play_gameover.lua")
    assert(type(PlayScene.keepConfirmButtons) == "function",
        "INBOX 61(32): keepConfirmButtons must be installed on PlayScene from play_gameover.lua")
    assert(type(PlayScene.drawBalatroCard) == "function",
        "INBOX 61(32): drawBalatroCard must be installed on PlayScene from play_gameover.lua")
    assert(type(PlayScene.handleDestroyedTouch) == "function",
        "INBOX 61(32): handleDestroyedTouch must be installed on PlayScene from play_gameover.lua")
    -- play_gameover.lua must contain the gameover code
    local goSrc = love.filesystem.read("game/scenes/play_gameover.lua") or ""
    assert(goSrc:find("destroyedPanelY"),
        "INBOX 61(32): play_gameover.lua must contain destroyedPanelY")
    assert(goSrc:find("drawBalatroCard"),
        "INBOX 61(32): play_gameover.lua must contain drawBalatroCard")
    -- play.lua must NOT have the inline destroyed layout code
    local playSrc = love.filesystem.read("game/scenes/play.lua") or ""
    assert(not playSrc:find("M%.destroyedPanelY = 340"),
        "INBOX 61(32): inline destroyedPanelY must be removed from play.lua")
    assert(not playSrc:find("function M%.drawBalatroCard"),
        "INBOX 61(32): inline drawBalatroCard must be removed from play.lua")
    print("  INBOX-61(32) play_gameover.lua extraction OK")
end

return M