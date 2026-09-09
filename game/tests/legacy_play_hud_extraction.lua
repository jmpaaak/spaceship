local PlayScene = require("game.scenes.play")

local M = {}

function M.run()
    -- INBOX 61(32) play_hud.lua extraction test: drawGearPopup and drawPauseOverlay
    -- must exist on PlayScene (installed from play_hud.lua) and gearPopup drawing
    -- source must live in play_hud.lua, not play.lua.
    assert(type(PlayScene.drawGearPopup) == "function",
        "INBOX 61(32): drawGearPopup must be installed on PlayScene from play_hud.lua")
    assert(type(PlayScene.drawPauseOverlay) == "function",
        "INBOX 61(32): drawPauseOverlay must be installed on PlayScene from play_hud.lua")
    -- Verify the source code lives in play_hud.lua
    local hudSrc = love.filesystem.read("game/scenes/play_hud.lua") or ""
    assert(hudSrc:find("drawGearPopup", 1, true),
        "INBOX 61(32): play_hud.lua must contain drawGearPopup definition")
    assert(hudSrc:find("drawPauseOverlay", 1, true),
        "INBOX 61(32): play_hud.lua must contain drawPauseOverlay definition")
    assert(hudSrc:find("synergyHint", 1, true),
        "INBOX 61(32): play_hud.lua must contain synergy hint drawing")
    -- play.lua must NOT have the inline gearPopup draw block
    local playSrc = love.filesystem.read("game/scenes/play.lua") or ""
    assert(not playSrc:find("Balatro%-style: small tooltip next to the gear slot"),
        "INBOX 61(32): inline gearPopup draw must be removed from play.lua")
    print("  INBOX-61(32) play_hud.lua extraction OK")
end

return M