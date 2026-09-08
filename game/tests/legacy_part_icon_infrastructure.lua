local play = require("game.scenes.play")

local M = {}

-- INBOX-61(8): Part icon infrastructure characterization coverage.
function M.run()
    -- getPartIcon function must exist.
    assert(type(play.getPartIcon) == "function",
        "getPartIcon helper must exist")

    -- hudGearSlotSize must remain 48 for INBOX-61(8).
    assert(play.hudGearSlotSize == 48,
        "INBOX-61(8): HUD gear slot size must be 48px, got " .. tostring(play.hudGearSlotSize))

    print("  INBOX-61(8) part icons infrastructure OK")
end

return M