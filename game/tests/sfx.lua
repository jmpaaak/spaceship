-- INBOX 61(36): SFX module unit tests
local M = {}

function M.run()
    local sfx = require("game.sfx")

    -- (a) defs table has exactly 3 entries with correct paths
    assert(sfx.defs.galaxy_discover, "INBOX 61(36): galaxy_discover def missing")
    assert(sfx.defs.star_sample,     "INBOX 61(36): star_sample def missing")
    assert(sfx.defs.collision,       "INBOX 61(36): collision def missing")
    assert(sfx.defs.collect,         "INBOX 61(50): collect def missing")
    assert(sfx.defs.slot_spin,       "INBOX 61(50): slot_spin def missing")
    assert(sfx.defs.boost,           "INBOX 61(50): boost def missing")
    assert(sfx.defs.galaxy_discover.path == "assets/sfx/galaxy_discover.mp3",
        "INBOX 61(36): galaxy_discover path")
    assert(sfx.defs.star_sample.path == "assets/sfx/star_sample.mp3",
        "INBOX 61(36): star_sample path")
    assert(sfx.defs.collision.path == "assets/sfx/collision.mp3",
        "INBOX 61(36): collision path")
    assert(sfx.defs.collect.path == "assets/sfx/collect.mp3",
        "INBOX (59): collect must use the former collision clip")
    assert(sfx.defs.slot_spin.path == "assets/sfx/slot_spin.ogg",
        "INBOX (50): slot_spin path")
    assert(sfx.defs.boost.path == "assets/sfx/boost.ogg",
        "INBOX (50): boost path")

    -- (b) star_sample is looping, others are not
    assert(sfx.defs.star_sample.loop == true,
        "INBOX 61(36): star_sample must loop")
    assert(sfx.defs.galaxy_discover.loop == false,
        "INBOX 61(36): galaxy_discover must not loop")
    assert(sfx.defs.collision.loop == false,
        "INBOX 61(36): collision must not loop")
    assert(sfx.defs.collect.loop == false,   "INBOX (50): collect must not loop")
    assert(sfx.defs.slot_spin.loop == false, "INBOX (50): slot_spin must not loop")
    assert(sfx.defs.boost.loop == false,     "INBOX (50): boost must not loop")

    -- INBOX (50): CC0 files exist and play sites are wired
    local function assertSfxFile(path, magic, label)
        local data = love.filesystem.read(path)
        assert(type(data) == "string" and #data > 1000,
            "INBOX (50): missing " .. label .. " " .. path)
        assert(data:sub(1, #magic) == magic,
            "INBOX (50): " .. path .. " must start with " .. label)
    end
    assertSfxFile("assets/sfx/collect.mp3", string.char(255), "MP3")
    local collectData = love.filesystem.read("assets/sfx/collect.mp3")
    assert(#collectData == 229041,
        "INBOX (59): collect must preserve the complete former collision clip")
    assertSfxFile("assets/sfx/slot_spin.ogg", "OggS", "OGG")
    assertSfxFile("assets/sfx/boost.ogg", "OggS", "OGG")

    local playSrc = love.filesystem.read("game/scenes/play_update.lua") or ""
    local slotSrc = love.filesystem.read("game/scenes/play_slot.lua") or ""
    local boostSrc = love.filesystem.read("game/scenes/play_boost.lua") or ""
    assert(playSrc:find('sfx.play("collect")', 1, true),
        "INBOX (50): play_update.lua must play collect")
    assert(slotSrc:find('sfx.play("slot_spin")', 1, true),
        "INBOX (50): play_slot.lua must play slot_spin")
    assert(boostSrc:find('sfx.play("boost")', 1, true),
        "INBOX (50): play_boost.lua must play boost")

    -- INBOX (62): slot_spin def volume is 0.3 (half of global 0.6).
    -- play_slot.lua stays a one-line sfx.play("slot_spin") — def overrides.
    assert(sfx.defs.slot_spin.volume == 0.3,
        "INBOX (62): slot_spin def volume must be 0.3, got "
            .. tostring(sfx.defs.slot_spin.volume))
    assert(sfx.defs.collision.volume == nil,
        "INBOX (62): other SFX defs must not gain a volume field")
    assert(sfx.defs.collect.volume == nil,
        "INBOX (62): collect volume must stay global default")
    assert(sfx.defs.boost.volume == nil,
        "INBOX (62): boost volume must stay global default")
    assert(sfx.defs.galaxy_discover.volume == nil,
        "INBOX (62): galaxy_discover volume must stay global default")
    assert(sfx.defs.star_sample.volume == nil,
        "INBOX (62): star_sample volume must stay global default")
    assert(sfx.defs.hub_sample.volume == nil,
        "INBOX (62): hub_sample volume must stay global default")
    local playSlotSrc = love.filesystem.read("game/scenes/play_slot.lua") or ""
    local slotPlayCount = 0
    for _ in playSlotSrc:gmatch('sfx%.play%("slot_spin"%)') do
        slotPlayCount = slotPlayCount + 1
    end
    assert(slotPlayCount == 1,
        "INBOX (62): play_slot.lua must keep one sfx.play(\"slot_spin\") line, got "
            .. tostring(slotPlayCount))
    assert(not playSlotSrc:find('sfx.play("slot_spin",', 1, true),
        "INBOX (62): play_slot.lua must not pass volume to sfx.play")

    sfx.resetGuards()
    sfx.lastVolume = nil
    sfx.play("slot_spin")
    assert(sfx.lastVolume == 0.3,
        "INBOX (62): sfx.play(\"slot_spin\") volume must be 0.3, got "
            .. tostring(sfx.lastVolume))
    sfx.lastVolume = nil
    sfx.play("collision")
    assert(sfx.lastVolume == 0.6,
        "INBOX (62): other SFX must keep global 0.6, got "
            .. tostring(sfx.lastVolume))

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

    print("  INBOX-61(36) SFX 3종 + INBOX (50) collect/slot/boost OK")
end

return M
