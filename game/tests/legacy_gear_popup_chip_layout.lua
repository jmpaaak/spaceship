local M = {}

function M.run()
    -- INBOX 61(7): gear popup chips must be vertical (one line each)
    local PlayScene = require("game.scenes.play")
    assert(PlayScene.gearPopupChipVertical == true,
        "INBOX 61(7): gearPopupChipVertical flag must be true for vertical stacking")
    print("  INBOX-61(7) gearPopupChipVertical OK")
end

return M
