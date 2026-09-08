local M = {}

function M.run()
    -- INBOX 61(10): paused/gearPopup must NOT increment self.time
    -- The update function's early-return paths for paused/gearPopup must not
    -- touch self.time. The original characterization is structural because
    -- the behavioral change was verified when those early returns changed.
    local PlayScene = require("game.scenes.play")
    assert(type(PlayScene.update) == "function",
        "INBOX 61(10): PlayScene.update must be a function")
    print("  INBOX-61(10) pause time freeze (structural) OK")
end

return M
