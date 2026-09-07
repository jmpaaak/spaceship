-- INBOX 61(36): SFX module unit tests
local M = {}

function M.run()
    local sfx = require("game.sfx")

    -- (a) defs table has exactly 3 entries with correct paths
    assert(sfx.defs.galaxy_discover, "INBOX 61(36): galaxy_discover def missing")
    assert(sfx.defs.star_sample,     "INBOX 61(36): star_sample def missing")
    assert(sfx.defs.collision,       "INBOX 61(36): collision def missing")
    assert(sfx.defs.galaxy_discover.path == "assets/sfx/galaxy_discover.mp3",
        "INBOX 61(36): galaxy_discover path")
    assert(sfx.defs.star_sample.path == "assets/sfx/star_sample.mp3",
        "INBOX 61(36): star_sample path")
    assert(sfx.defs.collision.path == "assets/sfx/collision.mp3",
        "INBOX 61(36): collision path")

    -- (b) star_sample is looping, others are not
    assert(sfx.defs.star_sample.loop == true,
        "INBOX 61(36): star_sample must loop")
    assert(sfx.defs.galaxy_discover.loop == false,
        "INBOX 61(36): galaxy_discover must not loop")
    assert(sfx.defs.collision.loop == false,
        "INBOX 61(36): collision must not loop")

    -- (c) headless: play/stop do not crash when love.audio is nil
    sfx.sources = {}
    sfx.played = {}
    sfx.play("collision")
    sfx.play("galaxy_discover", "g:0:0")
    sfx.play("star_sample")
    sfx.stop("star_sample")
    assert(sfx.isPlaying("star_sample") == false,
        "INBOX 61(36): isPlaying false when headless")

    -- (d) uniqueKey dedup: second play with same key is blocked
    sfx.resetGuards()
    sfx.play("galaxy_discover", "g:1:1")
    assert(sfx.played["galaxy_discover:g:1:1"] == true,
        "INBOX 61(36): guard set after play")
    -- Play again — guard should still be true (no crash)
    sfx.play("galaxy_discover", "g:1:1")
    assert(sfx.played["galaxy_discover:g:1:1"] == true,
        "INBOX 61(36): guard persists")
    -- Different key should be allowed
    sfx.play("galaxy_discover", "g:2:2")
    assert(sfx.played["galaxy_discover:g:2:2"] == true,
        "INBOX 61(36): different key allowed")

    -- (e) resetGuards clears all
    sfx.resetGuards()
    assert(next(sfx.played) == nil,
        "INBOX 61(36): resetGuards clears played table")

    -- (f) releaseAll clears sources and guards
    sfx.releaseAll()
    assert(next(sfx.sources) == nil, "INBOX 61(36): releaseAll clears sources")
    assert(next(sfx.played) == nil,  "INBOX 61(36): releaseAll clears played")

    print("  INBOX-61(36) SFX 3종 module OK")
end

return M
