local M = {}

function M.run()
    -- INBOX 61(29): help overlay + luck % + ? button
    -- play_help.lua installed on PlayScene
    local PlayScene = require("game.scenes.play")
    assert(type(PlayScene.drawHelpButton) == "function",
        "INBOX 61(29): drawHelpButton must be installed on PlayScene from play_help.lua")
    assert(type(PlayScene.drawHelpOverlay) == "function",
        "INBOX 61(29): drawHelpOverlay must be installed on PlayScene from play_help.lua")
    assert(type(PlayScene.hitHelpButton) == "function",
        "INBOX 61(29): hitHelpButton must be installed on PlayScene from play_help.lua")
    assert(type(PlayScene.helpButtonRect) == "function",
        "INBOX 61(29): helpButtonRect must be installed on PlayScene from play_help.lua")
    -- Help button rect is RIGHT of pause button (closer to minimap edge)
    local pb = PlayScene.pauseButton
    local hb = PlayScene.helpButtonRect(pb)
    assert(hb.x > pb.x, "INBOX 61(29): help button must be right of pause button")
    assert(hb.w == 44 and hb.h == 44, "INBOX 61(29): help button must be 44x44 touch target")
    -- Luck effect format includes %
    local i18n = require("game.i18n")
    i18n.setLocale("en")
    local luckLine = i18n.effectLine({ type = "luck", value = 10 })
    assert(luckLine == "LUCK +10%",
        "INBOX 61(29): luck effectLine must show percent, got: " .. tostring(luckLine))
    i18n.setLocale("ko")
    local luckLineKo = i18n.effectLine({ type = "luck", value = 10 })
    assert(luckLineKo:find("%%"),
        "INBOX 61(29): Korean luck effectLine must show percent, got: " .. tostring(luckLineKo))
    i18n.setLocale("en")
    -- i18n help keys exist
    for _, key in ipairs({ "help_title", "help_luck", "help_harvest", "help_streak",
                           "help_boost", "help_synergy", "help_slot" }) do
        local val = i18n.t(key)
        assert(val and val ~= key,
            "INBOX 61(29): i18n key " .. key .. " must exist, got: " .. tostring(val))
    end
    -- play_help.lua source exists
    local helpSrc = love.filesystem.read("game/scenes/play_help.lua") or ""
    assert(helpSrc:find("drawHelpOverlay"),
        "INBOX 61(29): play_help.lua must contain drawHelpOverlay")
    assert(helpSrc:find("drawHelpButton"),
        "INBOX 61(29): play_help.lua must contain drawHelpButton")
    print("  INBOX-61(29) help overlay + luck % + ? button OK")
end

return M