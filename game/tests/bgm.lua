-- INBOX 61(42): game-wide BGM is one looping Space orchestral track.
local M = {}

function M.run()
    local bgm = require("game.bgm")
    assert(#bgm.tracks == 1, "INBOX 61(42): one BGM track, not a playlist")
    assert(bgm.tracks[1] == "assets/sfx/space_orchestral.mp3",
        "INBOX 61(42): Space orchestral path, got " .. tostring(bgm.tracks[1]))
    assert(bgm.looping == true, "INBOX 61(42): single track must loop")

    local i18n = require("game.i18n")
    local expected = "BGM: Space — lasercheese (CC-BY 3.0)"
    i18n.setLocale("en")
    assert(i18n.t("title_bgm_credit") == expected, "INBOX 61(42): EN credit")
    i18n.setLocale("ko")
    assert(i18n.t("title_bgm_credit") == expected, "INBOX 61(42): KO credit")
    i18n.setLocale("en")

    bgm.isPlaying = false
    bgm.currentSource = nil
    bgm.start()
    if not (love.audio and love.audio.newSource) then
        assert(bgm.currentSource == nil, "INBOX 61(42): headless audio nil guard")
    end

    local TitleScene = require("game.scenes.title")
    local title = TitleScene.new({})
    title:enter()
    if love.audio and love.audio.newSource then
        assert(bgm.isPlaying, "INBOX 61(42): title enter starts BGM")
        assert(bgm.currentSource:getVolume() == 0.1875, "INBOX (57): BGM volume must be 0.1875")
    end
    print("  INBOX-61(42) Space orchestral BGM OK")
end

return M
