-- INBOX (54): debris hits play the planet collision clip at 1.5x volume (0.9).
local M = {}

function M.run()
    local sfx = require("game.sfx")

    assert(type(sfx.play) == "function", "INBOX (54): sfx.play must exist")

    sfx.resetGuards()
    sfx.lastVolume = nil
    sfx.play("collision")
    assert(sfx.lastVolume == 0.6,
        "INBOX (54): planet collision default volume must stay 0.6, got "
            .. tostring(sfx.lastVolume))

    sfx.play("collision", nil, 0.9)
    assert(sfx.lastVolume == 0.9,
        "INBOX (54): debris collision volume must be 0.9 (1.5x of 0.6), got "
            .. tostring(sfx.lastVolume))

    -- uniqueKey still dedups when volume is passed
    sfx.resetGuards()
    sfx.play("collision", "debris:1", 0.9)
    assert(sfx.played["collision:debris:1"] == true,
        "INBOX (54): uniqueKey guard must set with volume arg")
    sfx.lastVolume = nil
    sfx.play("collision", "debris:1", 0.9)
    assert(sfx.lastVolume == nil,
        "INBOX (54): duplicate uniqueKey must not replay / reset volume")

    local playSrc = love.filesystem.read("game/scenes/play.lua") or ""
    assert(playSrc:find('sfx.play("collision")', 1, true),
        "INBOX (54): planet collision must keep sfx.play(\"collision\")")
    assert(playSrc:find('sfx.play("collision", nil, 0.9)', 1, true),
        "INBOX (54): debris hit must one-line-delegate sfx.play(\"collision\", nil, 0.9)")

    local collisionCalls = 0
    for _ in playSrc:gmatch('sfx%.play%("collision"') do
        collisionCalls = collisionCalls + 1
    end
    assert(collisionCalls == 2,
        "INBOX (54): only planet + debris collision SFX (moon/comet out of scope), got "
            .. tostring(collisionCalls))

    print("  INBOX-54 debris collision SFX 1.5x OK")
end

return M
