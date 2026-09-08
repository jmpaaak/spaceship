-- INBOX (53): CONTINUE / NEW GAME must not play a departure/discover SFX.
-- Home/start galaxy skips galaxy_discover; title buttons have no tap SFX; BGM stays.
local M = {}

function M.run()
    local sfx = require("game.sfx")
    local TitleScene = require("game.scenes.title")
    local bgm = require("game.bgm")

    assert(type(sfx.playGalaxyDiscover) == "function",
        "INBOX (53): sfx.playGalaxyDiscover must exist (play.lua one-line delegate only)")

    sfx.resetGuards()
    sfx.playGalaxyDiscover({ id = "milkyway", gx = 0, gy = 0 })
    assert(sfx.played["galaxy_discover:milkyway"] == nil,
        "INBOX (53): home galaxy milkyway must skip galaxy_discover")

    sfx.resetGuards()
    sfx.playGalaxyDiscover({ id = "galaxy:0:0", gx = 0, gy = 0 })
    assert(sfx.played["galaxy_discover:galaxy:0:0"] == nil,
        "INBOX (53): start cell (0,0) must skip galaxy_discover")

    sfx.resetGuards()
    sfx.playGalaxyDiscover(nil)
    assert(next(sfx.played) == nil,
        "INBOX (53): nil galaxy must not play")

    sfx.resetGuards()
    sfx.playGalaxyDiscover({ id = "galaxy:2:3", gx = 2, gy = 3 })
    assert(sfx.played["galaxy_discover:galaxy:2:3"] == true,
        "INBOX (53): non-home galaxy must still play galaxy_discover")

    local titleSrc = love.filesystem.read("game/scenes/title.lua") or ""
    assert(not titleSrc:find("sfx.play", 1, true),
        "INBOX (53): title CONTINUE/NEW GAME must not play a button/tap SFX")
    assert(titleSrc:find("bgm.start", 1, true),
        "INBOX (53): title must keep BGM start")

    local title = TitleScene.new({})
    bgm.isPlaying = false
    bgm.currentSource = nil
    title:enter()
    if love.audio and love.audio.newSource then
        assert(bgm.isPlaying, "INBOX (53): title enter must still start BGM")
    end

    local playSrc = love.filesystem.read("game/scenes/play.lua") or ""
    assert(playSrc:find("sfx.playGalaxyDiscover(wellGalaxy)", 1, true),
        "INBOX (53): play.lua must one-line-delegate galaxy discover")
    assert(not playSrc:find('sfx.play("galaxy_discover"', 1, true),
        "INBOX (53): play.lua must not call sfx.play(\"galaxy_discover\") directly")

    print("  INBOX-53 title start SFX skip OK")
end

return M
