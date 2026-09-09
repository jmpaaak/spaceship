-- INBOX (60): hub_sample plays only on first hub explore / hub sample.
-- Must not mix with ordinary planet collect or the star-well star_sample loop.
local M = {}

function M.run()
    local sfx = require("game.sfx")

    assert(sfx.defs.hub_sample, "INBOX (60): hub_sample def missing")
    assert(sfx.defs.hub_sample.path == "assets/sfx/hub_sample.mp3",
        "INBOX (60): hub_sample path must be assets/sfx/hub_sample.mp3")
    assert(sfx.defs.hub_sample.loop == false,
        "INBOX (60): hub_sample must be oneshot, not a loop")
    assert(sfx.defs.star_sample and sfx.defs.star_sample.loop == true,
        "INBOX (60): star_sample loop must stay separate")
    assert(sfx.defs.collect and sfx.defs.collect.path == "assets/sfx/collect.mp3",
        "INBOX (60): ordinary collect clip must stay collect.mp3")

    local data = love.filesystem.read("assets/sfx/hub_sample.mp3")
    assert(type(data) == "string" and #data > 1000,
        "INBOX (60): missing hub_sample clip assets/sfx/hub_sample.mp3")

    sfx.resetGuards()
    sfx.play("hub_sample")
    sfx.play("collect")
    sfx.play("star_sample")
    sfx.stop("star_sample")

    local playSrc = love.filesystem.read("game/scenes/play_update.lua") or ""
    assert(playSrc:find('sfx.play("hub_sample")', 1, true),
        "INBOX (60): play_update.lua must one-line-delegate sfx.play(\"hub_sample\")")
    assert(playSrc:find('sfx.play("collect")', 1, true),
        "INBOX (60): ordinary planet collect must keep sfx.play(\"collect\")")
    assert(playSrc:find('sfx.play("star_sample")', 1, true),
        "INBOX (60): star well must keep sfx.play(\"star_sample\")")

    local hubCalls = 0
    for _ in playSrc:gmatch('sfx%.play%("hub_sample"') do
        hubCalls = hubCalls + 1
    end
    assert(hubCalls == 1,
        "INBOX (60): hub_sample must be a single one-line call, got " .. tostring(hubCalls))

    local hubPlanetIdx = playSrc:find("if planet.hub then", 1, true)
    local shopIdx = playSrc:find("elseif planet.isShop then", 1, true)
    local hubPlayIdx = playSrc:find('sfx.play("hub_sample")', 1, true)
    local hubCheckpoint = playSrc:find("Hub checkpoint proximity", 1, true)
    assert(hubPlanetIdx and shopIdx and hubPlayIdx and hubCheckpoint,
        "INBOX (60): hub / shop / hub_sample / star-well markers missing")
    assert(hubPlayIdx > hubPlanetIdx and hubPlayIdx < shopIdx,
        "INBOX (60): hub_sample must sit in the planet.hub first-explore branch")
    assert(hubPlayIdx > hubCheckpoint,
        "INBOX (60): hub_sample must not play in the star-well 10s survival block")

    local starWellExplore = playSrc:find("Engine part drop on star sample", 1, true)
    if starWellExplore then
        assert(hubPlayIdx > starWellExplore,
            "INBOX (60): star-well exploreHub must not play hub_sample")
    end

    print("  INBOX-60 hub_sample SFX OK")
end

return M
